import { isMongoDuplicate, COLL, nextSeq } from '../config/mongo.js';
import { SIGNUP_ROLES } from '../models/constants.js';
import { coll } from '../repositories/mongo.repository.js';
import { sanitizeUserRow, normalizeUserRole } from '../utils/userFormatting.js';

export async function signup(req, res) {
  const name = String(req.body?.name ?? '').trim();
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  const password = String(req.body?.password ?? '');
  const mobile = req.body?.mobile ? String(req.body.mobile).trim() : null;
  const address = req.body?.address ? String(req.body.address).trim() : null;
  const rawRole =
    req.body?.role ?? req.body?.accountRole ?? req.body?.userRole ?? req.body?.user_role;
  const role = normalizeUserRole(rawRole, { allowAdmin: true });
  if (!SIGNUP_ROLES.has(role)) {
    return res.status(400).json({ error: 'invalid role for signup' });
  }

  if (!name || !email || !password) return res.status(400).json({ error: 'name/email/password required' });
  try {
    const bcrypt = await import('bcryptjs');
    const bcryptLib = bcrypt.default ?? bcrypt;
    const passwordHash = await bcryptLib.hash(password, 10);
    const uid = await nextSeq(COLL.users);
    const now = new Date();
    await coll('users').insertOne({
      id: uid,
      name,
      email,
      password_hash: passwordHash,
      mobile,
      address,
      role,
      created_at: now,
      updated_at: now,
    });
    const user = await coll('users').findOne(
      { id: uid },
      { projection: { id: 1, name: 1, email: 1, mobile: 1, address: 1, role: 1, created_at: 1, updated_at: 1 } },
    );
    res.status(201).json(sanitizeUserRow(user));
  } catch (e) {
    if (isMongoDuplicate(e)) {
      return res.status(409).json({ error: 'email already exists' });
    }
    console.error('Signup error:', e);
    res.status(500).json({ error: 'failed to signup' });
  }
}

export async function signin(req, res) {
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  const password = String(req.body?.password ?? '');
  if (!email || !password) return res.status(400).json({ error: 'email/password required' });
  const user = await coll('users').findOne({ email });
  if (!user) return res.status(404).json({ error: 'invalid credentials' });

  const bcryptMod = await import('bcryptjs');
  const bcryptLib = bcryptMod.default ?? bcryptMod;
  const match = await bcryptLib.compare(password, user.password_hash || '');
  if (!match) return res.status(401).json({ error: 'invalid credentials' });

  res.json(sanitizeUserRow(user));
}
