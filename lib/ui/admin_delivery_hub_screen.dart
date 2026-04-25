import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import 'delivery_management_dashboard.dart';
import 'driver_management_dashboard.dart';
import 'driver_ratings_dashboard.dart';
import 'payment_management_dashboard.dart';

/// Comprehensive admin hub for managing drivers, ratings, feedback, and metrics
class AdminDeliveryHubScreen extends StatefulWidget {
  const AdminDeliveryHubScreen({super.key});

  @override
  State<AdminDeliveryHubScreen> createState() => _AdminDeliveryHubScreenState();
}

class _AdminDeliveryHubScreenState extends State<AdminDeliveryHubScreen> {
  final _api = ApiClient();
  int _selectedTab = 0;

  int _totalDrivers = 0;
  int _availableDrivers = 0; // CHANGED: was _activeDrivers ("Active Now")
  int _activeDeliveries = 0;
  int _unassignedOrders = 0;
  double _avgRating = 0;
  int _totalRatings = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final drivers = await _api.listDrivers(limit: 1000);
      final ratings = await _api.listDriverRatings(limit: 1000);
      final deliveries = await _api.listDeliveries();
      final unassigned = await _api.getUnassignedOrders();

      int available = 0;
      int activeDeliveries = 0;
      double sumRating = 0;

      for (final d in drivers) {
        if (d.status.toUpperCase() == 'ACTIVE') available++;
      }
      for (final r in ratings) {
        sumRating += r.rating;
      }
      for (final d in deliveries) {
        final s = d.status.toUpperCase();
        if (s == 'PENDING' || s == 'PICKED_UP' || s == 'OUT_FOR_DELIVERY') {
          activeDeliveries++;
        }
      }

      final avgRating = ratings.isNotEmpty ? sumRating / ratings.length : 0.0;

