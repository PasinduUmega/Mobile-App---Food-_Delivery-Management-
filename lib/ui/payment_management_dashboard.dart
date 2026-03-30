import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';

class PaymentManagementDashboard extends StatefulWidget {
  const PaymentManagementDashboard({super.key});

  @override
  State<PaymentManagementDashboard> createState() =>
      _PaymentManagementDashboardState();
}

class _PaymentManagementDashboardState
    extends State<PaymentManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  String? _error;
  List<Payment> _items = const [];
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listPayments(limit: 100);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await _showEditDialog();
    if (created == null) return;
    await _reload();
  }

  Future<void> _edit(Payment p) async {
    final ok = await _showEditDialog(existing: p);
    if (ok == null) return;
    await _reload();
  }

  Future<void> _delete(Payment p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Payment record #${p.id}'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deletePayment(id: p.id);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showEditDialog({Payment? existing}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentEditDialog(existing: existing, api: _api),
    );
  }

  List<Payment> _getFilteredPayments() {
    if (_filterStatus == 'All') return _items;
    return _items.where((p) => p.status == _filterStatus).toList();
  }

  double _getTotalAmount() => _items.fold(0, (sum, p) => sum + p.amount);
  double _getCapturedAmount() => _items.where((p) => p.status == 'CAPTURED').fold(0, (sum, p) => sum + p.amount);

  @override
  Widget build(BuildContext context) {
    final filteredPayments = _getFilteredPayments();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance & Payments'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: const Color(0xFFFF6A00),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Financial Stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard('Gross Vol', 'LKR ${_getTotalAmount().toStringAsFixed(0)}', Icons.payments, const Color(0xFFFF6A00))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Net Revenue', 'LKR ${_getCapturedAmount().toStringAsFixed(0)}', Icons.account_balance_wallet, const Color(0xFF11A36A))),
                      ],
                    ),
                  ),
                ),

                // Status Filter
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: ['All', 'CAPTURED', 'CREATED', 'AUTHORIZED', 'FAILED', 'CANCELLED']
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  selected: _filterStatus == s,
                                  onSelected: (_) => setState(() => _filterStatus = s),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(top: 24)),

                // Transaction List Header
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: Text('TRANSACTION LEDGER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1)),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: filteredPayments.isEmpty
                      ? const SliverFillRemaining(child: Center(child: Text('No transactions recorded')))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildPaymentCard(filteredPayments[i]),
                            childCount: filteredPayments.length,
                          ),
                        ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, overflow: TextOverflow.ellipsis)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    final isPaid = payment.status == 'CAPTURED';
    final statusColor = isPaid ? const Color(0xFF11A36A) : const Color(0xFFFF6A00);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
          child: Icon(payment.method == 'CASH_ON_DELIVERY' ? Icons.handshake_outlined : Icons.account_balance, color: statusColor, size: 24),
        ),
        title: Row(
          children: [
            Expanded(child: Text('Payment #${payment.id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
            Text('LKR ${payment.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFFF6A00))),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Order #${payment.orderId} • ${payment.method}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(payment.status, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
        onTap: () => _edit(payment),
      ),
    );
  }
}

class _PaymentEditDialog extends StatefulWidget {
  final Payment? existing;
  final ApiClient api;
  const _PaymentEditDialog({this.existing, required this.api});
  @override
  State<_PaymentEditDialog> createState() => _PaymentEditDialogState();
}

class _PaymentEditDialogState extends State<_PaymentEditDialog> {
  late final TextEditingController _orderIdCtrl;
  late final TextEditingController _amountCtrl;
  late String _method;
  late String _status;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _orderIdCtrl = TextEditingController(text: widget.existing?.orderId.toString() ?? '');
    _amountCtrl = TextEditingController(text: widget.existing?.amount.toString() ?? '');
    _method = widget.existing?.method ?? 'ONLINE_BANKING';
    _status = widget.existing?.status ?? 'CREATED';
  }

  Future<void> _save() async {
    final orderId = int.tryParse(_orderIdCtrl.text) ?? 0;
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (orderId <= 0 || amount <= 0) return;

    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await widget.api.createPayment(orderId: orderId, amount: amount, method: _method, status: _status, currency: 'LKR');
      } else {
        await widget.api.updatePayment(id: widget.existing!.id, status: _status);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
            Text(widget.existing == null ? 'Record Transaction' : 'Update Transaction', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 24),
            TextField(controller: _orderIdCtrl, decoration: const InputDecoration(labelText: 'Order ID', prefixIcon: Icon(Icons.receipt_long))),
            const SizedBox(height: 16),
            TextField(controller: _amountCtrl, decoration: const InputDecoration(labelText: 'Amount (LKR)', prefixIcon: Icon(Icons.payments))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(labelText: 'Method', prefixIcon: Icon(Icons.credit_card)),
              items: ['CASH_ON_DELIVERY', 'ONLINE_BANKING', 'PAYPAL'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _method = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline)),
              items: ['CREATED', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'CANCELLED'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6A00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm'),
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
