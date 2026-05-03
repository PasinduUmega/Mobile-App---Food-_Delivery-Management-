import { COLL, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';
import {
  assertOrderItemsAgainstMenu,
} from '../services/cartValidation.service.js';
import { fetchOrders } from '../services/orderFulfillment.service.js';
import { asFloat, asInt } from '../utils/parsers.js';

export async function createOrder(req, res) {
  const { userId = null, storeId = null, currency = 'USD', items = [], deliveryFee = 0 } = req.body || {};
  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'items required' });
  }

  const normalizedItems = items.map((it) => {
    const rawPid = it.productId ?? it.product_id;
    let productId = null;
    if (rawPid != null && rawPid !== '') {
      const n = Math.trunc(Number(rawPid));
      if (Number.isFinite(n) && n > 0) productId = n;
    }
    return {
      productId,
      name: String(it.name ?? ''),
      qty: Number(it.qty ?? 0),
      unitPrice: Number(it.unitPrice ?? 0),
      lineNote: it.lineNote != null && String(it.lineNote).trim()
        ? String(it.lineNote).trim().slice(0, 500)
        : null,
    };
  });
  if (
    normalizedItems.some(
      (it) =>
        !it.name
        || !Number.isFinite(it.qty)
        || it.qty <= 0
        || !Number.isFinite(it.unitPrice)
        || it.unitPrice < 0,
    )
  ) {
    return res.status(400).json({ error: 'invalid items' });
  }

  const subtotal = normalizedItems.reduce((s, it) => s + it.qty * it.unitPrice, 0);
  const delivery = Number(deliveryFee ?? 0);
  if (!Number.isFinite(delivery) || delivery < 0 || delivery > 1e7) {
    return res.status(400).json({ error: 'invalid delivery fee' });
  }
  const total = subtotal + delivery;
  const deliveryLat = asFloat(req.body.deliveryLatitude);
  const deliveryLng = asFloat(req.body.deliveryLongitude);

  try {
    try {
      await assertOrderItemsAgainstMenu(null, storeId, normalizedItems);
    } catch (e) {
      if (e.code === 'BAD') {
        return res.status(400).json({ error: e.message });
      }
      throw e;
    }

    const now = new Date();
    const orderId = await nextSeq(COLL.orders);
    await coll('orders').insertOne({
      id: orderId,
      user_id: userId,
      store_id: storeId,
      currency,
      subtotal,
      delivery_fee: delivery,
      total,
      status: 'PENDING_PAYMENT',
      delivery_latitude: deliveryLat,
      delivery_longitude: deliveryLng,
      created_at: now,
      updated_at: now,
    });

    for (const it of normalizedItems) {
      const lineTotal = it.qty * it.unitPrice;
      const oid = await nextSeq(COLL.orderItems);
      await coll('orderItems').insertOne({
        id: oid,
        order_id: orderId,
        product_id: it.productId,
        name: it.name,
        qty: it.qty,
        unit_price: it.unitPrice,
        line_total: lineTotal,
        line_note: it.lineNote,
      });
    }

    const requestCartId = asInt(req.body?.cartId);
    if (requestCartId) {
      try {
        const uidN = asInt(userId);
        const row = await coll('carts').findOne({ id: requestCartId });
        if (row && String(row.status) === 'ACTIVE' && uidN && Number(row.user_id) === uidN) {
          const bodyStore = asInt(storeId);
          if (!bodyStore || row.store_id == null || Number(row.store_id) === bodyStore) {
            await coll('cartItems').deleteMany({ cart_id: requestCartId });
            await coll('carts').updateOne(
              { id: requestCartId },
              { $set: { status: 'ABANDONED', updated_at: new Date() } },
            );
          }
        }
      } catch (ce) {
        console.error('post-order cart cleanup (order already saved):', ce);
      }
    }

    res.json({ orderId, currency, subtotal, deliveryFee: delivery, total });
  } catch (e) {
    console.error('Create order error:', e);
    res.status(500).json({ error: `failed to create order: ${e.message}` });
  }
}

export async function listOrders(req, res) {
  const userId = req.query.userId ? asInt(req.query.userId) : null;
  const storeId = req.query.storeId ? asInt(req.query.storeId) : null;
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 200) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;

  const rows = await fetchOrders({ userId, storeId, status, limit, offset });
  res.json({ items: rows });
}

