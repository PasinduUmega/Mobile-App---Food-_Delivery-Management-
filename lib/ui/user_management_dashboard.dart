import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/validators.dart';

class _UserRatingFeedbackRecord {
  final int id;
  final int userId;
  final String userName;
  final int rating;
  final String feedback;
  final String integrationArea;
  final DateTime createdAt;

  const _UserRatingFeedbackRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.feedback,
    required this.integrationArea,
    required this.createdAt,
  });

  _UserRatingFeedbackRecord copyWith({
    int? userId,
    String? userName,
    int? rating,
    String? feedback,
    String? integrationArea,
  }) {
    return _UserRatingFeedbackRecord(
      id: id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      integrationArea: integrationArea ?? this.integrationArea,
      createdAt: createdAt,
    );
  }
}

class UserManagementDashboard extends StatefulWidget {
  const UserManagementDashboard({super.key});

  @override
  State<UserManagementDashboard> createState() =>
      _UserManagementDashboardState();
}

class _UserManagementDashboardState extends State<UserManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  List<User> _items = const [];
  String _searchQuery = '';
  int _nextFeedbackId = 1;
  List<_UserRatingFeedbackRecord> _ratingFeedback = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });
    try {
      final items = await _api.listUsers();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deleteUser(id: u.id);
      _reload();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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

  double _averageRating() {
    if (_ratingFeedback.isEmpty) return 0;
    final total = _ratingFeedback.fold<int>(0, (s, e) => s + e.rating);
    return total / _ratingFeedback.length;
  }

  Future<void> _addRatingFeedback() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create users before adding feedback.')),
      );
      return;
    }
    final created = await showDialog<_UserRatingFeedbackRecord>(
      context: context,
      builder: (_) => _RatingFeedbackDialog(
        users: _items,
        nextId: _nextFeedbackId,
      ),
    );
    if (created == null) return;
    setState(() {
      _ratingFeedback = [created, ..._ratingFeedback];
      _nextFeedbackId += 1;
    });
  }

  Future<void> _editRatingFeedback(_UserRatingFeedbackRecord item) async {
    final edited = await showDialog<_UserRatingFeedbackRecord>(
      context: context,
      builder: (_) => _RatingFeedbackDialog(
        users: _items,
        nextId: item.id,
        existing: item,
      ),
    );
    if (edited == null) return;
    setState(() {
      _ratingFeedback = _ratingFeedback
          .map((e) => e.id == item.id ? edited : e)
          .toList(growable: false);
    });
  }

  Future<void> _deleteRatingFeedback(_UserRatingFeedbackRecord item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete feedback?'),
        content: Text(
          'Remove rating #${item.id} for ${item.userName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    setState(() {
      _ratingFeedback = _ratingFeedback
          .where((e) => e.id != item.id)
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity & Access'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
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
                        Expanded(
                          child: _buildStatCard(
                            'Total Members',
                            _items.length.toString(),
                            Icons.people,
                            const Color(0xFFFF6A00),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Admin Privileges',
                            _items
                                .where((u) => u.role == UserRole.admin)
                                .length
                                .toString(),
                            Icons.shield_outlined,
                            const Color(0xFF11A36A),
                          ),
                        ),
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
                          borderSide: BorderSide(
                            color: Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.grey.withOpacity(0.1),
                          ),
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
                    child: Text(
                      'ACCESS CONTROLS Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          _buildStatusRow('Role-Based Auth', 'Completed', true),
                          _buildStatusRow('Profile Updates', 'Completed', true),
                          _buildStatusRow(
                            'Account Lock/Unlock',
                            'Completed',
                            true,
                          ),
                          _buildStatusRow(
                            'Activity Logs',
                            'In Progress',
                            false,
                          ),
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
                      ? SliverFillRemaining(
                          child: Center(child: Text('No members found')),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildMemberCard(filteredUsers[i]),
                            childCount: filteredUsers.length,
                          ),
                        ),
                ),
                const SliverPadding(padding: EdgeInsets.only(top: 24)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Ratings',
                            _ratingFeedback.length.toString(),
                            Icons.star_rate_outlined,
                            const Color(0xFFF2994A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Avg Score',
                            _averageRating().toStringAsFixed(1),
                            Icons.reviews_outlined,
                            const Color(0xFF4A90E2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'USER RATING & FEEDBACK CRUD',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      onPressed: _addRatingFeedback,
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Add rating / feedback'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: _ratingFeedback.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Text(
                            'No rating entries yet. Add customer feedback for '
                            'payments, integrations, carts or UX quality.',
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final rf = _ratingFeedback[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  title: Text(
                                    '${rf.userName} • ${rf.rating}/5',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${rf.integrationArea}\n${rf.feedback}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _editRatingFeedback(rf);
                                      if (v == 'delete') {
                                        _deleteRatingFeedback(rf);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: _ratingFeedback.length,
                          ),
                        ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
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
          Text(
            feature,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.sync,
                size: 12,
                color: completed
                    ? const Color(0xFF11A36A)
                    : const Color(0xFFFF6A00),
              ),
              const SizedBox(width: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: completed
                      ? const Color(0xFF11A36A)
                      : const Color(0xFFFF6A00),
                ),
              ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6A00).withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              user.name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF6A00),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE9FFF3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  color: Color(0xFF11A36A),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.email,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 12,
                    color: user.role == UserRole.admin
                        ? const Color(0xFF11A36A)
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    user.role.displayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: user.role == UserRole.admin
                          ? const Color(0xFF11A36A)
                          : Colors.grey[700],
                    ),
                  ),
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

class _RatingFeedbackDialog extends StatefulWidget {
  final List<User> users;
  final int nextId;
  final _UserRatingFeedbackRecord? existing;

  const _RatingFeedbackDialog({
    required this.users,
    required this.nextId,
    this.existing,
  });

  @override
  State<_RatingFeedbackDialog> createState() => _RatingFeedbackDialogState();
}

class _RatingFeedbackDialogState extends State<_RatingFeedbackDialog> {
  late int _selectedUserId;
  late int _rating;
  late String _integrationArea;
  late final TextEditingController _feedbackCtrl;

  @override
  void initState() {
    super.initState();
    _selectedUserId =
        widget.existing?.userId ??
        (widget.users.isNotEmpty ? widget.users.first.id : 0);
    _rating = widget.existing?.rating ?? 5;
    _integrationArea = widget.existing?.integrationArea ?? 'Payment';
    _feedbackCtrl = TextEditingController(text: widget.existing?.feedback ?? '');
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final feedback = _feedbackCtrl.text.trim();
    if (feedback.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback text is required.')),
      );
      return;
    }
    final user = widget.users.firstWhere(
      (u) => u.id == _selectedUserId,
      orElse: () => widget.users.first,
    );
    Navigator.pop(
      context,
      _UserRatingFeedbackRecord(
        id: widget.existing?.id ?? widget.nextId,
        userId: user.id,
        userName: user.name,
        rating: _rating,
        feedback: feedback,
        integrationArea: _integrationArea,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? 'Create Rating & Feedback'
                  : 'Edit Rating & Feedback',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _selectedUserId,
              decoration: const InputDecoration(
                labelText: 'User',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: widget.users
                  .map(
                    (u) => DropdownMenuItem<int>(
                      value: u.id,
                      child: Text(u.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                if (v != null) setState(() => _selectedUserId = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _integrationArea,
              decoration: const InputDecoration(
                labelText: 'Area',
                prefixIcon: Icon(Icons.integration_instructions_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'Payment', child: Text('Payment')),
                DropdownMenuItem(
                  value: 'Integration',
                  child: Text('Integration'),
                ),
                DropdownMenuItem(value: 'Cart', child: Text('Cart')),
                DropdownMenuItem(value: 'Customer UX', child: Text('Customer UX')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _integrationArea = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _rating,
              decoration: const InputDecoration(
                labelText: 'Rating',
                prefixIcon: Icon(Icons.star_outline),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 - Very poor')),
                DropdownMenuItem(value: 2, child: Text('2 - Poor')),
                DropdownMenuItem(value: 3, child: Text('3 - Average')),
                DropdownMenuItem(value: 4, child: Text('4 - Good')),
                DropdownMenuItem(value: 5, child: Text('5 - Excellent')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _rating = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Feedback',
                prefixIcon: Icon(Icons.feedback_outlined),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
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
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
    _mobileCtrl = TextEditingController(text: widget.existing?.mobile ?? '');
    _selectedRole = widget.existing?.role ?? UserRole.customer;
  }

  Future<void> _save() async {
    final nameText = _nameCtrl.text.trim();
    final emailText = _emailCtrl.text.trim();
    final mobileText = _mobileCtrl.text.trim();

    final nameError = Validators.validateName(nameText);
    if (nameError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nameError)),
        );
      }
      return;
    }

    final emailError = Validators.validateEmail(emailText);
    if (emailError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(emailError)),
        );
      }
      return;
    }

    final mobileError = Validators.validateMobileNumber(
      mobileText.isEmpty ? null : mobileText,
    );
    if (mobileError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mobileError)),
        );
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await widget.api.createUser(
          name: nameText,
          email: emailText,
          mobile: mobileText.isEmpty ? null : mobileText,
        );
      } else {
        await widget.api.updateUser(
          id: widget.existing!.id,
          name: nameText,
          email: emailText,
          mobile: mobileText.isEmpty ? null : mobileText,
          role: _selectedRole,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
            Text(
              widget.existing == null
                  ? 'Invite New Member'
                  : 'Member Permissions',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mobileCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone (Optional)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            if (widget.existing != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'ROLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                  ),
                ),
              ),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Access level',
                  prefixIcon: Icon(Icons.manage_accounts_outlined),
                ),
                items: UserRole.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.displayLabel),
                      ),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (v) {
                        if (v != null) setState(() => _selectedRole = v);
                      },
              ),
              const SizedBox(height: 8),
              Text(
                'Only a signed-in administrator can change roles (enforced on the server).',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ] else ...[
              Text(
                'New members start as Customer. After they appear in the list, edit them to assign restaurant owner, driver, or admin.',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirm'),
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
