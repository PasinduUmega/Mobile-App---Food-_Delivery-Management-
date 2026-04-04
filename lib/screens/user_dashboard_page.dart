import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_api.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  final _api = UserApi();
  final _refreshInterval = const Duration(seconds: 30); // Increased from 5s to 30s

  final List<User> _users = [];
  int _totalUsers = 0;
  final int _pageSize = 20;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _autoRefresh = false;
  String? _errorMessage;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers({bool refresh = true}) async {
    if (!mounted) return;
    if (!refresh && _users.length >= _totalUsers) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _errorMessage = null;
    });

    try {
      final offset = refresh ? 0 : _users.length;
      final result = await _api.fetchUsers(limit: _pageSize, offset: offset);
      
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _users.clear();
        }
        _users.addAll(result.users);
        _totalUsers = result.total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _setAutoRefresh(bool value) {
    setState(() {
      _autoRefresh = value;
    });

    _timer?.cancel();
    _timer = null;

    if (!value) return;

    _timer = Timer.periodic(_refreshInterval, (_) => _loadUsers());
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => UserFormPage(
          api: _api,
          mode: const UserFormMode.create(),
        ),
      ),
    );
    if (created == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member added successfully!')),
        );
      }
      await _loadUsers();
    }
  }

  Future<void> _openEditForm(User user) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => UserFormPage(
          api: _api,
          mode: UserFormMode.edit(user: user),
        ),
      ),
    );
    if (updated == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member updated successfully!')),
        );
      }
      await _loadUsers();
    }
  }

  Future<void> _confirmDelete(User user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await _api.deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member deleted successfully!')),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('User Dashboard'),
            actions: [
              IconButton(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (!_isLoading && _errorMessage == null && _users.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total',
                        value: _users.length.toString(),
                        icon: Icons.people_outline_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Verified',
                        value: _users.where((u) => u.isVerified).length.toString(),
                        icon: Icons.verified_user_outlined,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Pending',
                        value: _users.where((u) => !u.isVerified).length.toString(),
                        icon: Icons.hourglass_empty_rounded,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_users.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_off_rounded, size: 64, color: colorScheme.onSurface.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text('No users found', style: TextStyle(fontSize: 18, color: colorScheme.onSurface.withOpacity(0.7))),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = _users[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openEditForm(user),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'user-avatar-${user.id}',
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: colorScheme.primaryContainer,
                                    child: Text(
                                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (user.isVerified)
                                            const Icon(Icons.verified, size: 18, color: Colors.blue),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                      Text(
                                        user.mobile,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _confirmDelete(user),
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _users.length,
                ),
              ),
            ),
          if (_users.isNotEmpty && _users.length < _totalUsers)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Center(
                  child: _isLoadingMore
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: () => _loadUsers(refresh: false),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text('Load More (${_totalUsers - _users.length} remaining)'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 48),
                            backgroundColor: colorScheme.surfaceVariant,
                            foregroundColor: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        label: const Text('Add Member'),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }
}


sealed class UserFormMode {
  const UserFormMode();

  const factory UserFormMode.create() = _UserCreateMode;
  const factory UserFormMode.edit({required User user}) = _UserEditMode;
}

class _UserCreateMode extends UserFormMode {
  const _UserCreateMode();
}

class _UserEditMode extends UserFormMode {
  final User user;
  const _UserEditMode({required this.user});
}

class UserFormPage extends StatefulWidget {
  final UserApi api;
  final UserFormMode mode;

  const UserFormPage({
    super.key,
    required this.api,
    required this.mode,
  });

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isVerified = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _submitError;

  bool get _isEdit => widget.mode is _UserEditMode;

  User? get _editUser => widget.mode is _UserEditMode ? (widget.mode as _UserEditMode).user : null;

  @override
  void initState() {
    super.initState();
    final editUser = _editUser;
    if (editUser != null) {
      _nameController.text = editUser.name;
      _emailController.text = editUser.email;
      _mobileController.text = editUser.mobile;
      _addressController.text = editUser.address;
      _isVerified = editUser.isVerified;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final editUser = _editUser;
    final password = _passwordController.text.trim();

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      if (editUser == null) {
        await widget.api.createUser(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          mobile: _mobileController.text.trim(),
          address: _addressController.text.trim(),
          password: password,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        await widget.api.updateUser(
          id: editUser.id,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          mobile: _mobileController.text.trim(),
          address: _addressController.text.trim(),
          isVerified: _isVerified,
          password: password.isNotEmpty ? password : null,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _isEdit;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Update Details' : 'New Member'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isEdit && _editUser != null) ...[
                  Center(
                    child: Hero(
                      tag: 'user-avatar-${_editUser!.id}',
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          _editUser!.name.isNotEmpty ? _editUser!.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _editUser!.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ] else if (!isEdit) ...[
                  Text(
                    'Create Account',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill in the details below to add a new member.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_android_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Mobile is required';
                    if (v.trim().length < 10) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Residential Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                ),
                const SizedBox(height: 16),
                if (isEdit) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text('Account Verified'),
                      secondary: const Icon(Icons.verified_user_outlined),
                      value: _isVerified,
                      onChanged: (v) => setState(() => _isVerified = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'Change Password' : 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    helperText: isEdit ? 'Leave blank to keep current password' : 'At least 6 characters recommended',
                    helperStyle: const TextStyle(fontSize: 11),
                  ),
                  obscureText: _obscurePassword,
                  validator: (v) {
                    if (!isEdit) {
                      if (v == null || v.trim().isEmpty) return 'Password is required';
                      if (v.trim().length < 6) return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                if (_submitError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _submitError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : Text(isEdit ? 'Update Member' : 'Create Member'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
