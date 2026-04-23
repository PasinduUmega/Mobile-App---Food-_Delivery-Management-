import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/validators.dart';

class DeliveryManagementDashboard extends StatefulWidget {
  /// When set, only deliveries for orders at this owner’s stores are listed.
  final int? ownerUserId;

  /// Store owners: watch drivers & status — no create/edit/delete.
  final bool readOnly;

  const DeliveryManagementDashboard({
    super.key,
    this.ownerUserId,
    this.readOnly = false,
  });

  @override
  State<DeliveryManagementDashboard> createState() =>
      _DeliveryManagementDashboardState();
}

class _DeliveryManagementDashboardState
    extends State<DeliveryManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  List<DeliveryInfo> _deliveries = [];
  final Map<int, Payment?> _latestPaymentByOrderId = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.listDeliveries();
      final payments = await _api.listPayments(limit: 600);
      final latestByOrder = <int, Payment>{};
      for (final p in payments) {
        final prev = latestByOrder[p.orderId];
        if (prev == null || p.updatedAt.isAfter(prev.updatedAt)) {
          latestByOrder[p.orderId] = p;
        }
      }
      var list = items;
      if (widget.ownerUserId != null) {
        final stores =
            await _api.listStores(ownerUserId: widget.ownerUserId);
        final storeIds = stores.map((s) => s.id).toSet();
        final orders = await _api.listOrders(limit: 500);
        final allowedOrderIds = orders
            .where(
              (o) => o.storeId != null && storeIds.contains(o.storeId),
            )
            .map((o) => o.orderId)
            .toSet();
        list =
            items.where((d) => allowedOrderIds.contains(d.orderId)).toList();
      }
      if (mounted)
        setState(() {
          _deliveries = list;
          _latestPaymentByOrderId
            ..clear()
            ..addAll(latestByOrder);
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showOwnerViewSheet(DeliveryInfo d) async {
    OrderSummary? order;
    User? customer;
    List<Payment> payments = const [];
    try {
      order = await _api.getOrderDetails(id: d.orderId);
      final uid = order.userId;
      if (uid != null) {
        try {
          customer = await _api.getUser(id: uid);
        } catch (_) {}
      }
      try {
        payments = await _api.listPayments(orderId: d.orderId, limit: 10);
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load order: $e')),
        );
      }
      return;
    }
    if (!mounted) return;
    final o = order;
    final captured =
        payments.any((p) => p.status == 'CAPTURED');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (_, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'Order #${o.orderId}',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  captured
                      ? 'Customer payment: received (captured in app).'
                      : 'Customer payment: not fully captured yet — order may still be unpaid.',
                  style: TextStyle(
                    color: captured ? cs.primary : Colors.orange.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Divider(height: 24),
                if (customer != null) ...[
                  _sheetRow(ctx, 'Customer', customer.name),
                  _sheetRow(ctx, 'Email', customer.email),
                ] else if (o.userId != null)
                  _sheetRow(ctx, 'Customer id', '#${o.userId}'),
                _sheetRow(ctx, 'Order status', o.status),
                _sheetRow(ctx, 'Delivery status', d.status),
                _sheetRow(
                  ctx,
                  'Total',
                  '${o.currency} ${o.total.toStringAsFixed(2)}',
                ),
                const Divider(height: 24),
                Text(
                  'Items customer selected',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (o.items != null && o.items!.isNotEmpty)
                  ...o.items!.map(
                    (it) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${it.qty}× ${it.name}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${o.currency} ${it.lineTotal.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    'No line items returned.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sheetRow(BuildContext ctx, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final res = await _showEditDialog();
    if (res == true) _load();
  }

  Future<void> _edit(DeliveryInfo delivery) async {
    final res = await _showEditDialog(existing: delivery);
    if (res == true) _load();
  }

  Future<void> _delete(DeliveryInfo delivery) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Delivery?'),
        content: Text(
          'Are you sure you want to delete delivery for order #${delivery.orderId}?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteDelivery(id: delivery.id);
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showEditDialog({DeliveryInfo? existing}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeliveryEditDialog(existing: existing, api: _api),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DELIVERED':
        return const Color(0xFF11A36A);
      case 'OUT_FOR_DELIVERY':
      case 'PICKED_UP':
        return Colors.blue;
      case 'PENDING':
        return const Color(0xFFFF6A00);
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _driverBusyNow(DeliveryInfo target) {
    final phone = (target.driverPhone ?? '').trim();
    if (phone.isEmpty) return false;
    const activeStatuses = {'PENDING', 'PICKED_UP', 'OUT_FOR_DELIVERY'};
    return _deliveries.any(
      (d) =>
          d.id != target.id &&
          (d.driverPhone ?? '').trim() == phone &&
          activeStatuses.contains(d.status.toUpperCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.readOnly
              ? 'Deliveries (my stores · view)'
              : widget.ownerUserId != null
                  ? 'Deliveries (filtered)'
                  : 'Delivery & Logistics',
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: const Color(0xFFFF6A00),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Delivery'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deliveries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delivery_dining_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text('No deliveries tracked yet'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _deliveries.length,
              itemBuilder: (ctx, i) {
                final d = _deliveries[i];
                final statusColor = _getStatusColor(d.status);
                final driverBusy = _driverBusyNow(d);
                final driverState = d.driverName == null
                    ? 'Unassigned'
                    : (driverBusy ? 'Busy' : 'Available');
                final pay = _latestPaymentByOrderId[d.orderId];
                final paid = pay != null && pay.status.toUpperCase() == 'CAPTURED';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: widget.readOnly
                        ? () => _showOwnerViewSheet(d)
                        : () => _edit(d),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF6A00,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.delivery_dining,
                                  color: Color(0xFFFF6A00),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${d.orderId}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Driver: ${d.driverName ?? 'Unassigned'} · $driverState',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Payment: ${pay == null ? 'Not recorded' : paid ? 'Paid (${pay.method})' : 'Pending (${pay.status})'}',
                                      style: TextStyle(
                                        color: paid ? const Color(0xFF11A36A) : Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  d.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          if (widget.readOnly)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showOwnerViewSheet(d),
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 18),
                                label: const Text('Cart & payment'),
                              ),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _edit(d),
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  label: const Text('Edit'),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _delete(d),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DeliveryEditDialog extends StatefulWidget {
  final DeliveryInfo? existing;
  final ApiClient api;
  const _DeliveryEditDialog({this.existing, required this.api});

  @override
  State<_DeliveryEditDialog> createState() => _DeliveryEditDialogState();
}

class _DeliveryEditDialogState extends State<_DeliveryEditDialog> {
  late final TextEditingController _driverNameCtrl;
  late final TextEditingController _driverPhoneCtrl;
  String _status = 'PENDING';
  int? _selectedOrderId;
  int? _selectedDriverUserId;
  bool _loading = false;
  bool _submitting = false;
  List<OrderSummary> _availableOrders = [];
  List<User> _drivers = [];
  final Set<String> _busyDriverPhones = <String>{};

  @override
  void initState() {
    super.initState();
    _driverNameCtrl = TextEditingController(
      text: widget.existing?.driverName ?? '',
    );
    _driverPhoneCtrl = TextEditingController(
      text: widget.existing?.driverPhone ?? '',
    );
    _status = widget.existing?.status ?? 'PENDING';
    _selectedOrderId = widget.existing?.orderId;

    // Ensure the status is valid
    const validStatuses = [
      'PENDING',
      'PICKED_UP',
      'OUT_FOR_DELIVERY',
      'DELIVERED',
      'CANCELLED',
    ];
    if (!validStatuses.contains(_status)) {
      _status = 'PENDING';
    }

    if (widget.existing == null) {
      _loadAvailableOrders();
    } else {
      _loadDrivers();
    }
  }

  Future<void> _loadAvailableOrders() async {
    setState(() => _loading = true);
    try {
      // Fetch orders that are PAID or PREPARING and don't have a delivery yet
      final allOrders = await widget.api.listOrders();
      final allDeliveries = await widget.api.listDeliveries();
      final drivers = await _loadDriverUsers();
      final deliveredOrderIds = allDeliveries.map((e) => e.orderId).toSet();

      if (mounted) {
        setState(() {
          _availableOrders = allOrders.where((o) {
            return (o.status == 'PAID' ||
                    o.status == 'PREPARING' ||
                    o.status == 'READY') &&
                !deliveredOrderIds.contains(o.orderId);
          }).toList();
          _drivers = _sortDrivers(drivers);
          _busyDriverPhones
            ..clear()
            ..addAll(_extractBusyDriverPhones(allDeliveries));
          _selectedDriverUserId = _findDriverIdByExisting();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDrivers() async {
    setState(() => _loading = true);
    try {
      final users = await _loadDriverUsers();
      final deliveries = await widget.api.listDeliveries();
      if (!mounted) return;
      setState(() {
        _drivers = _sortDrivers(users);
        _busyDriverPhones
          ..clear()
          ..addAll(_extractBusyDriverPhones(deliveries));
        _selectedDriverUserId = _findDriverIdByExisting();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<User>> _loadDriverUsers() async {
    final users = await widget.api.listUsers();
    return users.where((u) => u.role == UserRole.deliveryDriver).toList();
  }

  Set<String> _extractBusyDriverPhones(List<DeliveryInfo> deliveries) {
    const activeStatuses = {'PENDING', 'PICKED_UP', 'OUT_FOR_DELIVERY'};
    return deliveries
        .where((d) => activeStatuses.contains(d.status.toUpperCase()))
        .map((d) => d.driverPhone?.trim() ?? '')
        .where((phone) => phone.isNotEmpty)
        .toSet();
  }

  List<User> _sortDrivers(List<User> users) {
    final sorted = [...users];
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  int? _findDriverIdByExisting() {
    final phone = widget.existing?.driverPhone?.trim();
    if (phone == null || phone.isEmpty) return null;
    for (final d in _drivers) {
      if ((d.mobile ?? '').trim() == phone) return d.id;
    }
    return null;
  }

  bool _driverIsBusy(User driver) {
    final phone = (driver.mobile ?? '').trim();
    if (phone.isEmpty) return false;
    final existingPhone = (widget.existing?.driverPhone ?? '').trim();
    if (existingPhone.isNotEmpty && existingPhone == phone) {
      return false;
    }
    return _busyDriverPhones.contains(phone);
  }

  String _driverCompactLabel(User driver) {
    final busy = _driverIsBusy(driver);
    return '${driver.name} (${busy ? 'Busy' : 'Available'})';
  }

  String _driverMenuLabel(User driver) {
    final busy = _driverIsBusy(driver);
    final mobile = (driver.mobile ?? '').trim();
    final phoneText = mobile.isEmpty ? 'No phone' : mobile;
    return '${driver.name} · $phoneText · ${busy ? 'Busy' : 'Available'}';
  }

  Future<void> _save() async {
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an Order')));
      return;
    }

    final selectedDriver = _drivers.firstWhere(
      (d) => d.id == _selectedDriverUserId,
      orElse: () => User(
        id: 0,
        name: _driverNameCtrl.text.trim(),
        email: '',
        mobile: _driverPhoneCtrl.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final driverName = selectedDriver.name.trim();
    final driverPhone = (selectedDriver.mobile ?? '').trim();

    final driverNameError = Validators.validateName(driverName);
    if (driverNameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(driverNameError)),
      );
      return;
    }

    final phoneRequiredErr = Validators.requireString(
      driverPhone.isEmpty ? null : driverPhone,
      'Driver phone',
    );
    if (phoneRequiredErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneRequiredErr)),
      );
      return;
    }

    final driverPhoneError = Validators.validatePhoneNumber(driverPhone);
    if (driverPhoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(driverPhoneError)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await widget.api.createDelivery(
          orderId: _selectedOrderId!,
          driverName: driverName,
          driverPhone: driverPhone,
        );
      } else {
        await widget.api.updateDelivery(
          id: widget.existing!.id,
          status: _status,
          driverName: driverName,
          driverPhone: driverPhone,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isNew ? 'Create Delivery' : 'Edit Delivery',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (isNew) ...[
                    if (_availableOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No orders are currently awaiting delivery assignment.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: _selectedOrderId,
                        decoration: const InputDecoration(
                          labelText: 'Select Order',
                          prefixIcon: Icon(Icons.shopping_bag_outlined),
                        ),
                        items: _availableOrders
                            .map(
                              (o) => DropdownMenuItem(
                                value: o.orderId,
                                child: Text(
                                  'Order #${o.orderId} (${o.status})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedOrderId = v),
                      ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      'Order #${widget.existing!.orderId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!(isNew && _availableOrders.isEmpty)) ...[
                    DropdownButtonFormField<int>(
                      value: _selectedDriverUserId,
                      isExpanded: true,
                      selectedItemBuilder: (context) => _drivers
                          .map(
                            (d) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _driverCompactLabel(d),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Assign driver',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _drivers.map((d) {
                        final busy = _driverIsBusy(d);
                        return DropdownMenuItem<int>(
                          value: d.id,
                          enabled: !busy || d.id == _selectedDriverUserId,
                          child: Text(
                            _driverMenuLabel(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedDriverUserId = v;
                          final selected = _drivers.firstWhere(
                            (d) => d.id == v,
                            orElse: () => User(
                              id: 0,
                              name: '',
                              email: '',
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ),
                          );
                          _driverNameCtrl.text = selected.name;
                          _driverPhoneCtrl.text = selected.mobile ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Status',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items:
                          [
                                'PENDING',
                                'PICKED_UP',
                                'OUT_FOR_DELIVERY',
                                'DELIVERED',
                                'CANCELLED',
                              ]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              _submitting || (isNew && _availableOrders.isEmpty)
                              ? null
                              : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6A00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save'),
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
