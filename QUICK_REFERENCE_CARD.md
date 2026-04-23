# RBAC System Quick Reference Card

## File Locations
```
Permissions:        lib/services/permissions.dart
API Examples:       lib/services/permission_aware_api.dart
Dashboard Guides:   lib/ui/dashboard_templates_guide.dart
Models:             lib/models.dart
Documentation:      RBAC_PERMISSIONS_SYSTEM.md
                    IMPLEMENTATION_INTEGRATION_GUIDE.md
                    PHASE_3_ACTION_PLAN.md
```

---

## Permission Matrix (Quick View)

```
COMPONENT       | Customer | Restaurant | Driver | Admin
================|==========|============|========|======
Orders          | CRU      | RU*        | R      | CRUD
Carts           | CRUD     | -          | -      | CRUD
Menu            | R        | CRUD       | R      | CRUD
Inventory       | R        | CRUD       | R      | CRUD
Payments        | CR       | R          | R      | CRUD
Restaurants     | R        | U*         | R      | CRUD
Delivery        | R        | R          | RU*    | CRUD
Ratings         | CU       | R          | RU*    | CRUD
Users           | RU*      | -          | -      | CRUD
Location        | -        | -          | RU     | CRUD

Legend: C=Create, R=Read, U=Update, D=Delete
* = limited scope (own resources only)
- = no access
```

---

## Components

```dart
// Use these in permission checks
ComponentPermissions.orders       // Order management
ComponentPermissions.carts        // Shopping carts
ComponentPermissions.menu         // Menu items
ComponentPermissions.inventory    // Inventory levels
ComponentPermissions.payments     // Payment processing
ComponentPermissions.restaurants  // Restaurant info
ComponentPermissions.delivery     // Delivery management
ComponentPermissions.ratings      // Ratings & feedback
ComponentPermissions.users        // User management
ComponentPermissions.location     // Driver location
ComponentPermissions.userProfile  // User profile
```

---

## Permission Levels

```dart
PermissionLevel.create   // Can create new
PermissionLevel.read     // Can view/retrieve
PermissionLevel.update   // Can modify
PermissionLevel.delete   // Can remove
```

---

## UI Usage Patterns

### Pattern 1: Hide Button if No Permission
```dart
PermissionBuilder(
  userRole: userRole,
  component: ComponentPermissions.orders,
  level: PermissionLevel.create,
  child: ElevatedButton(onPressed: _create, child: Text('Create')),
  onDenied: SizedBox.shrink(),  // Hide button
)
```

### Pattern 2: Guard Operation at Callback
```dart
void _createOrder() {
  if (!PermissionHelper.guardOperation(
    context,        // BuildContext for error display
    userRole,       // UserRole (customer, admin, etc)
    ComponentPermissions.orders,
    PermissionLevel.create,
  )) {
    return;  // Permission denied, user was notified
  }
  
  // Proceed with operation
  _doCreateOrder();
}
```

### Pattern 3: Quick Check with Extensions
```dart
if (userRole.canCreate('orders')) {
  // Show create button
}

if (userRole.canUpdate('menu')) {
  // Show edit button
}

if (userRole.canDelete('restaurants')) {
  // Show delete button
}
```

### Pattern 4: Conditional Tab Display
```dart
PermissionBuilder(
  userRole: userRole,
  component: ComponentPermissions.users,
  level: PermissionLevel.read,
  child: Tab(icon: Icon(Icons.people), text: 'Users'),
)
```

---

## API Usage Pattern

```dart
import 'package:food_app/services/permission_aware_api.dart';

// In main.dart
void main() {
  final user = loadUser();
  PermissionAwareApiClient.initialize(
    userId: user.id.toString(),
    userRole: user.role,
  );
}

// In dashboard
try {
  final order = await PermissionAwareApiClient.createOrder(
    restaurantId: '123',
    items: [...],
  );
  print('Order created: ${order.id}');
} on PermissionException catch (e) {
  // Permission denied (caught client-side)
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message))
  );
} on SocketException {
  // Network error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Network error'))
  );
} catch (e) {
  // Other error
  print('Error: $e');
}
```

---

## Dashboard Template Structure

```dart
// Each dashboard follows this pattern:

class CustomerDashboard extends StatefulWidget {
  final User user;
  final UserRole userRole;
  
  const CustomerDashboard({
    required this.user,
    required this.userRole,
  });

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  @override
  void initState() {
    super.initState();
    _loadData();  // Load respecting permissions
  }

  Future<void> _loadData() async {
    if (widget.userRole.canRead('orders')) {
      // Load orders
    }
  }

  void _createOrder() {
    if (!PermissionHelper.guardOperation(
      context, widget.userRole, 'orders', PermissionLevel.create
    )) return;
    // Show create dialog
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          // Create button (guarded with PermissionBuilder)
          PermissionBuilder(...),
          
          // Orders list (only if can read)
          PermissionBuilder(...),
        ],
      ),
    );
  }
}
```

---

## Backend Validation (Node.js Example)

