import { getDb, COLL } from '../config/mongo.js';

/**
 * Typed collection accessors (camelCase matches keys on COLL).
 */
export function coll(kind) {
  const name = COLL[kind];
  if (!name) {
    throw new Error(`Unknown collection key: ${kind}`);
  }
  return getDb().collection(name);
}
