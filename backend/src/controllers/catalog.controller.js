import { COLL, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';
import {
  asInt,
  asMoney,
  normalizeComboComponentsInput,
  parseOptionalDateOnly,
} from '../utils/parsers.js';

export async function getStoreMenu(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const rows = await coll('menuItems').find({ store_id: id }).sort({ id: -1 }).toArray();
    res.json({ items: rows });
  } catch (_e) {
    res.status(500).json({ error: 'failed to fetch menu' });
  }
}

export async function createMenuItem(req, res) {
  const { storeId, name, description, price, imageUrl, specialForDate } = req.body || {};
  if (!storeId || !name || price == null) return res.status(400).json({ error: 'storeId, name, price required' });
  const specialDate = parseOptionalDateOnly(specialForDate);
  const isCombo = req.body?.isCombo === true || req.body?.isCombo === 1;
  const comboJson = isCombo ? (normalizeComboComponentsInput(req.body) || null) : null;
  try {
    const mid = await nextSeq(COLL.menuItems);
    const now = new Date();
    await coll('menuItems').insertOne({
      id: mid,
      store_id: asInt(storeId),
      name,
      description: description || null,
      price: asMoney(price),
      image_url: imageUrl || null,
      special_for_date: specialDate,
      is_combo: isCombo ? 1 : 0,
      combo_components: comboJson,
      created_at: now,
      updated_at: now,
    });
    const iid = await nextSeq(COLL.inventory);
    await coll('inventory').insertOne({
      id: iid,
      menu_item_id: mid,
      quantity: 0,
      updated_at: now,
    });
    const created = await coll('menuItems').findOne({ id: mid });

    res.status(201).json(created);
  } catch (e) {
    console.error('Create menu item error:', e);
    res.status(500).json({ error: 'failed to create menu item' });
  }
}

export async function updateMenuItem(req, res) {
  const id = asInt(req.params.id);
  const { name, description, price, imageUrl } = req.body || {};
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const curfull = await coll('menuItems').findOne({ id });
    if (!curfull) return res.status(404).json({ error: 'menu item not found' });

    const hasSpecial = Object.prototype.hasOwnProperty.call(req.body || {}, 'specialForDate');
    const specialDate = hasSpecial ? parseOptionalDateOnly(req.body.specialForDate) : undefined;

    const nm = req.body?.name;
    const dc = req.body?.description;

    const setDoc = {
      name: nm !== undefined ? (nm ?? null) : curfull.name,
      description: dc !== undefined ? (dc ?? null) : curfull.description,
      price: price != null ? asMoney(price) : curfull.price,
      image_url: imageUrl !== undefined ? (imageUrl ?? null) : curfull.image_url,
      special_for_date: hasSpecial ? specialDate : curfull.special_for_date,
      updated_at: new Date(),
    };

    await coll('menuItems').updateOne({ id }, { $set: setDoc });

    const hasIsCombo = Object.prototype.hasOwnProperty.call(req.body || {}, 'isCombo');
    const hasComboComponents = Object.prototype.hasOwnProperty.call(req.body || {}, 'comboComponents');
    if (hasIsCombo || hasComboComponents) {
      const cur = await coll('menuItems').findOne({ id }, { projection: { is_combo: 1, combo_components: 1 } });
      const nextIsCombo = hasIsCombo
        ? (req.body.isCombo === true || req.body.isCombo === 1 ? 1 : 0)
        : (cur?.is_combo ? 1 : 0);
      let nextCombo = hasComboComponents ? normalizeComboComponentsInput(req.body) : cur?.combo_components;
      if (!nextIsCombo) nextCombo = null;
      await coll('menuItems').updateOne(
        { id },
        { $set: { is_combo: nextIsCombo, combo_components: nextCombo, updated_at: new Date() } },
      );
    }

    const updated = await coll('menuItems').findOne({ id });
    res.json(updated);
  } catch (_e) {
    res.status(500).json({ error: 'failed to update menu item' });
  }
}

export async function deleteMenuItem(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    await coll('inventory').deleteMany({ menu_item_id: id });
    const result = await coll('menuItems').deleteOne({ id });
    res.json({ deleted: result.deletedCount === 1 });
  } catch (_e) {
    res.status(500).json({ error: 'failed to delete menu item' });
  }
}

export async function listInventory(req, res) {
  try {
    const storeId = asInt(req.query?.storeId);
    let invRows = await coll('inventory').find().sort({ id: -1 }).toArray();
    if (storeId) {
      const menuIds = (await coll('menuItems').find({ store_id: storeId }).project({ id: 1 }).toArray()).map((x) => x.id);
      const midSet = new Set(menuIds);
      invRows = invRows.filter((i) => midSet.has(i.menu_item_id));
    }
    const mids = [...new Set(invRows.map((i) => i.menu_item_id))];
    const menus = await coll('menuItems').find({ id: { $in: mids } }).toArray();
    const mmap = Object.fromEntries(menus.map((m) => [m.id, m]));
    const storeIds = [...new Set(menus.map((m) => m.store_id))];
    const stores = await coll('stores').find({ id: { $in: storeIds } }).toArray();
    const smap = Object.fromEntries(stores.map((s) => [s.id, s]));
    const rows = invRows.map((i) => {
      const m = mmap[i.menu_item_id];
      const s = m ? smap[m.store_id] : null;
      return {
        ...i,
        menu_item_name: m?.name ?? null,
        store_name: s?.name ?? null,
        store_id: m?.store_id ?? null,
      };
    });
    res.json({ items: rows });
  } catch (_e) {
    res.status(500).json({ error: 'failed to fetch inventory' });
  }
}

export async function updateInventory(req, res) {
  const id = asInt(req.params.id);
  const { quantity } = req.body || {};
  if (!id || quantity == null) return res.status(400).json({ error: 'id and quantity required' });
  try {
    await coll('inventory').updateOne(
      { id },
      { $set: { quantity: asInt(quantity), updated_at: new Date() } },
    );
    res.json({ ok: true });
  } catch (_e) {
    res.status(500).json({ error: 'failed to update inventory' });
  }
}

export async function createInventory(req, res) {
  const { menuItemId, quantity } = req.body || {};
  if (!menuItemId) return res.status(400).json({ error: 'menuItemId required' });
  try {
    const mid = asInt(menuItemId);
    const existing = await coll('inventory').findOne({ menu_item_id: mid });
    if (existing) {
      await coll('inventory').updateOne(
        { id: existing.id },
        { $set: { quantity: asInt(quantity ?? 0), updated_at: new Date() } },
      );
      return res.status(201).json({ id: existing.id, ok: true });
    }
    const nid = await nextSeq(COLL.inventory);
    await coll('inventory').insertOne({
      id: nid,
      menu_item_id: mid,
      quantity: asInt(quantity ?? 0),
      updated_at: new Date(),
    });
    res.status(201).json({ id: nid, ok: true });
  } catch (_e) {
    res.status(500).json({ error: 'failed to create inventory record' });
  }
}

export async function deleteInventory(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const result = await coll('inventory').deleteOne({ id });
    res.json({ deleted: result.deletedCount === 1 });
  } catch (_e) {
    res.status(500).json({ error: 'failed to delete inventory record' });
  }
}
