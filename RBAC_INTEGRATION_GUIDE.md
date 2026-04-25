/// Integration Guide - How to Implement RBAC in Your Existing App

# RBAC Integration Implementation Guide

## Overview

This guide explains how to integrate the Role-Based Access Control (RBAC) system into your existing food delivery app.

## Files Created

### 1. **lib/models/permissions.dart**
   - `OperationType` enum - All available operations
   - `DashboardModule` enum - All dashboard modules
   - `ModulePermission` class - Permission definition for a role/module pair
   - `PermissionMatrix` class - Complete permission matrix for all roles
   - `PermissionChecker` class - Runtime permission helper for a user

### 2. **lib/services/permission_service.dart**
   - `PermissionService` singleton - Main service for permission checking
   - `PermissionDeniedException` - Exception for permission violations
   - `PermissionExtension` - BuildContext extension methods
   - `PermissionGate`, `PermissionButton`, `PermissionText` - UI Widgets

### 3. **RBAC_COMPLETE_GUIDE.md**
   - Complete documentation of all permissions
   - Implementation examples
   - Best practices and guidelines

### 4. **RBAC_QUICK_REFERENCE.md**
   - Quick reference for developers
   - Code snippets
   - FAQ

### 5. **lib/ui/dashboards/example_dashboard_screens.dart**
   - Example implementations of role-based dashboards
   - Reusable permission-aware components

---

## Step-by-Step Integration

### Step 1: Update main.dart

Add permission initialization after user authentication:

```dart
import 'package:food_delivery/services/permission_service.dart';
import 'package:food_delivery/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Get authenticated user role from your auth service
  final userRole = await getAuthenticatedUserRole();
  
  // Initialize RBAC system
  PermissionService().initialize(userRole);
  
  runApp(const MyApp());
}

Future<UserRole> getAuthenticatedUserRole() async {
  // Implement logic to get role from:
  // - SharedPreferences
  // - Firebase/Backend API
  // - Your authentication provider
  
  // Example:
  final prefs = await SharedPreferences.getInstance();
  final roleString = prefs.getString('user_role') ?? 'CUSTOMER';
  return UserRole.fromApi(roleString);
}
```

### Step 2: Update Your Existing Screens

Convert your existing dashboard screens to use the permission system:

#### Before (No Permissions)
```dart
class OrdersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: ListView(
        children: [
          // Show all buttons for everyone
          ElevatedButton(
            onPressed: () => createOrder(),
            child: const Text('Create Order'),
          ),
          ElevatedButton(
            onPressed: () => editOrder(),
            child: const Text('Edit Order'),
          ),
          ElevatedButton(
            onPressed: () => deleteOrder(),
            child: const Text('Delete Order'),
          ),
        ],
      ),
    );
  }
}
```

#### After (With Permissions)
```dart
class OrdersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final permissions = PermissionService();

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: ListView(
        children: [
          // Only show if user can create
          if (permissions.canCreate(DashboardModule.ordersAndCarts))
            ElevatedButton(
              onPressed: () => createOrder(),
              child: const Text('Create Order'),
            ),

          // Only show if user can update
          if (permissions.canUpdate(DashboardModule.ordersAndCarts))
            ElevatedButton(
              onPressed: () => editOrder(),
              child: const Text('Edit Order'),
            ),

          // Only show if user can delete
          if (permissions.canDelete(DashboardModule.ordersAndCarts))
            ElevatedButton(
              onPressed: () => deleteOrder(),
              child: const Text('Delete Order'),
            ),

          // Show list with conditional buttons
          OrdersList(
            module: DashboardModule.ordersAndCarts,
          ),
        ],
      ),
    );
  }
}
```

### Step 3: Create Role-Specific Dashboard Navigation

