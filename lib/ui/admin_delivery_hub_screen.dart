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

  // Dashboard stats
  int _totalDrivers = 0;
  int _activeDrivers = 0;
  int _activeDeliveries = 0;
  int _pendingDeliveries = 0;
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

      int active = 0;
      int activeDeliveries = 0;
      int pendingDeliveries = 0;
      double totalRating = 0;
      double sumRating = 0;

      for (final d in drivers) {
        if (d.status == 'ACTIVE') active++;
      }

      for (final r in ratings) {
        sumRating += r.rating;
      }

      for (final d in deliveries) {
        final status = d.status.toUpperCase();
        if (status == 'PENDING' ||
            status == 'PICKED_UP' ||
            status == 'OUT_FOR_DELIVERY') {
          activeDeliveries++;
        }
        if (status == 'PENDING') {
          pendingDeliveries++;
        }
      }

      if (ratings.isNotEmpty) {
        totalRating = sumRating / ratings.length;
      }

      if (mounted) {
        setState(() {
          _totalDrivers = drivers.length;
          _activeDrivers = active;
          _activeDeliveries = activeDeliveries;
          _pendingDeliveries = pendingDeliveries;
          _avgRating = totalRating;
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Admin & Delivery Dashboard ',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          // Stats Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatCard(
                    label: 'Total Drivers',
                    value: '$_totalDrivers',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Active Now',
                    value: '$_activeDrivers',
                    icon: Icons.location_on,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Avg Rating',
                    value: _avgRating.toStringAsFixed(1),
                    icon: Icons.star,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Reviews',
                    value: '$_totalRatings',
                    icon: Icons.reviews,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Active Deliveries',
                    value: '$_activeDeliveries',
                    icon: Icons.local_shipping,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Pending Assignments',
                    value: '$_pendingDeliveries',
                    icon: Icons.assignment_late_outlined,
                    color: Colors.deepOrange,
                  ),
                ],
              ),
            ),
          ),
          // Tab Navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('Drivers'),
                    icon: Icon(Icons.people),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('Ratings'),
                    icon: Icon(Icons.star),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text('Deliveries'),
                    icon: Icon(Icons.local_shipping),
                  ),
                  ButtonSegment(
                    value: 3,
                    label: Text('Payments'),
                    icon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (s) {
                  setState(() => _selectedTab = s.first);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                const DriverManagementDashboard(),
                const DriverRatingDashboard(),
                const DeliveryManagementDashboard(readOnly: false),
                const PaymentManagementDashboard(readOnly: true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Stats'),
            )
          : null,
    );
  }

}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick-view admin dashboard for delivery operations
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

      if (mounted) {
        setState(() {
          _topDrivers = drivers;
          _recentRatings = ratings;
        });
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
                    Column(
                      children: _topDrivers
                          .map((d) => _DriverQuickView(driver: d))
                          .toList(),
                    ),
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
                    Column(
                      children: _recentRatings
                          .take(5)
                          .map((r) => _RatingQuickView(rating: r))
                          .toList(),
                    ),
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
            backgroundColor: Colors.blue.withValues(alpha: 0.2),
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
                      Icon(Icons.star, size: 14, color: Colors.amber),
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
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
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
            children: List.generate(5, (i) {
              return Icon(
                Icons.star,
                size: 14,
                color: i < rating.rating ? Colors.amber : Colors.grey[300],
              );
            }),
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
