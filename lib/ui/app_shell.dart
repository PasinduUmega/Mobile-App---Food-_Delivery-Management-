import 'package:flutter/material.dart';

import '../models.dart';
import 'auth_screen.dart';
import 'home_dashboard.dart';
import 'widgets/app_feedback.dart';

/// Main app shell that manages authentication & navigation
class AppShell extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;

  const AppShell({super.key, this.onThemeChanged});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  User? _currentUser;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Check if there's a user logged in (could also check local storage)
    setState(() => _loading = true);
    // For now, we start unauthenticated
    setState(() => _loading = false);
  }

  Future<void> _onSignIn(User user) async {
    setState(() => _currentUser = user);
    if (mounted) {
      AppFeedback.success(context, 'Welcome back, ${user.name}!');
    }
  }

  Future<void> _onSignOut() async {
    setState(() => _currentUser = null);
    if (mounted) {
      AppFeedback.success(context, 'You’re signed out. See you soon!');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_dining,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Opening Food Rush…',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Show auth flow if not logged in
    if (_currentUser == null) {
      return AuthScreen(onUserAuthenticated: _onSignIn);
    }

    // Show main app if logged in
    return HomeScreen(
      user: _currentUser!,
      onSignOut: _onSignOut,
      onThemeChanged: widget.onThemeChanged,
    );
  }
}
