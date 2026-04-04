const express = require("express");
const { pool } = require("../db/pool");

const router = express.Router();

function mapMenuItemRow(row) {
  return {
    id: row.id,
    restaurantId: row.restaurant_id,
    name: row.name,
    category: row.category,
    price: Number(row.price),
    available: row.available === 1
  };
}

// Get all menu items (optional: filter by restaurantId)
router.get("/", async (req, res) => {
  try {
    const restaurantId = req.query.restaurantId;
    let sql = "SELECT * FROM menu_items";
    const values = [];

    if (restaurantId) {
      sql += " WHERE restaurant_id = ?";
      values.push(restaurantId);
    }
    sql += " ORDER BY id DESC";

    const [rows] = await pool.query(sql, values);
    return res.json(rows.map(mapMenuItemRow));
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

// Create menu item
router.post("/", async (req, res) => {
  try {
    const { restaurantId, name, category, price, available } = req.body || {};
    if (!restaurantId || !name || !category || price === undefined) {
      return res.status(400).json({ error: "restaurantId, name, category, and price are required" });
    }

    const [result] = await pool.query(
      "INSERT INTO menu_items (restaurant_id, name, category, price, available) VALUES (?, ?, ?, ?, ?)",
      [restaurantId, name, category, price, available ? 1 : 0]
    );

    const [rows] = await pool.query("SELECT * FROM menu_items WHERE id = ?", [result.insertId]);

    // Broadcast update
    if (req.app.get("wsBroadcaster")) {
      req.app.get("wsBroadcaster")({ type: "menu-updated", restaurantId });
    }

    return res.status(201).json(mapMenuItemRow(rows[0]));
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

// Update menu item
router.put("/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    const { name, category, price, available } = req.body || {};

    const updates = [];
    const values = [];

    if (name !== undefined) { updates.push("name = ?"); values.push(name); }
    if (category !== undefined) { updates.push("category = ?"); values.push(category); }
    if (price !== undefined) { updates.push("price = ?"); values.push(price); }
    if (available !== undefined) { updates.push("available = ?"); values.push(available ? 1 : 0); }

    if (updates.length === 0) return res.status(400).json({ error: "No fields to update" });

    values.push(id);
    await pool.query(`UPDATE menu_items SET ${updates.join(", ")} WHERE id = ?`, values);

    const [rows] = await pool.query("SELECT * FROM menu_items WHERE id = ?", [id]);
    if (rows.length === 0) return res.status(404).json({ error: "Item not found" });

    // Broadcast update
    if (req.app.get("wsBroadcaster")) {
      req.app.get("wsBroadcaster")({ type: "menu-updated", restaurantId: rows[0].restaurant_id });
    }

    return res.json(mapMenuItemRow(rows[0]));
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

// Delete menu item
router.delete("/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    const [rows] = await pool.query("SELECT restaurant_id FROM menu_items WHERE id = ?", [id]);
    if (rows.length === 0) return res.status(404).json({ error: "Item not found" });
    const restaurantId = rows[0].restaurant_id;

    await pool.query("DELETE FROM menu_items WHERE id = ?", [id]);

    // Broadcast update
    if (req.app.get("wsBroadcaster")) {
      req.app.get("wsBroadcaster")({ type: "menu-updated", restaurantId });
    }

    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

module.exports = router;
