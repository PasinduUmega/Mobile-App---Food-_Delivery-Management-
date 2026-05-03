import { COLL, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';
import {
  assertCartAddAllowed,
  assertCartLineQtyUpdate,
} from '../services/cartValidation.service.js';
import { dbUserIsAdmin } from '../services/userAccess.service.js';
import { readActorUserId } from '../utils/requestUser.js';
import { asInt } from '../utils/parsers.js';

export async function auditCarts(req, res) {
  const actor = readActorUserId(req);
  if (!(await dbUserIsAdmin(actor))) {
    return res.status(403).json({ error: 'Only administrators can list cart history' });
  }
  const limit = Math.min(500, asInt(req.query?.limit) || 200);
  try {
    const carts = await coll('carts').find().sort({ id: -1 }).limit(limit).toArray();
    const rows = [];
    for (const c of carts) {
      const line_count = await coll('cartItems').countDocuments({ cart_id: c.id });
      rows.push({ ...c, line_count });
    }
    res.json({ items: rows });
  } catch (e) {
    console.error('carts/audit', e);
    res.status(500).json({ error: 'Failed to list carts' });
  }
}

export async function getUserCart(req, res) {
  const userId = asInt(req.params.userId);
  if (!userId) {
    return res.status(400).json({ error: 'invalid userId' });
  }

  try {
    const cart = await coll('carts').findOne({ user_id: userId, status: 'ACTIVE' }, { sort: { created_at: -1 } });

    if (!cart) {
      return res.json(null);
    }

    const items = await coll('cartItems').find({ cart_id: cart.id }).sort({ created_at: 1 }).toArray();

    res.json({
      ...cart,
      items: items || [],
    });
  } catch (e) {
    console.error('Error fetching cart:', e);
    res.status(500).json({ error: 'Failed to fetch cart' });
  }
}

export async function createOrGetCart(req, res) {
  const userId = asInt(req.body.userId);
  const storeId = asInt(req.body.storeId);

  if (!userId) {
    return res.status(400).json({ error: 'userId required' });
  }

  try {
    const existing = await coll('carts').findOne({ user_id: userId, status: 'ACTIVE' });

    if (existing) {
      const items = await coll('cartItems').find({ cart_id: existing.id }).sort({ created_at: 1 }).toArray();
      return res.status(201).json({
        ...existing,
        items: items || [],
      });
    }

    const cartId = await nextSeq(COLL.carts);
    const now = new Date();
    await coll('carts').insertOne({
      id: cartId,
      user_id: userId,
      store_id: storeId || null,
      status: 'ACTIVE',
      created_at: now,
      updated_at: now,
      checked_out_at: null,
    });

    const newCart = await coll('carts').findOne({ id: cartId });

    res.status(201).json({
      ...newCart,
      items: [],
    });
  } catch (e) {
    console.error('Error creating cart:', e);
    res.status(500).json({ error: 'Failed to create cart' });
  }
}

export async function addCartItem(req, res) {
  const cartId = asInt(req.params.cartId);
  const { productId, name, qty, unitPrice } = req.body || {};
  const lineNoteRaw = req.body?.lineNote;
  const lineNote = lineNoteRaw != null && String(lineNoteRaw).trim()
    ? String(lineNoteRaw).trim().slice(0, 500)
    : null;

  if (!cartId || !productId || !name || !qty || unitPrice === undefined) {
    return res.status(400).json({ error: 'cartId, productId, name, qty, unitPrice required' });
  }

  if (!Number.isFinite(qty) || qty <= 0 || !Number.isFinite(unitPrice) || unitPrice < 0) {
    return res.status(400).json({ error: 'invalid qty or unitPrice' });
  }

  try {
    await assertCartAddAllowed(null, { cartId, productId, addQty: qty });
    const existing = await coll('cartItems').findOne({ cart_id: cartId, product_id: productId });
    const now = new Date();

    if (existing) {
      const newQty = existing.qty + qty;
      await coll('cartItems').updateOne(
        { id: existing.id },
        {
          $set: {
            qty: newQty,
            line_note: lineNote != null ? lineNote : existing.line_note,
            updated_at: now,
          },
        },
      );
    } else {
      const cid = await nextSeq(COLL.cartItems);
      await coll('cartItems').insertOne({
        id: cid,
        cart_id: cartId,
        product_id: productId,
        name,
        qty,
        unit_price: unitPrice,
        line_note: lineNote,
        created_at: now,
        updated_at: now,
      });
    }
  } catch (e) {
    if (e.code === 'BAD') {
      return res.status(400).json({ error: e.message });
    }
    console.error('Error adding to cart:', e);
    return res.status(500).json({ error: 'Failed to add to cart' });
  }

  try {
    const items = await coll('cartItems').find({ cart_id: cartId }).sort({ created_at: 1 }).toArray();
    res.json({ success: true, items: items || [] });
  } catch (e) {
    console.error('Error loading cart after add:', e);
    res.status(500).json({ error: 'Failed to load cart items' });
  }
}

export async function updateCartItemQty(req, res) {
  const cartId = asInt(req.params.cartId);
  const itemId = asInt(req.params.itemId);
  const newQty = asInt(req.body?.qty);

  if (!cartId || !itemId || (!newQty && newQty !== 0)) {
    return res.status(400).json({ error: 'invalid params' });
  }

  try {
    if (newQty <= 0) {
      await coll('cartItems').deleteOne({ id: itemId, cart_id: cartId });
    } else {
      await assertCartLineQtyUpdate(null, { cartId, itemId, newQty });
      await coll('cartItems').updateOne(
        { id: itemId, cart_id: cartId },
        { $set: { qty: newQty, updated_at: new Date() } },
      );
    }

    const items = await coll('cartItems').find({ cart_id: cartId }).sort({ created_at: 1 }).toArray();
    res.json({ success: true, items: items || [] });
  } catch (e) {
    if (e.code === 'BAD') {
      return res.status(400).json({ error: e.message });
    }
    console.error('Error updating cart item:', e);
    res.status(500).json({ error: 'Failed to update cart item' });
  }
}

export async function deleteCartLine(req, res) {
  const cartId = asInt(req.params.cartId);
  const itemId = asInt(req.params.itemId);

  if (!cartId || !itemId) {
    return res.status(400).json({ error: 'invalid params' });
  }

  try {
    await coll('cartItems').deleteOne({ id: itemId, cart_id: cartId });

    const items = await coll('cartItems').find({ cart_id: cartId }).sort({ created_at: 1 }).toArray();
    res.json({ success: true, items: items || [] });
  } catch (e) {
    console.error('Error removing from cart:', e);
    res.status(500).json({ error: 'Failed to remove item from cart' });
  }
}

export async function abandonCart(req, res) {
  const cartId = asInt(req.params.cartId);

  if (!cartId) {
    return res.status(400).json({ error: 'invalid cartId' });
  }

  try {
    await coll('carts').updateOne({ id: cartId }, { $set: { status: 'ABANDONED', updated_at: new Date() } });
    res.json({ success: true });
  } catch (e) {
    console.error('Error clearing cart:', e);
    res.status(500).json({ error: 'Failed to clear cart' });
  }
}

export async function checkoutCart(req, res) {
  const cartId = asInt(req.params.cartId);

  if (!cartId) {
    return res.status(400).json({ error: 'invalid cartId' });
  }

  try {
    await coll('carts').updateOne(
      { id: cartId },
      { $set: { status: 'CHECKED_OUT', checked_out_at: new Date(), updated_at: new Date() } },
    );
    res.json({ success: true });
  } catch (e) {
    console.error('Error checking out cart:', e);
    res.status(500).json({ error: 'Failed to checkout cart' });
  }
}