```dart
class DashboardNavigation extends StatefulWidget {
  const DashboardNavigation({super.key});

  @override
  State<DashboardNavigation> createState() => _DashboardNavigationState();
}

class _DashboardNavigationState extends State<DashboardNavigation> {
  @override
  Widget build(BuildContext context) {
    final userRole = PermissionService().currentUserRole;
    
    // Route based on role
    return switch (userRole) {
      UserRole.customer => const CustomerDashboardScreen(),
      UserRole.storeOwner => const RestaurantDashboardScreen(),
      UserRole.admin => const AdminDashboardScreen(),
      UserRole.deliveryDriver => const DeliveryDashboardScreen(),
      _ => const SizedBox.shrink(),
    };
  }
}
```

### Step 4: Protect API Calls

In your API service/repository:

```dart
class OrderRepository {
  final ApiClient _apiClient;

  OrderRepository(this._apiClient);

  Future<Order> createOrder(CreateOrderRequest request) async {
    // Verify user has permission before making API call
    try {
      PermissionService().verifyPermission(
        DashboardModule.ordersAndCarts,
        OperationType.create,
      );
    } on PermissionDeniedException catch (e) {
      print('Permission denied: ${e.message}');
      rethrow; // Re-throw to handle in UI
    }

    // Make API call
    return await _apiClient.post('/orders', request);
  }

  Future<Order> updateOrder(int orderId, UpdateOrderRequest request) async {
    PermissionService().verifyPermission(
      DashboardModule.ordersAndCarts,
      OperationType.update,
    );

    return await _apiClient.put('/orders/$orderId', request);
  }

  Future<void> deleteOrder(int orderId) async {
    PermissionService().verifyPermission(
      DashboardModule.ordersAndCarts,
      OperationType.delete,
    );

    return await _apiClient.delete('/orders/$orderId');
  }
}
```

### Step 5: Create Reusable Widgets

Create wrapper widgets in your `lib/ui/widgets/` folder:

```dart
// lib/ui/widgets/permission_widgets.dart

class PermissionListTile<T> extends StatelessWidget {
  final T item;
  final DashboardModule module;
  final Widget Function(BuildContext, T) title;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PermissionListTile({
    required this.item,
    required this.module,
    required this.title,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: title(context, item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit button - only if permission
          if (context.canUpdate(module))
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),

          // Delete button - only if permission
          if (context.canDelete(module))
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
```

### Step 6: Update Your App Shell

In `lib/ui/app_shell.dart`, add role-based navigation:

```dart
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final userRole = PermissionService().currentUserRole;

    return Scaffold(
      appBar: AppBar(
        title: Text('${userRole?.displayLabel} Dashboard'),
      ),
      drawer: _buildRoleSpecificDrawer(),
      body: _buildRoleSpecificContent(),
    );
  }

  Widget _buildRoleSpecificDrawer() {
    final userRole = PermissionService().currentUserRole;
    final modules = PermissionService().getAccessibleModules();

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Text('${userRole?.displayLabel} Menu'),
          ),
          // Create menu items only for accessible modules
          ...modules.map((module) {
            return ListTile(
              title: Text(module.name),
              onTap: () {
                // Navigate to module screen
                _navigateToModule(module);
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRoleSpecificContent() {
    final userRole = PermissionService().currentUserRole;

    return switch (userRole) {
      UserRole.customer => const CustomerDashboardScreen(),
      UserRole.storeOwner => const RestaurantDashboardScreen(),
      UserRole.admin => const AdminDashboardScreen(),
      UserRole.deliveryDriver => const DeliveryDashboardScreen(),
      _ => const Center(child: Text('Unknown role')),
    };
  }

  void _navigateToModule(DashboardModule module) {
    // Implement navigation based on module
    switch (module) {
      case DashboardModule.ordersAndCarts:
        Navigator.pushNamed(context, '/orders');
      case DashboardModule.menuManagement:
        Navigator.pushNamed(context, '/menu');
      case DashboardModule.deliveryManagement:
        Navigator.pushNamed(context, '/delivery');
      // ... handle other modules
      default:
        break;
    }
  }
}
```

### Step 7: Backend API Permission Verification

Ensure your backend also verifies permissions:

