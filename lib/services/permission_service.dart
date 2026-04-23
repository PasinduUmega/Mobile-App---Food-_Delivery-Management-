/// Permission Service - Runtime permission checking and enforcement
///
/// This service provides methods to check user permissions throughout the app
/// and is used by screens to conditionally show/hide UI elements

import 'package:flutter/material.dart';
import '../models.dart';
import '../models/permissions.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();

  late PermissionChecker _currentPermissions;
  UserRole? _currentUserRole;

  PermissionService._internal();

  factory PermissionService() {
    return _instance;
  }

  /// Initialize permissions for current user
  void initialize(UserRole userRole) {
    _currentUserRole = userRole;
    _currentPermissions = PermissionChecker(userRole);
  }

  /// Get current user role
  UserRole? get currentUserRole => _currentUserRole;

  /// Get permission checker for current user
  PermissionChecker get checker => _currentPermissions;

  /// Check if current user can access a module
  bool canAccess(DashboardModule module) {
    return _currentPermissions.canAccess(module);
  }

  /// Check if current user can perform CRUD operations
  bool canCreate(DashboardModule module) =>
      _currentPermissions.canCreate(module);

  bool canRead(DashboardModule module) => _currentPermissions.canRead(module);

  bool canUpdate(DashboardModule module) =>
      _currentPermissions.canUpdate(module);

  bool canDelete(DashboardModule module) =>
      _currentPermissions.canDelete(module);

  /// Check if current user has full CRUD
  bool hasFullCrud(DashboardModule module) =>
      _currentPermissions.hasFullCrud(module);

  /// Check if user can manage a module
  bool canManage(DashboardModule module) =>
      _currentPermissions.canManage(module);

  /// Get all accessible modules for current user
  List<DashboardModule> getAccessibleModules() =>
      _currentPermissions.getAccessibleModules();

  /// Get all modules with full access
  List<DashboardModule> getFullAccessModules() =>
      _currentPermissions.getFullAccessModules();

  /// Verify permission and throw exception if denied
  void verifyPermission(DashboardModule module, OperationType operation) {
    if (!PermissionMatrix.canPerform(
      _currentUserRole ?? UserRole.customer,
      module,
      operation,
    )) {
      throw PermissionDeniedException(
        message:
            'Permission denied: ${_currentUserRole?.displayLabel} cannot $operation on ${module.name}',
        role: _currentUserRole ?? UserRole.customer,
        module: module,
        operation: operation,
      );
    }
  }

  /// Get permission description for UI display
  String getPermissionDescription(DashboardModule module) {
    final perm = PermissionMatrix.getPermission(_currentUserRole!, module);
    if (perm == null) return 'No access';

    if (perm.isFullAccess) {
      return 'Full access (Create, Read, Update, Delete)';
    }

    final ops = <String>[];
    if (perm.canCreate) ops.add('Create');
    if (perm.canRead) ops.add('Read');
    if (perm.canUpdate) ops.add('Update');
    if (perm.canDelete) ops.add('Delete');
    if (perm.canManage) ops.add('Manage');

    return ops.isEmpty ? 'No access' : ops.join(', ');
  }
}

/// Custom exception for permission violations
class PermissionDeniedException implements Exception {
  final String message;
  final UserRole role;
  final DashboardModule module;
  final OperationType operation;

  PermissionDeniedException({
    required this.message,
    required this.role,
    required this.module,
    required this.operation,
  });

  @override
  String toString() => message;
}

/// Extension for easier permission checking in widgets
extension PermissionExtension on BuildContext {
  PermissionService get permissions => PermissionService();

  bool canAccess(DashboardModule module) =>
      PermissionService().canAccess(module);

  bool canCreate(DashboardModule module) =>
      PermissionService().canCreate(module);

  bool canRead(DashboardModule module) => PermissionService().canRead(module);

  bool canUpdate(DashboardModule module) =>
      PermissionService().canUpdate(module);

  bool canDelete(DashboardModule module) =>
      PermissionService().canDelete(module);

  bool hasFullCrud(DashboardModule module) =>
      PermissionService().hasFullCrud(module);
}

/// Widget helpers for conditional rendering based on permissions

/// Show widget only if user has permission
class PermissionGate extends StatelessWidget {
  final DashboardModule module;
  final OperationType operation;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    required this.module,
    required this.operation,
    required this.child,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasPermission = PermissionMatrix.canPerform(
      PermissionService().currentUserRole ?? UserRole.customer,
      module,
      operation,
    );

    return hasPermission ? child : (fallback ?? const SizedBox.shrink());
  }
}

/// Show action button only if user has permission
class PermissionButton extends StatelessWidget {
  final DashboardModule module;
  final OperationType operation;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final ButtonStyle? style;

  const PermissionButton({
    required this.module,
    required this.operation,
    this.onPressed,
    required this.label,
    this.icon,
    this.style,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasPermission = PermissionService().hasFullCrud(module);

    return ElevatedButton.icon(
      onPressed: hasPermission ? onPressed : null,
      icon: Icon(icon ?? Icons.check),
      label: Text(label),
      style: style,
    );
  }
}

/// Show text only if user has permission
class PermissionText extends StatelessWidget {
  final DashboardModule module;
  final OperationType operation;
  final String text;
  final TextStyle? style;
  final String? denialText;

  const PermissionText({
    required this.module,
    required this.operation,
    required this.text,
    this.style,
    this.denialText = 'No access',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasPermission = PermissionMatrix.canPerform(
      PermissionService().currentUserRole ?? UserRole.customer,
      module,
      operation,
    );

    return Text(hasPermission ? text : denialText ?? 'No access', style: style);
  }
}
