const express = require("express");
const { pool } = require("../db/pool");

const router = express.Router();

function mapRestaurantRow(row) {
  return {
    id: row.id,
    name: row.name,
    location: row.location,
    contactDetails: row.contact_details,
    rating: Number(row.rating),
    openingHours: row.opening_hours,
    category: row.category,
    status: row.status
  };
}

// Get all restaurants
router.get("/", async (req, res) => {
  try {
    const [rows] = await pool.query("SELECT * FROM restaurants ORDER BY id DESC");
    return res.json(rows.map(mapRestaurantRow));
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

// Create restaurant
router.post("/", async (req, res) => {
  try {
    const { name, location, contactDetails, openingHours, category, status } = req.body || {};
    if (!name || !location) {
      return res.status(400).json({ error: "name and location are required" });
    }

    const [result] = await pool.query(
      "INSERT INTO restaurants (name, location, contact_details, opening_hours, category, status) VALUES (?, ?, ?, ?, ?, ?)",
      [name, location, contactDetails, openingHours, category, status || 'active']
    );

    const [rows] = await pool.query("SELECT * FROM restaurants WHERE id = ?", [result.insertId]);
    return res.status(201).json(mapRestaurantRow(rows[0]));
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

// Update restaurant
router.put("/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    const { name, location, contactDetails, openingHours, category, status, rating } = req.body || {};

    const updates = [];
    const values = [];

    const fields = { name, location, contact_details: contactDetails, opening_hours: openingHours, category, status, rating };
    for (const [key, value] of Object.entries(fields)) {
      if (value !== undefined) {
        updates.push(`${key} = ?`);
        values.push(value);
      }
    }

    if (updates.length === 0) return res.status(400).json({ error: "No fields to update" });

    values.push(id);
    await pool.query(`UPDATE restaurants SET ${updates.join(", ")} WHERE id = ?`, values);

    const [rows] = await pool.query("SELECT * FROM restaurants WHERE id = ?", [id]);
    if (rows.length === 0) return res.status(404).json({ error: "Restaurant not found" });

    // Broadcast update
    if (req.app.get("wsBroadcaster")) {
      req.app.get("wsBroadcaster")({ type: "restaurant-updated" });
    }

    return res.json(mapRestaurantRow(rows[0]));
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

// Delete restaurant
router.delete("/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    const [result] = await pool.query("DELETE FROM restaurants WHERE id = ?", [id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: "Restaurant not found" });

    // Broadcast update
    if (req.app.get("wsBroadcaster")) {
      req.app.get("wsBroadcaster")({ type: "restaurant-updated" });
    }

    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

module.exports = router;
