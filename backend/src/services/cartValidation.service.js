import { MAX_CART_LINE_QTY } from '../models/constants.js';
import { coll } from '../repositories/mongo.repository.js';
import { asInt } from '../utils/parsers.js';

/** Stock + store match + max line qty before adding to cart. */
export async function assertCartAddAllowed(_, { cartId, productId, addQty }) {
  const cartIdN = asInt(cartId);
  const productIdN = asInt(productId);
  const add = Number(addQty);
  if (!cartIdN || !productIdN || !Number.isFinite(add) || add <= 0) {
    throw Object.assign(new Error('invalid cart or product'), { code: 'BAD' });
  }
  const cart = await coll('carts').findOne({ id: cartIdN });
  if (!cart) throw Object.assign(new Error('cart not found'), { code: 'BAD' });
  const menu = await coll('menuItems').findOne({ id: productIdN });
  if (!menu) throw Object.assign(new Error('menu item not found'), { code: 'BAD' });
  if (cart.store_id != null && Number(menu.store_id) !== Number(cart.store_id)) {
    throw Object.assign(new Error('This item is not from the restaurant tied to your cart'), { code: 'BAD' });
  }
  const inv = await coll('inventory').findOne({ menu_item_id: productIdN });
  const stock = !inv
    ? Number.MAX_SAFE_INTEGER
    : (inv.quantity != null ? Number(inv.quantity) : 0);
  const existing = await coll('cartItems').findOne({ cart_id: cartIdN, product_id: productIdN });
  const current = existing ? Number(existing.qty) : 0;
  const need = current + add;
  if (need > MAX_CART_LINE_QTY) {
    throw Object.assign(new Error(`Quantity cannot exceed ${MAX_CART_LINE_QTY} per line`), { code: 'BAD' });
  }
  if (need > stock) {
    throw Object.assign(new Error('Not enough stock for this item'), { code: 'BAD' });
  }
}

export async function assertCartLineQtyUpdate(_, { cartId, itemId, newQty }) {
  const cartIdN = asInt(cartId);
  const itemIdN = asInt(itemId);
  const nq = asInt(newQty);
  if (!cartIdN || !itemIdN || nq == null || nq < 0) {
    throw Object.assign(new Error('invalid params'), { code: 'BAD' });
  }
  if (nq === 0) return;
  const row = await coll('cartItems').findOne({ id: itemIdN, cart_id: cartIdN });
  if (!row) throw Object.assign(new Error('cart line not found'), { code: 'BAD' });
  const pid = asInt(row.product_id);
  const inv = await coll('inventory').findOne({ menu_item_id: pid });
  const stock = !inv
    ? Number.MAX_SAFE_INTEGER
    : (inv.quantity != null ? Number(inv.quantity) : 0);
  if (nq > MAX_CART_LINE_QTY) {
    throw Object.assign(new Error(`Quantity cannot exceed ${MAX_CART_LINE_QTY} per line`), { code: 'BAD' });
  }
  if (nq > stock) {
    throw Object.assign(new Error('Not enough stock for this item'), { code: 'BAD' });
  }
}

/** Validate each line: menu item exists, belongs to [storeId], and price matches (anti-tamper). */
export async function assertOrderItemsAgainstMenu(_conn, storeId, normalizedItems) {
  const sid = asInt(storeId);
  if (!sid) {
    const err = new Error('storeId is required to place an order');
    err.code = 'BAD';
    throw err;
  }
  if (normalizedItems.length > 200) {
    const err = new Error('Order has too many line items');
    err.code = 'BAD';
    throw err;
  }
  const s = await coll('stores').findOne({ id: sid });
  if (!s) {
    const err = new Error('Store not found');
    err.code = 'BAD';
    throw err;
  }
  for (const it of normalizedItems) {
    const pid = asInt(it.productId);
    if (!pid) {
      const err = new Error('Each item must have a productId');
      err.code = 'BAD';
      throw err;
    }
    const m = await coll('menuItems').findOne({ id: pid });
    if (!m) {
      const err = new Error('Menu item not found');
      err.code = 'BAD';
      throw err;
    }
    if (Number(m.store_id) !== sid) {
      const err = new Error('Item does not belong to the selected store');
      err.code = 'BAD';
      throw err;
    }
    const expected = Math.round(Number(m.price) * 100) / 100;
    const got = Math.round(Number(it.unitPrice) * 100) / 100;
    if (Math.abs(expected - got) > 0.02) {
      const err = new Error('Price mismatch — refresh the menu and try again');
      err.code = 'BAD';
      throw err;
    }
  }
}
