# Food Rush - Restaurant Management

Flutter + Dart real-time restaurant management system with full CRUD operations.

## Tech Stack

- Mobile App: Flutter + Dart
- Backend API: Dart (`shelf`, `shelf_router`)
- Database: MySQL (`food_rush` schema)
- Real-time updates: WebSocket broadcast from backend to Flutter client

## Project Structure

- `lib/` - Flutter app
  - `src/models/menu_item.dart` - menu item model
  - `src/services/api_service.dart` - HTTP and WebSocket client
  - `src/screens/dashboard_screen.dart` - CRUD UI
  - `src/widgets/menu_item_form_dialog.dart` - add/edit form dialog
- `backend/` - Dart backend server
  - `bin/server.dart` - API + WebSocket server
  - `sql/food_rush_schema.sql` - MySQL schema script

## Setup MySQL (`food_rush`)

1. Start your MySQL server.
2. Run this SQL script:
   - `backend/sql/food_rush_schema.sql`
3. Update DB credentials in `backend/bin/server.dart` if needed:
   - `host`, `port`, `user`, `password`

## Run Backend

```bash
cd backend
dart pub get
dart run bin/server.dart
```

Backend runs at `http://localhost:8080`.

## Run Flutter App

```bash
flutter pub get
flutter run
```

Default API URL in Flutter is set to Android emulator loopback:
- `http://10.0.2.2:8080`

If you run on:
- Physical device: replace with your PC local IP
- iOS simulator/web/desktop: you can use `http://localhost:8080`
