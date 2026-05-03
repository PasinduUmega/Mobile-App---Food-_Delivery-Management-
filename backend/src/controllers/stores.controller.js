import { COLL, isMongoDuplicate, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';
import { asFloat, asInt } from '../utils/parsers.js';

export async function listStores(req, res) {
  const ownerUserId = asInt(req.query.ownerUserId);
  try {
    const filter = ownerUserId ? { owner_user_id: ownerUserId } : {};
    const rows = await coll('stores').find(filter).sort({ id: -1 }).toArray();
    res.json({ items: rows });
  } catch (e) {
    console.error('List stores error:', e);
    res.status(500).json({ error: 'failed to list stores' });
  }
}

export async function getStore(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const store = await coll('stores').findOne({ id });
  if (!store) return res.status(404).json({ error: 'store not found' });
  res.json(store);
}

export async function createStore(req, res) {
  const name = String(req.body?.name ?? '').trim();
  const address = String(req.body?.address ?? '').trim();
  const lat = asFloat(req.body?.latitude);
  const lng = asFloat(req.body?.longitude);
  const ownerUserId = asInt(req.body?.ownerUserId);

  console.log('Creating store with:', { name, address, lat, lng, ownerUserId });

  if (!name) return res.status(400).json({ error: 'name required' });
  try {
    const sid = await nextSeq(COLL.stores);
    const now = new Date();
    await coll('stores').insertOne({
      id: sid,
      name,
      address: address || null,
      latitude: lat,
      longitude: lng,
      owner_user_id: ownerUserId || null,
      created_at: now,
      updated_at: now,
    });
    const created = await coll('stores').findOne({ id: sid });
    console.log('Store created successfully:', created);
    res.status(201).json(created);
  } catch (e) {
    if (isMongoDuplicate(e)) {
      console.warn('Duplicate store name:', name);
      return res.status(409).json({ error: 'store name already exists' });
    }
    console.error('Create store error:', e.code, e.message);
    res.status(500).json({ error: `failed to create store: ${e.message}` });
  }
}

export async function updateStore(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const name = String(req.body?.name ?? '').trim();
  const address = String(req.body?.address ?? '').trim();
  const lat = asFloat(req.body?.latitude);
  const lng = asFloat(req.body?.longitude);
  const hasOwner = Object.prototype.hasOwnProperty.call(req.body || {}, 'ownerUserId');
  const ownerUserId = hasOwner ? asInt(req.body.ownerUserId) : undefined;

  if (!name) return res.status(400).json({ error: 'name required' });
  try {
    const setDoc = {
      name,
      address: address || null,
      latitude: lat,
      longitude: lng,
      updated_at: new Date(),
      ...(hasOwner ? { owner_user_id: ownerUserId ?? null } : {}),
    };
    const result = await coll('stores').updateOne({ id }, { $set: setDoc });
    if (!result.matchedCount) return res.status(404).json({ error: 'store not found' });
    const updated = await coll('stores').findOne({ id });
    res.json(updated);
  } catch (e) {
    if (isMongoDuplicate(e)) {
      return res.status(409).json({ error: 'store name already exists' });
    }
    console.error('Update store error:', e);
    res.status(500).json({ error: 'failed to update store' });
  }
}

export async function deleteStore(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const menus = await coll('menuItems').find({ store_id: id }).project({ id: 1 }).toArray();
    const mids = menus.map((m) => m.id);
    await coll('inventory').deleteMany({ menu_item_id: { $in: mids } });
    await coll('menuItems').deleteMany({ store_id: id });
    const result = await coll('stores').deleteOne({ id });
    res.json({ deleted: result.deletedCount === 1 });
  } catch (_e) {
    res.status(500).json({ error: 'failed to delete store' });
  }
}
