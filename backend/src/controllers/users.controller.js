import { nanoid } from 'nanoid';
import { COLL, isMongoDuplicate, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';
import { dbUserIsAdmin } from '../services/userAccess.service.js';
import { readActorUserId } from '../utils/requestUser.js';
import { asInt } from '../utils/parsers.js';
import { sanitizeUserRow, normalizeUserRole } from '../utils/userFormatting.js';

export async function listUsers(_req, res) {
  const rows = await coll('users').find().sort({ id: -1 }).toArray();
  res.json({ items: rows.map(sanitizeUserRow) });
}

export async function getUser(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const user = await coll('users').findOne({ id });
  if (!user) return res.status(404).json({ error: 'user not found' });
  res.json(sanitizeUserRow(user));
}

export async function createUser(req, res) {
  const name = String(req.body?.name ?? '').trim();
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  if (!name || !email) return res.status(400).json({ error: 'name/email required' });
  try {
    const bcryptModule = await import('bcryptjs');
    const bcryptLib = bcryptModule.default ?? bcryptModule;
    const passwordHash = await bcryptLib.hash(nanoid(32), 10);
    const uid = await nextSeq(COLL.users);
    const now = new Date();
    await coll('users').insertOne({
      id: uid,
      name,
      email,
      password_hash: passwordHash,
      role: 'CUSTOMER',
      mobile: null,
      address: null,
      created_at: now,
      updated_at: now,
    });
    const created = await coll('users').findOne({ id: uid });
    res.status(201).json(sanitizeUserRow(created));
  } catch (e) {
    if (isMongoDuplicate(e)) {
      return res.status(409).json({ error: 'email already exists' });
    }
    console.error('Create user error:', e);
    res.status(500).json({ error: 'failed to create user' });
  }
}

export async function updateUser(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const actorId = readActorUserId(req);
  const actorIsAdmin = actorId && (await dbUserIsAdmin(actorId));
  const actorIsSelf = actorId === id;
  if (!actorIsAdmin && !actorIsSelf) {
    return res.status(403).json({ error: 'You can only update your own profile' });
  }
  const name = String(req.body?.name ?? '').trim();
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  if (!name || !email) return res.status(400).json({ error: 'name/email required' });
  const mobileRaw = req.body?.mobile;
  const mobile =
    mobileRaw === undefined
      ? undefined
      : mobileRaw === null
        ? null
        : String(mobileRaw).trim() || null;
  const addressRaw = req.body?.address;
  const address =
    addressRaw === undefined
      ? undefined
      : addressRaw === null
        ? null
        : String(addressRaw).trim() || null;
  const roleProvided =
    req.body?.role != null && String(req.body.role).trim() !== '';
  let role = null;
  if (roleProvided) {
    if (!actorIsAdmin) {
      return res.status(403).json({ error: 'Only administrators can change user roles' });
    }
    role = normalizeUserRole(req.body.role, { allowAdmin: true });
  }
  try {
    const setFields = {
      name,
      email,
      updated_at: new Date(),
    };
    if (role != null) setFields.role = role;
    if (mobile !== undefined) setFields.mobile = mobile;
    if (address !== undefined) setFields.address = address;
    const result = await coll('users').updateOne({ id }, { $set: setFields });
    if (!result.matchedCount) return res.status(404).json({ error: 'user not found' });

    const updated = await coll('users').findOne({ id });
    res.json(sanitizeUserRow(updated));
  } catch (e) {
    if (isMongoDuplicate(e)) {
      return res.status(409).json({ error: 'email already exists' });
    }
    console.error('Update user error:', e);
    res.status(500).json({ error: 'failed to update user' });
  }
}

export async function deleteUser(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    await coll('driverProfiles').deleteMany({ user_id: id });
    const result = await coll('users').deleteOne({ id });
    res.json({ deleted: result.deletedCount === 1 });
  } catch (_e) {
    res.status(500).json({ error: 'failed to delete user' });
  }
}
