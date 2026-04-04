import 'package:flutter/material.dart';

import '../models.dart';
import 'admin_dashboard.dart';
import 'my_orders_screen.dart';
import 'restaurant_dashboard.dart';
import 'user_profile_screen.dart';

/// Admin-only shell: control suite, customer preview (browse/checkout), orders, account.
class AdminShellScreen extends StatefulWidget {
  final User user;
  final VoidCallback? onSignOut;
  final ValueChanged<bool>? onThemeChanged;

  const AdminShellScreen({
    super.key,
    required this.user,
    this.onSignOut,
    this.onThemeChanged,
  });

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.admin_panel_settings_outlined),
      selectedIcon: Icon(Icons.admin_panel_settings),
      label: 'Control',
    ),
    NavigationDestination(
      icon: Icon(Icons.restaurant_menu_outlined),
      selectedIcon: Icon(Icons.restaurant_menu),
      label: 'Browse',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Orders',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Account',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profile = UserProfileScreen(
      user: widget.user,
      onSignOut: widget.onSignOut,
      onThemeChanged: widget.onThemeChanged,
    );

    final screens = [
      const AdminDashboard(),
      RestaurantDashboard(user: widget.user),
      MyOrdersScreen(user: widget.user),
      profile,
    ];

    final safeIndex = _index.clamp(0, screens.length - 1);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        indicatorColor: cs.primaryContainer,
        destinations: _destinations,
      ),
    );
  }
}
