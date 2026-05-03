/** Prefer Vite dev proxy: use relative URLs when VITE_API_BASE_URL is unset. */
export function apiBase() {
  const raw = import.meta.env.VITE_API_BASE_URL?.trim();
  return raw || '';
}

export async function fetchHealth() {
  const res = await fetch(`${apiBase()}/health`);
  if (!res.ok) throw new Error(`Health ${res.status}`);
  return res.json();
}

export async function fetchStores() {
  const res = await fetch(`${apiBase()}/api/stores`);
  if (!res.ok) throw new Error(`Stores ${res.status}`);
  return res.json();
}
