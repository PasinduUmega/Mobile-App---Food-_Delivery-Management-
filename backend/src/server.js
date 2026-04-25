import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { nanoid } from 'nanoid';
import { createPoolFromEnv } from './db.js';
import { paypalClient, buildCreateOrderRequest, buildCaptureOrderRequest } from './paypal.js';

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

const pool = createPoolFromEnv();
const client = (() => {
  try {
    return paypalClient();
  } catch (e) {
    console.error('PayPal Initialization Error:', e.message);
    // allow backend to run for COD / receipt even without PayPal env configured
    return null;
  }
})();

app.get('/health', async (_req, res) => {
  const [[row]] = await pool.query('SELECT 1 as ok');
  res.json({ ok: row.ok === 1 });
});

const PAYMENT_METHODS = new Set(['PAYPAL', 'CASH_ON_DELIVERY', 'ONLINE_BANKING']);
const PAYMENT_STATUSES = new Set(['CREATED', 'APPROVAL_PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'CANCELLED']);

function asInt(v) {
  const n = Number(v);
  return Number.isInteger(n) ? n : null;
}

/** Caller identity for lightweight checks (sent by the Flutter app after sign-in). */
function readActorUserId(req) {
  const raw = req.headers['x-user-id'] ?? req.headers['X-User-Id'];
  return asInt(raw);
}

async function dbUserIsAdmin(actorId) {
  if (!actorId) return false;
  const [[row]] = await pool.query('SELECT role FROM users WHERE id = ?', [actorId]);
  return row && String(row.role ?? 'CUSTOMER').toUpperCase() === 'ADMIN';
}

function asMoney(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function normalizeCurrency(v) {
  const s = String(v ?? '').trim().toUpperCase();
  return /^[A-Z]{3}$/.test(s) ? s : null;
}

function asFloat(v) {
  const n = parseFloat(v);
  return Number.isNaN(n) ? null : n;
}

const MAX_CART_LINE_QTY = 50;

function stringifyComboComponents(arr) {
  if (!Array.isArray(arr) || arr.length === 0) return null;
  const cleaned = arr.map((s) => String(s ?? '').trim()).filter(Boolean).slice(0, 30);
  return cleaned.length ? JSON.stringify(cleaned) : null;
}

function normalizeComboComponentsInput(body) {
  if (Array.isArray(body?.comboComponents)) {
    return stringifyComboComponents(body.comboComponents);
  }
  if (typeof body?.comboComponents === 'string' && body.comboComponents.trim()) {
    return stringifyComboComponents(
      body.comboComponents.split(/[\n,]+/).map((s) => s.trim()).filter(Boolean),
    );
  }
  return null;
}

/** Stock + store match + max line qty before adding to cart. */
async function assertCartAddAllowed(pool, { cartId, productId, addQty }) {
  const cartIdN = asInt(cartId);
  const productIdN = asInt(productId);
  const add = Number(addQty);
  if (!cartIdN || !productIdN || !Number.isFinite(add) || add <= 0) {
    throw Object.assign(new Error('invalid cart or product'), { code: 'BAD' });
  }
  const [[cart]] = await pool.query('SELECT store_id FROM carts WHERE id = ?', [cartIdN]);
  if (!cart) throw Object.assign(new Error('cart not found'), { code: 'BAD' });
  const [[menu]] = await pool.query('SELECT id, store_id FROM menu_items WHERE id = ?', [productIdN]);
  if (!menu) throw Object.assign(new Error('menu item not found'), { code: 'BAD' });
  if (cart.store_id != null && Number(menu.store_id) !== Number(cart.store_id)) {
    throw Object.assign(new Error('This item is not from the restaurant tied to your cart'), { code: 'BAD' });
  }
  const [[inv]] = await pool.query('SELECT quantity FROM inventory WHERE menu_item_id = ?', [productIdN]);
  const stock = inv && inv.quantity != null ? Number(inv.quantity) : 0;
  const [[existing]] = await pool.query(
    'SELECT qty FROM cart_items WHERE cart_id = ? AND product_id = ?',
    [cartIdN, productIdN],
  );
  const current = existing ? Number(existing.qty) : 0;
  const need = current + add;
  if (need > MAX_CART_LINE_QTY) {
    throw Object.assign(new Error(`Quantity cannot exceed ${MAX_CART_LINE_QTY} per line`), { code: 'BAD' });
  }
  if (need > stock) {
    throw Object.assign(new Error('Not enough stock for this item'), { code: 'BAD' });
  }
}

async function assertCartLineQtyUpdate(pool, { cartId, itemId, newQty }) {
  const cartIdN = asInt(cartId);
  const itemIdN = asInt(itemId);
  const nq = asInt(newQty);
  if (!cartIdN || !itemIdN || nq == null || nq < 0) {
    throw Object.assign(new Error('invalid params'), { code: 'BAD' });
  }
  if (nq === 0) return;
  const [[row]] = await pool.query(
    'SELECT product_id FROM cart_items WHERE id = ? AND cart_id = ?',
    [itemIdN, cartIdN],
  );
  if (!row) throw Object.assign(new Error('cart line not found'), { code: 'BAD' });
  const pid = asInt(row.product_id);
  const [[inv]] = await pool.query('SELECT quantity FROM inventory WHERE menu_item_id = ?', [pid]);
  const stock = inv && inv.quantity != null ? Number(inv.quantity) : 0;
  if (nq > MAX_CART_LINE_QTY) {
    throw Object.assign(new Error(`Quantity cannot exceed ${MAX_CART_LINE_QTY} per line`), { code: 'BAD' });
  }
  if (nq > stock) {
    throw Object.assign(new Error('Not enough stock for this item'), { code: 'BAD' });
  }
}

/** Strip password hash from user rows returned by the API */
function sanitizeUserRow(row) {
  if (!row) return row;
  const u = { ...row };
  delete u.password_hash;
  if (u.role != null && u.role !== undefined) {
    u.role = String(u.role).trim().toUpperCase();
  }
  return u;
}

const USER_ROLES = new Set(['CUSTOMER', 'ADMIN', 'STORE_OWNER', 'DELIVERY_DRIVER']);
/** Public signup roles */
const SIGNUP_ROLES = new Set(['CUSTOMER', 'ADMIN', 'STORE_OWNER', 'DELIVERY_DRIVER']);

function normalizeUserRole(raw, { allowAdmin } = {}) {
  const r = String(raw ?? 'CUSTOMER').trim().toUpperCase();
  if (!USER_ROLES.has(r)) return 'CUSTOMER';
  if (r === 'ADMIN' && !allowAdmin) return 'CUSTOMER';
  return r;
}

/** Optional YYYY-MM-DD or null */
function parseOptionalDateOnly(v) {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  if (!s) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  return s;
}

async function createReceiptIfMissing(conn, { orderId, paymentId, paidAmount, currency, rawProviderResponse }) {
  const [[existing]] = await conn.query('SELECT id FROM receipts WHERE order_id=? LIMIT 1', [orderId]);
  if (existing) return;
  const receiptNo = `FR-${new Date().getFullYear()}-${nanoid(10).toUpperCase()}`;
  await conn.query(
    `INSERT INTO receipts (order_id, payment_id, receipt_no, paid_amount, currency, raw_provider_response)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [orderId, paymentId, receiptNo, paidAmount, currency, rawProviderResponse ? JSON.stringify(rawProviderResponse) : null],
  );
}

/** After checkout, drivers see a PENDING delivery row (idempotent). */
async function ensureDeliveryJobForOrder(conn, orderId) {
  const oid = asInt(orderId);
  if (!oid) return;
  try {
    await conn.query('INSERT IGNORE INTO deliveries (order_id) VALUES (?)', [oid]);
  } catch (e) {
    console.warn('ensureDeliveryJobForOrder:', e?.message ?? e);
  }
}

async function isDriverBusy({ driverPhone, excludeDeliveryId = null } = {}) {
  const phone = String(driverPhone ?? '').trim();
  if (!phone) return false;
  const activeStatuses = ['PENDING', 'PICKED_UP', 'OUT_FOR_DELIVERY'];
  const params = [phone, ...activeStatuses];
  let sql = `
    SELECT id
    FROM deliveries
    WHERE driver_phone = ?
      AND status IN (?, ?, ?)
  `;
  if (excludeDeliveryId != null) {
    sql += ' AND id <> ?';
    params.push(excludeDeliveryId);
  }
  sql += ' LIMIT 1';
  const [[row]] = await pool.query(sql, params);
  return Boolean(row);
}

// Create an order in MySQL
app.post('/api/orders', async (req, res) => {
  const { userId = null, storeId = null, currency = 'USD', items = [], deliveryFee = 0 } = req.body || {};
  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'items required' });
  }

  const normalizedItems = items.map((it) => ({
    productId: it.productId ?? null,
    name: String(it.name ?? ''),
    qty: Number(it.qty ?? 0),
    unitPrice: Number(it.unitPrice ?? 0),
    lineNote: it.lineNote != null && String(it.lineNote).trim()
      ? String(it.lineNote).trim().slice(0, 500)
      : null,
  }));
  if (normalizedItems.some((it) => !it.name || !Number.isFinite(it.qty) || it.qty <= 0 || !Number.isFinite(it.unitPrice) || it.unitPrice < 0)) {
    return res.status(400).json({ error: 'invalid items' });
  }

  const subtotal = normalizedItems.reduce((s, it) => s + it.qty * it.unitPrice, 0);
  const delivery = Number(deliveryFee ?? 0);
  const total = subtotal + delivery;
  const deliveryLat = asFloat(req.body.deliveryLatitude);
  const deliveryLng = asFloat(req.body.deliveryLongitude);

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [orderResult] = await conn.query(
      `INSERT INTO orders (user_id, store_id, currency, subtotal, delivery_fee, total, status, delivery_latitude, delivery_longitude)
       VALUES (?, ?, ?, ?, ?, ?, 'PENDING_PAYMENT', ?, ?)`,
      [userId, storeId, currency, subtotal, delivery, total, deliveryLat, deliveryLng],
    );
    const orderId = orderResult.insertId;

    for (const it of normalizedItems) {
      const lineTotal = it.qty * it.unitPrice;
      await conn.query(
        `INSERT INTO order_items (order_id, product_id, name, qty, unit_price, line_total, line_note)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [orderId, it.productId, it.name, it.qty, it.unitPrice, lineTotal, it.lineNote],
      );
    }
    await conn.commit();
    res.json({ orderId, currency, subtotal, deliveryFee: delivery, total });
  } catch (e) {
    await conn.rollback();
    console.error('Create order error:', e);
    res.status(500).json({ error: `failed to create order: ${e.message}` });
  } finally {
    conn.release();
  }
});

