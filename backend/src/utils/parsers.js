export function asInt(v) {
  const n = Number(v);
  return Number.isInteger(n) ? n : null;
}

export function asMoney(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

export function normalizeCurrency(v) {
  const s = String(v ?? '').trim().toUpperCase();
  return /^[A-Z]{3}$/.test(s) ? s : null;
}

export function asFloat(v) {
  const n = parseFloat(v);
  return Number.isNaN(n) ? null : n;
}

/** Optional YYYY-MM-DD or null */
export function parseOptionalDateOnly(v) {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  if (!s) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  return s;
}

export function stringifyComboComponents(arr) {
  if (!Array.isArray(arr) || arr.length === 0) return null;
  const cleaned = arr.map((s) => String(s ?? '').trim()).filter(Boolean).slice(0, 30);
  return cleaned.length ? JSON.stringify(cleaned) : null;
}

export function normalizeComboComponentsInput(body) {
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
