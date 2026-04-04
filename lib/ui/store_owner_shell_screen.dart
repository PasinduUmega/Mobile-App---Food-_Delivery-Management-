import 'package:flutter/material.dart';

import '../models.dart';
import 'order_management_dashboard.dart';
import 'store_owner_hub_screen.dart';
import 'user_profile_screen.dart';

/// Restaurant owner: **no customer Browse tab** — workspace, incoming orders, account.
class StoreOwnerShellScreen extends StatefulWidget {
  final User user;
  final Function()? onSignOut;
  final ValueChanged<bool>? onThemeChanged;

  const StoreOwnerShellScreen({
    super.key,
    required this.user,
    this.onSignOut,
    this.onThemeChanged,
  });

  @override
  State<StoreOwnerShellScreen> createState() => _StoreOwnerShellScreenState();
}

class _StoreOwnerShellScreenState extends State<StoreOwnerShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final profile = UserProfileScreen(
      user: widget.user,
      onSignOut: widget.onSignOut,
      onThemeChanged: widget.onThemeChanged,
    );
    final hub = StoreOwnerHubScreen(user: widget.user);
    final orders = OrderManagementDashboard(ownerUserId: widget.user.id);

    final screens = [hub, orders, profile];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex.clamp(0, screens.length - 1),
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex.clamp(0, 2),
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Store',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'Orders',
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
