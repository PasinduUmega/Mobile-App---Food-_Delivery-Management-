import { useEffect, useState } from 'react';
import './App.css';
import { apiBase, fetchHealth, fetchStores } from './api';

function App() {
  const [health, setHealth] = useState(null);
  const [stores, setStores] = useState(null);
  const [err, setErr] = useState(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [h, s] = await Promise.all([fetchHealth(), fetchStores()]);
        if (!cancelled) {
          setHealth(h);
          setStores(s);
        }
      } catch (e) {
        if (!cancelled) setErr(String(e?.message ?? e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="layout">
      <header className="hdr">
        <h1>Food Rush</h1>
        <p className="sub">React dashboard · API: {apiBase() || '(same origin / Vite proxy)'}</p>
      </header>
      <main className="main">
        <section className="card">
          <h2>Backend health</h2>
          {err && <p className="err">{err}</p>}
          {!err && health == null && <p>Checking…</p>}
          {!err && health != null && (
            <pre className="mono">{JSON.stringify(health, null, 2)}</pre>
          )}
        </section>
        <section className="card">
          <h2>Stores</h2>
          {stores == null && !err && <p>Loading…</p>}
          {stores && (
            <ul className="list">
              {(stores.items ?? []).map((s) => (
                <li key={s.id}>
                  <strong>{s.name}</strong>
                  {s.address ? ` · ${s.address}` : ''}
                </li>
              ))}
            </ul>
          )}
          {stores && (stores.items ?? []).length === 0 && (
            <p className="muted">No stores yet. Create them via the Flutter admin or POST /api/stores.</p>
          )}
        </section>
      </main>
    </div>
  );
}

export default App;
