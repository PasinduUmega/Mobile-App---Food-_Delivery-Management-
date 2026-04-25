import 'package:flutter/material.dart';

import '../models.dart';
import 'admin_dashboard.dart';
import 'customer_ops_readonly_screen.dart';
import 'user_profile_screen.dart';

/// Admin-only shell: control suite, view-only operations, and account.
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
      icon: Icon(Icons.visibility_outlined),
      selectedIcon: Icon(Icons.visibility),
      label: 'View Only',
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
      CustomerOpsReadOnlyScreen(user: widget.user),
      profile,
    ];

    final safeIndex = _index.clamp(0, screens.length - 1);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: safeIndex,
            children: screens,
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
                  'ADMIN',
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
