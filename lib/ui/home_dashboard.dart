import 'package:flutter/material.dart';

import '../models.dart';
import 'admin_dashboard.dart';
import 'restaurant_dashboard.dart';
import 'user_profile_screen.dart';

/// Main home dashboard - entry point after sign in
/// Shows bottom nav with Restaurant & Profile sections
class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    RestaurantDashboard(user: widget.user),
    const AdminDashboard(),
    UserProfileScreen(
      user: widget.user,
      onSignOut: widget.onSignOut,
      onThemeChanged: widget.onThemeChanged,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
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
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
