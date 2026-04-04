import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/validators.dart';

class AuthScreen extends StatefulWidget {
  final Function(User) onUserAuthenticated;

  const AuthScreen({super.key, required this.onUserAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  late AnimationController _animController;

  bool _isSignIn = true;
  bool _loading = false;
  String? _error;
  UserRole _signupAccountRole = UserRole.customer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final mobile = _mobileController.text.trim();
    final address = _addressController.text.trim();

    if (!_isSignIn) {
      final nameError = Validators.validateName(name);
      if (nameError != null) {
        _setError(nameError);
        return;
      }
    }

    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      _setError(emailError);
      return;
    }

    if (password.isEmpty) {
      _setError('Please enter your password');
      return;
    }

    if (!_isSignIn) {
      final mobileError = Validators.validateMobileNumber(
        mobile.isEmpty ? null : mobile,
      );
      if (mobileError != null) {
        _setError(mobileError);
        return;
      }

      final addressError = Validators.validateAddress(
        address.isEmpty ? null : address,
      );
      if (addressError != null) {
        _setError(addressError);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final user = _isSignIn
          ? await _api.signIn(email: email, password: password)
          : await _api.signUp(
              name: name,
              email: email,
              password: password,
              mobile: mobile.isEmpty ? null : mobile,
              address: address.isEmpty ? null : address,
              accountRole: _signupAccountRole,
            );
      if (!mounted) return;
      widget.onUserAuthenticated(user);
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _mobileController.clear();
      _addressController.clear();
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setError(String msg) {
    setState(() => _error = msg);
    if (mounted) {
      _animController.forward().then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _animController.reverse();
        });
      });
    }
  }

  void _toggleMode() {
    setState(() => _isSignIn = !_isSignIn);
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _mobileController.clear();
    _addressController.clear();
    setState(() => _error = null);
  }

  /// Short label when the account-type dropdown is closed (avoids horizontal overflow).
  Widget _accountTypeCollapsed(UserRole role) {
    return Text(
      role.displayLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const ink = Color(0xFF1F1F1F);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFF6F6F6),
              padding: const EdgeInsets.fromLTRB(24, 52, 24, 32),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Food Rush',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignIn
                        ? 'Sign in to order delivery'
                        : 'Create your account',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error message
                  if (_error != null)
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _animController,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red[200]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Name field (sign up only)
                  if (!_isSignIn) ...[
                    Text(
                      'Full Name',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      enabled: !_loading,
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  // Email field
                  Text(
                    'Email Address',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Password field
                  Text(
                    'Password',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    enabled: !_loading,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Account type',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSignIn
                        ? 'Used when you tap Sign Up — includes Administrator for a new admin account.'
                        : 'Your new account will be created with this role.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserRole>(
                    value: _signupAccountRole,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return [
                        _accountTypeCollapsed(UserRole.customer),
                        _accountTypeCollapsed(UserRole.storeOwner),
                        _accountTypeCollapsed(UserRole.deliveryDriver),
                        _accountTypeCollapsed(UserRole.admin),
                      ];
                    },
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.customer,
                        child: Text('Customer — order food'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.storeOwner,
                        child: Text('Restaurant owner — manage store & menu'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.deliveryDriver,
                        child: Text('Delivery driver — assigned runs & status'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('Administrator — full control & CRUD'),
                      ),
                    ],
                    onChanged: _loading
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(() => _signupAccountRole = v);
                            }
                          },
                  ),
                  if (!_isSignIn) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Mobile Number',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mobileController,
                      enabled: !_loading,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Enter your mobile (optional)',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Address',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressController,
                      enabled: !_loading,
                      decoration: InputDecoration(
                        hintText: 'Enter your address (optional)',
                        prefixIcon: const Icon(Icons.home_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                _isSignIn ? 'Sign In' : 'Create Account',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Toggle button
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _toggleMode,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _isSignIn
                                  ? 'Don\'t have an account? '
                                  : 'Already have an account? ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            TextSpan(
                              text: _isSignIn ? 'Sign Up' : 'Sign In',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