```javascript
// backend/middleware/permissions.js or similar

const checkPermission = (requiredModule, requiredOperation) => {
  return async (req, res, next) => {
    const userRole = req.user.role; // From JWT token
    
    // Verify permission (should match frontend logic)
    const hasPermission = PermissionMatrix.canPerform(
      userRole,
      requiredModule,
      requiredOperation
    );

    if (!hasPermission) {
      return res.status(403).json({
        error: 'Permission Denied',
        message: `${userRole} cannot perform ${requiredOperation}`,
      });
    }

    next();
  };
};

// Usage in routes
app.post(
  '/api/orders',
  authenticate,
  checkPermission('ORDERS_AND_CARTS', 'CREATE'),
  createOrderHandler
);

app.put(
  '/api/orders/:id',
  authenticate,
  checkPermission('ORDERS_AND_CARTS', 'UPDATE'),
  updateOrderHandler
);

app.delete(
  '/api/orders/:id',
  authenticate,
  checkPermission('ORDERS_AND_CARTS', 'DELETE'),
  deleteOrderHandler
);
```

---

## Testing Permissions

Create unit tests for your permission system:

```dart
// test/permissions_test.dart

void main() {
  group('Permission Matrix Tests', () {
    test('Customer can create orders', () {
      expect(
        PermissionMatrix.canPerform(
          UserRole.customer,
          DashboardModule.ordersAndCarts,
          OperationType.create,
        ),
        isTrue,
      );
    });

    test('Store owner cannot delete their restaurant', () {
      expect(
        PermissionMatrix.canPerform(
          UserRole.storeOwner,
          DashboardModule.restaurantManagement,
          OperationType.delete,
        ),
        isFalse, // Or isTrue depending on business rules
      );
    });

    test('Admin can manage users', () {
      expect(
        PermissionMatrix.canPerform(
          UserRole.admin,
          DashboardModule.userManagement,
          OperationType.manage,
        ),
        isTrue,
      );
    });

    test('Driver cannot access admin dashboard', () {
      final permission = PermissionMatrix.getPermission(
        UserRole.deliveryDriver,
        DashboardModule.adminDashboard,
      );
      expect(
        permission?.allowedOperations.isEmpty ?? true,
        isTrue,
      );
    });
  });
}
```

---

## Migration Checklist

- [ ] Create `lib/models/permissions.dart`
- [ ] Create `lib/services/permission_service.dart`
- [ ] Update `main.dart` to initialize permissions
- [ ] Update `lib/ui/app_shell.dart` with role-based navigation
- [ ] Convert existing screens to use permission checks
- [ ] Create reusable permission-aware widgets
- [ ] Update API calls to verify permissions
- [ ] Update backend to verify permissions
- [ ] Add unit tests for permissions
- [ ] Test all role scenarios
- [ ] Update UI tests with permission mocking
- [ ] Document any custom permissions

---

## Troubleshooting

### Issue: Permission always returns false/denied

**Solution**: Make sure `PermissionService().initialize(userRole)` is called in `main()` before any permission checks.

### Issue: API requests are being made even without permission

**Solution**: Verify you're calling `PermissionService().verifyPermission()` before API calls, or the permission check middleware is enabled on backend.

### Issue: Role changes during session aren't reflected

**Solution**: Call `PermissionService().initialize(newRole)` when user role changes (e.g., after elevating to admin).

### Issue: Permissions are different between frontend and backend

**Solution**: Ensure both frontend and backend use the same permission matrix logic. Consider moving to a shared configuration.

---

## Next Steps

1. **Implement** the RBAC system following this guide
2. **Test** all permission scenarios with different user roles
3. **Document** any custom permissions specific to your business logic
4. **Monitor** permission violations for security auditing
5. **Iterate** on permissions based on user feedback

---

## Support

For questions or issues with RBAC integration:
1. Check `RBAC_COMPLETE_GUIDE.md` for detailed documentation
2. Review example implementations in `example_dashboard_screens.dart`
3. Look at unit tests for usage patterns
4. Verify permissions are initialized in main()

---

**Version**: 1.0.0
**Last Updated**: April 2026
