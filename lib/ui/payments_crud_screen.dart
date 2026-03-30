import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';

class PaymentsCrudScreen extends StatefulWidget {
  const PaymentsCrudScreen({super.key});

  @override
  State<PaymentsCrudScreen> createState() => _PaymentsCrudScreenState();
}

class _PaymentsCrudScreenState extends State<PaymentsCrudScreen> {
  final _api = ApiClient();
  bool _loading = false;
  String? _error;
  List<Payment> _items = const [];

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
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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
        title: const Text('Delete payment?'),
        content: Text('Payment #${p.id} (order ${p.orderId})'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deletePayment(id: p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showEditDialog({Payment? existing}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _PaymentEditDialog(existing: existing, api: _api),
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments (CRUD)'),
        actions: [
          IconButton(onPressed: _loading ? null : _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _create,
        backgroundColor: const Color(0xFFFF6A00),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: cs.error, size: 34),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton(onPressed: _reload, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('No payments yet. Tap + to create one.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final p = _items[i];
                        final isPaid = p.status == 'CAPTURED';
                        final badgeBg = isPaid ? const Color(0xFFE9FFF3) : const Color(0xFFFFF1EA);
                        final badgeFg = isPaid ? const Color(0xFF11A36A) : const Color(0xFFFF6A00);
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _edit(p),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(isPaid ? Icons.check_circle_outline : Icons.payments_outlined, color: badgeFg),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '#${p.id} • Order ${p.orderId}',
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${p.method} • ${p.currency} ${p.amount.toStringAsFixed(2)}',
                                          style: TextStyle(color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      p.status,
                                      style: TextStyle(fontWeight: FontWeight.w800, color: badgeFg, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _edit(p);
                                      if (v == 'delete') _delete(p);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
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
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _providerCtrl;
  late final TextEditingController _providerOrderCtrl;
  late final TextEditingController _providerCaptureCtrl;
  late final TextEditingController _approvalUrlCtrl;

  late String _method;
  late String _status;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _orderIdCtrl = TextEditingController(text: p?.orderId.toString() ?? '');
    _amountCtrl = TextEditingController(text: p?.amount.toStringAsFixed(2) ?? '');
    _currencyCtrl = TextEditingController(text: p?.currency ?? 'USD');
    _providerCtrl = TextEditingController(text: p?.provider ?? '');
    _providerOrderCtrl = TextEditingController(text: p?.providerOrderId ?? '');
    _providerCaptureCtrl = TextEditingController(text: p?.providerCaptureId ?? '');
    _approvalUrlCtrl = TextEditingController(text: p?.approvalUrl ?? '');
    const validMethods = ['PAYPAL', 'CASH_ON_DELIVERY', 'ONLINE_BANKING'];
    const validStatuses = ['CREATED', 'APPROVAL_PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'CANCELLED'];
    
    _method = p?.method ?? 'ONLINE_BANKING';
    if (!validMethods.contains(_method)) _method = 'ONLINE_BANKING';
    
    _status = p?.status ?? 'CREATED';
    if (!validStatuses.contains(_status)) _status = 'CREATED';
  }

  @override
  void dispose() {
    _orderIdCtrl.dispose();
    _amountCtrl.dispose();
    _currencyCtrl.dispose();
    _providerCtrl.dispose();
    _providerOrderCtrl.dispose();
    _providerCaptureCtrl.dispose();
    _approvalUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isNew = widget.existing == null;
    final orderId = int.tryParse(_orderIdCtrl.text.trim());
    final amount = double.tryParse(_amountCtrl.text.trim());
    final currency = _currencyCtrl.text.trim().toUpperCase();

    if (orderId == null || orderId <= 0) {
      _showError('Order ID is required');
      return;
    }
    if (amount == null || amount < 0) {
      _showError('Amount is invalid');
      return;
    }
    if (currency.length != 3) {
      _showError('Currency must be 3 letters');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (isNew) {
        await widget.api.createPayment(
          orderId: orderId,
          method: _method,
          status: _status,
          provider: _providerCtrl.text.trim().isEmpty ? null : _providerCtrl.text.trim(),
          providerOrderId: _providerOrderCtrl.text.trim().isEmpty ? null : _providerOrderCtrl.text.trim(),
          providerCaptureId: _providerCaptureCtrl.text.trim().isEmpty ? null : _providerCaptureCtrl.text.trim(),
          approvalUrl: _approvalUrlCtrl.text.trim().isEmpty ? null : _approvalUrlCtrl.text.trim(),
          amount: amount,
          currency: currency,
        );
      } else {
        await widget.api.updatePayment(
          id: widget.existing!.id,
          status: _status,
          provider: _providerCtrl.text.trim().isEmpty ? null : _providerCtrl.text.trim(),
          providerOrderId: _providerOrderCtrl.text.trim().isEmpty ? null : _providerOrderCtrl.text.trim(),
          providerCaptureId: _providerCaptureCtrl.text.trim().isEmpty ? null : _providerCaptureCtrl.text.trim(),
          approvalUrl: _approvalUrlCtrl.text.trim().isEmpty ? null : _approvalUrlCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showError(e.toString());
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AlertDialog(
      title: Text(isNew ? 'Create payment' : 'Update payment #${widget.existing!.id}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _orderIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Order ID'),
              enabled: isNew,
            ),
            DropdownButtonFormField<String>(
              initialValue: _method,
              items: const [
                DropdownMenuItem(value: 'PAYPAL', child: Text('PAYPAL')),
                DropdownMenuItem(value: 'CASH_ON_DELIVERY', child: Text('CASH_ON_DELIVERY')),
                DropdownMenuItem(value: 'ONLINE_BANKING', child: Text('ONLINE_BANKING')),
              ],
              onChanged: isNew ? (v) => setState(() => _method = v ?? _method) : null,
              decoration: const InputDecoration(labelText: 'Method'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: const [
                DropdownMenuItem(value: 'CREATED', child: Text('CREATED')),
                DropdownMenuItem(value: 'APPROVAL_PENDING', child: Text('APPROVAL_PENDING')),
                DropdownMenuItem(value: 'AUTHORIZED', child: Text('AUTHORIZED')),
                DropdownMenuItem(value: 'CAPTURED', child: Text('CAPTURED')),
                DropdownMenuItem(value: 'FAILED', child: Text('FAILED')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('CANCELLED')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
              enabled: isNew,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currencyCtrl,
              decoration: const InputDecoration(labelText: 'Currency'),
              enabled: isNew,
            ),
            TextField(controller: _providerCtrl, decoration: const InputDecoration(labelText: 'Provider')),
            TextField(controller: _providerOrderCtrl, decoration: const InputDecoration(labelText: 'Provider order id')),
            TextField(controller: _providerCaptureCtrl, decoration: const InputDecoration(labelText: 'Provider capture id')),
            TextField(controller: _approvalUrlCtrl, decoration: const InputDecoration(labelText: 'Approval url')),
            const SizedBox(height: 8),
            const Text(
              'Tip: setting status to CAPTURED will mark the order PAID and auto-generate a receipt.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        _submitting
            ? const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : FilledButton(onPressed: _submit, child: Text(isNew ? 'Create' : 'Update')),
      ],
    );
  }
}

