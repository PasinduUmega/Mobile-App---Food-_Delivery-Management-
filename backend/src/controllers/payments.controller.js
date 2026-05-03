import { buildCaptureOrderRequest, buildCreateOrderRequest } from '../paypal.js';
import { COLL, nextSeq } from '../config/mongo.js';
import {
  PAYMENT_METHODS,
  PAYMENT_STATUSES,
} from '../models/constants.js';
import { coll } from '../repositories/mongo.repository.js';
import {
  createReceiptIfMissing,
  ensureDeliveryJobForOrder,
} from '../services/orderFulfillment.service.js';
import { asInt, asMoney, normalizeCurrency } from '../utils/parsers.js';

export function paypalReturn(_req, res) {
  res.type('text/plain').send('Payment approved. You can return to the app.');
}

export function paypalCancel(_req, res) {
  res.type('text/plain').send('Payment cancelled. You can return to the app.');
}

export function paypalCreate(paypalHttpClient) {
  return async (req, res) => {
    if (!paypalHttpClient) return res.status(500).json({ error: 'PayPal not configured on server' });
    const { orderId } = req.body || {};
    if (!orderId) return res.status(400).json({ error: 'orderId required' });

    const order = await coll('orders').findOne(
      { id: asInt(orderId) },
      { projection: { id: 1, total: 1, currency: 1, status: 1 } },
    );
    if (!order) return res.status(404).json({ error: 'order not found' });
    if (order.status !== 'PENDING_PAYMENT') return res.status(400).json({ error: 'order not payable' });

    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 8080}`;
    const returnUrl = `${baseUrl}/api/payments/paypal/return?orderId=${order.id}`;
    const cancelUrl = `${baseUrl}/api/payments/paypal/cancel?orderId=${order.id}`;

    const request = buildCreateOrderRequest({
      total: Number(order.total),
      currency: order.currency,
      returnUrl,
      cancelUrl,
    });

    try {
      const response = await paypalHttpClient.execute(request);
      const paypalOrderId = response.result.id;
      const approval = (response.result.links || []).find((l) => l.rel === 'approve');
      const approvalUrl = approval?.href ?? null;
      if (!approvalUrl) return res.status(500).json({ error: 'missing PayPal approval url' });

      const paymentId = await nextSeq(COLL.payments);
      const now = new Date();
      await coll('payments').insertOne({
        id: paymentId,
        order_id: order.id,
        method: 'PAYPAL',
        status: 'APPROVAL_PENDING',
        provider: 'PAYPAL',
        provider_order_id: paypalOrderId,
        approval_url: approvalUrl,
        amount: order.total,
        currency: order.currency,
        created_at: now,
        updated_at: now,
      });

      res.json({ paymentId, paypalOrderId, approvalUrl });
    } catch (e) {
      console.error('PayPal create order error:', e);
      res.status(500).json({ error: 'failed to create PayPal order' });
    }
  };
}

export function paypalCapture(paypalHttpClient) {
  return async (req, res) => {
    if (!paypalHttpClient) return res.status(500).json({ error: 'PayPal not configured on server' });
    const { orderId } = req.body || {};
    if (!orderId) return res.status(400).json({ error: 'orderId required' });

    const payment = await coll('payments').findOne(
      {
        order_id: asInt(orderId),
        method: 'PAYPAL',
      },
      { sort: { id: -1 } },
    );
    if (!payment) return res.status(404).json({ error: 'payment not found' });
    if (!payment.provider_order_id) return res.status(400).json({ error: 'missing provider order id' });

    try {
      const response = await paypalHttpClient.execute(buildCaptureOrderRequest(payment.provider_order_id));
      const capture = response?.result?.purchase_units?.[0]?.payments?.captures?.[0];
      const captureId = capture?.id ?? null;
      const captureStatus = response?.result?.status ?? 'UNKNOWN';
      const now = new Date();
      const oid = asInt(orderId);

      if (captureStatus === 'COMPLETED') {
        await coll('payments').updateOne(
          { id: payment.id },
          { $set: { status: 'CAPTURED', provider_capture_id: captureId, updated_at: now } },
        );
        await coll('orders').updateOne(
          { id: oid },
          { $set: { status: 'PAID', updated_at: now } },
        );
        await createReceiptIfMissing(null, {
          orderId: oid,
          paymentId: payment.id,
          paidAmount: Number(payment.amount),
          currency: payment.currency,
          rawProviderResponse: response.result,
        });
        await ensureDeliveryJobForOrder(null, oid);
      } else {
        await coll('payments').updateOne(
          { id: payment.id },
          { $set: { status: 'FAILED', updated_at: now } },
        );
        await coll('orders').updateOne({ id: oid }, { $set: { status: 'FAILED', updated_at: now } });
      }

      res.json({ ok: true, paypalStatus: captureStatus });
    } catch (e) {
      console.error('PayPal capture order error:', e);
      res.status(500).json({ error: 'failed to capture PayPal order' });
    }
  };
}

export async function confirmCod(req, res) {
  const { orderId } = req.body || {};
  if (!orderId) return res.status(400).json({ error: 'orderId required' });

  const order = await coll('orders').findOne({ id: asInt(orderId) });
  if (!order) return res.status(404).json({ error: 'order not found' });
  if (order.status !== 'PENDING_PAYMENT') return res.status(400).json({ error: 'order not payable' });

  try {
    const oid = order.id;
    const payResId = await nextSeq(COLL.payments);
    const now = new Date();
    await coll('payments').insertOne({
      id: payResId,
      order_id: oid,
      method: 'CASH_ON_DELIVERY',
      status: 'CAPTURED',
      provider: 'COD',
      amount: order.total,
      currency: order.currency,
      created_at: now,
      updated_at: now,
    });
    await coll('orders').updateOne({ id: oid }, { $set: { status: 'PAID', updated_at: new Date() } });
    await createReceiptIfMissing(null, {
      orderId: oid,
      paymentId: payResId,
      paidAmount: order.total,
      currency: order.currency,
      rawProviderResponse: { method: 'COD' },
    });
    await ensureDeliveryJobForOrder(null, oid);
    res.json({ ok: true });
  } catch (e) {
    console.error('confirmCod error:', e);
    res.status(500).json({ error: e?.message ?? 'failed to confirm COD' });
  }
}

export async function confirmOnlineBanking(req, res) {
  const { orderId, reference = null } = req.body || {};
  if (!orderId) return res.status(400).json({ error: 'orderId required' });

  const order = await coll('orders').findOne({ id: asInt(orderId) });
  if (!order) return res.status(404).json({ error: 'order not found' });
  if (order.status !== 'PENDING_PAYMENT') return res.status(400).json({ error: 'order not payable' });

  try {
    const oid = order.id;
    const payResId = await nextSeq(COLL.payments);
    const now = new Date();
    await coll('payments').insertOne({
      id: payResId,
      order_id: oid,
      method: 'ONLINE_BANKING',
      status: 'CAPTURED',
      provider: 'BANK',
      provider_order_id: reference ? String(reference) : null,
      amount: order.total,
      currency: order.currency,
      created_at: now,
      updated_at: now,
    });
    await coll('orders').updateOne({ id: oid }, { $set: { status: 'PAID', updated_at: new Date() } });
    await createReceiptIfMissing(null, {
      orderId: oid,
      paymentId: payResId,
      paidAmount: order.total,
      currency: order.currency,
      rawProviderResponse: { method: 'ONLINE_BANKING', reference },
    });
    await ensureDeliveryJobForOrder(null, oid);
    res.json({ ok: true });
  } catch (_e) {
    res.status(500).json({ error: 'failed to confirm online banking' });
  }
}

export async function listPayments(req, res) {
  const orderId = req.query.orderId ? asInt(req.query.orderId) : null;
  const method = req.query.method ? String(req.query.method).toUpperCase() : null;
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 200) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;

  if (method && !PAYMENT_METHODS.has(method)) return res.status(400).json({ error: 'invalid method' });
  if (status && !PAYMENT_STATUSES.has(status)) return res.status(400).json({ error: 'invalid status' });

  const filter = {};
  if (orderId) filter.order_id = orderId;
  if (method) filter.method = method;
  if (status) filter.status = status;

  const rows = await coll('payments').find(filter).sort({ id: -1 }).skip(offset).limit(limit).toArray();

  res.json({ items: rows });
}

export async function getPayment(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const row = await coll('payments').findOne({ id });
  if (!row) return res.status(404).json({ error: 'payment not found' });
  res.json(row);
}

export async function createPayment(req, res) {
  const orderId = asInt(req.body?.orderId);
  const method = String(req.body?.method ?? '').toUpperCase();
  const status = req.body?.status ? String(req.body.status).toUpperCase() : 'CREATED';
  const provider = req.body?.provider != null ? String(req.body.provider) : null;
  const providerOrderId = req.body?.providerOrderId != null ? String(req.body.providerOrderId) : null;
  const providerCaptureId = req.body?.providerCaptureId != null ? String(req.body.providerCaptureId) : null;
  const approvalUrl = req.body?.approvalUrl != null ? String(req.body.approvalUrl) : null;
  const amount = asMoney(req.body?.amount);
  const currency = normalizeCurrency(req.body?.currency);

  if (!orderId) return res.status(400).json({ error: 'orderId required' });
  if (!PAYMENT_METHODS.has(method)) return res.status(400).json({ error: 'invalid method' });
  if (!PAYMENT_STATUSES.has(status)) return res.status(400).json({ error: 'invalid status' });
  if (amount == null || amount < 0) return res.status(400).json({ error: 'invalid amount' });
  if (!currency) return res.status(400).json({ error: 'invalid currency' });

  const order = await coll('orders').findOne({ id: orderId });
  if (!order) return res.status(404).json({ error: 'order not found' });

  const payId = await nextSeq(COLL.payments);
  const now = new Date();
  await coll('payments').insertOne({
    id: payId,
    order_id: orderId,
    method,
    status,
    provider,
    provider_order_id: providerOrderId,
    provider_capture_id: providerCaptureId,
    approval_url: approvalUrl,
    amount,
    currency,
    created_at: now,
    updated_at: now,
  });

  if (status === 'CAPTURED') {
    try {
      await coll('orders').updateOne({ id: orderId }, { $set: { status: 'PAID', updated_at: new Date() } });
      await createReceiptIfMissing(null, {
        orderId,
        paymentId: payId,
        paidAmount: amount,
        currency,
        rawProviderResponse: { method, provider, providerOrderId, providerCaptureId },
      });
    } catch (_e) {
      // client can re-sync via update endpoint
    }
  }

  res.status(201).json({ id: payId });
}

export async function updatePayment(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });

  const patch = {
    status: req.body?.status != null ? String(req.body.status).toUpperCase() : null,
    provider: req.body?.provider != null ? String(req.body.provider) : null,
    provider_order_id: req.body?.providerOrderId != null ? String(req.body.providerOrderId) : null,
    provider_capture_id: req.body?.providerCaptureId != null ? String(req.body.providerCaptureId) : null,
    approval_url: req.body?.approvalUrl != null ? String(req.body.approvalUrl) : null,
  };
  if (patch.status && !PAYMENT_STATUSES.has(patch.status)) return res.status(400).json({ error: 'invalid status' });

  try {
    const payment = await coll('payments').findOne({ id });
    if (!payment) {
      return res.status(404).json({ error: 'payment not found' });
    }

    const nextStatus = patch.status ?? payment.status;
    const setDoc = {
      status: nextStatus,
      updated_at: new Date(),
    };
    if (patch.provider != null) setDoc.provider = patch.provider;
    if (patch.provider_order_id != null) setDoc.provider_order_id = patch.provider_order_id;
    if (patch.provider_capture_id != null) setDoc.provider_capture_id = patch.provider_capture_id;
    if (patch.approval_url != null) setDoc.approval_url = patch.approval_url;

    await coll('payments').updateOne({ id }, { $set: setDoc });

    if (nextStatus === 'CAPTURED') {
      await coll('orders').updateOne({ id: payment.order_id }, { $set: { status: 'PAID', updated_at: new Date() } });
      await createReceiptIfMissing(null, {
        orderId: payment.order_id,
        paymentId: id,
        paidAmount: Number(payment.amount),
        currency: payment.currency,
        rawProviderResponse: { status: nextStatus, provider: patch.provider ?? payment.provider },
      });
    } else if (nextStatus === 'FAILED') {
      await coll('orders').updateOne({ id: payment.order_id }, { $set: { status: 'FAILED', updated_at: new Date() } });
    } else if (nextStatus === 'CANCELLED') {
      await coll('orders').updateOne({ id: payment.order_id }, { $set: { status: 'CANCELLED', updated_at: new Date() } });
    }

    res.json({ ok: true });
  } catch (_e) {
    res.status(500).json({ error: 'failed to update payment' });
  }
}

export async function deletePayment(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    await coll('receipts').deleteMany({ payment_id: id });
    const result = await coll('payments').deleteOne({ id });
    res.json({ deleted: result.deletedCount === 1 });
  } catch (_e) {
    res.status(409).json({ error: 'cannot delete payment' });
  }
}
