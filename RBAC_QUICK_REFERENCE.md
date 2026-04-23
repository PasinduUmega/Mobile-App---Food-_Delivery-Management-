# RBAC Quick Reference Card

## Permission Matrix at a Glance

### Customer Role ✓
```
✓ Orders & Carts        → Full CRUD
✓ Customer Dashboard    → Full CRUD  
✓ Payment & Integrations → Create & View
✓ Rating & Feedback     → Create & View
- Restaurant Mgmt       → View only
- Menu                  → View only
- Inventory             → View only
- Delivery Mgmt         → View only
- User Mgmt             → View only
✗ Admin Dashboard       → No access
```

### Store Owner Role 🏪
```
- Orders & Carts        → View only
✓ Restaurant Mgmt       → Full CRUD
✓ Menu                  → Full CRUD
✓ Inventory             → Full CRUD
- Payment & Integrations → View only
- Delivery Mgmt         → View only
- Customer Dashboard    → View only
- User Mgmt             → View only
- Rating & Feedback     → View only
✗ Admin Dashboard       → No access
```

### Admin Role 👨‍💼
```
✓ User Mgmt             → Full + Manage
✓ Delivery Mgmt         → Full + Manage
✓ Admin Dashboard       → Full access
- Orders & Carts        → View only
- Customer Dashboard    → View only
- Restaurant Mgmt       → View only
- Menu                  → View only
- Inventory             → View only
- Payment & Integrations → View only
- Rating & Feedback     → View + Manage
```

### Delivery Driver Role 🚗
```
✓ Delivery Mgmt         → Full CRUD
- Orders & Carts        → View only
- Customer Dashboard    → View only
- Restaurant Mgmt       → View only
- Menu                  → View only
- Rating & Feedback     → View only
✗ All Others            → No access
```

---

## Code Snippets

### Initialize (main.dart)
```dart
PermissionService().initialize(currentUserRole);
```

### Check Permission
```dart
context.canCreate(DashboardModule.menuManagement)
```

### Full CRUD Check
```dart
PermissionService().hasFullCrud(DashboardModule.ordersAndCarts)
```

### Get All Accessible Modules
```dart
PermissionService().getAccessibleModules()
```

### Verify & Throw Error
```dart
PermissionService().verifyPermission(
  DashboardModule.adminDashboard,
  OperationType.read,
);
```

### UI Wrapper
```dart
PermissionGate(
  module: DashboardModule.inventoryManagement,
  operation: OperationType.update,
  child: EditButton(),
)
```

---

## FAQ

**Q: How do I check if user can create orders?**
```dart
if (context.canCreate(DashboardModule.ordersAndCarts)) {
  // Show create button
}
```

**Q: How do I prevent unauthorized API calls?**
```dart
PermissionService().verifyPermission(
  DashboardModule.paymentAndIntegrations,
  OperationType.create,
); // Throws PermissionDeniedException if not allowed
```

**Q: How do I hide elements from certain roles?**
```dart
PermissionGate(
  module: DashboardModule.adminDashboard,
  operation: OperationType.create,
  child: AdminPanel(),
  fallback: UnauthorizedWidget(),
)
```

**Q: Can I have custom permissions per module?**
Not in core, but you can extend `PermissionChecker` for custom logic.

---

**Module Name Reference:**
- `ordersAndCarts`
- `customerDashboard`
- `paymentAndIntegrations`
- `userManagement`
- `restaurantManagement`
- `menuManagement`
- `inventoryManagement`
- `deliveryManagement`
- `adminDashboard`
- `ratingAndFeedback`

**Operation Reference:**
- `create` - Add new items
- `read` - View items
- `update` - Modify items
- `delete` - Remove items
- `approve` - Approve actions
- `reject` - Reject actions
- `cancel` - Cancel operations
- `submit` - Submit forms
- `manage` - Full management
