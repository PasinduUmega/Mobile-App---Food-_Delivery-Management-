Parallels **`lib/models.dart`** and **`lib/models/`** in Flutter.

Heavy domain types remain in **`lib/models.dart`** for now (single large Dart module).  

This folder holds small JS mirrors where useful for RN (see `roles.js`). Full parity would mean splitting TypeScript/JS models per entity over time.

| Flutter | React Native |
|---------|----------------|
| `models.dart` (UserRole, etc.) | Start with `roles.js`; expand as screens grow |
| `models/permissions.dart` | *(permission matrix not ported)* |
