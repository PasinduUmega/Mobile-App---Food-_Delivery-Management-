import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import 'widgets/app_feedback.dart';

/// Driver-focused list: assigned runs, order context, payment clarity.
class DriverDeliveriesScreen extends StatefulWidget {
  final User user;
  final bool readOnly;

  const DriverDeliveriesScreen({
    super.key,
    required this.user,
    this.readOnly = false,
  });

  @override
  State<DriverDeliveriesScreen> createState() => _DriverDeliveriesScreenState();
}

class _DriverDeliveriesScreenState extends State<DriverDeliveriesScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _error;
  List<DeliveryInfo> _items = [];

  /// Order id → details (includes line items = chosen menu / cart).
  final Map<int, OrderSummary> _orderById = {};
  final Set<int> _orderLoadingIds = {};

  /// Latest payment row for this order (customer paid restaurant / platform).
  final Map<int, Payment?> _paymentByOrderId = {};
  final Map<int, String> _storeNameByOrderId = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _prefetchOrderDetails(int orderId) async {
    if (_orderById.containsKey(orderId) || _orderLoadingIds.contains(orderId)) {
      return;
    }
    setState(() => _orderLoadingIds.add(orderId));
    try {
      final o = await _api.getOrderDetails(id: orderId);
      List<Payment> payments = const [];
      try {
        payments = await _api.listPayments(orderId: orderId, limit: 10);
      } catch (_) {}
      Payment? pay;
      if (payments.isNotEmpty) {
        payments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        pay = payments.first;
      }
      String? storeName;
      final sid = o.storeId;
      if (sid != null) {
        try {
          final store = await _api.getStore(id: sid);
          storeName = store.name;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _orderById[orderId] = o;
        _paymentByOrderId[orderId] = pay;
        if (storeName != null) _storeNameByOrderId[orderId] = storeName;
        _orderLoadingIds.remove(orderId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _orderLoadingIds.remove(orderId));
    }
  }

  static String _paymentMethodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'PAYPAL':
        return 'PayPal';
      case 'CASH_ON_DELIVERY':
        return 'Cash on delivery';
      case 'ONLINE_BANKING':
        return 'Online banking';
      default:
        return method.replaceAll('_', ' ');
    }
  }

  static String _handoverLine(Payment? p) {
    if (p == null) {
      return 'Payment: still loading or not recorded — confirm with support if unsure.';
    }
    final captured = p.status == 'CAPTURED';
    if (p.method == 'CASH_ON_DELIVERY') {
      if (captured) {
        return 'COD logged in app — hand over the food to the customer.';
      }
      return 'Cash on delivery — collect cash at the door only if dispatch told you to.';
    }
    if (captured) {
      return 'Customer paid online. Money flows to the restaurant / platform — you only deliver the bag.';
    }
    return 'Payment status: ${p.status} — handover as instructed by dispatch.';
  }

  void _prefetchAllOrderDetails() {
    for (final d in _items) {
      _prefetchOrderDetails(d.orderId);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var list = await _api.listDeliveries();
      if (!widget.readOnly) {
        final myName = widget.user.name.trim().toLowerCase();
        final myPhone = (widget.user.mobile ?? '').trim();
        list = list.where((d) {
          final assignedName = (d.driverName ?? '').trim().toLowerCase();
          final assignedPhone = (d.driverPhone ?? '').trim();
          final assignedToMeByPhone =
              myPhone.isNotEmpty && assignedPhone == myPhone;
          final assignedToMeByName =
              myName.isNotEmpty && assignedName == myName;
          return assignedToMeByPhone || assignedToMeByName;
        }).toList();
      }
      if (!mounted) return;
      list.sort((a, b) {
        int rank(String s) {
          switch (s) {
            case 'PENDING':
              return 0;
            case 'PICKED_UP':
              return 1;
            case 'OUT_FOR_DELIVERY':
              return 2;
            case 'DELIVERED':
              return 3;
            default:
              return 9;
          }
        }

        final c = rank(a.status).compareTo(rank(b.status));
        if (c != 0) return c;
        return b.orderId.compareTo(a.orderId);
      });
      setState(() {
        _items = list;
        _loading = false;
      });
      _prefetchAllOrderDetails();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showOrderSheet(DeliveryInfo d) async {
    OrderSummary? order;
    User? customer;
    Payment? sheetPayment;
    String? sheetStoreName;
    try {
      order = await _api.getOrderDetails(id: d.orderId);
      final uid = order.userId;
      if (uid != null) {
        try {
          customer = await _api.getUser(id: uid);
        } catch (_) {}
      }
      try {
        final pays = await _api.listPayments(orderId: order.orderId, limit: 10);
        if (pays.isNotEmpty) {
          pays.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          sheetPayment = pays.first;
        }
      } catch (_) {}
      final sid = order.storeId;
      if (sid != null) {
        try {
          sheetStoreName = (await _api.getStore(id: sid)).name;
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Could not load order: $e');
      return;
    }
    if (!mounted) return;
    final o = order;
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
          initialChildSize: 0.85,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scroll) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ListView(
                controller: scroll,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Order #${o.orderId}',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This sheet is for handover: exact basket, money flow, and drop-off. '
                    'Follow the payment hint — online orders are already paid to the store side.',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (sheetStoreName != null) _kv('Restaurant', sheetStoreName),
                  if (customer != null) ...[
                    _kv('Customer', customer.name),
                    _kv('Email', customer.email),
                  ] else if (o.userId != null)
                    _kv('Customer account', '#${o.userId}'),
                  _kv('Order status', o.status),
                  const Divider(height: 22),
                  Text(
                    'Cart totals',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _kv('Subtotal', '${o.currency} ${o.subtotal.toStringAsFixed(2)}'),
                  _kv('Delivery fee', '${o.currency} ${o.deliveryFee.toStringAsFixed(2)}'),
                  _kv('Total', '${o.currency} ${o.total.toStringAsFixed(2)}'),
                  const Divider(height: 22),
                  Text(
                    'Customer payment',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (sheetPayment != null) ...[
                    _kv('Method', _paymentMethodLabel(sheetPayment.method)),
                    _kv('Status', sheetPayment.status),
                    _kv(
                      'Amount',
                      '${sheetPayment.currency} ${sheetPayment.amount.toStringAsFixed(2)}',
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'No payment record found for this order yet.',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _handoverLine(sheetPayment),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (o.deliveryLatitude != null &&
                      o.deliveryLongitude != null)
                    _kv(
                      'Drop-off GPS',
                      '${o.deliveryLatitude!.toStringAsFixed(5)}, '
                      '${o.deliveryLongitude!.toStringAsFixed(5)}',
                    ),
                  const Divider(height: 28),
                  Text(
                    'Line items (menu / cart)',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (o.items != null && o.items!.isNotEmpty)
                    ...o.items!.map(
                      (it) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${it.qty}× ${it.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${o.currency} ${it.lineTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'No line items returned for this order. The kitchen may still be finalizing the ticket.',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check),
                    label: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  Future<void> _setStatus(DeliveryInfo d, String status) async {
    if (widget.readOnly) return;
    try {
      await _api.updateDelivery(id: d.id, status: status);
      if (!mounted) return;
      final friendly = _statusLabelForDriver(status);
      AppFeedback.success(
        context,
        '$friendly · Customer order status updated in the app.',
      );
      setState(() {
        _orderById.remove(d.orderId);
        _paymentByOrderId.remove(d.orderId);
        _storeNameByOrderId.remove(d.orderId);
      });
      await _prefetchOrderDetails(d.orderId);
      _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.toString());
    }
  }

  Future<void> _claim(DeliveryInfo d) async {
    if (widget.readOnly) return;
    try {
      await _api.updateDelivery(
        id: d.id,
        driverName: widget.user.name,
        driverPhone: widget.user.mobile,
        status: 'PICKED_UP',
      );
      if (!mounted) return;
      AppFeedback.success(
        context,
        'Pickup started · Customer sees that the order is on the way.',
      );
      setState(() {
        _orderById.remove(d.orderId);
        _paymentByOrderId.remove(d.orderId);
        _storeNameByOrderId.remove(d.orderId);
      });
      await _prefetchOrderDetails(d.orderId);
      _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.toString());
    }
  }

  Future<void> _collectCod(DeliveryInfo d) async {
    if (widget.readOnly) return;
    final order = _orderById[d.orderId];
    final pay = _paymentByOrderId[d.orderId];

    final shouldShow =
        order != null &&
        order.status.toUpperCase() == 'PENDING_PAYMENT' &&
        (pay == null ||
            (pay.method.toUpperCase() == 'CASH_ON_DELIVERY' &&
                pay.status.toUpperCase() != 'CAPTURED'));
    if (!shouldShow) return;

    final totalText =
        '${order.currency} ${order.total.toStringAsFixed(2)}';

    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Collect cash & mark paid?'),
        content: Text(
          'Confirm you collected $totalText for order #${d.orderId}. '
          'This will mark the order as paid in the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      await _api.confirmCod(orderId: d.orderId);
      if (!mounted) return;
      AppFeedback.success(context, 'Payment captured (COD).');
      setState(() {
        _orderById.remove(d.orderId);
        _paymentByOrderId.remove(d.orderId);
      });
      await _prefetchOrderDetails(d.orderId);
      _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.toString());
    }
  }

  static String _statusLabelForDriver(String status) {
    switch (status) {
      case 'PICKED_UP':
        return 'Marked picked up';
      case 'OUT_FOR_DELIVERY':
        return 'Out for delivery';
      case 'DELIVERED':
        return 'Delivered';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Widget _buildCartAndPaymentSection(DeliveryInfo d, ColorScheme cs) {
    final loading = _orderLoadingIds.contains(d.orderId);
    final o = _orderById[d.orderId];
    final pay = _paymentByOrderId[d.orderId];
    final storeName = _storeNameByOrderId[d.orderId];

    if (loading && o == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(
          minHeight: 3,
          borderRadius: BorderRadius.circular(99),
          color: cs.primary,
        ),
      );
    }
    if (o == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton.icon(
          onPressed: () => _prefetchOrderDetails(d.orderId),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Load basket & payment'),
        ),
      );
    }

    final items = o.items ?? [];
    final n = items.fold<int>(0, (s, it) => s + it.qty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (storeName != null) ...[
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  storeName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Basket · $n items (customer menu choices)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: cs.onSurface.withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(
            'No line items listed yet for #${d.orderId}.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          )
        else
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${it.qty}× ${it.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ),
                  Text(
                    '${o.currency} ${it.lineTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.65),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cart totals',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              _totRow(cs, 'Subtotal', '${o.currency} ${o.subtotal.toStringAsFixed(2)}'),
              _totRow(cs, 'Delivery fee', '${o.currency} ${o.deliveryFee.toStringAsFixed(2)}'),
              const Divider(height: 14),
              _totRow(
                cs,
                'Total',
                '${o.currency} ${o.total.toStringAsFixed(2)}',
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.primary.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Customer payment → restaurant',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.88),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (pay != null) ...[
                Text(
                  '${_paymentMethodLabel(pay.method)} · ${pay.status}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${pay.currency} ${pay.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                Text(
                  'No payment row yet — customer may still be checking out.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              const SizedBox(height: 8),
              Text(
                _handoverLine(pay),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totRow(ColorScheme cs, String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DELIVERED':
        return const Color(0xFF11A36A);
      case 'OUT_FOR_DELIVERY':
      case 'PICKED_UP':
        return Colors.blue;
      case 'PENDING':
        return const Color(0xFFFF6A00);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? 'Deliveries (view only)' : 'My deliveries'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: cs.error),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: cs.primaryContainer.withOpacity(0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments_outlined, color: cs.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Payments & your role',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Each card shows the customer’s basket (what they chose from the menu), '
                          'cart totals, and how they paid the restaurant. '
                          'Use that at handover. Status buttons keep the customer app in sync.',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_items.isEmpty)
                  Text(
                    'No delivery jobs yet. When orders are assigned, they appear here.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                else
                  ..._items.map((d) {
                    final o = _orderById[d.orderId];
                    final pay = _paymentByOrderId[d.orderId];
                    final showCollectCod =
                        !widget.readOnly &&
                        o != null &&
                        o.status.toUpperCase() == 'PENDING_PAYMENT' &&
                        (pay == null ||
                            (pay.method.toUpperCase() == 'CASH_ON_DELIVERY' &&
                                pay.status.toUpperCase() != 'CAPTURED'));

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Order #${d.orderId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(d.status)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    d.status.replaceAll('_', ' '),
                                    style: TextStyle(
                                      color: _statusColor(d.status),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (d.driverName != null &&
                                d.driverName!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Driver: ${d.driverName}'
                                  '${d.driverPhone != null ? ' · ${d.driverPhone}' : ''}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            _buildCartAndPaymentSection(d, cs),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showOrderSheet(d),
                                  icon: const Icon(Icons.person_outline, size: 18),
                                  label: const Text('Customer & map'),
                                ),
                                if (showCollectCod)
                                  FilledButton.icon(
                                    onPressed: () => _collectCod(d),
                                    icon: const Icon(Icons.payments_outlined, size: 18),
                                    label: const Text('Collect COD (mark paid)'),
                                  ),
                                if (!widget.readOnly && d.status == 'PENDING')
                                  FilledButton.icon(
                                    onPressed: () => _claim(d),
                                    icon: const Icon(Icons.delivery_dining, size: 18),
                                    label: const Text('Start delivery'),
                                  ),
                                if (!widget.readOnly && d.status == 'PICKED_UP')
                                  FilledButton.tonal(
                                    onPressed: () =>
                                        _setStatus(d, 'OUT_FOR_DELIVERY'),
                                    child: const Text('Out for delivery'),
                                  ),
                                if (!widget.readOnly &&
                                    (d.status == 'OUT_FOR_DELIVERY' ||
                                        d.status == 'PICKED_UP'))
                                  FilledButton(
                                    onPressed: () =>
                                        _setStatus(d, 'DELIVERED'),
                                    child: const Text('Mark delivered'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
