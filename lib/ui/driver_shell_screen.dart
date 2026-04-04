import 'package:flutter/material.dart';

import '../models.dart';
import 'driver_deliveries_screen.dart';
import 'restaurant_dashboard.dart';
import 'user_profile_screen.dart';

/// Delivery driver: browse restaurants, deliveries, and profile (location & details).
class DriverShellScreen extends StatefulWidget {
  final User user;
  final Function()? onSignOut;
  final ValueChanged<bool>? onThemeChanged;

  const DriverShellScreen({
    super.key,
    required this.user,
    this.onSignOut,
    this.onThemeChanged,
  });

  @override
  State<DriverShellScreen> createState() => _DriverShellScreenState();
}

class _DriverShellScreenState extends State<DriverShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profile = UserProfileScreen(
      user: widget.user,
      onSignOut: widget.onSignOut,
      onThemeChanged: widget.onThemeChanged,
    );
    final browse = RestaurantDashboard(user: widget.user);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          browse,
          DriverDeliveriesScreen(user: widget.user),
          profile,
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        indicatorColor: cs.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining),
            label: 'Deliveries',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
