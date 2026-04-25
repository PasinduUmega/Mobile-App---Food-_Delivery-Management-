import 'package:flutter/material.dart';

import '../models.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'restaurant_dashboard.dart';
import 'user_profile_screen.dart';

/// Customer-only shell: browse, orders, profile (no admin or store tools).
class CustomerDashboard extends StatefulWidget {
  final User user;
  final Function()? onSignOut;
  final ValueChanged<bool>? onThemeChanged;

  const CustomerDashboard({
    super.key,
    required this.user,
    this.onSignOut,
    this.onThemeChanged,
  });

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;
  late final List<NavigationDestination> _destinations;

  @override
  void initState() {
    super.initState();
    final profile = UserProfileScreen(
      user: widget.user,
      onSignOut: widget.onSignOut,
      onThemeChanged: widget.onThemeChanged,
    );
    final browse = RestaurantDashboard(user: widget.user);
    final cart = CartScreen(userId: widget.user.id);
    final orders = MyOrdersScreen(user: widget.user);

    _screens = [browse, cart, orders, profile];
    _destinations = const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.shopping_cart_outlined),
        selectedIcon: Icon(Icons.shopping_cart),
        label: 'Cart',
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex.clamp(0, _screens.length - 1),
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex.clamp(0, _destinations.length - 1),
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        destinations: _destinations,
      ),
    );
  }
}
