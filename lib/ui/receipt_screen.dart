import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api.dart';
import '../models.dart';

class ReceiptScreen extends StatefulWidget {
  final int orderId;
  const ReceiptScreen({super.key, required this.orderId});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _api = ApiClient();
  Timer? _timer;
  bool _loading = true;
  String? _error;
  ReceiptResponse? _data;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final resp = await _api.getReceipt(orderId: widget.orderId);
      if (!mounted) return;
      setState(() {
        _error = null;
        _loading = false;
        _data = resp;
      });
      if (resp.receipt != null) {
        _timer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _data?.receipt;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : receipt == null
                  ? _pendingView()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _statusCard(
                          theme: theme,
                          title: receipt.paymentStatus == 'CAPTURED' ? 'Payment Success' : receipt.paymentStatus,
                          subtitle: 'Order #${widget.orderId}',
                          amountText: '${_data!.total.toStringAsFixed(2)} ${_data!.currency}',
                          isSuccess: receipt.paymentStatus == 'CAPTURED',
                        ),
                        const SizedBox(height: 12),
                        _detailsCard(receipt),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error ?? 'Unknown error'),
          const SizedBox(height: 12),
          FilledButton(onPressed: _poll, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _pendingView() {
    final orderStatus = _data?.orderStatus ?? '';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          const Text('Waiting for payment confirmation...'),
          const SizedBox(height: 8),
          Text('Order status: $orderStatus'),
        ],
      ),
    );
  }

  Widget _statusCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required String amountText,
    required bool isSuccess,
  }) {
    final cs = theme.colorScheme;
    final bg = isSuccess ? const Color(0xFFE9FFF3) : const Color(0xFFFFF7E6);
    final accent = isSuccess ? const Color(0xFF11A36A) : const Color(0xFFFF6A00);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Icon(isSuccess ? Icons.check_circle_outline : Icons.info_outline, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(amountText, style: TextStyle(fontWeight: FontWeight.w900, color: accent)),
        ],
      ),
    );
  }

  Widget _detailsCard(Receipt r) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _kv('Reference No', r.receiptNo),
            const Divider(height: 22),
            _kv('Payment Method', r.paymentMethod),
            _kv('Status', r.paymentStatus == 'CAPTURED' ? 'Payment Success' : r.paymentStatus, valueColor: const Color(0xFF11A36A)),
            _kv('Transaction Time', _formatTime(r.issuedAt)),
            const Divider(height: 22),
            _kv('Amount', '${r.currency} ${r.paidAmount.toStringAsFixed(2)}', isStrong: true),
            const SizedBox(height: 6),
            Text(
              'Order status: ${_data?.orderStatus ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mon = months[(dt.month - 1).clamp(0, 11)];
    final hh = ((dt.hour % 12) == 0) ? 12 : (dt.hour % 12);
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$mon ${dt.day.toString().padLeft(2, '0')}, ${dt.year} at $hh:$mm$ampm';
  }

  Widget _kv(String label, String value, {bool isStrong = false, Color? valueColor}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // kept for compatibility (unused now)
}

