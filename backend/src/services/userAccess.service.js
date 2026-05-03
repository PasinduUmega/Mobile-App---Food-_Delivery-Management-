import { coll } from '../repositories/mongo.repository.js';

export async function dbUserIsAdmin(actorId) {
  if (!actorId) return false;
  const row = await coll('users').findOne({ id: actorId });
  return row && String(row.role ?? 'CUSTOMER').toUpperCase() === 'ADMIN';
}
