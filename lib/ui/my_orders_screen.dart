import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import 'driver_feedback_screen.dart';
import 'order_tracking_screen.dart';
import 'payment_method_screen.dart';

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
      final newlyAssigned = myDeliveries.where((d) {
        final hasDriver = (d.driverName ?? '').trim().isNotEmpty;
        return hasDriver && !_seenAssignedOrders.contains(d.orderId);
      }).toList(growable: false);
      setState(() {
        _orders = mine;
        _deliveryByOrderId = nextDeliveryMap;
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
    return '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _cancelOrder(OrderSummary order) async {
    final s = order.status.toUpperCase();
    if (!(s == 'PENDING_PAYMENT' || s == 'PAID')) {
      _showSnackBar('Only pending/paid orders can be cancelled.');
      return;
    }
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

  Future<void> _deleteOrder(OrderSummary order) async {
    final s = order.status.toUpperCase();
    const deletable = {'PENDING_PAYMENT', 'CANCELLED', 'FAILED'};
    if (!deletable.contains(s)) {
      _showSnackBar('Only pending/cancelled/failed orders can be deleted.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete order?'),
        content: Text(
          'Delete order #${order.orderId}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteOrder(id: order.orderId);
      await _load();
      if (mounted) _showSnackBar('Order deleted.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to delete order: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Complete card / wallet / COD payment for an order that is still pending payment.
  Future<void> _openPayment(OrderSummary order) async {
    if (order.status.toUpperCase() != 'PENDING_PAYMENT') {
      _showSnackBar('This order is not waiting for payment.');
      return;
    }
    final created = CreatedOrder.fromOrderSummary(order);
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => PaymentMethodScreen(order: created),
      ),
    );
    if (done == true && mounted) {
      _showSnackBar('Payment completed.');
      await _load();
    }
  }

  Future<void> _rateDriver(OrderSummary order) async {
    final delivery = _deliveryByOrderId[order.orderId];
    if (delivery == null || (delivery.driverName ?? '').trim().isEmpty) {
      _showSnackBar('Driver details are not available for this order yet.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DriverFeedbackDialog(
        delivery: delivery,
        customerId: widget.user.id,
      ),
    );
    if (ok == true && mounted) {
      _showSnackBar('Thanks! Your rating and feedback were submitted.');
    }
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
                              'and receipts show up here — same idea as Uber Eats.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tip: open the Home tab, pick a restaurant, then '
                              'add items and check out.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 14,
                                height: 1.4,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: stColor.withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(20),
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
                                            if (['PENDING_PAYMENT', 'PAID'].contains(o.status.toUpperCase()))
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8),
                                                child: TextButton(
                                                  onPressed: () => _cancelOrder(o),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: const Size(50, 30),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            if (['PENDING_PAYMENT', 'CANCELLED', 'FAILED'].contains(o.status.toUpperCase()))
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8),
                                                child: TextButton(
                                                  onPressed: () => _deleteOrder(o),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red.shade800,
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: const Size(52, 30),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                                                      color: cs
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${o.currency} ${o.total.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                        if (o.status.toUpperCase() == 'PENDING_PAYMENT')
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: FilledButton.tonalIcon(
                                                onPressed: () => _openPayment(o),
                                                icon: const Icon(
                                                  Icons.credit_score_rounded,
                                                  size: 20,
                                                ),
                                                label: const Text(
                                                  'Pay now (card, wallet, or COD)',
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (assignedDriver != null &&
                                            assignedDriver.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.notifications_active_outlined,
                                                  size: 16,
                                                  color: cs.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Driver assigned: $assignedDriver',
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
                                        if (o.status.toUpperCase() == 'COMPLETED' &&
                                            assignedDriver != null &&
                                            assignedDriver.trim().isNotEmpty)
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                              onPressed: () => _rateDriver(o),
                                              icon: const Icon(
                                                Icons.star_rate_rounded,
                                                size: 18,
                                              ),
                                              label: const Text('Rate Driver'),
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
