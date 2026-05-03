# food_delivery

Food Rush (Flutter) + Payments (PayPal/COD/Online Banking demo).

## Getting Started

### Backend (MongoDB + Express)

See [`backend/README.md`](backend/README.md) for environment variables, MongoDB, and PayPal setup.

```bash
cd backend
npm install
npm run dev
```

### Web & React Native (optional)

- **Web (Vite):** `frontend/` — `npm install` / `npm run dev` (proxies API in dev).
- **React Native:** `frontend/native/` — same REST API as Flutter; set `src/config.js` for device vs emulator. See [`frontend/README.md`](frontend/README.md).

### Flutter app

- Install deps:

```bash
flutter pub get
```

- **Run with correct API url**:
  - **Android emulator**: `http://10.0.2.2:8080` (default)
  - **iOS simulator**: `http://localhost:8080`
  - **Real device**: use your PC LAN IP (example `http://192.168.1.20:8080`)

Override at runtime:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

### App flow

- Cart → Checkout → Choose payment method
- **PayPal**: opens PayPal approval in WebView, then captures on return URL
- **COD / Online banking**: confirms instantly (demo) and generates receipt
- Receipt screen polls `/api/receipts/{orderId}` every ~2 seconds until ready

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