async function fetchOrders({ userId = null, storeId = null, status = null, limit = 50, offset = 0 } = {}) {
  const where = [];
  const params = [];
  if (userId != null) {
    where.push('user_id = ?');
    params.push(userId);
  }
  if (storeId != null) {
    where.push('store_id = ?');
    params.push(storeId);
  }
  if (status) {
    where.push('status = ?');
    params.push(status);
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const [rows] = await pool.query(
    `SELECT id, user_id, store_id, currency, subtotal, delivery_fee, total, status, created_at, updated_at
     FROM orders
     ${whereSql}
     ORDER BY id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, offset],
  );

  return rows;
}

// List orders (optionally filtered by userId/storeId/status)
app.get('/api/orders', async (req, res) => {
  const userId = req.query.userId ? asInt(req.query.userId) : null;
  const storeId = req.query.storeId ? asInt(req.query.storeId) : null;
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 200) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;

  const rows = await fetchOrders({ userId, storeId, status, limit, offset });
  res.json({ items: rows });
});
// Admin: get all orders that need a driver assigned
// ⚠️ Must be BEFORE /api/orders/:id
app.get('/api/orders/unassigned', async (req, res) => {
  const [rows] = await pool.query(
    `SELECT o.*, 
            d.id as delivery_id, d.driver_name, d.driver_phone, d.status as delivery_status
     FROM orders o
     LEFT JOIN deliveries d ON d.order_id = o.id
     WHERE o.status IN ('PAID', 'PREPARING','PENDING_PAYMENT')
       AND (d.id IS NULL OR d.driver_name IS NULL)
     ORDER BY o.created_at ASC`
  );
  res.json({ items: rows });
});

app.get('/api/orders/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const [[order]] = await pool.query('SELECT * FROM orders WHERE id = ?', [id]);
    if (!order) return res.status(404).json({ error: 'order not found' });
    const [items] = await pool.query('SELECT * FROM order_items WHERE order_id = ?', [id]);
    order.items = items;
    res.json(order);
  } catch (e) {
    res.status(500).json({ error: 'failed to fetch order details' });
  }
});

app.get('/api/users/:userId/orders', async (req, res) => {
  const userId = asInt(req.params.userId);
  if (!userId) return res.status(400).json({ error: 'invalid userId' });
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 200) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;

  const rows = await fetchOrders({ userId, status, limit, offset });
  res.json({ items: rows });
});

app.get('/api/stores/:storeId/orders', async (req, res) => {
  const storeId = asInt(req.params.storeId);
  if (!storeId) return res.status(400).json({ error: 'invalid storeId' });
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 200) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;

  const rows = await fetchOrders({ storeId, status, limit, offset });
  res.json({ items: rows });
});

// Update an order (status and/or items)
app.put('/api/orders/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });

  const status = req.body?.status ? String(req.body.status).toUpperCase() : null;
  const items = req.body?.items;

  if (!status && !items) return res.status(400).json({ error: 'no update fields provided' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [[order]] = await conn.query('SELECT * FROM orders WHERE id = ? FOR UPDATE', [id]);
    if (!order) {
      await conn.rollback();
      return res.status(404).json({ error: 'order not found' });
    }

    if (status) {
      await conn.query('UPDATE orders SET status=?, updated_at=NOW() WHERE id=?', [status, id]);
    }

    // If items are provided, update the cart items and totals
    if (Array.isArray(items)) {
      const normalizedItems = items.map((it) => ({
        productId: it.productId ?? null,
        name: String(it.name ?? ''),
        qty: Number(it.qty ?? 0),
        unitPrice: Number(it.unitPrice ?? 0),
        lineNote: it.lineNote != null && String(it.lineNote).trim()
          ? String(it.lineNote).trim().slice(0, 500)
          : null,
      }));

      if (normalizedItems.some((it) => !it.name || !Number.isFinite(it.qty) || it.qty <= 0 || !Number.isFinite(it.unitPrice) || it.unitPrice < 0)) {
        await conn.rollback();
        return res.status(400).json({ error: 'invalid items array' });
      }

      const subtotal = normalizedItems.reduce((s, it) => s + it.qty * it.unitPrice, 0);
      const delivery = Number(order.delivery_fee ?? 0);
      const total = subtotal + delivery;

      await conn.query('UPDATE orders SET subtotal=?, total=?, updated_at=NOW() WHERE id=?', [subtotal, total, id]);

      // Replace existing order items
      await conn.query('DELETE FROM order_items WHERE order_id=?', [id]);
      for (const it of normalizedItems) {
        const lineTotal = it.qty * it.unitPrice;
        await conn.query(
          `INSERT INTO order_items (order_id, product_id, name, qty, unit_price, line_total, line_note)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [id, it.productId, it.name, it.qty, it.unitPrice, lineTotal, it.lineNote],
        );
      }
    }

    await conn.commit();
    res.json({ ok: true });
  } catch (e) {
    await conn.rollback();
    console.error('Update order error:', e);
    res.status(500).json({ error: 'failed to update order' });
  } finally {
    conn.release();
  }
});

// Delete an order
app.delete('/api/orders/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    // Check if order exists and get its status
    const [[order]] = await pool.query('SELECT id, status FROM orders WHERE id = ?', [id]);
    if (!order) return res.status(404).json({ error: 'order not found' });

    // Prevent deletion of paid/completed orders
    const protectedStatuses = ['PAID', 'COMPLETED', 'PREPARING', 'READY'];
    if (protectedStatuses.includes(order.status)) {
      return res.status(400).json({ error: `Cannot delete order with status: ${order.status}. Only PENDING_PAYMENT, CANCELLED, and FAILED orders can be deleted.` });
    }

    const [result] = await pool.query('DELETE FROM orders WHERE id=?', [id]);
    res.json({ deleted: result.affectedRows === 1 });
  } catch (e) {
    console.error('Delete order error:', e);
    res.status(500).json({ error: 'failed to delete order' });
  }
});

// Start PayPal Checkout for an order
app.post('/api/payments/paypal/create', async (req, res) => {
  if (!client) return res.status(500).json({ error: 'PayPal not configured on server' });
  const { orderId } = req.body || {};
  if (!orderId) return res.status(400).json({ error: 'orderId required' });

  const [[order]] = await pool.query('SELECT id, total, currency, status FROM orders WHERE id = ?', [orderId]);
  if (!order) return res.status(404).json({ error: 'order not found' });
  if (order.status !== 'PENDING_PAYMENT') return res.status(400).json({ error: 'order not payable' });

  const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 8080}`;
  const returnUrl = `${baseUrl}/api/payments/paypal/return?orderId=${order.id}`;
  const cancelUrl = `${baseUrl}/api/payments/paypal/cancel?orderId=${order.id}`;

  const request = buildCreateOrderRequest({
    total: Number(order.total),
    currency: order.currency,
    returnUrl,
    cancelUrl,
  });

  try {
    const response = await client.execute(request);
    const paypalOrderId = response.result.id;
    const approval = (response.result.links || []).find((l) => l.rel === 'approve');
    const approvalUrl = approval?.href ?? null;
    if (!approvalUrl) return res.status(500).json({ error: 'missing PayPal approval url' });

    const [paymentResult] = await pool.query(
      `INSERT INTO payments (order_id, method, status, provider, provider_order_id, approval_url, amount, currency)
       VALUES (?, 'PAYPAL', 'APPROVAL_PENDING', 'PAYPAL', ?, ?, ?, ?)`,
      [order.id, paypalOrderId, approvalUrl, order.total, order.currency],
    );

    res.json({ paymentId: paymentResult.insertId, paypalOrderId, approvalUrl });
  } catch (e) {
    console.error('PayPal create order error:', e);
    res.status(500).json({ error: 'failed to create PayPal order' });
  }
});

// Capture PayPal payment (client calls after approval)
app.post('/api/payments/paypal/capture', async (req, res) => {
  if (!client) return res.status(500).json({ error: 'PayPal not configured on server' });
  const { orderId } = req.body || {};
  if (!orderId) return res.status(400).json({ error: 'orderId required' });

  const [[payment]] = await pool.query(
    `SELECT id, provider_order_id, status, amount, currency
     FROM payments
     WHERE order_id = ? AND method = 'PAYPAL'
     ORDER BY id DESC
     LIMIT 1`,
    [orderId],
  );
  if (!payment) return res.status(404).json({ error: 'payment not found' });
  if (!payment.provider_order_id) return res.status(400).json({ error: 'missing provider order id' });

  try {
    const response = await client.execute(buildCaptureOrderRequest(payment.provider_order_id));
    const capture = response?.result?.purchase_units?.[0]?.payments?.captures?.[0];
    const captureId = capture?.id ?? null;
    const status = response?.result?.status ?? 'UNKNOWN';

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      if (status === 'COMPLETED') {
        await conn.query(
          `UPDATE payments SET status='CAPTURED', provider_capture_id=?, updated_at=NOW() WHERE id=?`,
          [captureId, payment.id],
        );
        await conn.query(`UPDATE orders SET status='PAID', updated_at=NOW() WHERE id=?`, [orderId]);

        const receiptNo = `FR-${new Date().getFullYear()}-${nanoid(10).toUpperCase()}`;
        await conn.query(
          `INSERT INTO receipts (order_id, payment_id, receipt_no, paid_amount, currency, raw_provider_response)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [orderId, payment.id, receiptNo, payment.amount, payment.currency, JSON.stringify(response.result)],
        );
        await ensureDeliveryJobForOrder(conn, orderId);
      } else {
        await conn.query(`UPDATE payments SET status='FAILED', updated_at=NOW() WHERE id=?`, [payment.id]);
        await conn.query(`UPDATE orders SET status='FAILED', updated_at=NOW() WHERE id=?`, [orderId]);
      }
      await conn.commit();
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }

    res.json({ ok: true, paypalStatus: status });
  } catch (e) {
    console.error('PayPal capture order error:', e);
    res.status(500).json({ error: 'failed to capture PayPal order' });
  }
});

