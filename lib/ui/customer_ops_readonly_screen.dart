import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';

class CustomerOpsReadOnlyScreen extends StatefulWidget {
  final User user;
  const CustomerOpsReadOnlyScreen({super.key, required this.user});

  @override
  State<CustomerOpsReadOnlyScreen> createState() =>
      _CustomerOpsReadOnlyScreenState();
}

class _CustomerOpsReadOnlyScreenState extends State<CustomerOpsReadOnlyScreen> {
  final _api = ApiClient();
  bool _loading = false;
  String? _error;
  List<OrderSummary> _orders = const [];
  List<Payment> _payments = const [];
  List<DeliveryInfo> _deliveries = const [];

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
      final orders = await _api.listOrders(userId: widget.user.id, limit: 200);
      final orderIds = orders.map((e) => e.orderId).toSet();
      final payments = await _api.listPayments(limit: 400);
      final deliveries = await _api.listDeliveries();

      if (!mounted) return;
      setState(() {
        _orders = orders;
        _payments = payments.where((p) => orderIds.contains(p.orderId)).toList();
        _deliveries =
            deliveries.where((d) => orderIds.contains(d.orderId)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Operations (View Only)'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade900),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Read-only view for payments, delivery and integration status. '
                              'Changes are managed by operations/admin dashboards.',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildStats(cs),
                    const SizedBox(height: 20),
                    _sectionTitle('Payments & Integrations'),
                    ..._payments.map(_buildPaymentCard),
                    if (_payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6, bottom: 12),
                        child: Text('No payment records found for your orders.'),
                      ),
                    const SizedBox(height: 8),
                    _sectionTitle('Delivery View'),
                    ..._deliveries.map(_buildDeliveryCard),
                    if (_deliveries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('No delivery records found yet.'),
                      ),
                  ],
                ),
    );
  }

  Widget _buildStats(ColorScheme cs) {
    final captured = _payments
        .where((p) => p.status.toUpperCase() == 'CAPTURED')
        .fold<double>(0, (sum, p) => sum + p.amount);
    return Row(
      children: [
        Expanded(
          child: _stat(
            title: 'Orders',
            value: '${_orders.length}',
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF4A90E2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            title: 'Paid',
            value: 'LKR ${captured.toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF11A36A),
          ),
        ),
      ],
    );
  }

  Widget _stat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Payment p) {
    final status = p.status.toUpperCase();
    final isPaid = status == 'CAPTURED';
    final statusColor = isPaid ? const Color(0xFF11A36A) : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          p.method.toUpperCase() == 'PAYPAL'
              ? Icons.paypal
              : Icons.account_balance_outlined,
          color: statusColor,
        ),
        title: Text(
          'Order #${p.orderId} • LKR ${p.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('Method: ${p.method}  |  Status: ${p.status}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(DeliveryInfo d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.delivery_dining_outlined),
        title: Text(
          'Order #${d.orderId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('Driver: ${d.driverName ?? 'Unassigned'}'),
        trailing: Text(
          d.status,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}
