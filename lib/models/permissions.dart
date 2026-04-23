/// Role-Based Access Control (RBAC) - Permission definitions for the food delivery app
/// 
/// This file defines all permissions and operations available for each user role:
/// - CUSTOMER: Orders, carts, payments, ratings, feedback
/// - ADMIN: User management, delivery management, system-wide view
/// - STORE_OWNER: Restaurant management, menu, inventory
/// - DELIVERY_DRIVER: Delivery tracking and updates

import '../models.dart';

/// Enum for all available operations in the system
enum OperationType {
  // Basic CRUD
  create,
  read,
  update,
  delete,

  // Special operations
  approve,
  reject,
  cancel,
  submit,
  manage,
}

/// Enum for dashboard components/modules
enum DashboardModule {
  ordersAndCarts,
  customerDashboard,
  paymentAndIntegrations,
  userManagement,
  restaurantManagement,
  menuManagement,
  inventoryManagement,
  deliveryManagement,
  adminDashboard,
  ratingAndFeedback,
}

/// Defines what operations are allowed on each module for each role
class ModulePermission {
  final DashboardModule module;
  final UserRole role;
  final Set<OperationType> allowedOperations;
  final bool isFullAccess;

  ModulePermission({
    required this.module,
    required this.role,
    this.allowedOperations = const {},
    this.isFullAccess = false,
  });

  bool canPerform(OperationType operation) {
    if (isFullAccess) return true;
    return allowedOperations.contains(operation);
  }

  bool get canCreate => canPerform(OperationType.create);
  bool get canRead => canPerform(OperationType.read);
  bool get canUpdate => canPerform(OperationType.update);
  bool get canDelete => canPerform(OperationType.delete);
  bool get canApprove => canPerform(OperationType.approve);
  bool get canReject => canPerform(OperationType.reject);
  bool get canCancel => canPerform(OperationType.cancel);
  bool get canManage => canPerform(OperationType.manage);
}

