const express = require("express");
const bcrypt = require("bcryptjs");
const { pool } = require("../db/pool");

const router = express.Router();

function mapUserRow(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    mobile: row.mobile,
    address: row.address,
    isVerified: row.is_verified === 1,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

router.get("/", async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT id, name, email, mobile, address, is_verified, created_at, updated_at FROM users ORDER BY id DESC"
    );
    return res.json({ data: rows.map(mapUserRow) });
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

router.get("/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json({ error: "Invalid id" });

    const [rows] = await pool.query(
      "SELECT id, name, email, mobile, address, is_verified, created_at, updated_at FROM users WHERE id = ?",
      [id]
    );
    if (rows.length === 0) return res.status(404).json({ error: "User not found" });
    return res.json({ data: mapUserRow(rows[0]) });
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

router.post("/", async (req, res) => {
  try {
    const { name, email, mobile, address, password } = req.body || {};

    if (!name || !email || !mobile || !address || !password) {
      return res.status(400).json({ error: "name, email, mobile, address, and password are required" });
    }

    console.log(`[Backend] Creating user with password length: ${password.length}`);
    const passwordHash = await bcrypt.hash(String(password), 8);

    const [result] = await pool.query(
      "INSERT INTO users (name, email, mobile, address, password_hash, is_verified) VALUES (?, ?, ?, ?, ?, 0)",
      [name, email, mobile, address, passwordHash]
    );

    const insertedId = result.insertId;
    const [rows] = await pool.query(
      "SELECT id, name, email, mobile, address, is_verified, created_at, updated_at FROM users WHERE id = ?",
      [insertedId]
    );

    console.log(`[Backend] User created: ${name} (${email})`);
    return res.status(201).json({ data: mapUserRow(rows[0]) });
  } catch (err) {
    // MySQL duplicate key error code: ER_DUP_ENTRY
    if (err && err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ error: "Email or mobile already exists" });
    }
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

router.put("/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json({ error: "Invalid id" });

    const { name, email, mobile, address, password, isVerified } = req.body || {};

    const updates = [];
    const values = [];

    if (name !== undefined) {
      updates.push("name = ?");
      values.push(name);
    }
    if (email !== undefined) {
      updates.push("email = ?");
      values.push(email);
    }
    if (mobile !== undefined) {
      updates.push("mobile = ?");
      values.push(mobile);
    }
    if (address !== undefined) {
      updates.push("address = ?");
      values.push(address);
    }
    if (isVerified !== undefined) {
      updates.push("is_verified = ?");
      values.push(isVerified ? 1 : 0);
    }

    if (password !== undefined && password !== null && String(password).trim() !== "") {
      console.log(`[Backend] Updating password for user ${id}, length: ${password.length}`);
      const passwordHash = await bcrypt.hash(String(password), 8);
      updates.push("password_hash = ?");
      values.push(passwordHash);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: "Provide at least one field to update" });
    }

    values.push(id);

    const sql = `UPDATE users SET ${updates.join(", ")} WHERE id = ?`;
    const [result] = await pool.query(sql, values);

    if (result.affectedRows === 0) return res.status(404).json({ error: "User not found" });

    const [rows] = await pool.query(
      "SELECT id, name, email, mobile, address, is_verified, created_at, updated_at FROM users WHERE id = ?",
      [id]
    );

    return res.json({ data: mapUserRow(rows[0]) });
  } catch (err) {
    if (err && err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ error: "Email or mobile already exists" });
    }
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json({ error: "Invalid id" });

    const [result] = await pool.query("DELETE FROM users WHERE id = ?", [id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: "User not found" });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

module.exports = router;