export async function getOrder(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const order = await coll('orders').findOne({ id });
    if (!order) return res.status(404).json({ error: 'order not found' });
    const items = await coll('orderItems').find({ order_id: id }).sort({ id: 1 }).toArray();
    order.items = items;
    res.json(order);
  } catch (_e) {
    res.status(500).json({ error: 'failed to fetch order details' });
  }
}

export async function updateOrder(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });

  const statusBody = req.body?.status ? String(req.body.status).toUpperCase() : null;
  const items = req.body?.items;

  if (!statusBody && !items) return res.status(400).json({ error: 'no update fields provided' });

  try {
    const order = await coll('orders').findOne({ id });
    if (!order) {
      return res.status(404).json({ error: 'order not found' });
    }

    const updates = {};
    if (statusBody) {
      updates.status = statusBody;
      updates.updated_at = new Date();
    }

    if (Array.isArray(items)) {
      const normalizedItems = items.map((it) => ({
        productId: it.productId ?? null,
        name: String(it.name ?? ''),
        qty: Number(it.qty ?? 0),
        unitPrice: Number(it.unitPrice ?? 0),
        lineNote:
          it.lineNote != null && String(it.lineNote).trim()
            ? String(it.lineNote).trim().slice(0, 500)
            : null,
      }));

      if (
        normalizedItems.some(
          (it) =>
            !it.name
            || !Number.isFinite(it.qty)
            || it.qty <= 0
            || !Number.isFinite(it.unitPrice)
            || it.unitPrice < 0,
        )
      ) {
        return res.status(400).json({ error: 'invalid items array' });
      }

      const subtotal = normalizedItems.reduce((s, it) => s + it.qty * it.unitPrice, 0);
      const delivery = Number(order.delivery_fee ?? 0);
      const total = subtotal + delivery;
      updates.subtotal = subtotal;
      updates.total = total;
      updates.updated_at = new Date();

      await coll('orderItems').deleteMany({ order_id: id });
      for (const it of normalizedItems) {
        const lineTotal = it.qty * it.unitPrice;
        const oid = await nextSeq(COLL.orderItems);
        await coll('orderItems').insertOne({
          id: oid,
          order_id: id,
          product_id: it.productId,
          name: it.name,
          qty: it.qty,
          unit_price: it.unitPrice,
          line_total: lineTotal,
          line_note: it.lineNote,
        });
      }
    }

    const setAll = {};
    Object.assign(setAll, updates);
    await coll('orders').updateOne({ id }, { $set: setAll });
    res.json({ ok: true });
  } catch (e) {
    console.error('Update order error:', e);
    res.status(500).json({ error: 'failed to update order' });
  }
}

export async function deleteOrder(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const order = await coll('orders').findOne({ id });
    if (!order) return res.status(404).json({ error: 'order not found' });

    const protectedStatuses = ['PAID', 'COMPLETED', 'PREPARING', 'READY'];
    if (protectedStatuses.includes(order.status)) {
      return res.status(400).json({
        error: `Cannot delete order with status: ${order.status}. Only PENDING_PAYMENT, CANCELLED, and FAILED orders can be deleted.`,
      });
    }

    await coll('orderItems').deleteMany({ order_id: id });
    await coll('deliveries').deleteMany({ order_id: id });
    await coll('refundRequests').deleteMany({ order_id: id });
    await coll('receipts').deleteMany({ order_id: id });
    await coll('payments').deleteMany({ order_id: id });
    const result = await coll('orders').deleteOne({ id });
    res.json({ deleted: result.deletedCount === 1 });
  } catch (e) {
    console.error('Delete order error:', e);
    res.status(500).json({ error: 'failed to delete order' });
  }
}

export async function listOrdersForUser(req, res) {
  const userId = asInt(req.params.userId);
  if (!userId) return res.status(400).json({ error: 'invalid userId' });
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 200) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;

  const rows = await fetchOrders({ userId, status, limit, offset });
  res.json({ items: rows });
}

export async function listOrdersForStore(req, res) {
  const storeId = asInt(req.params.storeId);
  if (!storeId) return res.status(400).json({ error: 'invalid storeId' });
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 200) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;

  const rows = await fetchOrders({ storeId, status, limit, offset });
  res.json({ items: rows });
}
