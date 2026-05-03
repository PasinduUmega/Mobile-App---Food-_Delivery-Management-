import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/cart_manager.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'restaurant_dashboard.dart';
import 'user_profile_screen.dart';

/// Customer-only shell: browse, orders, profile (no admin or store tools).
class CustomerDashboard extends StatefulWidget {
  final User user;
  final Function()? onSignOut;
  final ValueChanged<bool>? onThemeChanged;
  final ValueChanged<User>? onUserProfileUpdated;

  const CustomerDashboard({
    super.key,
    required this.user,
    this.onSignOut,
    this.onThemeChanged,
    this.onUserProfileUpdated,
  });

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;
  late User _user;
  late final CartManager _cartManager;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _cartManager = CartManager(api: ApiClient());
  }

  @override
  void didUpdateWidget(CustomerDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.id != oldWidget.user.id ||
        widget.user.updatedAt != oldWidget.user.updatedAt) {
      _user = widget.user;
    }
  }

  void _onProfileUpdated(User u) {
    setState(() => _user = u);
    widget.onUserProfileUpdated?.call(u);
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserProfileScreen(
      user: _user,
      onSignOut: widget.onSignOut,
      onThemeChanged: widget.onThemeChanged,
      onUserUpdated: _onProfileUpdated,
    );
    final browse = RestaurantDashboard(
      user: _user,
      cartManager: _cartManager,
    );
    final cart = CartScreen(
      userId: _user.id,
      cartManager: _cartManager,
    );
    final orders = MyOrdersScreen(user: _user);

    final screens = [browse, cart, orders, profile];
    const destinations = [
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex.clamp(0, screens.length - 1),
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex.clamp(0, destinations.length - 1),
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        destinations: destinations,
      ),
    );
  }
}