// Cash on delivery confirm (creates receipt immediately)
app.post('/api/payments/cod/confirm', async (req, res) => {
  const { orderId } = req.body || {};
  if (!orderId) return res.status(400).json({ error: 'orderId required' });

  const [[order]] = await pool.query('SELECT id, total, currency, status FROM orders WHERE id=?', [orderId]);
  if (!order) return res.status(404).json({ error: 'order not found' });
  if (order.status !== 'PENDING_PAYMENT') return res.status(400).json({ error: 'order not payable' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [payRes] = await conn.query(
      `INSERT INTO payments (order_id, method, status, provider, amount, currency)
       VALUES (?, 'CASH_ON_DELIVERY', 'CAPTURED', 'COD', ?, ?)`,
      [orderId, order.total, order.currency],
    );
    await conn.query(`UPDATE orders SET status='PAID', updated_at=NOW() WHERE id=?`, [orderId]);
    const receiptNo = `FR-${new Date().getFullYear()}-${nanoid(10).toUpperCase()}`;
    await conn.query(
      `INSERT INTO receipts (order_id, payment_id, receipt_no, paid_amount, currency, raw_provider_response)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [orderId, payRes.insertId, receiptNo, order.total, order.currency, JSON.stringify({ method: 'COD' })],
    );
    await ensureDeliveryJobForOrder(conn, orderId);
    await conn.commit();
    res.json({ ok: true });
  } catch (e) {
    await conn.rollback();
    console.error('confirmCod error:', e);
    res.status(500).json({ error: e?.message ?? 'failed to confirm COD' });
  } finally {
    conn.release();
  }
});

// Online banking placeholder (keeps flow consistent; you'd integrate a bank gateway similarly)
app.post('/api/payments/online-banking/confirm', async (req, res) => {
  const { orderId, reference = null } = req.body || {};
  if (!orderId) return res.status(400).json({ error: 'orderId required' });

  const [[order]] = await pool.query('SELECT id, total, currency, status FROM orders WHERE id=?', [orderId]);
  if (!order) return res.status(404).json({ error: 'order not found' });
  if (order.status !== 'PENDING_PAYMENT') return res.status(400).json({ error: 'order not payable' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [payRes] = await conn.query(
      `INSERT INTO payments (order_id, method, status, provider, provider_order_id, amount, currency)
       VALUES (?, 'ONLINE_BANKING', 'CAPTURED', 'BANK', ?, ?, ?)`,
      [orderId, reference ? String(reference) : null, order.total, order.currency],
    );
    await conn.query(`UPDATE orders SET status='PAID', updated_at=NOW() WHERE id=?`, [orderId]);
    const receiptNo = `FR-${new Date().getFullYear()}-${nanoid(10).toUpperCase()}`;
    await conn.query(
      `INSERT INTO receipts (order_id, payment_id, receipt_no, paid_amount, currency, raw_provider_response)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [orderId, payRes.insertId, receiptNo, order.total, order.currency, JSON.stringify({ method: 'ONLINE_BANKING', reference })],
    );
    await ensureDeliveryJobForOrder(conn, orderId);
    await conn.commit();
    res.json({ ok: true });
  } catch (e) {
    await conn.rollback();
    res.status(500).json({ error: 'failed to confirm online banking' });
  } finally {
    conn.release();
  }
});

// -----------------------------
// Payments CRUD (for app UI)
// -----------------------------

// List payments (optionally filter by orderId/method/status)
app.get('/api/payments', async (req, res) => {
  const orderId = req.query.orderId ? asInt(req.query.orderId) : null;
  const method = req.query.method ? String(req.query.method).toUpperCase() : null;
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 200) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;

  if (method && !PAYMENT_METHODS.has(method)) return res.status(400).json({ error: 'invalid method' });
  if (status && !PAYMENT_STATUSES.has(status)) return res.status(400).json({ error: 'invalid status' });

  const where = [];
  const params = [];
  if (orderId) {
    where.push('p.order_id = ?');
    params.push(orderId);
  }
  if (method) {
    where.push('p.method = ?');
    params.push(method);
  }
  if (status) {
    where.push('p.status = ?');
    params.push(status);
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const [rows] = await pool.query(
    `SELECT p.*
     FROM payments p
     ${whereSql}
     ORDER BY p.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, offset],
  );
  res.json({ items: rows });
});

// Get a payment by id
app.get('/api/payments/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const [[row]] = await pool.query('SELECT * FROM payments WHERE id=?', [id]);
  if (!row) return res.status(404).json({ error: 'payment not found' });
  res.json(row);
});

// Create a payment record (useful for wallet/bank flows)
app.post('/api/payments', async (req, res) => {
  const orderId = asInt(req.body?.orderId);
  const method = String(req.body?.method ?? '').toUpperCase();
  const status = req.body?.status ? String(req.body.status).toUpperCase() : 'CREATED';
  const provider = req.body?.provider != null ? String(req.body.provider) : null;
  const providerOrderId = req.body?.providerOrderId != null ? String(req.body.providerOrderId) : null;
  const providerCaptureId = req.body?.providerCaptureId != null ? String(req.body.providerCaptureId) : null;
  const approvalUrl = req.body?.approvalUrl != null ? String(req.body.approvalUrl) : null;
  const amount = asMoney(req.body?.amount);
  const currency = normalizeCurrency(req.body?.currency);

  if (!orderId) return res.status(400).json({ error: 'orderId required' });
  if (!PAYMENT_METHODS.has(method)) return res.status(400).json({ error: 'invalid method' });
  if (!PAYMENT_STATUSES.has(status)) return res.status(400).json({ error: 'invalid status' });
  if (amount == null || amount < 0) return res.status(400).json({ error: 'invalid amount' });
  if (!currency) return res.status(400).json({ error: 'invalid currency' });

  const [[order]] = await pool.query('SELECT id, total, currency, status as order_status FROM orders WHERE id=?', [orderId]);
  if (!order) return res.status(404).json({ error: 'order not found' });

  const [result] = await pool.query(
    `INSERT INTO payments (order_id, method, status, provider, provider_order_id, provider_capture_id, approval_url, amount, currency)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [orderId, method, status, provider, providerOrderId, providerCaptureId, approvalUrl, amount, currency],
  );

  // If created already CAPTURED, ensure order/receipt consistency.
  if (status === 'CAPTURED') {
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      await conn.query(`UPDATE orders SET status='PAID', updated_at=NOW() WHERE id=?`, [orderId]);
      await createReceiptIfMissing(conn, {
        orderId,
        paymentId: result.insertId,
        paidAmount: amount,
        currency,
        rawProviderResponse: { method, provider, providerOrderId, providerCaptureId },
      });
      await conn.commit();
    } catch (e) {
      await conn.rollback();
      // do not fail creation; client can re-sync via update endpoint
    } finally {
      conn.release();
    }
  }

  res.status(201).json({ id: result.insertId });
});

// Update a payment (status/provider fields). If status becomes CAPTURED, issue receipt + mark order PAID.
app.put('/api/payments/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });

  const patch = {
    status: req.body?.status != null ? String(req.body.status).toUpperCase() : null,
    provider: req.body?.provider != null ? String(req.body.provider) : null,
    provider_order_id: req.body?.providerOrderId != null ? String(req.body.providerOrderId) : null,
    provider_capture_id: req.body?.providerCaptureId != null ? String(req.body.providerCaptureId) : null,
    approval_url: req.body?.approvalUrl != null ? String(req.body.approvalUrl) : null,
  };
  if (patch.status && !PAYMENT_STATUSES.has(patch.status)) return res.status(400).json({ error: 'invalid status' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [[payment]] = await conn.query('SELECT * FROM payments WHERE id=? FOR UPDATE', [id]);
    if (!payment) {
      await conn.rollback();
      return res.status(404).json({ error: 'payment not found' });
    }

    const nextStatus = patch.status ?? payment.status;
    await conn.query(
      `UPDATE payments
       SET status=?, provider=COALESCE(?, provider), provider_order_id=COALESCE(?, provider_order_id),
           provider_capture_id=COALESCE(?, provider_capture_id), approval_url=COALESCE(?, approval_url),
           updated_at=NOW()
       WHERE id=?`,
      [nextStatus, patch.provider, patch.provider_order_id, patch.provider_capture_id, patch.approval_url, id],
    );

    if (nextStatus === 'CAPTURED') {
      await conn.query(`UPDATE orders SET status='PAID', updated_at=NOW() WHERE id=?`, [payment.order_id]);
      await createReceiptIfMissing(conn, {
        orderId: payment.order_id,
        paymentId: id,
        paidAmount: Number(payment.amount),
        currency: payment.currency,
        rawProviderResponse: { status: nextStatus, provider: patch.provider ?? payment.provider },
      });
    } else if (nextStatus === 'FAILED') {
      await conn.query(`UPDATE orders SET status='FAILED', updated_at=NOW() WHERE id=?`, [payment.order_id]);
    } else if (nextStatus === 'CANCELLED') {
      await conn.query(`UPDATE orders SET status='CANCELLED', updated_at=NOW() WHERE id=?`, [payment.order_id]);
    }

    await conn.commit();
    res.json({ ok: true });
  } catch (e) {
    await conn.rollback();
    res.status(500).json({ error: 'failed to update payment' });
  } finally {
    conn.release();
  }
});

// Delete a payment (mainly for dev/test; will fail if a receipt references it)
app.delete('/api/payments/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const [result] = await pool.query('DELETE FROM payments WHERE id=?', [id]);
    res.json({ deleted: result.affectedRows === 1 });
  } catch (e) {
    res.status(409).json({ error: 'cannot delete payment (maybe receipt exists)' });
  }
});

// Receipt fetch (Flutter will poll this until it exists)
app.get('/api/receipts/:orderId', async (req, res) => {
  const orderId = req.params.orderId;
  const [[order]] = await pool.query('SELECT id, status, total, currency FROM orders WHERE id=?', [orderId]);
  if (!order) return res.status(404).json({ error: 'order not found' });

  const [[receipt]] = await pool.query(
    `SELECT r.receipt_no, r.issued_at, r.paid_amount, r.currency, p.method, p.status as payment_status
     FROM receipts r
     JOIN payments p ON p.id = r.payment_id
     WHERE r.order_id = ?
     LIMIT 1`,
    [orderId],
  );

  res.json({
    orderId: order.id,
    orderStatus: order.status,
    total: Number(order.total),
    currency: order.currency,
    receipt: receipt
      ? {
        receiptNo: receipt.receipt_no,
        issuedAt: receipt.issued_at,
        paidAmount: Number(receipt.paid_amount),
        currency: receipt.currency,
        paymentMethod: receipt.method,
        paymentStatus: receipt.payment_status,
      }
      : null,
  });
});

// User management CRUD
app.get('/api/users', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM users ORDER BY id DESC');
  res.json({ items: rows.map(sanitizeUserRow) });
});

app.get('/api/users/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const [[user]] = await pool.query('SELECT * FROM users WHERE id = ?', [id]);
  if (!user) return res.status(404).json({ error: 'user not found' });
  res.json(sanitizeUserRow(user));
});

app.post('/api/users', async (req, res) => {
  const name = String(req.body?.name ?? '').trim();
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  if (!name || !email) return res.status(400).json({ error: 'name/email required' });
  try {
    const [result] = await pool.query('INSERT INTO users (name, email) VALUES (?, ?)', [name, email]);
    const [[created]] = await pool.query('SELECT * FROM users WHERE id = ?', [result.insertId]);
    res.status(201).json(sanitizeUserRow(created));
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'email already exists' });
    }
    console.error('Create user error:', e);
    res.status(500).json({ error: 'failed to create user' });
  }
});

app.put('/api/users/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const name = String(req.body?.name ?? '').trim();
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  if (!name || !email) return res.status(400).json({ error: 'name/email required' });
  const roleProvided =
    req.body?.role != null && String(req.body.role).trim() !== '';
  let role = null;
  if (roleProvided) {
    const actorId = readActorUserId(req);
    if (!(await dbUserIsAdmin(actorId))) {
      return res.status(403).json({ error: 'Only administrators can change user roles' });
    }
    role = normalizeUserRole(req.body.role, { allowAdmin: true });
  }
  try {
    if (role != null) {
      const [result] = await pool.query(
        'UPDATE users SET name=?, email=?, role=?, updated_at=NOW() WHERE id=?',
        [name, email, role, id]
      );
      if (result.affectedRows !== 1) return res.status(404).json({ error: 'user not found' });
    } else {
      const [result] = await pool.query(
        'UPDATE users SET name=?, email=?, updated_at=NOW() WHERE id=?',
        [name, email, id]
      );
      if (result.affectedRows !== 1) return res.status(404).json({ error: 'user not found' });
    }
    const [[updated]] = await pool.query('SELECT * FROM users WHERE id = ?', [id]);
    res.json(sanitizeUserRow(updated));
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'email already exists' });
    }
    console.error('Update user error:', e);
    res.status(500).json({ error: 'failed to update user' });
  }
});

app.delete('/api/users/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const [result] = await pool.query('DELETE FROM users WHERE id=?', [id]);
    res.json({ deleted: result.affectedRows === 1 });
  } catch (e) {
    res.status(500).json({ error: 'failed to delete user' });
  }
});

// -----------------------------
// Driver profile + ratings APIs
// -----------------------------
function normalizeDriverStatus(raw) {
  const s = String(raw ?? 'ACTIVE').trim().toUpperCase();
  if (['ACTIVE', 'INACTIVE', 'ON_DELIVERY', 'PENDING_VERIFICATION'].includes(s)) {
    return s;
  }
  return 'ACTIVE';
}

