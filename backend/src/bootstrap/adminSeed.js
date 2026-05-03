import { COLL, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';

export async function seedDefaultAdmin() {
  const defaultAdminEmail = 'admin@gmail.com';
  const defaultAdminPassword = '123456';
  const existing = await coll('users').findOne({ email: defaultAdminEmail });
  if (existing) return;

  const bcryptModule = await import('bcryptjs');
  const bcryptLib = bcryptModule.default ?? bcryptModule;
  const passwordHash = await bcryptLib.hash(defaultAdminPassword, 10);
  const uid = await nextSeq(COLL.users);
  const now = new Date();
  await coll('users').insertOne({
    id: uid,
    name: 'System Admin',
    email: defaultAdminEmail,
    password_hash: passwordHash,
    role: 'ADMIN',
    created_at: now,
    updated_at: now,
  });
  console.log('✓ Created default admin account: admin@gmail.com');
}
