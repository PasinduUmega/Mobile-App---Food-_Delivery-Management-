# Flutter `lib/` ↔ frontend mapping

Flutter **requires** the folder **`lib/`** at the **repository root** (next to `pubspec.yaml`). **`lib/` is not deleted or moved into `frontend/`** — doing so breaks `flutter run`.

This table shows where concepts live:

| Flutter | Web (Vite) | React Native |
|---------|------------|----------------|
| `lib/config.dart` | `frontend/vite` uses proxy; optional `VITE_API_BASE_URL` | `frontend/native/src/config.js` |
| `lib/services/api.dart` | `frontend/src/api.js` (subset) | `frontend/native/src/services/api.js` |
| `lib/models.dart`, `lib/models/` | *(not mirrored yet)* | `frontend/native/src/models/` (starter: `roles.js`) |
| `lib/ui/*.dart` | `frontend/src/*.jsx` (dashboard shell only) | `frontend/native/src/ui/*.js` |
| `main.dart` | `frontend/index.html` + `src/main.jsx` | `native/App.js` + `index.js` |

To **migrate fully off Flutter**, you would remove the Flutter project intentionally; that is separate from organizing `frontend/native` to mirror `lib/`.
