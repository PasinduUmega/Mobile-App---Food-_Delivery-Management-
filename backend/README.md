# food_delivery

Food Rush (Flutter) + Payments (PayPal/COD/Online Banking demo).

## Getting Started

### Backend (MongoDB + Express + PayPal)

- **1)** Run [MongoDB](https://www.mongodb.com/docs/manual/installation/) locally (or point `MONGODB_URI` at Atlas).
- **2) Configure backend env**:
  - Copy `backend/.env.example` → `backend/.env`
  - Set `MONGODB_URI` and optionally `MONGODB_DB` (default `food_rush`). Indexes are created on startup via `backend/src/config/mongo.js`.
  - Set PayPal sandbox credentials: `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`

- **3) Run backend**:

```bash
cd backend
npm install
npm run dev
```

Backend default: `http://localhost:8080`

**Layout**

- `src/server.js` — connect MongoDB, seed default admin, `createApp`, listen  
- `src/app.js` — Express app (`cors`, JSON), PayPal client, `registerRoutes`  
- `src/routes/` — HTTP routers (mount paths)  
- `src/controllers/` — request / response adapters  
- `src/services/` — business rules / orchestration helpers  
- `src/repositories/` — Mongo accessors (`coll()`)  
- `src/models/` — shared enums / constants (`constants.js`)  
- `src/utils/` — parsers, request user header, formatting  
- `src/config/mongo.js`, `src/bootstrap/`, `src/paypal.js`
- `docs/API_ENDPOINTS.md` — full route list grouped by domain (incl. health, catalog, drivers, feedback)  
- `docs/API_ENDPOINT_TABLES_README.md` — **seven** Swagger-style tables: Method · Endpoint · Description · Protected (Auth, Stores, Orders+refunds, Payments+receipts, Users, Deliveries, Carts)

### Web dashboard (`frontend/` — Vite + React)

In development, `/api` and `/health` are proxied to Express on port `8080` (see `frontend/vite.config.js`).

```bash
cd frontend
npm install
npm run dev
```

Optional: `frontend/.env` with `VITE_API_BASE_URL` for production builds.

### React Native (`frontend/native/`)

Shares the same API as Flutter (`lib/`). Configure the device URL in `frontend/native/src/config.js`, then:

```bash
cd frontend/native
npm install
npm start
```

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
