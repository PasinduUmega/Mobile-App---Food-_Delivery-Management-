import 'package:flutter/material.dart';

import '../models.dart';
import 'customer_ops_readonly_screen.dart';
import 'driver_deliveries_screen.dart';
import 'user_profile_screen.dart';

/// Delivery role: browse restaurants, manage deliveries (CRUD), and profile.
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
    final readOnlyOps = CustomerOpsReadOnlyScreen(user: widget.user);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              readOnlyOps,
              DriverDeliveriesScreen(user: widget.user, readOnly: false),
              profile,
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.only(top: 8, right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'DRIVER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
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
            icon: Icon(Icons.visibility_outlined),
            selectedIcon: Icon(Icons.visibility),
            label: 'View Only',
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
