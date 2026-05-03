import { USER_ROLES } from '../models/constants.js';

/** Strip password hash from user rows returned by the API */
export function sanitizeUserRow(row) {
  if (!row) return row;
  const u = { ...row };
  delete u.password_hash;
  if (u.role != null && u.role !== undefined) {
    u.role = String(u.role).trim().toUpperCase();
  }
  return u;
}

export function normalizeUserRole(raw, { allowAdmin } = {}) {
  const r = String(raw ?? 'CUSTOMER').trim().toUpperCase();
  if (!USER_ROLES.has(r)) return 'CUSTOMER';
  if (r === 'ADMIN' && !allowAdmin) return 'CUSTOMER';
  return r;
}
