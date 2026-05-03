import { asInt } from './parsers.js';

/** Caller identity for lightweight checks (sent by the Flutter app after sign-in). */
export function readActorUserId(req) {
  const raw = req.headers['x-user-id'] ?? req.headers['X-User-Id'];
  return asInt(raw);
}