async function computeDriverRuntimeStatus(profileRow) {
  const base = normalizeDriverStatus(profileRow?.status);
  if (base === 'INACTIVE' || base === 'PENDING_VERIFICATION') return base;
  const phone = String(profileRow?.phone ?? '').trim();
  const name = String(profileRow?.name ?? '').trim();
  const [activeRows] = await pool.query(
    `SELECT id
     FROM deliveries
     WHERE status IN ('PENDING','PICKED_UP','OUT_FOR_DELIVERY')
       AND (
         (driver_phone IS NOT NULL AND driver_phone = ?)
         OR (driver_name IS NOT NULL AND driver_name = ?)
       )
     LIMIT 1`,
    [phone || '__none__', name || '__none__'],
  );
  return activeRows.length > 0 ? 'ON_DELIVERY' : 'ACTIVE';
}

async function getDriverByUserId(userId) {
  const [[row]] = await pool.query(
    `SELECT 
       u.id as id,
       u.id as user_id,
       u.name,
       u.mobile as phone,
       u.email,
       dp.vehicle_type,
       dp.vehicle_number,
       dp.license_number,
       dp.status,
       dp.verified,
       dp.verified_at,
       u.created_at,
       u.updated_at
     FROM users u
     LEFT JOIN driver_profiles dp ON dp.user_id = u.id
     WHERE u.id = ? AND u.role = 'DELIVERY_DRIVER'`,
    [userId],
  );
  if (!row) return null;

  const [[ratingAgg]] = await pool.query(
    `SELECT COUNT(*) as cnt, AVG(rating) as avg_rating
     FROM driver_ratings
     WHERE driver_id = ?`,
    [userId],
  );
  const runtimeStatus = await computeDriverRuntimeStatus(row);
  return {
    ...row,
    status: runtimeStatus,
    ratings_count: Number(ratingAgg?.cnt ?? 0),
    ratings_average:
      ratingAgg?.avg_rating != null ? Number(ratingAgg.avg_rating) : null,
    verified: row.verified ? 1 : 0,
  };
}

app.get('/api/drivers', async (req, res) => {
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;
  const verified = req.query.verified != null ? String(req.query.verified) : null;
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 500) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;

  const [users] = await pool.query(
    `SELECT 
       u.id as id,
       u.id as user_id,
       u.name,
       u.mobile as phone,
       u.email,
       dp.vehicle_type,
       dp.vehicle_number,
       dp.license_number,
       dp.status,
       dp.verified,
       dp.verified_at,
       u.created_at,
       u.updated_at
     FROM users u
     LEFT JOIN driver_profiles dp ON dp.user_id = u.id
     WHERE u.role = 'DELIVERY_DRIVER'
     ORDER BY u.id DESC
     LIMIT ? OFFSET ?`,
    [limit, offset],
  );

  const items = [];
  for (const row of users) {
    const runtimeStatus = await computeDriverRuntimeStatus(row);
    if (status && runtimeStatus !== status) continue;
    if (verified != null) {
      const shouldBeVerified = verified === '1' || verified.toLowerCase() === 'true';
      const isVerified = Boolean(row.verified);
      if (shouldBeVerified !== isVerified) continue;
    }
    const [[agg]] = await pool.query(
      `SELECT COUNT(*) as cnt, AVG(rating) as avg_rating
       FROM driver_ratings
       WHERE driver_id = ?`,
      [row.id],
    );
    items.push({
      ...row,
      status: runtimeStatus,
      ratings_count: Number(agg?.cnt ?? 0),
      ratings_average: agg?.avg_rating != null ? Number(agg.avg_rating) : null,
      verified: row.verified ? 1 : 0,
    });
  }
  res.json({ items });
});

app.get('/api/drivers/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const driver = await getDriverByUserId(id);
  if (!driver) return res.status(404).json({ error: 'driver not found' });
  res.json(driver);
});

app.post('/api/drivers', async (req, res) => {
  const userId = asInt(req.body?.userId);
  const name = String(req.body?.name ?? '').trim();
  const phone = req.body?.phone != null ? String(req.body.phone).trim() : null;
  const email = req.body?.email != null ? String(req.body.email).trim().toLowerCase() : null;
  const vehicleType = req.body?.vehicleType != null ? String(req.body.vehicleType).trim() : null;
  const vehicleNumber = req.body?.vehicleNumber != null ? String(req.body.vehicleNumber).trim() : null;
  const licenseNumber = req.body?.licenseNumber != null ? String(req.body.licenseNumber).trim() : null;
  if (!userId || !name) return res.status(400).json({ error: 'userId and name required' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [[u]] = await conn.query('SELECT id FROM users WHERE id = ? FOR UPDATE', [userId]);
    if (!u) {
      await conn.rollback();
      return res.status(404).json({ error: 'user not found' });
    }
    await conn.query(
      `UPDATE users
       SET name = ?, email = COALESCE(?, email), mobile = COALESCE(?, mobile), role = 'DELIVERY_DRIVER', updated_at = NOW()
       WHERE id = ?`,
      [name, email, phone, userId],
    );
    await conn.query(
      `INSERT INTO driver_profiles (user_id, vehicle_type, vehicle_number, license_number, status, verified)
       VALUES (?, ?, ?, ?, 'ACTIVE', 0)
       ON DUPLICATE KEY UPDATE
         vehicle_type = COALESCE(VALUES(vehicle_type), vehicle_type),
         vehicle_number = COALESCE(VALUES(vehicle_number), vehicle_number),
         license_number = COALESCE(VALUES(license_number), license_number),
         updated_at = NOW()`,
      [userId, vehicleType || null, vehicleNumber || null, licenseNumber || null],
    );
    await conn.commit();
    const driver = await getDriverByUserId(userId);
    res.status(201).json(driver);
  } catch (e) {
    await conn.rollback();
    res.status(500).json({ error: 'failed to create driver profile' });
  } finally {
    conn.release();
  }
});

app.put('/api/drivers/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const name = req.body?.name != null ? String(req.body.name).trim() : null;
  const phone = req.body?.phone != null ? String(req.body.phone).trim() : null;
  const email = req.body?.email != null ? String(req.body.email).trim().toLowerCase() : null;
  const vehicleType = req.body?.vehicleType != null ? String(req.body.vehicleType).trim() : null;
  const vehicleNumber = req.body?.vehicleNumber != null ? String(req.body.vehicleNumber).trim() : null;
  const licenseNumber = req.body?.licenseNumber != null ? String(req.body.licenseNumber).trim() : null;
  const status = req.body?.status != null ? normalizeDriverStatus(req.body.status) : null;
  const verified = req.body?.verified != null ? (req.body.verified ? 1 : 0) : null;

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [[u]] = await conn.query('SELECT id FROM users WHERE id = ? FOR UPDATE', [id]);
    if (!u) {
      await conn.rollback();
      return res.status(404).json({ error: 'driver user not found' });
    }
    await conn.query(
      `UPDATE users
       SET name = COALESCE(?, name),
           email = COALESCE(?, email),
           mobile = COALESCE(?, mobile),
           role = 'DELIVERY_DRIVER',
           updated_at = NOW()
       WHERE id = ?`,
      [name, email, phone, id],
    );
    await conn.query(
      `INSERT INTO driver_profiles (user_id, vehicle_type, vehicle_number, license_number, status, verified, verified_at)
       VALUES (?, ?, ?, ?, COALESCE(?, 'ACTIVE'), COALESCE(?, 0), CASE WHEN ? = 1 THEN NOW() ELSE NULL END)
       ON DUPLICATE KEY UPDATE
         vehicle_type = COALESCE(VALUES(vehicle_type), vehicle_type),
         vehicle_number = COALESCE(VALUES(vehicle_number), vehicle_number),
         license_number = COALESCE(VALUES(license_number), license_number),
         status = COALESCE(VALUES(status), status),
         verified = COALESCE(VALUES(verified), verified),
         verified_at = CASE WHEN COALESCE(VALUES(verified), verified) = 1 THEN NOW() ELSE NULL END,
         updated_at = NOW()`,
      [
        id,
        vehicleType || null,
        vehicleNumber || null,
        licenseNumber || null,
        status,
        verified,
        verified,
      ],
    );
    await conn.commit();
    const driver = await getDriverByUserId(id);
    res.json(driver);
  } catch (e) {
    await conn.rollback();
    res.status(500).json({ error: 'failed to update driver profile' });
  } finally {
    conn.release();
  }
});

app.delete('/api/drivers/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const [r] = await pool.query(
      `UPDATE users SET role='CUSTOMER', updated_at=NOW() WHERE id=?`,
      [id],
    );
    await pool.query('DELETE FROM driver_profiles WHERE user_id = ?', [id]);
    res.json({ deleted: r.affectedRows === 1 });
  } catch (e) {
    res.status(500).json({ error: 'failed to delete driver profile' });
  }
});

app.get('/api/drivers/:driverId/metrics', async (req, res) => {
  const driverId = asInt(req.params.driverId);
  if (!driverId) return res.status(400).json({ error: 'invalid driverId' });

  const [[driver]] = await pool.query('SELECT id, name FROM users WHERE id=? AND role=?', [driverId, 'DELIVERY_DRIVER']);
  if (!driver) return res.status(404).json({ error: 'driver not found' });

  const [delRows] = await pool.query(
    `SELECT status, delivery_time
     FROM deliveries
     WHERE driver_name = ? OR driver_phone = (
       SELECT mobile FROM users WHERE id = ?
     )`,
    [driver.name, driverId],
  );
  const totalDeliveries = delRows.length;
  const completedDeliveries = delRows.filter((d) => String(d.status).toUpperCase() === 'DELIVERED').length;

  const [[ratingAgg]] = await pool.query(
    `SELECT COUNT(*) as rating_count, AVG(rating) as average_rating
     FROM driver_ratings
     WHERE driver_id = ?`,
    [driverId],
  );

  const [distRows] = await pool.query(
    `SELECT rating, COUNT(*) as c
     FROM driver_ratings
     WHERE driver_id = ?
     GROUP BY rating`,
    [driverId],
  );
  const ratingDistribution = [0, 0, 0, 0, 0];
  for (const r of distRows) {
    const idx = Number(r.rating) - 1;
    if (idx >= 0 && idx < 5) ratingDistribution[idx] = Number(r.c);
  }

  const [[lastDelivery]] = await pool.query(
    `SELECT delivery_time
     FROM deliveries
     WHERE (driver_name = ? OR driver_phone = (SELECT mobile FROM users WHERE id = ?))
       AND delivery_time IS NOT NULL
     ORDER BY delivery_time DESC
     LIMIT 1`,
    [driver.name, driverId],
  );

  res.json({
    driver_id: driverId,
    driver_name: driver.name,
    total_deliveries: totalDeliveries,
    completed_deliveries: completedDeliveries,
    average_rating: ratingAgg?.average_rating != null ? Number(ratingAgg.average_rating) : 0,
    rating_count: Number(ratingAgg?.rating_count ?? 0),
    average_delivery_time: null,
    last_delivery: lastDelivery?.delivery_time ?? null,
    rating_distribution: ratingDistribution,
  });
});

