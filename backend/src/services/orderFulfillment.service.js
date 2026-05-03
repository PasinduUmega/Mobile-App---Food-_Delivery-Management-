import { nanoid } from 'nanoid';
import { COLL, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';
import { asInt } from '../utils/parsers.js';

export async function createReceiptIfMissing(_conn, { orderId, paymentId, paidAmount, currency, rawProviderResponse }) {
  const existing = await coll('receipts').findOne({ order_id: orderId });
  if (existing) return;
  const receiptNo = `FR-${new Date().getFullYear()}-${nanoid(10).toUpperCase()}`;
  const id = await nextSeq('receipts');
  await coll('receipts').insertOne({
    id,
    order_id: orderId,
    payment_id: paymentId,
    receipt_no: receiptNo,
    issued_at: new Date(),
    paid_amount: paidAmount,
    currency,
    raw_provider_response: rawProviderResponse ?? null,
  });
}

/** After checkout, drivers see a PENDING delivery row (idempotent). */
export async function ensureDeliveryJobForOrder(_conn, orderId) {
  const oid = asInt(orderId);
  if (!oid) return;
  try {
    const ex = await coll('deliveries').findOne({ order_id: oid });
    if (ex) return;
    const id = await nextSeq(COLL.deliveries);
    await coll('deliveries').insertOne({
      id,
      order_id: oid,
      driver_name: null,
      driver_phone: null,
      status: 'PENDING',
      created_at: new Date(),
      updated_at: new Date(),
    });
  } catch (e) {
    console.warn('ensureDeliveryJobForOrder:', e?.message ?? e);
  }
}

export async function isDriverBusy({ driverPhone, excludeDeliveryId = null } = {}) {
  const phone = String(driverPhone ?? '').trim();
  if (!phone) return false;
  const activeStatuses = ['PENDING', 'PICKED_UP', 'OUT_FOR_DELIVERY'];
  const query = { driver_phone: phone, status: { $in: activeStatuses } };
  if (excludeDeliveryId != null) query.id = { $ne: excludeDeliveryId };
  const row = await coll('deliveries').findOne(query);
  return Boolean(row);
}

export async function fetchOrders({ userId = null, storeId = null, status = null, limit = 50, offset = 0 } = {}) {
  const filter = {};
  if (userId != null) filter.user_id = userId;
  if (storeId != null) filter.store_id = storeId;
  if (status) filter.status = status;

  const rows = await coll('orders')
    .find(filter)
    .sort({ id: -1 })
    .skip(offset)
    .limit(limit)
    .project({
      id: 1,
      user_id: 1,
      store_id: 1,
      currency: 1,
      subtotal: 1,
      delivery_fee: 1,
      total: 1,
      status: 1,
      created_at: 1,
      updated_at: 1,
    })
    .toArray();

  return rows;
}
