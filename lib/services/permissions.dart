import 'package:flutter/material.dart';
import '../models.dart';

/// Permission levels for different operations
enum PermissionLevel { create, read, update, delete }

/// Base permission interface
abstract class RolePermission {
  bool canPerform(PermissionLevel level, String component);
  bool canAccessComponent(String component);
  UserRole get role;
}

/// Customer permissions
class CustomerPermission implements RolePermission {
  @override
  UserRole get role => UserRole.customer;

  @override
  bool canPerform(PermissionLevel level, String component) {
    switch (component) {
      case 'orders':
      case 'carts':
        // Full CRUD for own orders/carts
        return true;

      case 'payments':
        // Create & Read only
        return level == PermissionLevel.create || level == PermissionLevel.read;

      case 'restaurants':
      case 'menu':
      case 'inventory':
        // Read only
        return level == PermissionLevel.read;

      case 'delivery':
        // Read only - track delivery
        return level == PermissionLevel.read;

      case 'ratings':
        // Managed by admin in user management only
        return false;

      case 'user_profile':
        // Read & Update own profile only
        return level != PermissionLevel.delete;

      default:
        return false;
    }
  }

  @override
  bool canAccessComponent(String component) {
    return canPerform(PermissionLevel.read, component);
  }
}

/// Restaurant Owner permissions
class RestaurantPermission implements RolePermission {
  @override
  UserRole get role => UserRole.storeOwner;

  @override
  bool canPerform(PermissionLevel level, String component) {
    switch (component) {
      case 'restaurant':
        // Full CRUD for own restaurant
        return true;

      case 'menu':
      case 'inventory':
        // Full CRUD for own restaurant items
        return true;

      case 'orders':
      case 'carts':
        // Full CRUD for order/cart management dashboard
        return true;

      case 'payments':
      case 'delivery':
        // Read only
        return level == PermissionLevel.read;

      case 'ratings':
        // Read only - view customer ratings
        return level == PermissionLevel.read;

      case 'users':
        // Managed by admin in user management only
        return false;

      default:
        return false;
    }
  }

  @override
  bool canAccessComponent(String component) {
    return canPerform(PermissionLevel.read, component);
  }
}

/// Delivery Driver permissions
class DeliveryDriverPermission implements RolePermission {
  @override
  UserRole get role => UserRole.deliveryDriver;

  @override
  bool canPerform(PermissionLevel level, String component) {
    switch (component) {
      case 'delivery':
        // Delivery dashboard management only
        return level == PermissionLevel.read || level == PermissionLevel.update;

      case 'orders':
        // Read only - view assigned order details
        return level == PermissionLevel.read;

      case 'restaurants':
      case 'menu':
      case 'inventory':
      case 'payments':
        // Read only
        return level == PermissionLevel.read;

      case 'ratings':
        // Managed by admin in user management only
        return false;

      case 'location':
        // Create & Update (real-time location)
        return level == PermissionLevel.create ||
            level == PermissionLevel.update;

      default:
        return false;
    }
  }

  @override
  bool canAccessComponent(String component) {
    return canPerform(PermissionLevel.read, component);
  }
}

/// Admin permissions
class AdminPermission implements RolePermission {
  @override
  UserRole get role => UserRole.admin;

  @override
  bool canPerform(PermissionLevel level, String component) {
    // Admin has full access to everything
    return true;
  }

  @override
  bool canAccessComponent(String component) {
    // Admin can access all components
    return true;
  }
}

/// Permission checker utility
class PermissionManager {
  static RolePermission getPermissions(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return CustomerPermission();
      case UserRole.storeOwner:
        return RestaurantPermission();
      case UserRole.deliveryDriver:
        return DeliveryDriverPermission();
      case UserRole.admin:
        return AdminPermission();
    }
  }

  /// Check if user can perform an action
  static bool canPerform(
    UserRole role,
    PermissionLevel level,
    String component,
  ) {
    final permission = getPermissions(role);
    return permission.canPerform(level, component);
  }

  /// Check if user can access a component
  static bool canAccess(UserRole role, String component) {
    final permission = getPermissions(role);
    return permission.canAccessComponent(component);
  }

  /// Check multiple permissions
  static bool canPerformMultiple(
    UserRole role,
    String component,
    List<PermissionLevel> levels,
  ) {
    final permission = getPermissions(role);
    return levels.every((level) => permission.canPerform(level, component));
  }
}

/// UI Helper - Show/Hide buttons based on permissions
class PermissionBuilder extends StatelessWidget {
  final UserRole userRole;
  final String component;
  final PermissionLevel level;
  final Widget child;
  final Widget? onDenied;

  const PermissionBuilder({
    required this.userRole,
    required this.component,
    required this.level,
    required this.child,
    this.onDenied,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasPermission = PermissionManager.canPerform(
      userRole,
      level,
      component,
    );

    if (hasPermission) {
      return child;
    }

    return onDenied ?? const SizedBox.shrink();
  }
}

/// UI Helper - Show toast/dialog for permission denied
class PermissionHelper {
  static void showPermissionDenied(BuildContext context, {String? message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ?? 'You do not have permission to perform this action',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  static void showAccessDenied(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text(
          'You do not have permission to access this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Guard for widget building
  static bool guardAccess(
    BuildContext context,
    UserRole role,
    String component, {
    bool showError = true,
  }) {
    if (!PermissionManager.canAccess(role, component)) {
      if (showError) {
        showAccessDenied(context);
      }
      return false;
    }
    return true;
  }

  /// Guard for operations
  static bool guardOperation(
    BuildContext context,
    UserRole role,
    String component,
    PermissionLevel level, {
    bool showError = true,
  }) {
    if (!PermissionManager.canPerform(role, level, component)) {
      if (showError) {
        showPermissionDenied(context);
      }
      return false;
    }
    return true;
  }
}

/// Extension for easier permission checks in widgets
extension PermissionExtension on UserRole {
  RolePermission get permission => PermissionManager.getPermissions(this);

  bool canCreate(String component) =>
      PermissionManager.canPerform(this, PermissionLevel.create, component);

  bool canRead(String component) =>
      PermissionManager.canPerform(this, PermissionLevel.read, component);

  bool canUpdate(String component) =>
      PermissionManager.canPerform(this, PermissionLevel.update, component);

  bool canDelete(String component) =>
      PermissionManager.canPerform(this, PermissionLevel.delete, component);

  bool canAccess(String component) =>
      PermissionManager.canAccess(this, component);
}

/// Component permissions constants
class ComponentPermissions {
  static const String orders = 'orders';
  static const String carts = 'carts';
  static const String payments = 'payments';
  static const String restaurants = 'restaurants';
  static const String menu = 'menu';
  static const String inventory = 'inventory';
  static const String delivery = 'delivery';
  static const String ratings = 'ratings';
  static const String users = 'users';
  static const String location = 'location';
  static const String userProfile = 'user_profile';
}