app.get('/api/drivers/metrics/leaderboard', async (req, res) => {
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 20, 1), 200) : 20;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;
  const [drivers] = await pool.query(
    `SELECT id, name FROM users
     WHERE role='DELIVERY_DRIVER'
     ORDER BY id DESC
     LIMIT ? OFFSET ?`,
    [limit, offset],
  );
  const items = [];
  for (const d of drivers) {
    const [[ratingAgg]] = await pool.query(
      `SELECT COUNT(*) as rating_count, AVG(rating) as average_rating
       FROM driver_ratings
       WHERE driver_id = ?`,
      [d.id],
    );
    const [delRows] = await pool.query(
      `SELECT status
       FROM deliveries
       WHERE driver_name = ? OR driver_phone = (
         SELECT mobile FROM users WHERE id = ?
       )`,
      [d.name, d.id],
    );
    items.push({
      driver_id: d.id,
      driver_name: d.name,
      total_deliveries: delRows.length,
      completed_deliveries: delRows.filter((x) => String(x.status).toUpperCase() === 'DELIVERED').length,
      average_rating: ratingAgg?.average_rating != null ? Number(ratingAgg.average_rating) : 0,
      rating_count: Number(ratingAgg?.rating_count ?? 0),
      average_delivery_time: null,
      last_delivery: null,
      rating_distribution: [0, 0, 0, 0, 0],
    });
  }
  items.sort((a, b) => b.average_rating - a.average_rating);
  res.json({ items });
});

app.get('/api/driver-ratings', async (req, res) => {
  const driverId = req.query.driverId ? asInt(req.query.driverId) : null;
  const orderId = req.query.orderId ? asInt(req.query.orderId) : null;
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 300) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;
  const where = [];
  const params = [];
  if (driverId) {
    where.push('r.driver_id = ?');
    params.push(driverId);
  }
  if (orderId) {
    where.push('r.order_id = ?');
    params.push(orderId);
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const [rows] = await pool.query(
    `SELECT 
       r.*,
       CASE WHEN r.is_anonymous = 1 THEN NULL ELSE u.name END as customer_name
     FROM driver_ratings r
     LEFT JOIN users u ON u.id = r.customer_id
     ${whereSql}
     ORDER BY r.id DESC
     LIMIT ? OFFSET ?`,
    [...params, limit, offset],
  );
  res.json({ items: rows });
});

app.post('/api/driver-ratings', async (req, res) => {
  const driverId = asInt(req.body?.driverId);
  const orderId = asInt(req.body?.orderId);
  const customerId = req.body?.customerId ? asInt(req.body.customerId) : null;
  const rating = asInt(req.body?.rating);
  const feedback = req.body?.feedback != null ? String(req.body.feedback).trim() : null;
  const category = req.body?.category != null ? String(req.body.category).trim() : null;
  const isAnonymous = req.body?.isAnonymous ? 1 : 0;

  if (!driverId || !orderId || !rating || rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'driverId, orderId and rating(1-5) required' });
  }

  const [result] = await pool.query(
    `INSERT INTO driver_ratings (driver_id, order_id, customer_id, rating, feedback, category, is_anonymous)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [driverId, orderId, customerId, rating, feedback || null, category || null, isAnonymous],
  );
  const [[created]] = await pool.query('SELECT * FROM driver_ratings WHERE id = ?', [result.insertId]);
  res.status(201).json(created);
});

app.put('/api/driver-ratings/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const rating = req.body?.rating != null ? asInt(req.body.rating) : null;
  const feedback = req.body?.feedback != null ? String(req.body.feedback).trim() : null;
  const category = req.body?.category != null ? String(req.body.category).trim() : null;
  if (rating != null && (rating < 1 || rating > 5)) {
    return res.status(400).json({ error: 'rating must be between 1 and 5' });
  }
  await pool.query(
    `UPDATE driver_ratings
     SET rating = COALESCE(?, rating),
         feedback = COALESCE(?, feedback),
         category = COALESCE(?, category),
         updated_at = NOW()
     WHERE id = ?`,
    [rating, feedback, category, id],
  );
  const [[updated]] = await pool.query('SELECT * FROM driver_ratings WHERE id = ?', [id]);
  if (!updated) return res.status(404).json({ error: 'rating not found' });
  res.json(updated);
});

// Authentication (simple email-based)
app.post('/api/auth/signup', async (req, res) => {
  const name = String(req.body?.name ?? '').trim();
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  const password = String(req.body?.password ?? '');
  const mobile = req.body?.mobile ? String(req.body.mobile).trim() : null;
  const address = req.body?.address ? String(req.body.address).trim() : null;
  const rawRole =
    req.body?.role ?? req.body?.accountRole ?? req.body?.userRole ?? req.body?.user_role;
  const role = normalizeUserRole(rawRole, { allowAdmin: true });
  if (!SIGNUP_ROLES.has(role)) {
    return res.status(400).json({ error: 'invalid role for signup' });
  }

  if (!name || !email || !password) return res.status(400).json({ error: 'name/email/password required' });
  try {
    const bcrypt = await import('bcryptjs');
    const passwordHash = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO users (name, email, password_hash, mobile, address, role) VALUES (?, ?, ?, ?, ?, ?)',
      [name, email, passwordHash, mobile, address, role]
    );
    const [[user]] = await pool.query(
      'SELECT id, name, email, mobile, address, role, created_at, updated_at FROM users WHERE id=?',
      [result.insertId]
    );
    res.status(201).json(sanitizeUserRow(user));
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'email already exists' });
    }
    console.error('Signup error:', e);
    res.status(500).json({ error: 'failed to signup' });
  }
});

app.post('/api/auth/signin', async (req, res) => {
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  const password = String(req.body?.password ?? '');
  if (!email || !password) return res.status(400).json({ error: 'email/password required' });
  const [[user]] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
  if (!user) return res.status(404).json({ error: 'invalid credentials' });

  const bcrypt = await import('bcryptjs');
  const match = await bcrypt.compare(password, user.password_hash || '');
  if (!match) return res.status(401).json({ error: 'invalid credentials' });

  res.json(sanitizeUserRow(user));
});

app.get('/api/stores/:id/menu', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const [rows] = await pool.query('SELECT * FROM menu_items WHERE store_id = ? ORDER BY id DESC', [id]);
    res.json({ items: rows });
  } catch (e) {
    res.status(500).json({ error: 'failed to fetch menu' });
  }
});

// Menu Item CRUD
app.post('/api/menu_items', async (req, res) => {
  const { storeId, name, description, price, imageUrl, specialForDate } = req.body || {};
  if (!storeId || !name || price == null) return res.status(400).json({ error: 'storeId, name, price required' });
  const specialDate = parseOptionalDateOnly(specialForDate);
  const isCombo = req.body?.isCombo === true || req.body?.isCombo === 1;
  const comboJson = isCombo ? (normalizeComboComponentsInput(req.body) || null) : null;
  try {
    const [result] = await pool.query(
      'INSERT INTO menu_items (store_id, name, description, price, image_url, special_for_date, is_combo, combo_components) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [asInt(storeId), name, description || null, asMoney(price), imageUrl || null, specialDate, isCombo ? 1 : 0, comboJson]
    );
    const [[created]] = await pool.query('SELECT * FROM menu_items WHERE id = ?', [result.insertId]);

    // Initialize inventory for new item
    await pool.query('INSERT INTO inventory (menu_item_id, quantity) VALUES (?, 0) ON DUPLICATE KEY UPDATE id=id', [result.insertId]);

    res.status(201).json(created);
  } catch (e) {
    console.error('Create menu item error:', e);
    res.status(500).json({ error: 'failed to create menu item' });
  }
});

app.put('/api/menu_items/:id', async (req, res) => {
  const id = asInt(req.params.id);
  const { name, description, price, imageUrl } = req.body || {};
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const hasSpecial = Object.prototype.hasOwnProperty.call(req.body || {}, 'specialForDate');
    const specialDate = hasSpecial ? parseOptionalDateOnly(req.body.specialForDate) : undefined;
    if (hasSpecial) {
      await pool.query(
        'UPDATE menu_items SET name=COALESCE(?, name), description=COALESCE(?, description), price=COALESCE(?, price), image_url=COALESCE(?, image_url), special_for_date=?, updated_at=NOW() WHERE id=?',
        [name || null, description || null, price != null ? asMoney(price) : null, imageUrl || null, specialDate, id]
      );
    } else {
      await pool.query(
        'UPDATE menu_items SET name=COALESCE(?, name), description=COALESCE(?, description), price=COALESCE(?, price), image_url=COALESCE(?, image_url), updated_at=NOW() WHERE id=?',
        [name || null, description || null, price != null ? asMoney(price) : null, imageUrl || null, id]
      );
    }
    const hasIsCombo = Object.prototype.hasOwnProperty.call(req.body || {}, 'isCombo');
    const hasComboComponents = Object.prototype.hasOwnProperty.call(req.body || {}, 'comboComponents');
    if (hasIsCombo || hasComboComponents) {
      const [[cur]] = await pool.query('SELECT is_combo, combo_components FROM menu_items WHERE id = ?', [id]);
      const nextIsCombo = hasIsCombo
        ? (req.body.isCombo === true || req.body.isCombo === 1 ? 1 : 0)
        : (cur?.is_combo ? 1 : 0);
      let nextCombo = hasComboComponents ? normalizeComboComponentsInput(req.body) : cur?.combo_components;
      if (!nextIsCombo) nextCombo = null;
      await pool.query(
        'UPDATE menu_items SET is_combo=?, combo_components=?, updated_at=NOW() WHERE id=?',
        [nextIsCombo, nextCombo, id],
      );
    }
    const [[updated]] = await pool.query('SELECT * FROM menu_items WHERE id = ?', [id]);
    res.json(updated);
  } catch (e) {
    res.status(500).json({ error: 'failed to update menu item' });
  }
});

app.delete('/api/menu_items/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const [result] = await pool.query('DELETE FROM menu_items WHERE id=?', [id]);
    res.json({ deleted: result.affectedRows === 1 });
  } catch (e) {
    res.status(500).json({ error: 'failed to delete menu item' });
  }
});

// Inventory CRUD
app.get('/api/inventory', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT i.*, m.name as menu_item_name, s.name as store_name, s.id as store_id 
      FROM inventory i
      JOIN menu_items m ON i.menu_item_id = m.id
      JOIN stores s ON m.store_id = s.id
      ORDER BY i.id DESC
    `);
    res.json({ items: rows });
  } catch (e) {
    res.status(500).json({ error: 'failed to fetch inventory' });
  }
});

app.put('/api/inventory/:id', async (req, res) => {
  const id = asInt(req.params.id);
  const { quantity } = req.body || {};
  if (!id || quantity == null) return res.status(400).json({ error: 'id and quantity required' });
  try {
    await pool.query('UPDATE inventory SET quantity=?, updated_at=NOW() WHERE id=?', [asInt(quantity), id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'failed to update inventory' });
  }
});

app.post('/api/inventory', async (req, res) => {
  const { menuItemId, quantity } = req.body || {};
  if (!menuItemId) return res.status(400).json({ error: 'menuItemId required' });
  try {
    const [result] = await pool.query(
      'INSERT INTO inventory (menu_item_id, quantity) VALUES (?, ?) ON DUPLICATE KEY UPDATE quantity=VALUES(quantity)',
      [asInt(menuItemId), asInt(quantity ?? 0)]
    );
    res.status(201).json({ id: result.insertId || null, ok: true });
  } catch (e) {
    res.status(500).json({ error: 'failed to create inventory record' });
  }
});

