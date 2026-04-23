# Complete Implementation & Integration Guide

This guide shows how to integrate the RBAC permission system into your food delivery app across all dashboards and screens.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [File Structure](#file-structure)
3. [Integration Steps](#integration-steps)
4. [Dashboard Implementation Examples](#dashboard-implementation-examples)
5. [API Integration Guidelines](#api-integration-guidelines)
6. [Database Schema](#database-schema)
7. [Testing Checklist](#testing-checklist)

---

## Architecture Overview

### Layered Permission Enforcement

```
┌─────────────────────────────────────────┐
│     UI Layer (Flutter Widgets)          │
│  - PermissionBuilder wraps UI          │
│  - Permission guards on actions        │
│  - Show/hide based on userRole.can*()  │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│   API Client Layer (HTTP requests)      │
│  - Pre-flight permission checks         │
│  - Headers: X-User-Id, X-User-Role      │
│  - Throw PermissionException if denied  │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│   Backend API Endpoints (Node.js)       │
│  - Validate User ID & Role              │
│  - Check permission matrix              │
│  - Data isolation per user/role         │
│  - Return 403 if denied                 │
│  - Log all attempts                     │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│   Database Layer (SQL/MongoDB)          │
│  - Data owned by specific users         │
│  - Row-level security if possible       │
│  - Audit logs of changes                │
└─────────────────────────────────────────┘
```

---

## File Structure

### New/Modified Files in This Phase

```
lib/
├── models.dart
│   ├── DeliveryLocation (NEW)
│   └── Delivery (NEW)
│
├── services/
│   ├── permissions.dart (MODIFIED - added 'location' component)
│   ├── permission_aware_api.dart (NEW - API with permission checks)
│   └── api.dart (existing)
│
└── ui/
    ├── dashboard_templates_guide.dart (NEW - 4 dashboard templates)
    ├── customer_dashboard.dart (TO IMPLEMENT)
    ├── restaurant_dashboard.dart (TO IMPLEMENT)
    ├── driver_dashboard.dart (TO IMPLEMENT)
    └── admin_dashboard.dart (TO IMPLEMENT)
```

---

## Quick Start

### 1. Initialize App (main.dart)

```dart
import 'package:food_app/services/permission_aware_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final user = await _loadUser();
  
  // Initialize permission system
  PermissionAwareApiClient.initialize(
    userId: user.id.toString(),
    userRole: user.role,
  );
  
  runApp(MyApp(user: user));
}
```

### 2. Route by Role (main_dashboard.dart)

```dart
Widget _buildDashboard() {
  return switch (userRole) {
    UserRole.customer => CustomerDashboardGuide(...),
    UserRole.storeOwner => RestaurantDashboardGuide(...),
    UserRole.deliveryDriver => DeliveryDashboardGuide(...),
    UserRole.admin => AdminDashboardGuide(...),
  };
}
```

### 3. Use Permission Builder

```dart
// Show button only if permission allows
PermissionBuilder(
  userRole: userRole,
  component: ComponentPermissions.orders,
  level: PermissionLevel.create,
  child: ElevatedButton(onPressed: _create, child: Text('Create'))
)
```

### 4. Guard API Calls

```dart
try {
  await PermissionAwareApiClient.createOrder(...);
} on PermissionException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message))
  );
}
```

---

## Permission Matrix Reference

### Customer Permissions

| Component | Create | Read | Update | Delete |
|-----------|--------|------|--------|--------|
| Orders    | ✅     | ✅   | ✅*    | ❌     |
| Carts     | ✅     | ✅   | ✅     | ✅     |
| Payments  | ✅     | ✅   | ❌     | ❌     |
| Restaurants| ❌    | ✅   | ❌     | ❌     |
| Menu      | ❌     | ✅   | ❌     | ❌     |
| Inventory | ❌     | ✅   | ❌     | ❌     |
| Delivery  | ❌     | ✅   | ❌     | ❌     |
| Ratings   | ✅     | ✅   | ✅     | ❌     |
| Users     | ❌     | ✅   | ✅*    | ❌     |

\* Pending status only

### Restaurant Owner Permissions

| Component | Create | Read | Update | Delete |
|-----------|--------|------|--------|--------|
| Restaurants| ❌    | ✅   | ✅*    | ❌     |
| Menu      | ✅     | ✅   | ✅     | ✅     |
| Inventory | ✅     | ✅   | ✅     | ✅     |
| Orders    | ❌     | ✅   | ✅*    | ❌     |
| Payments  | ❌     | ✅   | ❌     | ❌     |
| Delivery  | ❌     | ✅   | ❌     | ❌     |
| Ratings   | ❌     | ✅   | ❌     | ❌     |

\* Own restaurant/own orders only, status updates

### Delivery Driver Permissions

| Component | Create | Read | Update | Delete |
|-----------|--------|------|--------|--------|
| Delivery  | ❌     | ✅   | ✅*    | ❌     |
| Location  | ❌     | ✅   | ✅     | ❌     |
| Orders    | ❌     | ✅   | ❌     | ❌     |
| Restaurants| ❌    | ✅   | ❌     | ❌     |
| Menu      | ❌     | ✅   | ❌     | ❌     |
| Ratings   | ❌     | ✅   | ✅*    | ❌     |

\* Assigned deliveries only, own ratings only

### Admin Permissions

| Component | Create | Read | Update | Delete |
|-----------|--------|------|--------|--------|
| All       | ✅     | ✅   | ✅     | ✅     |

---

## Backend Requirements

Every API endpoint must:

1. **Check Headers**
   ```
   X-User-Id: "123"
   X-User-Role: "customer"
   ```

2. **Validate Permission**
   ```
   If user.role != "customer": return 403
   ```

3. **Enforce Data Isolation**
   ```
   Only return data where ownerId == X-User-Id
   ```

4. **Validate State Transitions**
   ```
   pending → confirmed → preparing → ready → completed
   ```

5. **Log All Access**
   ```
   INSERT INTO audit_logs VALUES (user_id, role, action, resource, allowed)
   ```

---

## Next Steps

1. **Implement Customer Dashboard** → Use `CustomerDashboardGuide` as reference
2. **Implement Restaurant Dashboard** → Use `RestaurantDashboardGuide` as reference
3. **Implement Driver Dashboard** → Use `DeliveryDashboardGuide` as reference
4. **Implement Admin Dashboard** → Use `AdminDashboardGuide` as reference
5. **Backend: Add permission middleware** → Validate every endpoint
6. **Backend: Create audit logging** → Track all permission attempts
7. **Testing: Run permission check tests** → Ensure no unauthorized access
8. **Production: Enable location tracking** → Real-time driver location

---

## Files to Review

- **Permission System**: `lib/services/permissions.dart`
- **API Examples**: `lib/services/permission_aware_api.dart`
- **Dashboard Templates**: `lib/ui/dashboard_templates_guide.dart`
- **Models**: `lib/models.dart` (Delivery, DeliveryLocation)
- **RBAC Documentation**: `RBAC_PERMISSIONS_SYSTEM.md`

