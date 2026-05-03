import { COLL, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';
import { dbUserIsAdmin } from '../services/userAccess.service.js';
import { readActorUserId } from '../utils/requestUser.js';
import { asInt } from '../utils/parsers.js';

export async function createFeedback(req, res) {
  const userId = readActorUserId(req);
  if (!userId) return res.status(401).json({ error: 'Sign in required' });
  const rating = asInt(req.body?.rating);
  const feedback = String(req.body?.feedback ?? '').trim();
  const category =
    req.body?.category != null ? String(req.body.category).trim() || 'General' : 'General';
  if (!rating || rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'rating must be 1–5' });
  }
  if (!feedback) return res.status(400).json({ error: 'feedback text required' });
  try {
    const fid = await nextSeq(COLL.customerFeedback);
    const now = new Date();
    await coll('customerFeedback').insertOne({
      id: fid,
      user_id: userId,
      rating,
      feedback,
      category,
      created_at: now,
    });
    const user = await coll('users').findOne({ id: userId });
    res.status(201).json({
      id: fid,
      user_id: userId,
      rating,
      feedback,
      category,
      created_at: now,
      user_name: user?.name ?? null,
    });
  } catch (e) {
    console.error('customer-feedback insert:', e);
    res.status(500).json({ error: 'failed to save feedback' });
  }
}

export async function listFeedbackMe(req, res) {
  const userId = readActorUserId(req);
  if (!userId) return res.status(401).json({ error: 'Sign in required' });
  try {
    const rows = await coll('customerFeedback').find({ user_id: userId }).sort({ created_at: -1 }).toArray();
    const self = await coll('users').findOne({ id: userId });
    const name = self?.name ?? null;
    res.json({
      items: rows.map((cf) => ({ ...cf, user_name: name })),
    });
  } catch (e) {
    console.error('customer-feedback me:', e);
    res.status(500).json({ error: 'failed to list feedback' });
  }
}

export async function listFeedbackAdmin(req, res) {
  const actorId = readActorUserId(req);
  if (!(await dbUserIsAdmin(actorId))) {
    return res.status(403).json({ error: 'admin only' });
  }
  try {
    const rows = await coll('customerFeedback').find().sort({ created_at: -1 }).toArray();
    const userIds = [...new Set(rows.map((r) => r.user_id))];
    const users = await coll('users').find({ id: { $in: userIds } }).project({ id: 1, name: 1 }).toArray();
    const nameById = Object.fromEntries(users.map((u) => [u.id, u.name]));
    res.json({
      items: rows.map((cf) => ({ ...cf, user_name: nameById[cf.user_id] ?? null })),
    });
  } catch (e) {
    console.error('customer-feedback list:', e);
    res.status(500).json({ error: 'failed to list feedback' });
  }
}
