# RBAC System - Visual Overview & Summary

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER AUTHENTICATION                          │
│                    (Firebase, Auth Service, etc.)                    │
└────────────────────────────┬──────────────────────────────────────┘
                             │
                    Get User Role: UserRole
                             │
┌────────────────────────────▼──────────────────────────────────────┐
│ PermissionService.initialize(userRole)                             │
│  └─ Initialize permission system with user's role                 │
│  └─ Create PermissionChecker for runtime checks                   │
└────────────────────────────┬──────────────────────────────────────┘
                             │
         ┌───────────────────┴─────────────────┐
         │                                     │
         ▼                                     ▼
┌────────────────────────┐         ┌──────────────────────┐
│ PermissionMatrix       │         │ Permission Service   │
│ - Get all permissions  │         │ - Check permissions  │
│ - Verify operations    │         │ - Helper methods     │
│ - Static access        │         │ - Singleton instance │
└────────────────────────┘         └──────────────────────┘
         │                                     │
         └───────────────────┬─────────────────┘
                             │
                    Used throughout app for:
         ┌──────────────────┬──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
    ┌─────────┐        ┌─────────┐        ┌─────────────┐
    │   UIs   │        │  APIs   │        │  Backend    │
    │         │        │         │        │  Middleware │
    └─────────┘        └─────────┘        └─────────────┘
```

## Module & Role Matrix

```
                    CUSTOMER    STORE_OWNER    ADMIN    DELIVERY_DRIVER
┌────────────────────────────────────────────────────────────────┐
│ Orders & Carts          ✓CRUD      ✗VIEW      ✗VIEW       ✗VIEW   │
│ Restaurant Mgmt         ✗VIEW      ✓CRUD      ✗VIEW       ✗VIEW   │
│ Menu                    ✗VIEW      ✓CRUD      ✗VIEW       ✗VIEW   │
│ Inventory               ✗VIEW      ✓CRUD      ✗VIEW        ✗        │
│ Delivery Mgmt           ✗VIEW      ✗VIEW      ✓CRUD       ✓CRUD   │
│ User Management         ✗VIEW      ✗VIEW      ✓CRUD        ✗        │
│ Admin Dashboard         ✗           ✗         ✓CRUD        ✗        │
│ Payment & Integrations  ✓CV        ✗VIEW      ✗VIEW        ✗        │
│ Rating & Feedback       ✓CV        ✗VIEW      ✓MNG        ✗VIEW   │
└────────────────────────────────────────────────────────────────┘

Legend:
✓CRUD = Full Create-Read-Update-Delete
✓CV  = Create & View only
✓VIEW = View/Read only
✓MNG  = Manage (with moderation)
✗    = No access
```

## Package Structure

```
lib/
├── models/
│   ├── permissions.dart          ← NEW: RBAC Permission Definitions
│   │   ├── OperationType enum
│   │   ├── DashboardModule enum
│   │   ├── ModulePermission class
│   │   ├── PermissionMatrix class
│   │   └── PermissionChecker class
│   └── ... (existing models)
│
├── services/
│   ├── permission_service.dart   ← NEW: Runtime Permission Service
│   │   ├── PermissionService (singleton)
│   │   ├── PermissionCheckDialog Exception
│   │   ├── PermissionExtension
│   │   ├── PermissionGate widget
│   │   ├── PermissionButton widget
│   │   └── PermissionText widget
│   └── ... (existing services)
│
├── ui/
│   ├── dashboards/
│   │   ├── example_dashboard_screens.dart  ← NEW: Reference Implementations
│   │   │   ├── CustomerDashboardScreen
│   │   │   ├── RestaurantDashboardScreen
│   │   │   ├── AdminDashboardScreen
│   │   │   ├── DeliveryDashboardScreen
│   │   │   └── Reusable Components
│   │   └── ... (existing dashboard screens)
│   └── ... (existing UI)
│
├── main.dart                     ← UPDATED: Initialize permissions
│
└── ... (other folders)

docs/
├── RBAC_COMPLETE_GUIDE.md       ← Comprehensive documentation
├── RBAC_QUICK_REFERENCE.md      ← Developer quick reference
├── RBAC_INTEGRATION_GUIDE.md    ← How to integrate into app
└── RBAC_ARCHITECTURE.md         ← This file
```

## Module Details

### 1. Models & Permissions
```dart
lib/models/permissions.dart

Purpose: Define all permissions for the system
Contains:
- OperationType: create, read, update, delete, approve, reject, cancel, submit, manage
- DashboardModule: 10 modules for the app
- Permission definitions for each role/module combination
```

### 2. Permission Service
```dart
lib/services/permission_service.dart

Purpose: Runtime permission checking
Provides:
- Singleton pattern for permission management
- Methods for all permission checks
- UI helper widgets (PermissionGate, PermissionButton)
- BuildContext extension methods
```

### 3. Example Dashboards
```dart
lib/ui/dashboards/example_dashboard_screens.dart