app.delete('/api/inventory/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const [result] = await pool.query('DELETE FROM inventory WHERE id=?', [id]);
    res.json({ deleted: result.affectedRows === 1 });
  } catch (e) {
    res.status(500).json({ error: 'failed to delete inventory record' });
  }
});

// Delivery CRUD
app.get('/api/deliveries', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM deliveries ORDER BY id DESC');
    res.json({ items: rows });
  } catch (e) {
    res.status(500).json({ error: 'failed to fetch deliveries' });
  }
});

// Admin assigns a driver to an order
app.post('/api/orders/:id/assign', async (req, res) => {
  const orderId = asInt(req.params.id);
  const { driverUserId } = req.body || {};
  if (!orderId || !driverUserId) {
    return res.status(400).json({ error: 'orderId and driverUserId required' });
  }

  // Check order exists and is PAID
  const [[order]] = await pool.query('SELECT * FROM orders WHERE id = ?', [orderId]);
  if (!order) return res.status(404).json({ error: 'order not found' });
  if (!['PAID', 'PREPARING','PENDING_PAYMENT'].includes(order.status)) {
    return res.status(400).json({ error: `Cannot assign driver to order with status: ${order.status}. Order must be PAID.` });
  }

  // Check driver exists
  const [[driver]] = await pool.query(
    'SELECT id, name, mobile FROM users WHERE id = ? AND role = ?',
    [driverUserId, 'DELIVERY_DRIVER']
  );
  if (!driver) return res.status(404).json({ error: 'delivery driver not found' });

  // Check driver is not busy
  const busy = await isDriverBusy({ driverPhone: driver.mobile });
  if (busy) {
    return res.status(409).json({ error: 'Driver is currently busy with another delivery. Please assign a different driver.' });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // Remove any existing unassigned delivery for this order
    await conn.query(
      `DELETE FROM deliveries WHERE order_id = ? AND driver_name IS NULL`,
      [orderId]
    );

    // Check if delivery already assigned
    const [[existing]] = await conn.query(
      'SELECT id, driver_name FROM deliveries WHERE order_id = ?',
      [orderId]
    );
    if (existing && existing.driver_name) {
      await conn.rollback();
      return res.status(409).json({ error: 'Order already assigned to a driver' });
    }

    let deliveryId;
    if (existing) {
      // Update existing delivery with driver info
      await conn.query(
        `UPDATE deliveries SET driver_name = ?, driver_phone = ?, status = 'PENDING', updated_at = NOW()
         WHERE order_id = ?`,
        [driver.name, driver.mobile, orderId]
      );
      deliveryId = existing.id;
    } else {
      // Create new delivery
      const [result] = await conn.query(
        `INSERT INTO deliveries (order_id, driver_name, driver_phone, status)
         VALUES (?, ?, ?, 'PENDING')`,
        [orderId, driver.name, driver.mobile]
      );
      deliveryId = result.insertId;
    }

    // Move order to PREPARING
    await conn.query(
      `UPDATE orders SET status = 'PREPARING', updated_at = NOW() WHERE id = ?`,
      [orderId]
    );

    await conn.commit();

    const [[delivery]] = await pool.query('SELECT * FROM deliveries WHERE id = ?', [deliveryId]);
    res.json({ ok: true, delivery });
  } catch (e) {
    await conn.rollback();
    console.error('Assign driver error:', e);
    res.status(500).json({ error: 'failed to assign driver' });
  } finally {
    conn.release();
  }
});

// Keep original POST /api/deliveries for internal use only
app.post('/api/deliveries', async (req, res) => {
  const { orderId, driverName, driverPhone } = req.body || {};
  if (!orderId) return res.status(400).json({ error: 'orderId required' });
  try {
    const phone = String(driverPhone ?? '').trim();
    if (phone) {
      const busy = await isDriverBusy({ driverPhone: phone });
      if (busy) {
        return res.status(409).json({ error: 'driver is busy with another active delivery' });
      }
    }
    const [result] = await pool.query(
      'INSERT INTO deliveries (order_id, driver_name, driver_phone) VALUES (?, ?, ?)',
      [asInt(orderId), driverName || null, phone || null]
    );
    const [[created]] = await pool.query('SELECT * FROM deliveries WHERE id = ?', [result.insertId]);
    res.status(201).json(created);
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'delivery for this order already exists' });
    res.status(500).json({ error: 'failed to create delivery' });
  }
});

// Driver sees only their own assigned deliveries
app.get('/api/deliveries/driver/:userId', async (req, res) => {
  const userId = asInt(req.params.userId);
  if (!userId) return res.status(400).json({ error: 'invalid userId' });

  const [[driver]] = await pool.query(
    'SELECT id, name, mobile FROM users WHERE id = ? AND role = ?',
    [userId, 'DELIVERY_DRIVER']
  );
  if (!driver) return res.status(404).json({ error: 'driver not found' });

  const [rows] = await pool.query(
    `SELECT d.*, 
            o.total, o.currency, o.subtotal, o.delivery_fee,
            o.status as order_status, o.user_id,
            o.delivery_latitude, o.delivery_longitude
     FROM deliveries d
     JOIN orders o ON o.id = d.order_id
     WHERE d.driver_phone = ? OR d.driver_name = ?
     ORDER BY d.id DESC`,
    [driver.mobile || '__none__', driver.name]
  );
  res.json({ items: rows });
});

app.put('/api/deliveries/:id', async (req, res) => {
  const id = asInt(req.params.id);
  const { status, driverName, driverPhone, pickupTime, deliveryTime, currentLatitude, currentLongitude } = req.body || {};
  if (!id) return res.status(400).json({ error: 'id required' });
  // Only allow status updates — no reassignment via this endpoint
  const allowedStatuses = ['PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED'];
  if (status && !allowedStatuses.includes(String(status).toUpperCase())) {
    return res.status(400).json({ 
      error: `Invalid status. Driver can only set: ${allowedStatuses.join(', ')}` 
    });
  }

  try {
    const [[deliveryRow]] = await pool.query('SELECT order_id FROM deliveries WHERE id = ?', [id]);
    if (!deliveryRow) return res.status(404).json({ error: 'delivery not found' });
    const orderId = deliveryRow.order_id;

    const nextStatus = status ? String(status).trim().toUpperCase() : null;
    const phone = driverPhone != null ? String(driverPhone).trim() : null;
    if (phone) {
      const busy = await isDriverBusy({
        driverPhone: phone,
        excludeDeliveryId: id,
      });
      if (busy) {
        return res.status(409).json({ error: 'driver is busy with another active delivery' });
      }
    }

    if (nextStatus === 'OUT_FOR_DELIVERY') {
      const hasLat = currentLatitude != null && asFloat(currentLatitude) != null;
      const hasLng = currentLongitude != null && asFloat(currentLongitude) != null;
      if (!hasLat || !hasLng) {
        return res.status(400).json({
          error: 'currentLatitude and currentLongitude are required for OUT_FOR_DELIVERY',
        });
      }
    }

    const lat = currentLatitude != null ? asFloat(currentLatitude) : null;
    const lng = currentLongitude != null ? asFloat(currentLongitude) : null;
    const effectivePickupTime =
      nextStatus === 'PICKED_UP' && !pickupTime ? new Date() : pickupTime || null;
    const effectiveDeliveryTime =
      nextStatus === 'DELIVERED' && !deliveryTime ? new Date() : deliveryTime || null;
    await pool.query(
      `UPDATE deliveries SET 
        status=COALESCE(?, status), 
        driver_name=COALESCE(?, driver_name), 
        driver_phone=COALESCE(?, driver_phone),
        pickup_time=COALESCE(?, pickup_time),
        delivery_time=COALESCE(?, delivery_time),
        current_latitude=COALESCE(?, current_latitude),
        current_longitude=COALESCE(?, current_longitude),
        updated_at=NOW() 
       WHERE id=?`,
      [
        nextStatus || null,
        driverName || null,
        phone || null,
        effectivePickupTime,
        effectiveDeliveryTime,
        lat,
        lng,
        id,
      ]
    );

    // Keep customer order status in sync when the driver updates the run
    if (nextStatus) {
      const s = nextStatus;
      if (s === 'DELIVERED') {
        await pool.query(
          "UPDATE orders SET status='COMPLETED', updated_at=NOW() WHERE id=? AND status NOT IN ('CANCELLED','FAILED')",
          [orderId]
        );
      } else if (s === 'PICKED_UP' || s === 'OUT_FOR_DELIVERY') {
        await pool.query(
          "UPDATE orders SET status='READY', updated_at=NOW() WHERE id=? AND status NOT IN ('COMPLETED','CANCELLED','FAILED')",
          [orderId]
        );
      }
    }

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'failed to update delivery' });
  }
});

app.delete('/api/deliveries/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const [result] = await pool.query('DELETE FROM deliveries WHERE id=?', [id]);
    res.json({ deleted: result.affectedRows === 1 });
  } catch (e) {
    res.status(500).json({ error: 'failed to delete delivery' });
  }
});


// Store management CRUD
app.get('/api/stores', async (req, res) => {
  const ownerUserId = asInt(req.query.ownerUserId);
  try {
    const [rows] = ownerUserId
      ? await pool.query('SELECT * FROM stores WHERE owner_user_id = ? ORDER BY id DESC', [ownerUserId])
      : await pool.query('SELECT * FROM stores ORDER BY id DESC');
    res.json({ items: rows });
  } catch (e) {
    console.error('List stores error:', e);
    res.status(500).json({ error: 'failed to list stores' });
  }
});

app.get('/api/stores/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const [[store]] = await pool.query('SELECT * FROM stores WHERE id = ?', [id]);
  if (!store) return res.status(404).json({ error: 'store not found' });
  res.json(store);
});

app.post('/api/stores', async (req, res) => {
  const name = String(req.body?.name ?? '').trim();
  const address = String(req.body?.address ?? '').trim();
  const lat = asFloat(req.body?.latitude);
  const lng = asFloat(req.body?.longitude);
  const ownerUserId = asInt(req.body?.ownerUserId);

  console.log('Creating store with:', { name, address, lat, lng, ownerUserId });

  if (!name) return res.status(400).json({ error: 'name required' });
  try {
    const [result] = await pool.query(
      'INSERT INTO stores (name, address, latitude, longitude, owner_user_id) VALUES (?, ?, ?, ?, ?)',
      [name, address || null, lat, lng, ownerUserId || null]
    );
    const [[created]] = await pool.query('SELECT * FROM stores WHERE id = ?', [result.insertId]);
    console.log('Store created successfully:', created);
    res.status(201).json(created);
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') {
      console.warn('Duplicate store name:', name);
      return res.status(409).json({ error: 'store name already exists' });
    }
    if (e.code === 'ER_BAD_FIELD_ERROR' || e.code === 'ER_NO_SUCH_TABLE') {
      console.error('Database schema error:', e.message);
      return res.status(500).json({ error: 'database schema error: ' + e.message });
    }
    console.error('Create store error:', e.code, e.message);
    res.status(500).json({ error: 'failed to create store: ' + e.message });
  }
});

