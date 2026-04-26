import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import 'driver_rating_sheet.dart';
import 'order_tracking_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  final User user;
  const MyOrdersScreen({super.key, required this.user});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _error;
  List<OrderSummary> _orders = [];
  Map<int, DeliveryInfo> _deliveryByOrderId = {};
  final Set<int> _seenAssignedOrders = <int>{};

  // NEW: phone → driverId map, built once on load
  Map<String, int> _driverIdByPhone = {};

  // NEW: tracks which orders the customer already rated this session
  // so we hide the button after they submit
  final Set<int> _ratedOrderIds = <int>{};

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
      final items = await _api.listOrders(limit: 80);
      final deliveries = await _api.listDeliveries();

      // NEW: load drivers to build phone→id map so we can pass driverId
      // to the rating sheet (DeliveryInfo only has driverPhone, not userId)
      final drivers = await _api.listDrivers(limit: 500);
      final driverIdByPhone = <String, int>{};
      for (final d in drivers) {
        if (d.phone != null && d.phone!.isNotEmpty) {
          driverIdByPhone[d.phone!.trim()] = d.id;
        }
      }

      if (!mounted) return;

      final mine = items.where((o) => o.userId == widget.user.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final orderIds = mine.map((o) => o.orderId).toSet();
      final myDeliveries = deliveries
          .where((d) => orderIds.contains(d.orderId))
          .toList(growable: false);

      final nextDeliveryMap = <int, DeliveryInfo>{
        for (final d in myDeliveries) d.orderId: d,
      };

      final newlyAssigned = myDeliveries
          .where((d) {
            final hasDriver = (d.driverName ?? '').trim().isNotEmpty;
            return hasDriver && !_seenAssignedOrders.contains(d.orderId);
          })
          .toList(growable: false);

      setState(() {
        _orders = mine;
        _deliveryByOrderId = nextDeliveryMap;
        _driverIdByPhone = driverIdByPhone; // NEW
        for (final d in myDeliveries) {
          final hasDriver = (d.driverName ?? '').trim().isNotEmpty;
          if (hasDriver) _seenAssignedOrders.add(d.orderId);
        }
        _loading = false;
      });

      if (newlyAssigned.isNotEmpty) {
        final first = newlyAssigned.first;
        final driver = first.driverName ?? 'driver';
        final count = newlyAssigned.length;
        _showSnackBar(
          count == 1
              ? 'Driver assigned to order #${first.orderId}: $driver'
              : '$count orders now have assigned drivers',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your orders. Pull down to try again.';
      });
    }
  }

  static String _statusLabel(String raw) {
    switch (raw) {
      case 'PENDING_PAYMENT':
        return 'Payment pending';
      case 'PAID':
        return 'Paid · preparing';
      case 'PREPARING':
        return 'Preparing your food';
      case 'READY':
        return 'Ready for pickup';
      case 'COMPLETED':
        return 'Delivered';
      case 'CANCELLED':
        return 'Cancelled';
      case 'FAILED':
        return 'Failed';
      default:
        return raw.replaceAll('_', ' ').toLowerCase();
    }
  }

  static Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'COMPLETED':
        return cs.primary;
      case 'CANCELLED':
      case 'FAILED':
        return cs.error;
      case 'PENDING_PAYMENT':
        return Colors.orange.shade800;
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _shortDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} · '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _cancelOrder(OrderSummary order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: Text('Cancel order #${order.orderId}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.updateOrder(id: order.orderId, status: 'CANCELLED');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to cancel order: $e');
    }
  }

  // NEW: opens the driver rating sheet.
  // Looks up driverId by matching driverPhone against the drivers list.
  // If no match found, shows a snackbar — shouldn't happen in normal flow.
  Future<void> _rateDriver(OrderSummary order) async {
    final delivery = _deliveryByOrderId[order.orderId];
    if (delivery == null) return;

    final phone = (delivery.driverPhone ?? '').trim();
    final driverId = _driverIdByPhone[phone];

    if (driverId == null) {
      _showSnackBar('Could not find driver details. Please try again later.');
      return;
    }

    await showDriverRatingSheet(
      context,
      orderId: order.orderId,
      driverId: driverId,
      driverName: delivery.driverName ?? 'Your driver',
      customerId: widget.user.id,
    );

    // Mark this order as rated so the button disappears this session
    if (mounted) setState(() => _ratedOrderIds.add(order.orderId));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ink = cs.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : RefreshIndicator(
              color: cs.primary,
              onRefresh: _load,
              child: _error != null && _orders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: [
                        const SizedBox(height: 48),
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 56,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ink,
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : _orders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 48,
                      ),
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No orders yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'When you order from Home, your delivery updates '
                          'and receipts show up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _orders.length,
                      itemBuilder: (ctx, i) {
                        final o = _orders[i];
                        final stColor = _statusColor(o.status, cs);
                        final delivery = _deliveryByOrderId[o.orderId];
                        final assignedDriver = delivery?.driverName;

                        // NEW: show Rate Driver button when:
                        // 1. Order is COMPLETED (driver marked delivered)
                        // 2. There is a delivery with a driver assigned
                        // 3. Customer hasn't rated this order yet this session
                        final isCompleted =
                            o.status.toUpperCase() == 'COMPLETED';
                        final hasDriver = (delivery?.driverName ?? '')
                            .trim()
                            .isNotEmpty;
                        final alreadyRated = _ratedOrderIds.contains(o.orderId);
                        final canRate =
                            isCompleted && hasDriver && !alreadyRated;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        OrderTrackingScreen(order: o),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Status row
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: stColor.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            _statusLabel(o.status),
                                            style: TextStyle(
                                              color: stColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if ([
                                          'PENDING_PAYMENT',
                                          'PAID',
                                        ].contains(o.status.toUpperCase()))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            child: TextButton(
                                              onPressed: () => _cancelOrder(o),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(50, 30),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        const Spacer(),
                                        Text(
                                          '#${o.orderId}',
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Total row
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.storefront_outlined,
                                          size: 20,
                                          color: cs.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Order total',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${o.currency} ${o.total.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: ink,
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Driver assigned notification
                                    if (assignedDriver != null &&
                                        assignedDriver.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .notifications_active_outlined,
                                              size: 16,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Driver: $assignedDriver',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    Text(
                                      _shortDate(o.createdAt),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),

                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap for tracking & details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    // NEW: Rate Driver button — only on
                                    // COMPLETED orders with a known driver
                                    // that haven't been rated yet
                                    if (canRate) ...[
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _rateDriver(o),
                                          icon: const Icon(
                                            Icons.star_outline_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            'Rate ${delivery!.driverName ?? "your driver"}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.amber.shade800,
                                            side: BorderSide(
                                              color: Colors.amber.shade300,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    // Show "Rated" label after submission
                                    if (isCompleted &&
                                        hasDriver &&
                                        alreadyRated) ...[
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 16,
                                            color: Colors.green.shade600,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'You rated this driver',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