```javascript
// Middleware: Validate permissions on EVERY endpoint

const authMiddleware = (req, res, next) => {
  req.userId = req.headers['x-user-id'];
  req.userRole = req.headers['x-user-role'];
  
  if (!req.userId || !req.userRole) {
    return res.status(401).json({ error: 'Missing headers' });
  }
  next();
};

const requirePermission = (component, level) => {
  return (req, res, next) => {
    const permissions = {
      customer: { orders: ['create','read','update'] },
      storeOwner: { menu: ['create','read','update','delete'] },
      // ... see IMPLEMENTATION_INTEGRATION_GUIDE.md for full matrix
    };
    
    if (!permissions[req.userRole]?.[component]?.includes(level)) {
      logger.warn(`DENIED: ${req.userRole} ${level} ${component}`);
      return res.status(403).json({ error: 'Permission denied' });
    }
    next();
  };
};

// Use on every endpoint:
app.post('/api/orders',
  authMiddleware,
  requirePermission('orders', 'create'),
  async (req, res) => {
    // Create order
  }
);
```

---

## User Roles

```dart
enum UserRole {
  customer,         // Users placing orders, paying
  storeOwner,       // Restaurant owners managing menu
  deliveryDriver,   // Drivers managing deliveries
  admin,            // Full system access
}

// Extension methods available:
userRole.canCreate(component)
userRole.canRead(component)
userRole.canUpdate(component)
userRole.canDelete(component)
userRole.canAccess(component)

// Display labels:
userRole.displayLabel
// "Customer", "Restaurant owner", "Delivery driver", "Administrator"
```

---

## Error Handling

```dart
// PermissionException
class PermissionException implements Exception {
  final String message;      // User-friendly error message
  final UserRole userRole;   // Which role denied
  final String component;    // What was denied
  final PermissionLevel level; // Create/Read/Update/Delete
  
  // Use in catch block:
  try { ... }
  on PermissionException catch (e) {
    showError(e.message);  // "You cannot delete orders"
    log(e.toString());      // Full details for debugging
  }
}

// Show errors to user:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Permission denied: You cannot access this'))
);
```

---

## Testing Checklist

```
Customer:
  ✓ Can create order
  ✗ Cannot delete order
  ✓ Can make payment / view history
  ✗ Cannot edit payment
  ✓ Can rate driver
  ✓ Can update profile

Restaurant:
  ✓ Can edit own restaurant
  ✓ Can add menu items
  ✓ Can delete menu items
  ✓ Can update inventory
  ✓ Can update order status
  ✗ Cannot delete orders
  ✗ Cannot create users

Driver:
  ✓ Can accept delivery
  ✓ Can update location
  ✓ Can mark as delivered
  ✓ Can view assigned orders
  ✗ Cannot modify order
  ✗ Cannot delete delivery

Admin:
  ✓ Can do everything
  ✓ Can create users
  ✓ Can change roles
  ✓ Can delete anything
  ✓ Can view audit logs
```

---

## Debugging Tips

```dart
// Print user role and permissions
print('Current role: ${userRole.displayLabel}');
print('Can create orders: ${userRole.canCreate('orders')}');
print('Can delete orders: ${userRole.canDelete('orders')}');

// Check permission object
final perm = UserRole.customer.permission;
print('Customer can create orders: ${perm.canPerform(PermissionLevel.create, 'orders')}');

// In backend, log permission checks:
logger.info(`User ${userId} (${userRole}) attempt ${action} ${resource}`);
```

---

## Security Reminders

✅ **Always validate on backend** - Never trust client-side checks
✅ **Check headers** - Validate X-User-Id and X-User-Role on every API request
✅ **Enforce data isolation** - Users can only see their own data
✅ **Log attempts** - Monitor failed permission checks for security threats
✅ **Return 403** - Forbidden for permission denials, 401 for authentication
❌ **Never bypass on UI** - Permission denied = no button, but backend checks are critical
❌ **Don't cascade permissions** - Check each component separately
❌ **Don't trust role strings** - Validate against your permission matrix

---

## Quick Copy-Paste Templates

### Customer Dashboard Tab
```dart
Tab(
  icon: Icon(Icons.shopping_cart),
  text: PermissionBuilder(
    userRole: userRole,
    component: ComponentPermissions.orders,
    level: PermissionLevel.read,
    child: Text('My Orders'),
    onDenied: SizedBox.shrink(),
  ),
)
```

### Create Button with Permission
```dart
PermissionBuilder(
  userRole: userRole,
  component: ComponentPermissions.menu,
  level: PermissionLevel.create,
  child: ElevatedButton.icon(
    onPressed: _addMenuItem,
    icon: Icon(Icons.add),
    label: Text('Add Item'),
  ),
)
```

### List with Conditional Actions
```dart
ListTile(
  title: Text('Order #123'),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (userRole.canUpdate('orders'))
        IconButton(icon: Icon(Icons.edit), onPressed: _edit),
      if (userRole.canDelete('orders'))
        IconButton(icon: Icon(Icons.delete), onPressed: _delete),
    ],
  ),
)
```

### Tab Navigation
```dart
SegmentedButton<int>(
  segments: [
    ButtonSegment(value: 0, label: Text('Orders')),
    ButtonSegment(value: 1, label: Text('Payments')),
    if (userRole.canAccess('menu'))
      ButtonSegment(value: 2, label: Text('Menu')),
  ],
  selected: {_selected},
  onSelectionChanged: (s) => setState(() => _selected = s.first),
)
```

---

## Resources

- **Full permission matrix:** RBAC_PERMISSIONS_SYSTEM.md
- **Implementation guide:** IMPLEMENTATION_INTEGRATION_GUIDE.md  
- **Dashboard examples:** lib/ui/dashboard_templates_guide.dart
- **API examples:** lib/services/permission_aware_api.dart
- **Action plan:** PHASE_3_ACTION_PLAN.md

---

**Remember:** This is a complete, production-ready system. Start implementing Phase 3 dashboards using the templates, then secure the backend with permission middleware.

