# Frontend (web + React Native)

Two clients share the same Express + MongoDB API as the Flutter app (**`lib/` stays at repo root for Flutter — do not remove it**).

Mapping: see [`FLUTTER_LIB_MAP.md`](FLUTTER_LIB_MAP.md). React Native code mirrors **`lib/services`**, **`lib/ui`**, **`lib/models`** under `native/src/`.

| App | Path | Run |
|-----|------|-----|
| **Web** (Vite + React) | `frontend/` (this folder, `package.json` here) | `npm install` · `npm run dev` |
| **Mobile** (React Native) | `frontend/native/` | `cd native` · `npm install` · `npm start` · `npm run android` / `ios` |

**API base URL**

- Flutter: `lib/config.dart` (`API_BASE_URL`, default Android emulator `http://10.0.2.2:8080`).
- Web: `vite.config.js` dev proxy → `127.0.0.1:8080`.
- React Native: `native/src/config.js` — same emulator/simulator defaults; use your PC LAN IP on a real device.

Web-only details: see comments in `src/api.js` and `.env.example`.
