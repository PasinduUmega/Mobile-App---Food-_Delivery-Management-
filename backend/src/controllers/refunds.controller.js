import { COLL, nextSeq } from '../config/mongo.js';
import {
  PAID_LIKE_ORDER_STATUSES,
  REFUND_STATUSES,
} from '../models/constants.js';
import { coll } from '../repositories/mongo.repository.js';
import { dbUserIsAdmin } from '../services/userAccess.service.js';
import { readActorUserId } from '../utils/requestUser.js';
import { asInt } from '../utils/parsers.js';

export async function createRefundRequest(req, res) {
  const actorId = readActorUserId(req);
  if (!actorId) return res.status(401).json({ error: 'Sign in required' });
  const orderId = asInt(req.body?.orderId);
  const reason = String(req.body?.reason ?? '').trim() || null;
  if (!orderId) return res.status(400).json({ error: 'orderId required' });

  try {
    const order = await coll('orders').findOne({ id: orderId }, { projection: { id: 1, user_id: 1, status: 1 } });
    if (!order) return res.status(404).json({ error: 'order not found' });
    if (order.user_id == null || Number(order.user_id) !== actorId) {
      return res.status(403).json({ error: 'You can only request a refund for your own orders' });
    }
    const st = String(order.status ?? '').toUpperCase();
    if (!PAID_LIKE_ORDER_STATUSES.has(st)) {
      return res.status(400).json({
        error: 'Refunds are only available for paid or in-progress orders (not pending payment, cancelled, or failed).',
      });
    }

    const prevRows = await coll('refundRequests').find({ order_id: orderId }).sort({ id: -1 }).limit(1).toArray();
    if (prevRows?.length) {
      const last = String(prevRows[0].status ?? '').toUpperCase();
      if (last === 'PENDING' || last === 'APPROVED' || last === 'PROCESSED') {
        return res.status(400).json({
          error: 'A refund is already open or completed for this order. Contact support if you need help.',
        });
      }
    }

    const rid = await nextSeq(COLL.refundRequests);
    const now = new Date();
    await coll('refundRequests').insertOne({
      id: rid,
      order_id: orderId,
      user_id: actorId,
      reason,
      status: 'PENDING',
      admin_note: null,
      created_at: now,
      updated_at: now,
    });
    const row = await coll('refundRequests').findOne({ id: rid });
    res.status(201).json(row);
  } catch (e) {
    console.error('refund create', e);
    res.status(500).json({ error: 'Failed to create refund request' });
  }
}

export async function listRefundRequests(req, res) {
  const actorId = readActorUserId(req);
  if (!actorId) return res.status(401).json({ error: 'Sign in required' });
  const asAdmin = await dbUserIsAdmin(actorId);
  const filterUserId = asInt(req.query.userId);
  const filterStatus = String(req.query.status ?? '').trim().toUpperCase() || null;

  try {
    if (!asAdmin) {
      if (!filterUserId || filterUserId !== actorId) {
        return res.status(403).json({ error: 'You can only view your own refund requests' });
      }
    }

    const query = {};
    if (!asAdmin) {
      query.user_id = actorId;
    } else if (filterUserId) {
      query.user_id = filterUserId;
    }
    if (filterStatus && REFUND_STATUSES.has(filterStatus)) {
      query.status = filterStatus;
    }
    const rows = await coll('refundRequests').find(query).sort({ created_at: -1 }).toArray();
    res.json({ items: rows || [] });
  } catch (e) {
    console.error('refund list', e);
    res.status(500).json({ error: 'Failed to list refund requests' });
  }
}

export async function patchRefundRequest(req, res) {
  const actorId = readActorUserId(req);
  if (!actorId) return res.status(401).json({ error: 'Sign in required' });
  if (!(await dbUserIsAdmin(actorId))) {
    return res.status(403).json({ error: 'Only administrators can update refund requests' });
  }
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const status = String(req.body?.status ?? '').trim().toUpperCase();
  const adminNote = String(req.body?.adminNote ?? '').trim() || null;
  if (!REFUND_STATUSES.has(status) || status === 'PENDING') {
    return res.status(400).json({ error: 'status must be APPROVED, REJECTED, or PROCESSED' });
  }
  try {
    const result = await coll('refundRequests').updateOne(
      { id },
      { $set: { status, admin_note: adminNote, updated_at: new Date() } },
    );
    if (!result.matchedCount) return res.status(404).json({ error: 'not found' });
    const row = await coll('refundRequests').findOne({ id });
    res.json(row);
  } catch (e) {
    console.error('refund patch', e);
    res.status(500).json({ error: 'Failed to update refund request' });
  }
}
