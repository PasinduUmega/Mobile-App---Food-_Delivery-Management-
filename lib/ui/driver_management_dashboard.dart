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
      if (mounted) {
        setState(() {
          _drivers = drivers;
          _loading = false;
        });
      }
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
      list = list.where((d) {
        return d.name.toLowerCase().contains(q) ||
            (d.phone?.toLowerCase().contains(q) ?? false) ||
            (d.email?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return list;
  }

  Future<void> _showCreateDriver() async {
    final created = await _showEditDialog();
    if (created == null) return;
    await _reload();
  }

  Future<void> _showEditDriver(DriverProfile driver) async {
    final ok = await _showEditDialog(existing: driver);
    if (ok == null) return;
    await _reload();
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

  Future<bool?> _showEditDialog({DriverProfile? existing}) async {
    return showDialog<bool?>(
      context: context,
      builder: (_) => _EditDriverDialog(api: _api, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              MobilePartitionCard(
                title: 'Driver Summary',
                subtitle: 'Quick status view for your delivery fleet.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statChip('Total', _drivers.length.toString(), Colors.blue),
                    _statChip('Active', _activeCount.toString(), Colors.green),
                    _statChip('Busy', _busyCount.toString(), Colors.orange),
                    _statChip(
                      'Verified',
                      _verifiedCount.toString(),
                      Colors.purple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              MobilePartitionCard(
                title: 'Search & Filters',
                subtitle: 'Find drivers quickly by name, status, or verification.',
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search drivers...',
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
                        final statusDropdown = DropdownButtonFormField<String>(
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
            ],
          ),
        ),
        if (filtered.isEmpty)
          Padding(
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
          )
        else
          ...filtered.map(
            (d) => _DriverCard(
              driver: d,
              onEdit: () => _showEditDriver(d),
              onDelete: () => _deleteDriver(d),
              onViewMetrics: () => _showMetrics(d),
            ),
          ),
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
          title: Text('${driver.name} - Performance Metrics'),
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

  Widget _metricRow(String label, String value) {
    return Padding(
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

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          Text(
                            driver.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          if (verified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
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
                    color: _statusColor(driver.status).withValues(alpha: 0.2),
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
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Metrics'),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
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
    switch (status) {
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

class _EditDriverDialog extends StatefulWidget {
  final ApiClient api;
  final DriverProfile? existing;

  const _EditDriverDialog({required this.api, this.existing});

  @override
  State<_EditDriverDialog> createState() => _EditDriverDialogState();
}

class _EditDriverDialogState extends State<_EditDriverDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _vehicleTypeCtrl;
  late TextEditingController _vehicleNumberCtrl;
  late TextEditingController _licenseNumberCtrl;
  late TextEditingController _userIdCtrl;
  late String _statusVal;
  bool _verified = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _phoneCtrl = TextEditingController(text: ex?.phone ?? '');
    _emailCtrl = TextEditingController(text: ex?.email ?? '');
    _vehicleTypeCtrl = TextEditingController(text: ex?.vehicleType ?? '');
    _vehicleNumberCtrl = TextEditingController(text: ex?.vehicleNumber ?? '');
    _licenseNumberCtrl = TextEditingController(text: ex?.licenseNumber ?? '');
    _userIdCtrl = TextEditingController(text: ex?.userId.toString() ?? '');
    _statusVal = ex?.status ?? 'PENDING_VERIFICATION';
    _verified = ex?.verified ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        final userId = int.tryParse(_userIdCtrl.text);
        if (userId == null) throw 'User ID is required';
        await widget.api.createDriver(
          userId: userId,
          name: name,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text,
          vehicleType: _vehicleTypeCtrl.text.trim().isEmpty
              ? null
              : _vehicleTypeCtrl.text,
          vehicleNumber: _vehicleNumberCtrl.text.trim().isEmpty
              ? null
              : _vehicleNumberCtrl.text,
          licenseNumber: _licenseNumberCtrl.text.trim().isEmpty
              ? null
              : _licenseNumberCtrl.text,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Driver created')));
      } else {
        await widget.api.updateDriver(
          id: widget.existing!.id,
          name: name,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text,
          vehicleType: _vehicleTypeCtrl.text.trim().isEmpty
              ? null
              : _vehicleTypeCtrl.text,
          vehicleNumber: _vehicleNumberCtrl.text.trim().isEmpty
              ? null
              : _vehicleNumberCtrl.text,
          licenseNumber: _licenseNumberCtrl.text.trim().isEmpty
              ? null
              : _licenseNumberCtrl.text,
          status: _statusVal,
          verified: _verified,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Driver updated')));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Driver' : 'Edit Driver'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.existing == null) ...[
              TextField(
                controller: _userIdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'User ID *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleTypeCtrl,
              decoration: InputDecoration(
                labelText: 'Vehicle Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleNumberCtrl,
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _licenseNumberCtrl,
              decoration: InputDecoration(
                labelText: 'License Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.existing != null) ...[
              DropdownButtonFormField<String>(
                value: _statusVal,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items:
                    [
                          'ACTIVE',
                          'INACTIVE',
                          'ON_DELIVERY',
                          'PENDING_VERIFICATION',
                        ]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _statusVal = v);
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Verified'),
                value: _verified,
                onChanged: (v) => setState(() => _verified = v ?? false),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
