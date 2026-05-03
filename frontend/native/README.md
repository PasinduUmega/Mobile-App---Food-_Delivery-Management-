# Food Rush — React Native

Uses the **same REST API** as the Flutter client (`lib/services/api.dart`). Folder layout parallels Flutter `lib/` — see **`../FLUTTER_LIB_MAP.md`**.

```
src/
  config.js           ← lib/config.dart
  services/api.js     ← lib/services/api.dart
  models/             ← lib/models (starter)
  ui/                 ← lib/ui (subset screens)
  navigation/
  theme.js
```

## Configuration

- **`src/config.js`** — `API_BASE_URL` (Android emulator `http://10.0.2.2:8080`, iOS sim `http://127.0.0.1:8080`). For a physical device, set the URL to `http://<your-pc-lan-ip>:8080`.

## Networking

`src/services/api.js` mirrors Flutter `ApiClient`: JSON requests and optional `X-User-Id` after sign-in (`sessionUserId`).

## Run

```bash
npm install
npm start
npm run android
# or
npm run ios
```

### Native projects (`android/` / `ios/`)

This repo may only contain JS sources. If those folders are missing, create a temporary React Native 0.74 app and merge this `App.js`, `src/`, `index.js`, `app.json`, `babel.config.js`, and dependencies from `package.json`, or regenerate with the official RN template matching your toolchain.
