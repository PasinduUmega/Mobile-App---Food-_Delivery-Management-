import { API_BASE_URL } from '../config';

/**
 * Mirrors Flutter `ApiClient` in `lib/services/api.dart`.
 * Sends `X-User-Id` when `sessionUserId` is set.
 */
class ApiClient {
  /** @type {number|null} */
  sessionUserId = null;

  /** @param {string} path e.g. '/api/stores' */
  async request(path, options = {}) {
    const method = options.method ?? 'GET';
    const body = options.body;
    const p = path.startsWith('/') ? path : `/${path}`;
    const url = `${API_BASE_URL}${p}`;

    /** @type {Record<string,string>} */
    const headers = {
      Accept: 'application/json',
      ...options.headers,
    };
    const isJsonBody = body != null && typeof body === 'object' && !(body instanceof FormData);
    if (isJsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    if (this.sessionUserId != null) {
      headers['X-User-Id'] = String(this.sessionUserId);
    }

    const init = {
      method,
      headers,
      body:
        body == null
          ? undefined
          : isJsonBody
            ? JSON.stringify(body)
            : body,
    };

    const ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
    const timeoutMs = options.timeoutMs ?? 15000;
    const to = ctrl
      ? setTimeout(() => ctrl.abort(), timeoutMs)
      : null;
    try {
      const res = await fetch(url, ctrl ? { ...init, signal: ctrl.signal } : init);
      const text = await res.text();
      let data = null;
      if (text) {
        try {
          data = JSON.parse(text);
        } catch {
          data = { raw: text };
        }
      }
      if (!res.ok) {
        const msg =
          (data && typeof data === 'object' && data.error) ||
          `HTTP ${res.status}`;
        throw new Error(String(msg));
      }
      return data;
    } finally {
      if (to) clearTimeout(to);
    }
  }

  health() {
    return this.request('/health');
  }

  listStores(params = {}) {
    const qs = new URLSearchParams(params).toString();
    const q = qs ? `?${qs}` : '';
    return this.request(`/api/stores${q}`);
  }

  async signIn(email, password) {
    const u = await this.request('/api/auth/signin', {
      method: 'POST',
      body: { email, password },
    });
    const id = u?.id != null ? Number(u.id) : null;
    this.sessionUserId = Number.isFinite(id) ? id : null;
    return u;
  }

  clearSession() {
    this.sessionUserId = null;
  }
}

export const api = new ApiClient();
