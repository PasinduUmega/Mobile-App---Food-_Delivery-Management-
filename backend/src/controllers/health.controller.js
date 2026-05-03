import { getDb } from '../config/mongo.js';

export async function health(_req, res) {
  try {
    await getDb().command({ ping: 1 });
    res.json({ ok: true });
  } catch (_e) {
    res.status(500).json({ ok: false });
  }
}
