import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import 'widgets/mobile_partition_card.dart';

class DriverManagementDashboard extends StatefulWidget {
  const DriverManagementDashboard({super.key});

  @override
  State<DriverManagementDashboard> createState() =>
      _DriverManagementDashboardState();
}

class _DriverManagementDashboardState extends State<DriverManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  List<DriverProfile> _drivers = [];
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  bool _verifiedFilter = false;

  int get _activeCount =>
      _drivers.where((d) => d.status.toUpperCase() == 'ACTIVE').length;
  int get _busyCount =>
      _drivers.where((d) => d.status.toUpperCase() == 'ON_DELIVERY').length;
  int get _verifiedCount => _drivers.where((d) => d.verified).length;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final drivers = await _api.listDrivers(
        status: _statusFilter == 'ALL' ? null : _statusFilter,
        verified: _verifiedFilter ? true : null,
      );
      if (mounted)
        setState(() {
          _drivers = drivers;
          _loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  List<DriverProfile> get _filtered {
    var list = _drivers;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (d) =>
                d.name.toLowerCase().contains(q) ||
                (d.phone?.toLowerCase().contains(q) ?? false) ||
                (d.email?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  Future<void> _showCreateDriver() async {
    final created = await showDialog<bool?>(
      context: context,
      builder: (_) => _CreateDriverDialog(api: _api),
    );
    if (created == true) await _reload();
  }

  Future<void> _showEditDriver(DriverProfile driver) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (_) => _EditDriverDialog(api: _api, existing: driver),
    );
    if (ok == true) await _reload();
  }

  Future<void> _deleteDriver(DriverProfile driver) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove driver?'),
        content: Text('Are you sure you want to remove ${driver.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deleteDriver(id: driver.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Driver removed')));
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;
    // Divider colour used in the summary grid
    final divColor = cs.outlineVariant;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Add button
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Driver Management',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    ElevatedButton.icon(
                      onPressed: _showCreateDriver,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Driver'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Driver Summary ─────────────────────────────────────
                // FIX: replaced IntrinsicHeight + Expanded (caused overflow)
                // with plain Row + fixed-height Container divider.
                // Each cell uses Expanded directly in the Row — no
                // IntrinsicHeight needed, so no unbounded-height crash.
                MobilePartitionCard(
                  title: 'Driver Summary',
                  subtitle: 'Quick health view for your delivery fleet.',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryStatCell(
                              label: 'Total',
                              value: _drivers.length.toString(),
                              icon: Icons.people,
                              color: Colors.blue,
                            ),
                          ),
                          Container(width: 1, height: 64, color: divColor),
                          Expanded(
                            child: _SummaryStatCell(
                              label: 'Available',
                              value: _activeCount.toString(),
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 1, color: divColor),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryStatCell(
                              label: 'On Run',
                              value: _busyCount.toString(),
                              icon: Icons.local_shipping,
                              color: Colors.orange,
                            ),
                          ),
                          Container(width: 1, height: 64, color: divColor),
                          Expanded(
                            child: _SummaryStatCell(
                              label: 'Verified',
                              value: _verifiedCount.toString(),
                              icon: Icons.verified_outlined,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Search & Filters ───────────────────────────────────
                MobilePartitionCard(
                  title: 'Search & Filters',
                  subtitle:
                      'Find drivers quickly by name, status, or verification.',
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name, phone or email…',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final statusDropdown =
                              DropdownButtonFormField<String>(
                                value: _statusFilter,
                                decoration: InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  isDense: true,
                                ),
                                items:
                                    [
                                          'ALL',
                                          'ACTIVE',
                                          'INACTIVE',
                                          'ON_DELIVERY',
                                          'PENDING_VERIFICATION',
                                        ]
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s.replaceAll('_', ' ')),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _statusFilter = v);
                                    _reload();
                                  }
                                },
                              );
                          final verifiedChip = Align(
                            alignment: Alignment.centerLeft,
                            child: FilterChip(
                              selected: _verifiedFilter,
                              label: const Text('Verified only'),
                              onSelected: (v) {
                                setState(() => _verifiedFilter = v);
                                _reload();
                              },
                            ),
                          );
                          if (constraints.maxWidth < 560) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                statusDropdown,
                                const SizedBox(height: 10),
                                verifiedChip,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: statusDropdown),
                              const SizedBox(width: 10),
                              verifiedChip,
                            ],
                          );
                        },
                      ),
                      if (_searchQuery.isNotEmpty ||
                          _statusFilter != 'ALL' ||
                          _verifiedFilter)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _statusFilter = 'ALL';
                                _verifiedFilter = false;
                              });
                              _reload();
                            },
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Reset filters'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // ── Driver list ────────────────────────────────────────────────
        if (_loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delivery_dining_outlined,
                      size: 54,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _drivers.isEmpty
                          ? 'No drivers added yet'
                          : 'No drivers match the current filters',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _drivers.isEmpty
                          ? 'Add your first delivery driver to start assigning deliveries.'
                          : 'Try changing status/search filters.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_drivers.isEmpty)
                      FilledButton.icon(
                        onPressed: _showCreateDriver,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add Driver'),
                      ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final d = filtered[i];
              return _DriverCard(
                driver: d,
                onEdit: () => _showEditDriver(d),
                onDelete: () => _deleteDriver(d),
                onViewMetrics: () => _showMetrics(d),
              );
            }, childCount: filtered.length),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Future<void> _showMetrics(DriverProfile driver) async {
    try {
      final metrics = await _api.getDriverMetrics(driverId: driver.id);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${driver.name} — Performance'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _metricRow('Total Deliveries', '${metrics.totalDeliveries}'),
                _metricRow('Completed', '${metrics.completedDeliveries}'),
                _metricRow(
                  'Average Rating',
                  '${metrics.averageRating.toStringAsFixed(1)}★ (${metrics.ratingCount} ratings)',
                ),
                if (metrics.averageDeliveryTime != null)
                  _metricRow(
                    'Avg Delivery Time',
                    '${metrics.averageDeliveryTime?.toStringAsFixed(0)} min',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading metrics: $e')));
      }
    }
  }

  Widget _metricRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary stat cell — FIX: removed Expanded (caused overflow inside
// IntrinsicHeight). Expanded is now applied at the call site in the Row.
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryStatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryStatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver card — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _DriverCard extends StatelessWidget {
  final DriverProfile driver;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewMetrics;

  const _DriverCard({
    required this.driver,
    required this.onEdit,
    required this.onDelete,
    required this.onViewMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final verified = driver.verified;
    final avgRating = driver.ratingsAverage;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              driver.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (verified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (avgRating != null)
                        Text(
                          '★ ${avgRating.toStringAsFixed(1)} (${driver.ratingsCount} ratings)',
                          style: TextStyle(fontSize: 14, color: cs.outline),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(driver.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(driver.status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _statusColor(driver.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (driver.phone != null || driver.vehicleNumber != null)
              Row(
                children: [
                  if (driver.phone != null) ...[
                    Icon(Icons.phone, size: 16, color: cs.outline),
                    const SizedBox(width: 4),
                    Text(
                      driver.phone!,
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (driver.vehicleNumber != null)
                    Text(
                      driver.vehicleNumber!,
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onViewMetrics,
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: const Text('Metrics'),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'ON_DELIVERY':
        return Colors.blue;
      case 'INACTIVE':
        return Colors.orange;
      case 'PENDING_VERIFICATION':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING_VERIFICATION':
        return 'Pending';
      case 'ON_DELIVERY':
        return 'Busy';
      case 'ACTIVE':
        return 'Active';
      case 'INACTIVE':
        return 'Inactive';
      default:
        return status.replaceAll('_', ' ');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE driver dialog — Option A
// Creates a brand-new user account (POST /api/auth/signup with role
// DELIVERY_DRIVER) then immediately creates their driver profile
// (POST /api/drivers) using the returned user ID.
// Admin fills everything in one form — driver gets email + password to log in.
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Shared validators — used by both Create and Edit dialogs
// ─────────────────────────────────────────────────────────────────────────────
class _V {
  static const _emailRx = r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$';

  static String? name(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Name is required';
    if (s.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    if (!RegExp(_emailRx).hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 6) return 'Password must be at least 6 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(s))
      return 'Must contain at least one letter';
    if (!RegExp(r'[0-9]').hasMatch(s))
      return 'Must contain at least one number';
    return null;
  }

  static String? phone(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Phone number is required';
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Phone number must be exactly 10 digits';
    return null;
  }

  static String? vehicleType(String? v) {
    if (v == null || v.isEmpty) return 'Please select a vehicle type';
    return null;
  }

  static String? vehicleNumber(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Vehicle number is required';
    if (s.length < 4) return 'Enter a valid vehicle number (min 4 characters)';
    if (!RegExp(r'^[A-Za-z0-9\s\-]+$').hasMatch(s)) {
      return 'Only letters, numbers, spaces and hyphens allowed';
    }
    return null;
  }

  static String? licenseNumber(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'License number is required';
    if (s.length < 5) return 'Enter a valid license number (min 5 characters)';
    if (!RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(s)) {
      return 'Only letters, numbers and hyphens allowed';
    }
    return null;
  }
}

// Vehicle type options shown as a dropdown
const _kVehicleTypes = [
  'Motorbike',
  'Scooter',
  'Bicycle',
  'Car',
  'Van',
  'Truck',
  'Three-Wheeler',
];

// ─────────────────────────────────────────────────────────────────────────────
// CREATE driver dialog — Option A
// Step 1: signUp (creates DELIVERY_DRIVER user account with password)
// Step 2: createDriver (creates vehicle profile using returned user ID)
// Full Form validation on all fields before any API call is made.
// ─────────────────────────────────────────────────────────────────────────────
class _CreateDriverDialog extends StatefulWidget {
  final ApiClient api;
  const _CreateDriverDialog({required this.api});

  @override
  State<_CreateDriverDialog> createState() => _CreateDriverDialogState();
}

class _CreateDriverDialogState extends State<_CreateDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _vehicleNumCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  String? _selectedVehicleType;
  bool _obscurePassword = true;
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _vehicleNumCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Validate all fields first — shows inline errors under each field
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _serverError = null;
    });

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');

    try {
      // Step 1: create login account
      final user = await widget.api.signUp(
        name: name,
        email: email,
        password: password,
        mobile: phone,
        accountRole: UserRole.deliveryDriver,
      );

      // Step 2: create driver profile
      await widget.api.createDriver(
        userId: user.id,
        name: name,
        phone: phone,
        email: email,
        vehicleType: _selectedVehicleType,
        vehicleNumber: _vehicleNumCtrl.text.trim(),
        licenseNumber: _licenseCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver "$name" created. Login: $email'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _saving = false;
          _serverError = e.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Driver'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.25)),
                ),
                child: const Text(
                  'Creates a login account + driver profile in one step. '
                  'Share the email & password with the driver.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),

              // ── Account details ──────────────────────────────────────
              _sectionLabel('Login Account'),
              const SizedBox(height: 10),
              _formField(
                ctrl: _nameCtrl,
                label: 'Full name *',
                validator: _V.name,
              ),
              const SizedBox(height: 10),
              _formField(
                ctrl: _emailCtrl,
                label: 'Email *',
                keyboard: TextInputType.emailAddress,
                validator: _V.email,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                validator: _V.password,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  helperText:
                      'Min 6 chars · must include a letter and a number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Phone — exactly 10 digits
              _formField(
                ctrl: _phoneCtrl,
                label: 'Phone number *',
                keyboard: TextInputType.phone,
                helperText: 'Must be exactly 10 digits',
                validator: _V.phone,
                maxLength: 10,
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),

              // ── Vehicle details ──────────────────────────────────────
              _sectionLabel('Vehicle Details'),
              const SizedBox(height: 10),

              // Vehicle type — dropdown, not free text
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                validator: _V.vehicleType,
                decoration: InputDecoration(
                  labelText: 'Vehicle type *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _kVehicleTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVehicleType = v),
              ),
              const SizedBox(height: 10),
              // Vehicle number — alphanumeric, min 4 chars
              _formField(
                ctrl: _vehicleNumCtrl,
                label: 'Vehicle number *',
                helperText: 'e.g. ABC-1234  (letters, numbers, hyphens)',
                validator: _V.vehicleNumber,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 10),
              // License — alphanumeric, min 5 chars
              _formField(
                ctrl: _licenseCtrl,
                label: 'License number *',
                helperText: 'e.g. B1234567  (min 5 characters)',
                validator: _V.licenseNumber,
                textCapitalization: TextCapitalization.characters,
              ),

              // Server error (e.g. email already exists)
              if (_serverError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _serverError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create Driver'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  );

  Widget _formField({
    required TextEditingController ctrl,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    String? helperText,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: validator,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        counterText: maxLength != null ? '' : null, // hide counter
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT driver dialog — same validations, no password field, no status field
// ─────────────────────────────────────────────────────────────────────────────
class _EditDriverDialog extends StatefulWidget {
  final ApiClient api;
  final DriverProfile existing;

  const _EditDriverDialog({required this.api, required this.existing});

  @override
  State<_EditDriverDialog> createState() => _EditDriverDialogState();
}

class _EditDriverDialogState extends State<_EditDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _vehicleNumCtrl;
  late TextEditingController _licenseCtrl;
  String? _selectedVehicleType;
  late bool _verified;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex.name);
    _phoneCtrl = TextEditingController(text: ex.phone ?? '');
    _emailCtrl = TextEditingController(text: ex.email ?? '');
    _vehicleNumCtrl = TextEditingController(text: ex.vehicleNumber ?? '');
    _licenseCtrl = TextEditingController(text: ex.licenseNumber ?? '');
    _verified = ex.verified;
    // Pre-select vehicle type if it matches a known option
    _selectedVehicleType = _kVehicleTypes.contains(ex.vehicleType)
        ? ex.vehicleType
        : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _vehicleNumCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.api.updateDriver(
        id: widget.existing.id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), ''),
        email: _emailCtrl.text.trim(),
        vehicleType: _selectedVehicleType,
        vehicleNumber: _vehicleNumCtrl.text.trim(),
        licenseNumber: _licenseCtrl.text.trim(),
        verified: _verified,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Driver updated')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Driver'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _formField(_nameCtrl, 'Name *', validator: _V.name),
              const SizedBox(height: 12),
              _formField(
                _phoneCtrl,
                'Phone number *',
                keyboard: TextInputType.phone,
                helperText: 'Must be exactly 10 digits',
                validator: _V.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 12),
              _formField(
                _emailCtrl,
                'Email *',
                keyboard: TextInputType.emailAddress,
                validator: _V.email,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                validator: _V.vehicleType,
                decoration: InputDecoration(
                  labelText: 'Vehicle type *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _kVehicleTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVehicleType = v),
              ),
              const SizedBox(height: 12),
              _formField(
                _vehicleNumCtrl,
                'Vehicle number *',
                helperText: 'Letters, numbers, hyphens — min 4 chars',
                validator: _V.vehicleNumber,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              _formField(
                _licenseCtrl,
                'License number *',
                helperText: 'Min 5 characters',
                validator: _V.licenseNumber,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Verified'),
                subtitle: const Text(
                  'Tick after confirming license & vehicle documents',
                  style: TextStyle(fontSize: 12),
                ),
                value: _verified,
                onChanged: (v) => setState(() => _verified = v ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Widget _formField(
    TextEditingController ctrl,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    String? helperText,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: validator,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        counterText: maxLength != null ? '' : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