Purpose: Reference implementation of role-based dashboards
Shows:
- Customer Dashboard with conditional features
- Store Owner Dashboard with full CRUD management
- Admin Dashboard with system control
- Delivery Driver Dashboard with delivery focus
- Reusable permission-aware components
```

## Usage Flow

### User Login Flow
```
1. User logs in
2. Authentication service returns UserRole
3. PermissionService().initialize(role)
4. App navigates to role-specific dashboard
5. All screens check permissions before showing UI
```

### Permission Check Flow
```
User interacts with UI
    ↓
Widget calls: context.canUpdate(module)
    ↓
BuildContext extension calls: PermissionService()
    ↓
PermissionService checks PermissionMatrix
    ↓
Returns boolean (true/false)
    ↓
Widget shows/hides UI element
```

### API Protection Flow
```
User initiates action (e.g., create order)
    ↓
Screen calls: repository.createOrder(data)
    ↓
Repository calls: PermissionService().verifyPermission(module, operation)
    ↓
If no permission → Throw PermissionDeniedException
    ↓
If permission → Make API call to backend
    ↓
Backend verifies permission again
    ↓
Process returned data or error
```

## Key Features

✅ **Centralized Permission Management**
- Single source of truth for all permissions
- Easy to audit and modify

✅ **Runtime Checking**
- Extensible for custom logic
- Can be updated without app rebuild

✅ **Multiple Checking Methods**
- Direct service calls: `PermissionService().canCreate(...)`
- BuildContext extension: `context.canUpdate(...)`
- Widget wrappers: `PermissionGate(...)`

✅ **UI Integration**
- Conditional rendering based on permissions
- Permission-aware buttons and forms
- Fallback UI for denied permissions

✅ **API Protection**
- Verify permissions before API calls
- Backend double-verification
- Permission denial exceptions

✅ **Developer Experience**
- Clear, readable API
- Good documentation
- Example implementations
- Quick reference guide

## Implementation Quick Start

### 1. Initialize (main.dart)
```dart
final userRole = await getAuthenticatedUserRole();
PermissionService().initialize(userRole);
```

### 2. Check in UI
```dart
if (context.canCreate(DashboardModule.menuManagement)) {
  // Show create button
}
```

### 3. Protect API
```dart
PermissionService().verifyPermission(module, operation);
// Make API call
```

### 4. Wrap Components
```dart
PermissionGate(
  module: DashboardModule.deliveryManagement,
  operation: OperationType.manage,
  child: DeliveryManagementPanel(),
)
```

## Files Reference

| File | Purpose | Type |
|------|---------|------|
| `lib/models/permissions.dart` | RBAC definitions | Dart Class |
| `lib/services/permission_service.dart` | Runtime service | Dart Service |
| `lib/ui/dashboards/example_dashboard_screens.dart` | Reference impls | Dart UI |
| `RBAC_COMPLETE_GUIDE.md` | Full docs | Markdown |
| `RBAC_QUICK_REFERENCE.md` | Quick ref | Markdown |
| `RBAC_INTEGRATION_GUIDE.md` | Integration steps | Markdown |

## Roles & Responsibilities

### Customer 👤
- **Can**: Manage orders, carts, payments, ratings
- **Cannot**: Manage restaurants, inventory, users, deliveries
- **Primary Dashboard**: Personal account & orders

### Store Owner 🏪
- **Can**: Manage restaurant, menu, inventory
- **Cannot**: Delete restaurants, modify users, approve payments
- **Primary Dashboard**: Restaurant management

### Admin 👨‍💼
- **Can**: Manage users, deliveries, oversee system
- **Cannot**: Direct payment handling, create orders for others
- **Primary Dashboard**: System administration

### Delivery Driver 🚗
- **Can**: Manage their deliveries, pick up orders
- **Cannot**: Manage restaurants, payments, users
- **Primary Dashboard**: Active deliveries

## Security Considerations

✓ Frontend permission checks for UX
✓ Backend permission verification for security (MUST HAVE)
✓ Token-based authentication
✓ Permission denial logging
✓ Rate limiting on sensitive operations
✓ Audit trail for admin actions

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Permissions always false | Call `initialize()` in main |
| API calls without permission | Add `verifyPermission()` checks |
| Role changes not reflected | Re-initialize with new role |
| Permission mismatch (FE/BE) | Sync permission matrices |
| UI shows for denied permission | Use `PermissionGate` wrapper |

## Next Steps

1. ✅ Review RBAC_COMPLETE_GUIDE.md
2. ✅ Check RBAC_QUICK_REFERENCE.md
3. ✅ Follow RBAC_INTEGRATION_GUIDE.md
4. ✅ Examine example_dashboard_screens.dart
5. ✅ Implement in your app
6. ✅ Test all role scenarios
7. ✅ Update backend with same logic
8. ✅ Monitor permission violations

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Apr 2026 | Initial RBAC system |

---

## Questions?

Refer to:
- **"How do I...?"** → RBAC_QUICK_REFERENCE.md
- **"What permissions does X role have?"** → RBAC_COMPLETE_GUIDE.md
- **"How do I integrate this?"** → RBAC_INTEGRATION_GUIDE.md
- **"Show me examples"** → example_dashboard_screens.dart

---

**Last Updated**: April 2026
**Maintained by**: Development Team
