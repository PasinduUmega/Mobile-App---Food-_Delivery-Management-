import 'package:flutter/material.dart';

import '../models.dart';
import 'customer_dashboard.dart';

/// Entry point after sign-in: full customer dashboard (browse, orders, profile, admin).
class HomeScreen extends StatelessWidget {
  final User user;
  final Function()? onSignOut;
  final ValueChanged<bool>? onThemeChanged;

  const HomeScreen({
    super.key,
    required this.user,
    this.onSignOut,
    this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomerDashboard(
      user: user,
      onSignOut: onSignOut,
      onThemeChanged: onThemeChanged,
    );
  }
}