app.put('/api/stores/:id', async (req, res) => {
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
    const [result] = hasOwner
      ? await pool.query(
          'UPDATE stores SET name=?, address=?, latitude=?, longitude=?, owner_user_id=?, updated_at=NOW() WHERE id=?',
          [name, address || null, lat, lng, ownerUserId ?? null, id]
        )
      : await pool.query(
          'UPDATE stores SET name=?, address=?, latitude=?, longitude=?, updated_at=NOW() WHERE id=?',
          [name, address || null, lat, lng, id]
        );
    if (result.affectedRows !== 1) return res.status(404).json({ error: 'store not found' });
    const [[updated]] = await pool.query('SELECT * FROM stores WHERE id = ?', [id]);
    res.json(updated);
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'store name already exists' });
    }
    console.error('Update store error:', e);
    res.status(500).json({ error: 'failed to update store' });
  }
});

app.delete('/api/stores/:id', async (req, res) => {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const [result] = await pool.query('DELETE FROM stores WHERE id=?', [id]);
    res.json({ deleted: result.affectedRows === 1 });
  } catch (e) {
    res.status(500).json({ error: 'failed to delete store' });
  }
});

// Optional: PayPal return/cancel endpoints for browser-based flows
app.get('/api/payments/paypal/return', (_req, res) => {
  res.type('text/plain').send('Payment approved. You can return to the app.');
});
app.get('/api/payments/paypal/cancel', (_req, res) => {
  res.type('text/plain').send('Payment cancelled. You can return to the app.');
});

// Cart Management Endpoints
// Get active cart for user
app.get('/api/carts/user/:userId', async (req, res) => {
  const userId = asInt(req.params.userId);
  if (!userId) {
    return res.status(400).json({ error: 'invalid userId' });
  }

  try {
    const [[cart]] = await pool.query(
      `SELECT c.* FROM carts c 
       WHERE c.user_id = ? AND c.status = 'ACTIVE'
       ORDER BY c.created_at DESC LIMIT 1`,
      [userId],
    );

    if (!cart) {
      return res.json(null);
    }

    const [items] = await pool.query(
      `SELECT * FROM cart_items WHERE cart_id = ? ORDER BY created_at ASC`,
      [cart.id],
    );

    res.json({
      ...cart,
      items: items || [],
    });
  } catch (e) {
    console.error('Error fetching cart:', e);
    res.status(500).json({ error: 'Failed to fetch cart' });
  }
});

// Create or get active cart for user
app.post('/api/carts', async (req, res) => {
  const userId = asInt(req.body.userId);
  const storeId = asInt(req.body.storeId);

  if (!userId) {
    return res.status(400).json({ error: 'userId required' });
  }

  try {
    // Check if active cart exists
    const [[existing]] = await pool.query(
      `SELECT * FROM carts WHERE user_id = ? AND status = 'ACTIVE' LIMIT 1`,
      [userId],
    );

    if (existing) {
      const [items] = await pool.query(
        `SELECT * FROM cart_items WHERE cart_id = ? ORDER BY created_at ASC`,
        [existing.id],
      );
      return res.status(201).json({
        ...existing,
        items: items || [],
      });
    }

    // Create new cart
    const [result] = await pool.query(
      `INSERT INTO carts (user_id, store_id, status) VALUES (?, ?, 'ACTIVE')`,
      [userId, storeId || null],
    );

    const cartId = result.insertId;
    const [[newCart]] = await pool.query(`SELECT * FROM carts WHERE id = ?`, [cartId]);

    res.status(201).json({
      ...newCart,
      items: [],
    });
  } catch (e) {
    console.error('Error creating cart:', e);
    res.status(500).json({ error: 'Failed to create cart' });
  }
});

