import 'package:flutter/material.dart';

import '../models.dart';
import 'admin_shell_screen.dart';
import 'customer_dashboard.dart';
import 'driver_shell_screen.dart';
import 'store_owner_shell_screen.dart';

/// Entry after sign-in: role-specific home (customer, admin, store owner, driver).
class HomeDashboard extends StatelessWidget {
  final User user;
  final VoidCallback? onSignOut;
  final ValueChanged<bool>? onThemeChanged;

  const HomeDashboard({
    super.key,
    required this.user,
    this.onSignOut,
    this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (user.role) {
      case UserRole.admin:
        return AdminShellScreen(
          user: user,
          onSignOut: onSignOut,
          onThemeChanged: onThemeChanged,
        );
      case UserRole.customer:
        return CustomerDashboard(
          user: user,
          onSignOut: onSignOut,
          onThemeChanged: onThemeChanged,
        );
      case UserRole.storeOwner:
        return StoreOwnerShellScreen(
          user: user,
          onSignOut: onSignOut,
          onThemeChanged: onThemeChanged,
        );
      case UserRole.deliveryDriver:
        return DriverShellScreen(
          user: user,
          onSignOut: onSignOut,
          onThemeChanged: onThemeChanged,
        );
    }
  }
}