      if (mounted) {
        setState(() {
          _totalDrivers = drivers.length;
          _availableDrivers = available;
          _activeDeliveries = activeDeliveries;
          _unassignedOrders = unassigned.length;
          _avgRating = avgRating;
          _totalRatings = ratings.length;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading stats: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Admin Hub'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh stats',
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Stat cards ─────────────────────────────────────────────────
          // CHANGED: was a horizontal-scroll row of fixed 160px cards.
          // Now a 3-column GridView that fills the full screen width.
          // 6 cards = 2 rows × 3 columns, no scrolling needed.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.55,
              children: [
                _StatCard(
                  label: 'Total\nDrivers',
                  value: '$_totalDrivers',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                // CHANGED: "Active Now" → "Available"
                // Available = drivers with ACTIVE status (not on a run).
                // Drivers ON_DELIVERY are counted in "On Run" instead.
                _StatCard(
                  label: 'Available',
                  value: '$_availableDrivers',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                _StatCard(
                  label: 'Avg\nRating',
                  value: _avgRating.toStringAsFixed(1),
                  icon: Icons.star,
                  color: Colors.amber,
                ),
                _StatCard(
                  label: 'Reviews',
                  value: '$_totalRatings',
                  icon: Icons.reviews,
                  color: Colors.purple,
                ),
                _StatCard(
                  label: 'On Run',
                  value: '$_activeDeliveries',
                  icon: Icons.local_shipping,
                  color: Colors.teal,
                ),
                _StatCard(
                  label: 'Need\nDriver',
                  value: '$_unassignedOrders',
                  icon: Icons.assignment_late_outlined,
                  color: _unassignedOrders > 0
                      ? Colors.deepOrange
                      : Colors.grey,
                  highlight: _unassignedOrders > 0,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Tab navigation ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: [
                  const ButtonSegment(
                    value: 0,
                    label: Text('Drivers'),
                    icon: Icon(Icons.people),
                  ),
                  const ButtonSegment(
                    value: 1,
                    label: Text('Ratings'),
                    icon: Icon(Icons.star),
                  ),
                  const ButtonSegment(
                    value: 2,
                    label: Text('Deliveries'),
                    icon: Icon(Icons.local_shipping),
                  ),
                  const ButtonSegment(
                    value: 3,
                    label: Text('Payments'),
                    icon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  ButtonSegment(
                    value: 4,
                    label: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Text('Assign'),
                        if (_unassignedOrders > 0)
                          Positioned(
                            right: -10,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.deepOrange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_unassignedOrders',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    icon: const Icon(Icons.assignment_ind_outlined),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (s) =>
                    setState(() => _selectedTab = s.first),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Tab content ────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                const DriverManagementDashboard(),
                const DriverRatingDashboard(),

                // CHANGED: readOnly: true (was false)
                // Flow: admin assigns driver → driver updates status
                // (PENDING → PICKED_UP → OUT_FOR_DELIVERY → DELIVERED)
                // → admin watches here in real time.
                // Admin should NOT manually override driver status —
                // if something's wrong, use the Assign tab to reassign.
                const DeliveryManagementDashboard(readOnly: true),

                const PaymentManagementDashboard(readOnly: true),
                _UnassignedOrdersPanel(onAssigned: _loadStats),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCard — CHANGED: no fixed width (fills grid cell).
// Added `highlight` for "Need Driver" card (orange border + dot when > 0).
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlight
            ? BorderSide(color: color.withOpacity(0.6), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 18),
                if (highlight)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UnassignedOrdersPanel — logic unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _UnassignedOrdersPanel extends StatefulWidget {
  final VoidCallback onAssigned;
  const _UnassignedOrdersPanel({required this.onAssigned});

  @override
  State<_UnassignedOrdersPanel> createState() => _UnassignedOrdersPanelState();
}

class _UnassignedOrdersPanelState extends State<_UnassignedOrdersPanel> {
  final _api = ApiClient();
  List<OrderSummary> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await _api.getUnassignedOrders();
      if (mounted) setState(() => _orders = orders);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAssignDialog(OrderSummary order) async {
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignDriverDialog(order: order, api: _api),
    );
    if (assigned == true) {
      widget.onAssigned();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'All orders have drivers assigned!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final o = _orders[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepOrange.withOpacity(0.15),
                child: const Icon(Icons.receipt_long, color: Colors.deepOrange),
              ),
              title: Text(
                'Order #${o.orderId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${o.currency} ${o.total.toStringAsFixed(2)} · ${o.status}',
                  ),
                  Text(
                    'Placed: ${_fmt(o.createdAt)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: FilledButton.icon(
                onPressed: () => _openAssignDialog(o),
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Assign'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// _AssignDriverDialog — logic unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _AssignDriverDialog extends StatefulWidget {
  final OrderSummary order;
  final ApiClient api;
  const _AssignDriverDialog({required this.order, required this.api});

  @override
  State<_AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends State<_AssignDriverDialog> {
  List<DriverProfile> _drivers = [];
  DriverProfile? _selected;
  bool _loading = true;
  bool _assigning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final all = await widget.api.listDrivers(limit: 500);
      final active = all
          .where((d) => d.status.toUpperCase() == 'ACTIVE')
          .toList();
      if (mounted) setState(() => _drivers = active);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign() async {
    if (_selected == null) return;
    setState(() {
      _assigning = true;
      _error = null;
    });
    try {
      await widget.api.assignDriverToOrder(
        orderId: widget.order.orderId,
        driverUserId: _selected!.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted)
        setState(() {
          _assigning = false;
          _error = e.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Driver — Order #${widget.order.orderId}'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : _drivers.isEmpty
            ? const Text(
                'No available drivers right now.\nTry again later.',
                textAlign: TextAlign.center,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total: ${widget.order.currency} '
                    '${widget.order.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select an available driver:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _drivers.length,
                      itemBuilder: (_, i) {
                        final d = _drivers[i];
                        final isSelected = _selected?.id == d.id;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blue.withOpacity(0.15),
                            child: Text(
                              d.name.isNotEmpty ? d.name[0] : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(d.name),
                          subtitle: Text(
                            '${d.vehicleType ?? 'Unknown vehicle'}'
                            '${d.phone != null ? ' · ${d.phone}' : ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : null,
                          selected: isSelected,
                          selectedTileColor: Colors.green.withOpacity(0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onTap: () => setState(() => _selected = d),
                        );
                      },
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _assigning ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_selected == null || _assigning || _loading)
              ? null
              : _assign,
          child: _assigning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Assign Driver'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unchanged: AdminDeliveryDashboard, _DriverQuickView, _RatingQuickView
// ─────────────────────────────────────────────────────────────────────────────
class AdminDeliveryDashboard extends StatefulWidget {
  const AdminDeliveryDashboard({super.key});

  @override
  State<AdminDeliveryDashboard> createState() => _AdminDeliveryDashboardState();
}

class _AdminDeliveryDashboardState extends State<AdminDeliveryDashboard> {
  final _api = ApiClient();
  List<DriverProfile> _topDrivers = [];
  List<DriverRating> _recentRatings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final drivers = await _api.listDrivers(verified: true, limit: 5);
      final ratings = await _api.listDriverRatings(limit: 10);
      if (mounted)
        setState(() {
          _topDrivers = drivers;
          _recentRatings = ratings;
        });
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
    if (_topDrivers.isEmpty && _recentRatings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver Dashboard',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Verified Drivers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_topDrivers.isEmpty)
                    const Text('No verified drivers')
                  else
                    ..._topDrivers.map((d) => _DriverQuickView(driver: d)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Ratings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_recentRatings.isEmpty)
                    const Text('No ratings yet')
                  else
                    ..._recentRatings
                        .take(5)
                        .map((r) => _RatingQuickView(rating: r)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverQuickView extends StatelessWidget {
  final DriverProfile driver;
  const _DriverQuickView({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.withOpacity(0.2),
            child: Text(driver.name[0]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (driver.ratingsAverage != null)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        driver.ratingsAverage!.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: driver.status == 'ACTIVE'
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              driver.status,
              style: TextStyle(
                fontSize: 11,
                color: driver.status == 'ACTIVE' ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingQuickView extends StatelessWidget {
  final DriverRating rating;
  const _RatingQuickView({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                Icons.star,
                size: 14,
                color: i < rating.rating ? Colors.amber : Colors.grey[300],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rating.customerName ?? 'Anonymous',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (rating.category != null)
                  Text(
                    rating.category!,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Text(
            'Order #${rating.orderId}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
