import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/validators.dart';

class UsersCrudScreen extends StatefulWidget {
  const UsersCrudScreen({super.key});

  @override
  State<UsersCrudScreen> createState() => _UsersCrudScreenState();
}

class _UsersCrudScreenState extends State<UsersCrudScreen> {
  final _api = ApiClient();
  bool _loading = false;
  String? _error;
  List<User> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listUsers();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await _showEditDialog();
    if (created == null) return;
    await _reload();
  }

  Future<void> _edit(User u) async {
    final ok = await _showEditDialog(existing: u);
    if (ok == null) return;
    await _reload();
  }

  Future<void> _delete(User u) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('${u.name} (${u.email})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deleteUser(id: u.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showEditDialog({User? existing}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _UserEditDialog(existing: existing, api: _api),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users (CRUD)'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _create,
        backgroundColor: const Color(0xFFFF6A00),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 34),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _items.isEmpty
          ? const Center(child: Text('No users yet. Tap + to create one.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final u = _items[i];
                return Card(
                  child: ListTile(
                    title: Text(u.name),
                    subtitle: Text('${u.email} · ${u.role.displayLabel}'),
                    onTap: () => _edit(u),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _edit(u);
                        if (v == 'delete') _delete(u);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _UserEditDialog extends StatefulWidget {
  final User? existing;
  final ApiClient api;

  const _UserEditDialog({this.existing, required this.api});

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _mobileCtrl;
  late UserRole _selectedRole;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _mobileCtrl = TextEditingController(text: u?.mobile ?? '');
    _selectedRole = u?.role ?? UserRole.customer;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text;
    final email = _emailCtrl.text;
    final mobile = _mobileCtrl.text.trim();

    // Validate name
    var error = Validators.validateName(name);
    if (error != null) {
      _showError(error);
      return;
    }

    // Validate email
    error = Validators.validateEmail(email);
    if (error != null) {
      _showError(error);
      return;
    }

    // Validate mobile number if provided
    error = Validators.validateMobileNumber(mobile.isEmpty ? null : mobile);
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await widget.api.createUser(
          name: name.trim(),
          email: email.trim(),
          mobile: mobile.isNotEmpty ? mobile : null,
        );
      } else {
        await widget.api.updateUser(
          id: widget.existing!.id,
          name: name.trim(),
          email: email.trim(),
          mobile: mobile,
          role: _selectedRole,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Create user' : 'Edit user'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Full name (min 2 chars)',
              errorText: _nameCtrl.text.isNotEmpty
                  ? Validators.validateName(_nameCtrl.text)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'user@example.com',
              errorText: _emailCtrl.text.isNotEmpty
                  ? Validators.validateEmail(_emailCtrl.text)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Mobile Number',
              hintText: 'Enter 10-digit number',
              errorText: _mobileCtrl.text.isNotEmpty
                  ? Validators.validateMobileNumber(_mobileCtrl.text)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