// Add item to cart
app.post('/api/carts/:cartId/items', async (req, res) => {
  const cartId = asInt(req.params.cartId);
  const { productId, name, qty, unitPrice } = req.body || {};
  const lineNoteRaw = req.body?.lineNote;
  const lineNote = lineNoteRaw != null && String(lineNoteRaw).trim()
    ? String(lineNoteRaw).trim().slice(0, 500)
    : null;

  if (!cartId || !productId || !name || !qty || unitPrice === undefined) {
    return res.status(400).json({ error: 'cartId, productId, name, qty, unitPrice required' });
  }

  if (!Number.isFinite(qty) || qty <= 0 || !Number.isFinite(unitPrice) || unitPrice < 0) {
    return res.status(400).json({ error: 'invalid qty or unitPrice' });
  }

  try {
    await assertCartAddAllowed(pool, { cartId, productId, addQty: qty });
    // Check if product already in cart
    const [[existing]] = await pool.query(
      `SELECT * FROM cart_items WHERE cart_id = ? AND product_id = ?`,
      [cartId, productId],
    );

    if (existing) {
      // Update quantity
      const newQty = existing.qty + qty;
      await pool.query(
        `UPDATE cart_items SET qty = ?, line_note = COALESCE(?, line_note), updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
        [newQty, lineNote, existing.id],
      );
    } else {
      // Insert new item
      await pool.query(
        `INSERT INTO cart_items (cart_id, product_id, name, qty, unit_price, line_note) 
         VALUES (?, ?, ?, ?, ?, ?)`,
        [cartId, productId, name, qty, unitPrice, lineNote],
      );
    }
  } catch (e) {
    if (e.code === 'BAD') {
      return res.status(400).json({ error: e.message });
    }
    console.error('Error adding to cart:', e);
    return res.status(500).json({ error: 'Failed to add to cart' });
  }

  try {
    const [items] = await pool.query(
      `SELECT * FROM cart_items WHERE cart_id = ? ORDER BY created_at ASC`,
      [cartId],
    );
    res.json({ success: true, items: items || [] });
  } catch (e) {
    console.error('Error loading cart after add:', e);
    res.status(500).json({ error: 'Failed to load cart items' });
  }
});

// Update cart item quantity
app.put('/api/carts/:cartId/items/:itemId', async (req, res) => {
  const cartId = asInt(req.params.cartId);
  const itemId = asInt(req.params.itemId);
  const newQty = asInt(req.body?.qty);

  if (!cartId || !itemId || (!newQty && newQty !== 0)) {
    return res.status(400).json({ error: 'invalid params' });
  }

  try {
    if (newQty <= 0) {
      await pool.query(`DELETE FROM cart_items WHERE id = ? AND cart_id = ?`, [itemId, cartId]);
    } else {
      await assertCartLineQtyUpdate(pool, { cartId, itemId, newQty });
      await pool.query(
        `UPDATE cart_items SET qty = ?, updated_at = CURRENT_TIMESTAMP 
         WHERE id = ? AND cart_id = ?`,
        [newQty, itemId, cartId],
      );
    }

    const [items] = await pool.query(
      `SELECT * FROM cart_items WHERE cart_id = ? ORDER BY created_at ASC`,
      [cartId],
    );
    res.json({ success: true, items: items || [] });
  } catch (e) {
    if (e.code === 'BAD') {
      return res.status(400).json({ error: e.message });
    }
    console.error('Error updating cart item:', e);
    res.status(500).json({ error: 'Failed to update cart item' });
  }
});

// Remove item from cart
app.delete('/api/carts/:cartId/items/:itemId', async (req, res) => {
  const cartId = asInt(req.params.cartId);
  const itemId = asInt(req.params.itemId);

  if (!cartId || !itemId) {
    return res.status(400).json({ error: 'invalid params' });
  }

  try {
    await pool.query(`DELETE FROM cart_items WHERE id = ? AND cart_id = ?`, [itemId, cartId]);

    const [items] = await pool.query(
      `SELECT * FROM cart_items WHERE cart_id = ? ORDER BY created_at ASC`,
      [cartId],
    );
    res.json({ success: true, items: items || [] });
  } catch (e) {
    console.error('Error removing from cart:', e);
    res.status(500).json({ error: 'Failed to remove item from cart' });
  }
});

// Clear cart
app.delete('/api/carts/:cartId', async (req, res) => {
  const cartId = asInt(req.params.cartId);

  if (!cartId) {
    return res.status(400).json({ error: 'invalid cartId' });
  }

  try {
    await pool.query(`DELETE FROM cart_items WHERE cart_id = ?`, [cartId]);
    await pool.query(`UPDATE carts SET status = 'ABANDONED' WHERE id = ?`, [cartId]);
    res.json({ success: true });
  } catch (e) {
    console.error('Error clearing cart:', e);
    res.status(500).json({ error: 'Failed to clear cart' });
  }
});

// Checkout cart (mark as checked out)
app.post('/api/carts/:cartId/checkout', async (req, res) => {
  const cartId = asInt(req.params.cartId);

  if (!cartId) {
    return res.status(400).json({ error: 'invalid cartId' });
  }

  try {
    await pool.query(
      `UPDATE carts SET status = 'CHECKED_OUT', checked_out_at = CURRENT_TIMESTAMP 
       WHERE id = ?`,
      [cartId],
    );
    res.json({ success: true });
  } catch (e) {
    console.error('Error checking out cart:', e);
    res.status(500).json({ error: 'Failed to checkout cart' });
  }
});

async function ensureSchema() {

  // Make backend runnable even if DB schema wasn't applied yet.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS orders (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      user_id BIGINT UNSIGNED NULL,
      store_id BIGINT UNSIGNED NULL,
      currency CHAR(3) NOT NULL DEFAULT 'USD',
      subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      status ENUM('PENDING_PAYMENT','PAID','PREPARING','READY','COMPLETED','CANCELLED','FAILED') NOT NULL DEFAULT 'PENDING_PAYMENT',
      delivery_latitude DECIMAL(10,8) NULL,
      delivery_longitude DECIMAL(11,8) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_orders_user_id (user_id),
      KEY idx_orders_store_id (store_id),
      KEY idx_orders_status (status),
      KEY idx_orders_created_at (created_at)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS order_items (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      order_id BIGINT UNSIGNED NOT NULL,
      product_id BIGINT UNSIGNED NULL,
      name VARCHAR(255) NOT NULL,
      qty INT UNSIGNED NOT NULL,
      unit_price DECIMAL(10,2) NOT NULL,
      line_total DECIMAL(10,2) NOT NULL,
      PRIMARY KEY (id),
      KEY idx_order_items_order_id (order_id),
      CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      name VARCHAR(100) NOT NULL,
      email VARCHAR(150) NOT NULL,
      mobile VARCHAR(20) NULL,
      address VARCHAR(255) NULL,
      password_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_users_email (email)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS stores (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      name VARCHAR(150) NOT NULL,
      address VARCHAR(255) NULL,
      latitude DECIMAL(10,8) NULL,
      longitude DECIMAL(11,8) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_stores_name (name)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS payments (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      order_id BIGINT UNSIGNED NOT NULL,
      method ENUM('PAYPAL','CASH_ON_DELIVERY','ONLINE_BANKING') NOT NULL,
      status ENUM('CREATED','APPROVAL_PENDING','AUTHORIZED','CAPTURED','FAILED','CANCELLED') NOT NULL DEFAULT 'CREATED',
      provider VARCHAR(32) NULL,
      provider_order_id VARCHAR(128) NULL,
      provider_capture_id VARCHAR(128) NULL,
      approval_url TEXT NULL,
      amount DECIMAL(10,2) NOT NULL,
      currency CHAR(3) NOT NULL DEFAULT 'USD',
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_payments_provider_order_id (provider_order_id),
      KEY idx_payments_order_id (order_id),
      KEY idx_payments_status (status),
      CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS receipts (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      order_id BIGINT UNSIGNED NOT NULL,
      payment_id BIGINT UNSIGNED NOT NULL,
      receipt_no VARCHAR(32) NOT NULL,
      issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      paid_amount DECIMAL(10,2) NOT NULL,
      currency CHAR(3) NOT NULL DEFAULT 'USD',
      raw_provider_response JSON NULL,
      PRIMARY KEY (id),
      UNIQUE KEY uq_receipts_order_id (order_id),
      UNIQUE KEY uq_receipts_receipt_no (receipt_no),
      KEY idx_receipts_issued_at (issued_at),
      CONSTRAINT fk_receipts_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE,
      CONSTRAINT fk_receipts_payment
        FOREIGN KEY (payment_id) REFERENCES payments(id)
        ON DELETE RESTRICT
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS menu_items (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      store_id BIGINT UNSIGNED NOT NULL,
      name VARCHAR(255) NOT NULL,
      description TEXT NULL,
      price DECIMAL(10,2) NOT NULL,
      image_url VARCHAR(512) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_menu_items_store_id (store_id),
      CONSTRAINT fk_menu_items_store
        FOREIGN KEY (store_id) REFERENCES stores(id)
        ON DELETE CASCADE
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS inventory (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      menu_item_id BIGINT UNSIGNED NOT NULL,
      quantity INT NOT NULL DEFAULT 0,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_inventory_menu_item_id (menu_item_id),
      CONSTRAINT fk_inventory_menu_item
        FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
        ON DELETE CASCADE
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS deliveries (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      order_id BIGINT UNSIGNED NOT NULL,
      driver_name VARCHAR(100) NULL,
      driver_phone VARCHAR(20) NULL,
      status ENUM('PENDING', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
      current_latitude DECIMAL(10,8) NULL,
      current_longitude DECIMAL(11,8) NULL,
      pickup_time TIMESTAMP NULL,
      delivery_time TIMESTAMP NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_deliveries_order_id (order_id),
      CONSTRAINT fk_deliveries_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS driver_profiles (
      user_id BIGINT UNSIGNED NOT NULL,
      vehicle_type VARCHAR(64) NULL,
      vehicle_number VARCHAR(64) NULL,
      license_number VARCHAR(64) NULL,
      status ENUM('ACTIVE','INACTIVE','ON_DELIVERY','PENDING_VERIFICATION') NOT NULL DEFAULT 'ACTIVE',
      verified TINYINT(1) NOT NULL DEFAULT 0,
      verified_at TIMESTAMP NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id),
      CONSTRAINT fk_driver_profiles_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS driver_ratings (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      driver_id BIGINT UNSIGNED NOT NULL,
      order_id BIGINT UNSIGNED NOT NULL,
      customer_id BIGINT UNSIGNED NULL,
      rating TINYINT UNSIGNED NOT NULL,
      feedback TEXT NULL,
      category VARCHAR(64) NULL,
      is_anonymous TINYINT(1) NOT NULL DEFAULT 0,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_driver_ratings_driver_id (driver_id),
      KEY idx_driver_ratings_order_id (order_id),
      CONSTRAINT fk_driver_ratings_driver
        FOREIGN KEY (driver_id) REFERENCES users(id)
        ON DELETE CASCADE,
      CONSTRAINT fk_driver_ratings_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE
    )
  `);

  // Persistent shopping carts
  await pool.query(`
    CREATE TABLE IF NOT EXISTS carts (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      user_id BIGINT UNSIGNED NOT NULL,
      store_id BIGINT UNSIGNED NULL,
      status ENUM('ACTIVE','CHECKED_OUT','ABANDONED') NOT NULL DEFAULT 'ACTIVE',
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      checked_out_at TIMESTAMP NULL,
      PRIMARY KEY (id),
      KEY idx_carts_user_id (user_id),
      KEY idx_carts_status (status),
      KEY idx_carts_created_at (created_at)
    )
  `);

  // Items in shopping carts
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cart_items (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      cart_id BIGINT UNSIGNED NOT NULL,
      product_id BIGINT UNSIGNED NOT NULL,
      name VARCHAR(255) NOT NULL,
      qty INT UNSIGNED NOT NULL,
      unit_price DECIMAL(10,2) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_cart_items_product (cart_id, product_id),
      KEY idx_cart_items_cart_id (cart_id),
      CONSTRAINT fk_cart_items_cart
        FOREIGN KEY (cart_id) REFERENCES carts(id)
        ON DELETE CASCADE
    )
  `);

  // Alter to add cart_id column to orders table if not exists
  try {
    await pool.query(`ALTER TABLE orders ADD COLUMN cart_id BIGINT UNSIGNED NULL`);
    console.log('✓ Added cart_id column to orders');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add cart_id to orders:', e.message);
    }
  }

  // Alter to add cart index to orders table if not exists
  try {
    await pool.query(`ALTER TABLE orders ADD KEY IF NOT EXISTS idx_orders_cart_id (cart_id)`);
    console.log('✓ Added cart_id index to orders');
  } catch (e) {
    console.log('Note: Could not add cart index to orders:', e.message);
  }

  // Alter to add cart_id foreign key to orders table if not exists
  try {
    await pool.query(`
      ALTER TABLE orders ADD CONSTRAINT fk_orders_cart
      FOREIGN KEY (cart_id) REFERENCES carts(id)
      ON DELETE SET NULL
    `);
    console.log('✓ Added cart_id foreign key to orders');
  } catch (e) {
    if (!e.message.includes('Duplicate')) {
      console.log('Note: Could not add cart foreign key to orders:', e.message);
    }
  }

  // Alter existing orders table to add new status enums if they don't exist
  try {
    await pool.query(`
      ALTER TABLE orders 
      MODIFY COLUMN status ENUM('PENDING_PAYMENT','PAID','PREPARING','READY','COMPLETED','CANCELLED','FAILED') NOT NULL DEFAULT 'PENDING_PAYMENT'
    `);
  } catch (e) {
    // Ignore errors if table doesn't exist or column is already correct
    console.log('Note: Could not alter orders table status enum (table may not exist yet)');
  }

  // Add missing columns to stores table if they don't exist
  try {
    await pool.query(`ALTER TABLE stores ADD COLUMN latitude DECIMAL(10,8) NULL`);
    console.log('✓ Added latitude column to stores');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add latitude to stores:', e.message);
    }
  }

  try {
    await pool.query(`ALTER TABLE stores ADD COLUMN longitude DECIMAL(11,8) NULL`);
    console.log('✓ Added longitude column to stores');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add longitude to stores:', e.message);
    }
  }

  try {
    await pool.query(`ALTER TABLE users ADD COLUMN role VARCHAR(32) NOT NULL DEFAULT 'CUSTOMER'`);
    console.log('✓ Added role column to users');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add role to users:', e.message);
    }
  }

  try {
    await pool.query(`ALTER TABLE stores ADD COLUMN owner_user_id BIGINT UNSIGNED NULL`);
    console.log('✓ Added owner_user_id column to stores');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add owner_user_id to stores:', e.message);
    }
  }

  try {
    await pool.query(`ALTER TABLE menu_items ADD COLUMN special_for_date DATE NULL`);
    console.log('✓ Added special_for_date column to menu_items');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add special_for_date to menu_items:', e.message);
    }
  }

  try {
    await pool.query(`ALTER TABLE menu_items ADD COLUMN is_combo TINYINT(1) NOT NULL DEFAULT 0`);
    console.log('✓ Added is_combo to menu_items');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add is_combo to menu_items:', e.message);
    }
  }

  try {
    await pool.query(`ALTER TABLE menu_items ADD COLUMN combo_components TEXT NULL`);
    console.log('✓ Added combo_components to menu_items');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add combo_components to menu_items:', e.message);
    }
  }

  try {
    await pool.query(`ALTER TABLE cart_items ADD COLUMN line_note VARCHAR(512) NULL`);
    console.log('✓ Added line_note to cart_items');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add line_note to cart_items:', e.message);
    }
  }

  try {
    await pool.query(`ALTER TABLE order_items ADD COLUMN line_note VARCHAR(512) NULL`);
    console.log('✓ Added line_note to order_items');
  } catch (e) {
    if (!e.message.includes('Duplicate column')) {
      console.log('Note: Could not add line_note to order_items:', e.message);
    }
  }
}

async function ensureDefaultAdminAccount() {
  const defaultAdminEmail = 'admin@gmail.com';
  const defaultAdminPassword = '123456';
  const [[existing]] = await pool.query(
    'SELECT id FROM users WHERE email = ? LIMIT 1',
    [defaultAdminEmail],
  );
  if (existing) return;

  const bcrypt = await import('bcryptjs');
  const passwordHash = await bcrypt.hash(defaultAdminPassword, 10);
  await pool.query(
    `INSERT INTO users (name, email, password_hash, role)
     VALUES (?, ?, ?, 'ADMIN')`,
    ['System Admin', defaultAdminEmail, passwordHash],
  );
  console.log('✓ Created default admin account: admin@gmail.com');
}

async function main() {
  try {
    await ensureSchema();
    await ensureDefaultAdminAccount();
    if ((process.env.SEED_DEMO_DATA || '').toLowerCase() === 'true') {
      const [[row]] = await pool.query('SELECT COUNT(*) as c FROM orders');
      const count = Number(row?.c ?? 0);
      if (count === 0) {
        const conn = await pool.getConnection();
        try {
          await conn.beginTransaction();
          const currency = 'LKR';
          const deliveryFee = 200;
          const items = [
            { productId: 1, name: 'Chicken Burger', qty: 2, unitPrice: 850 },
            { productId: 2, name: 'French Fries', qty: 1, unitPrice: 450 },
            { productId: 3, name: 'Cola', qty: 2, unitPrice: 250 },
          ];
          const subtotal = items.reduce((s, it) => s + it.qty * it.unitPrice, 0);
          const total = subtotal + deliveryFee;
          const [orderResult] = await conn.query(
            `INSERT INTO orders (user_id, store_id, currency, subtotal, delivery_fee, total, status)
             VALUES (1, 1, ?, ?, ?, ?, 'PAID')`,
            [currency, subtotal, deliveryFee, total],
          );
          const orderId = orderResult.insertId;
          for (const it of items) {
            await conn.query(
              `INSERT INTO order_items (order_id, product_id, name, qty, unit_price, line_total)
               VALUES (?, ?, ?, ?, ?, ?)`,
              [orderId, it.productId, it.name, it.qty, it.unitPrice, it.qty * it.unitPrice],
            );
          }
          const [payRes] = await conn.query(
            `INSERT INTO payments (order_id, method, status, provider, provider_order_id, amount, currency)
             VALUES (?, 'ONLINE_BANKING', 'CAPTURED', 'BANK', ?, ?, ?)`,
            [orderId, '63123187', total, currency],
          );
          await createReceiptIfMissing(conn, {
            orderId,
            paymentId: payRes.insertId,
            paidAmount: total,
            currency,
            rawProviderResponse: { method: 'ONLINE_BANKING', reference: '63123187', status: 'Payment Success' },
          });
          await conn.commit();
          console.log('Seeded demo order/payment/receipt');
        } catch (e) {
          await conn.rollback();
          console.error('Failed to seed demo data', e);
        } finally {
          conn.release();
        }
      }
    }
  } catch (e) {
    console.error('Failed to ensure DB schema', e);
    process.exit(1);
  }

  const port = Number(process.env.PORT || 8080);
  app.listen(port, '0.0.0.0', () => {
    console.log(`API listening on ${port}`);
  });
}

main();

