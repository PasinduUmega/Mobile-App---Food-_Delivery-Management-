import { coll } from '../repositories/mongo.repository.js';
import { asInt } from '../utils/parsers.js';
import {
  createMenuItem as createCatalogMenuItem,
  updateMenuItem as updateCatalogMenuItem,
  deleteMenuItem as deleteCatalogMenuItem,
} from './catalog.controller.js';

export async function listMenuItems(req, res) {
  try {
    const storeId = asInt(req.query?.storeId);
    const filter = storeId ? { store_id: storeId } : {};
    const items = await coll('menuItems').find(filter).sort({ id: -1 }).toArray();
    res.json({ items });
  } catch (_e) {
    res.status(500).json({ error: 'failed to fetch menu items' });
  }
}

export async function getMenuItem(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const item = await coll('menuItems').findOne({ id });
    if (!item) return res.status(404).json({ error: 'menu item not found' });
    res.json(item);
  } catch (_e) {
    res.status(500).json({ error: 'failed to fetch menu item' });
  }
}

export const createMenuItem = createCatalogMenuItem;
export const updateMenuItem = updateCatalogMenuItem;
export const deleteMenuItem = deleteCatalogMenuItem;