/// Permission matrix for the entire application
class PermissionMatrix {
  static final Map<UserRole, Map<DashboardModule, ModulePermission>>
      _permissionMatrix = {
    // ===== CUSTOMER ROLE =====
    UserRole.customer: {
      DashboardModule.ordersAndCarts: ModulePermission(
        module: DashboardModule.ordersAndCarts,
        role: UserRole.customer,
        isFullAccess: true, // Full CRUD: Create, Read, Update, Delete
      ),
      DashboardModule.customerDashboard: ModulePermission(
        module: DashboardModule.customerDashboard,
        role: UserRole.customer,
        isFullAccess: true,
      ),
      DashboardModule.paymentAndIntegrations: ModulePermission(
        module: DashboardModule.paymentAndIntegrations,
        role: UserRole.customer,
        allowedOperations: {OperationType.create, OperationType.read},
        // Create & View only for payment processing
      ),
      DashboardModule.ratingAndFeedback: ModulePermission(
        module: DashboardModule.ratingAndFeedback,
        role: UserRole.customer,
        allowedOperations: {},
        // Rating/feedback CRUD is managed by admin in user management
      ),
      DashboardModule.restaurantManagement: ModulePermission(
        module: DashboardModule.restaurantManagement,
        role: UserRole.customer,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.menuManagement: ModulePermission(
        module: DashboardModule.menuManagement,
        role: UserRole.customer,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.inventoryManagement: ModulePermission(
        module: DashboardModule.inventoryManagement,
        role: UserRole.customer,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.deliveryManagement: ModulePermission(
        module: DashboardModule.deliveryManagement,
        role: UserRole.customer,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.userManagement: ModulePermission(
        module: DashboardModule.userManagement,
        role: UserRole.customer,
        allowedOperations: {},
      ),
      DashboardModule.adminDashboard: ModulePermission(
        module: DashboardModule.adminDashboard,
        role: UserRole.customer,
        allowedOperations: {},
        // No access
      ),
    },

    // ===== STORE_OWNER ROLE =====
    UserRole.storeOwner: {
      DashboardModule.ordersAndCarts: ModulePermission(
        module: DashboardModule.ordersAndCarts,
        role: UserRole.storeOwner,
        isFullAccess: true,
        // Full CRUD for restaurant owner orders/carts management
      ),
      DashboardModule.restaurantManagement: ModulePermission(
        module: DashboardModule.restaurantManagement,
        role: UserRole.storeOwner,
        isFullAccess: true,
        // Full CRUD: Create, Read, Update, Delete restaurant info
      ),
      DashboardModule.menuManagement: ModulePermission(
        module: DashboardModule.menuManagement,
        role: UserRole.storeOwner,
        isFullAccess: true,
        // Full CRUD: Manage menu items
      ),
      DashboardModule.inventoryManagement: ModulePermission(
        module: DashboardModule.inventoryManagement,
        role: UserRole.storeOwner,
        isFullAccess: true,
        // Full CRUD: Manage inventory/stock
      ),
      DashboardModule.paymentAndIntegrations: ModulePermission(
        module: DashboardModule.paymentAndIntegrations,
        role: UserRole.storeOwner,
        allowedOperations: {OperationType.read},
        // View only for payment info
      ),
      DashboardModule.deliveryManagement: ModulePermission(
        module: DashboardModule.deliveryManagement,
        role: UserRole.storeOwner,
        allowedOperations: {OperationType.read},
        // View only for delivery tracking
      ),
      DashboardModule.customerDashboard: ModulePermission(
        module: DashboardModule.customerDashboard,
        role: UserRole.storeOwner,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.userManagement: ModulePermission(
        module: DashboardModule.userManagement,
        role: UserRole.storeOwner,
        allowedOperations: {},
      ),
      DashboardModule.ratingAndFeedback: ModulePermission(
        module: DashboardModule.ratingAndFeedback,
        role: UserRole.storeOwner,
        allowedOperations: {OperationType.read},
        // View customer ratings/feedback for their restaurant
      ),
      DashboardModule.adminDashboard: ModulePermission(
        module: DashboardModule.adminDashboard,
        role: UserRole.storeOwner,
        allowedOperations: {},
        // No access
      ),
    },

    // ===== ADMIN ROLE =====
    UserRole.admin: {
      DashboardModule.userManagement: ModulePermission(
        module: DashboardModule.userManagement,
        role: UserRole.admin,
        isFullAccess: true,
        // Manage users, ratings, feedback
      ),
      DashboardModule.deliveryManagement: ModulePermission(
        module: DashboardModule.deliveryManagement,
        role: UserRole.admin,
        allowedOperations: {
          OperationType.read,
          OperationType.update,
          OperationType.manage,
        },
        // Delivery management access for admin dashboard
      ),
      DashboardModule.adminDashboard: ModulePermission(
        module: DashboardModule.adminDashboard,
        role: UserRole.admin,
        isFullAccess: true,
        // Full access to admin panel
      ),
      // View-only access to other modules (the "six components")
      DashboardModule.ordersAndCarts: ModulePermission(
        module: DashboardModule.ordersAndCarts,
        role: UserRole.admin,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.customerDashboard: ModulePermission(
        module: DashboardModule.customerDashboard,
        role: UserRole.admin,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.restaurantManagement: ModulePermission(
        module: DashboardModule.restaurantManagement,
        role: UserRole.admin,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.menuManagement: ModulePermission(
        module: DashboardModule.menuManagement,
        role: UserRole.admin,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.inventoryManagement: ModulePermission(
        module: DashboardModule.inventoryManagement,
        role: UserRole.admin,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.paymentAndIntegrations: ModulePermission(
        module: DashboardModule.paymentAndIntegrations,
        role: UserRole.admin,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.ratingAndFeedback: ModulePermission(
        module: DashboardModule.ratingAndFeedback,
        role: UserRole.admin,
        allowedOperations: {
          OperationType.create,
          OperationType.read,
          OperationType.update,
          OperationType.delete,
          OperationType.manage,
        },
      ),
    },

    // ===== DELIVERY_DRIVER ROLE =====
    UserRole.deliveryDriver: {
      DashboardModule.deliveryManagement: ModulePermission(
        module: DashboardModule.deliveryManagement,
        role: UserRole.deliveryDriver,
        allowedOperations: {
          OperationType.read,
          OperationType.update,
          OperationType.manage,
        },
        // Delivery dashboard management access for driver
      ),
      DashboardModule.ordersAndCarts: ModulePermission(
        module: DashboardModule.ordersAndCarts,
        role: UserRole.deliveryDriver,
        allowedOperations: {OperationType.read},
        // View only for order details
      ),
      DashboardModule.customerDashboard: ModulePermission(
        module: DashboardModule.customerDashboard,
        role: UserRole.deliveryDriver,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.restaurantManagement: ModulePermission(
        module: DashboardModule.restaurantManagement,
        role: UserRole.deliveryDriver,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.menuManagement: ModulePermission(
        module: DashboardModule.menuManagement,
        role: UserRole.deliveryDriver,
        allowedOperations: {OperationType.read},
      ),
      DashboardModule.inventoryManagement: ModulePermission(
        module: DashboardModule.inventoryManagement,
        role: UserRole.deliveryDriver,
        allowedOperations: {},
      ),
      DashboardModule.paymentAndIntegrations: ModulePermission(
        module: DashboardModule.paymentAndIntegrations,
        role: UserRole.deliveryDriver,
        allowedOperations: {},
      ),
      DashboardModule.userManagement: ModulePermission(
        module: DashboardModule.userManagement,
        role: UserRole.deliveryDriver,
        allowedOperations: {},
      ),
      DashboardModule.adminDashboard: ModulePermission(
        module: DashboardModule.adminDashboard,
        role: UserRole.deliveryDriver,
        allowedOperations: {},
      ),
      DashboardModule.ratingAndFeedback: ModulePermission(
        module: DashboardModule.ratingAndFeedback,
        role: UserRole.deliveryDriver,
        allowedOperations: {OperationType.read},
      ),
    },
  };

  /// Get permission for a specific role and module
  static ModulePermission? getPermission(
    UserRole role,
    DashboardModule module,
  ) {
    return _permissionMatrix[role]?[module];
  }

  /// Check if a role can perform an operation on a module
  static bool canPerform(
    UserRole role,
    DashboardModule module,
    OperationType operation,
  ) {
    final permission = getPermission(role, module);
    if (permission == null) return false;
    return permission.canPerform(operation);
  }

  /// Get all accessible modules for a role
  static List<DashboardModule> getAccessibleModules(UserRole role) {
    final permissions = _permissionMatrix[role];
    if (permissions == null) return [];

    return permissions.entries
        .where((e) => e.value.allowedOperations.isNotEmpty ||
            e.value.isFullAccess)
        .map((e) => e.key)
        .toList();
  }

  /// Get all modules with full access for a role
  static List<DashboardModule> getFullAccessModules(UserRole role) {
    final permissions = _permissionMatrix[role];
    if (permissions == null) return [];

    return permissions.entries
        .where((e) => e.value.isFullAccess)
        .map((e) => e.key)
        .toList();
  }
}

/// Helper class for permission checking in UI
class PermissionChecker {
  final UserRole userRole;

  PermissionChecker(this.userRole);

  bool canAccess(DashboardModule module) {
    final permission = PermissionMatrix.getPermission(userRole, module);
    return permission != null &&
        (permission.isFullAccess || permission.allowedOperations.isNotEmpty);
  }

  bool canCreate(DashboardModule module) {
    return PermissionMatrix.canPerform(
      userRole,
      module,
      OperationType.create,
    );
  }

  bool canRead(DashboardModule module) {
    return PermissionMatrix.canPerform(
      userRole,
      module,
      OperationType.read,
    );
  }

  bool canUpdate(DashboardModule module) {
    return PermissionMatrix.canPerform(
      userRole,
      module,
      OperationType.update,
    );
  }

  bool canDelete(DashboardModule module) {
    return PermissionMatrix.canPerform(
      userRole,
      module,
      OperationType.delete,
    );
  }

  bool canManage(DashboardModule module) {
    return PermissionMatrix.canPerform(
      userRole,
      module,
      OperationType.manage,
    );
  }

  bool hasFullCrud(DashboardModule module) {
    return canCreate(module) &&
        canRead(module) &&
        canUpdate(module) &&
        canDelete(module);
  }

  List<DashboardModule> getAccessibleModules() {
    return PermissionMatrix.getAccessibleModules(userRole);
  }

  List<DashboardModule> getFullAccessModules() {
    return PermissionMatrix.getFullAccessModules(userRole);
  }
}
