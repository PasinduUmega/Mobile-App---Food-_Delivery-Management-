import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';

class UserManagementDashboard extends StatefulWidget {
  const UserManagementDashboard({super.key});

  @override
  State<UserManagementDashboard> createState() =>
      _UserManagementDashboardState();
}

class _UserManagementDashboardState extends State<UserManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  String? _error;
  List<User> _items = const [];
  String _searchQuery = '';

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
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
        title: const Text('Remove access?'),
        content: Text('Are you sure you want to remove ${u.name}?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deleteUser(id: u.id);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showEditDialog({User? existing}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserEditDialog(existing: existing, api: _api),
    );
  }

  List<User> _getFilteredUsers() {
    if (_searchQuery.isEmpty) return _items;
    final query = _searchQuery.toLowerCase();
    return _items
        .where(
          (u) =>
              u.name.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity & Access'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: const Color(0xFFFF6A00),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invite User'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Top Statistics Grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard('Total Members', _items.length.toString(), Icons.people, const Color(0xFFFF6A00))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Admin Privileges', '3', Icons.shield_outlined, const Color(0xFF11A36A))),
                      ],
                    ),
                  ),
                ),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search members by name or email...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(top: 24)),

                // Feature Status Table
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: Text('ACCESS CONTROLS Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
                      child: Column(
                        children: [
                          _buildStatusRow('Role-Based Auth', 'Completed', true),
                          _buildStatusRow('Profile Updates', 'Completed', true),
                          _buildStatusRow('Account Lock/Unlock', 'Completed', true),
                          _buildStatusRow('Activity Logs', 'In Progress', false),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(top: 24)),

                // Member List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: filteredUsers.isEmpty
                      ? SliverFillRemaining(child: Center(child: Text('No members found')))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildMemberCard(filteredUsers[i]),
                            childCount: filteredUsers.length,
                          ),
                        ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String feature, String status, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(feature, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Row(
            children: [
              Icon(completed ? Icons.check_circle : Icons.sync, size: 12, color: completed ? const Color(0xFF11A36A) : const Color(0xFFFF6A00)),
              const SizedBox(width: 4),
              Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: completed ? const Color(0xFF11A36A) : const Color(0xFFFF6A00))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: const Color(0xFFFF6A00).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
          child: Center(
            child: Text(
              user.name[0].toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFF6A00)),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFE9FFF3), borderRadius: BorderRadius.circular(6)),
              child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF11A36A), fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.email, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.shield, size: 12, color: Colors.blue),
                  const SizedBox(width: 4),
                  const Text('Admin Access', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (v) {
            if (v == 'edit') _edit(user);
            if (v == 'delete') _delete(user);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit Permissions')),
            PopupMenuItem(value: 'delete', child: Text('Revoke Access')),
          ],
        ),
        onTap: () => _edit(user),
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
  late final TextEditingController _addressCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
    _mobileCtrl = TextEditingController(text: widget.existing?.mobile ?? '');
    _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await widget.api.createUser(name: _nameCtrl.text, email: _emailCtrl.text);
      } else {
        await widget.api.updateUser(id: widget.existing!.id, name: _nameCtrl.text, email: _emailCtrl.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Invite New Member' : 'Member Permissions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 24),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 16),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.alternate_email))),
            const SizedBox(height: 16),
            TextField(controller: _mobileCtrl, decoration: const InputDecoration(labelText: 'Phone (Optional)', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 16),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('ASSIGN ROLES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(label: const Text('Admin'), onSelected: (_) {}, selected: true),
                FilterChip(label: const Text('Delivery Agent'), onSelected: (_) {}, selected: false),
                FilterChip(label: const Text('Store Owner'), onSelected: (_) {}, selected: false),
              ],
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6A00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
