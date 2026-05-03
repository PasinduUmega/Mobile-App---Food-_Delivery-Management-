import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
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
    print('Application: AppShell initState started.');
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    print('Application: _checkAuthState() started.');
    // Check if there's a user logged in (could also check local storage)
    setState(() => _loading = true);
    // For now, we start unauthenticated
    setState(() => _loading = false);
    print('Application: _checkAuthState() finished. Loading: false, CurrentUser: $_currentUser');
  }

  Future<void> _onSignIn(User user) async {
    ApiClient.sessionUserId = user.id;
    setState(() => _currentUser = user);
    // Defer snackbar: subtree swaps (Auth -> Home) in the same frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppFeedback.success(context, 'Welcome back, ${user.name}!');
    });
  }

  Future<void> _onSignOut() async {
    setState(() => _currentUser = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppFeedback.success(context, 'You’re signed out. See you soon!');
    });
  }

  @override
  Widget build(BuildContext context) {
    print('Application: AppShell building... loading=$_loading, user=$_currentUser');
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delivery_dining_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading menus & offers…',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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
    return HomeDashboard(
      user: _currentUser!,
      onSignOut: _onSignOut,
      onThemeChanged: widget.onThemeChanged,
      onUserProfileUpdated: (u) => setState(() => _currentUser = u),
    );
  }
}
