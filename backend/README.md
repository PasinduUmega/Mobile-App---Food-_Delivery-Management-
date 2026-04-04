# food_delivery

Food Rush (Flutter) + Payments (PayPal/COD/Online Banking demo).

## Getting Started

### Backend (MySQL + PayPal)

- **1) Create / use your MySQL schema**: `food_rush`
- **2) Apply tables**:

```bash
mysql -u root -p food_rush < backend/sql/food_rush_payments.sql
```

- **3) Configure backend env**:
  - Copy `backend/.env.example` → `backend/.env`
  - Set `MYSQL_*`
  - Set PayPal sandbox credentials: `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`

- **4) Run backend**:

```bash
cd backend
npm install
npm run dev
```

Backend default: `http://localhost:8080`

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
