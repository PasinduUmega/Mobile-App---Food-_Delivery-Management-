import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/validators.dart';
import 'paypal_webview_screen.dart';
import 'receipt_screen.dart';
import '../models.dart';

class PaymentMethodScreen extends StatefulWidget {
  final CreatedOrder order;
  const PaymentMethodScreen({super.key, required this.order});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

enum PaymentOption { card, digitalWallet, cashOnDelivery }

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final _api = ApiClient();
  bool _loading = false;
  PaymentOption _selected = PaymentOption.digitalWallet;

  final _walletIdController = TextEditingController();
  String _walletProvider = 'QuickPay';

  @override
  void dispose() {
    _walletIdController.dispose();
    super.dispose();
  }

  Future<void> _payWithPayPal() async {
    setState(() => _loading = true);
    try {
      final created = await _api.createPayPalPayment(orderId: widget.order.orderId);
      if (!mounted) return;
      final didApprove = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PayPalWebViewScreen(
            orderId: widget.order.orderId,
            approvalUrl: created.approvalUrl,
          ),
        ),
      );
      if (didApprove == true && mounted) {
        final receipt = await _api.getReceipt(orderId: widget.order.orderId);
        if (mounted) {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payWithCod() async {
    setState(() => _loading = true);
    try {
      await _api.confirmCod(orderId: widget.order.orderId);
      if (!mounted) return;
      final receipt = await _api.getReceipt(orderId: widget.order.orderId);
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payWithOnlineBanking({required String reference}) async {
    setState(() => _loading = true);
    try {
      await _api.confirmOnlineBanking(orderId: widget.order.orderId, reference: reference);
      if (!mounted) return;
      final receipt = await _api.getReceipt(orderId: widget.order.orderId);
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _paySecurely() async {
    FocusScope.of(context).unfocus();
    switch (_selected) {
      case PaymentOption.cashOnDelivery:
        return _payWithCod();
      case PaymentOption.card:
        // Card checkout is routed through PayPal (supports card in checkout UI).
        return _payWithPayPal();
      case PaymentOption.digitalWallet:
        final providerLower = _walletProvider.toLowerCase();
        if (providerLower == 'paypal') {
          return _payWithPayPal();
        }

        final walletId = _walletIdController.text.trim();
        final requiredErr = Validators.requireString(
          walletId.isEmpty ? null : walletId,
          'Wallet ID / phone number',
        );
        if (requiredErr != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(requiredErr)),
          );
          return;
        }

        final walletIdError = Validators.validateMobileNumber(walletId);
        if (walletIdError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(walletIdError)),
          );
          return;
        }

        return _payWithOnlineBanking(
          reference: '$_walletProvider:$walletId',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final theme = Theme.of(context);
    final orange = theme.colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: AbsorbPointer(
              absorbing: _loading,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 4),
                      Text('Payment', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _orderHeader(orderId: order.orderId, amountText: '${order.total.toStringAsFixed(2)} ${order.currency}'),
                  const SizedBox(height: 18),
                  Text('Payment Method', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _optionCard(
                    option: PaymentOption.card,
                    selected: _selected,
                    orange: orange,
                    title: 'Credit / Debit Card',
                    subtitle: 'Visa, Mastercard, AMEX',
                    icon: Icons.credit_card_outlined,
                    onTap: () => setState(() => _selected = PaymentOption.card),
                  ),
                  const SizedBox(height: 10),
                  _optionCard(
                    option: PaymentOption.digitalWallet,
                    selected: _selected,
                    orange: orange,
                    title: 'Digital Wallet',
                    subtitle: 'Apple Pay, Google Pay, PayPal',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => setState(() => _selected = PaymentOption.digitalWallet),
                  ),
                  const SizedBox(height: 10),
                  _optionCard(
                    option: PaymentOption.cashOnDelivery,
                    selected: _selected,
                    orange: orange,
                    title: 'Cash on Delivery',
                    subtitle: 'Pay when food arrives',
                    icon: Icons.payments_outlined,
                    onTap: () => setState(() => _selected = PaymentOption.cashOnDelivery),
                  ),
                  const SizedBox(height: 14),
                  if (_selected == PaymentOption.digitalWallet) _digitalWalletForm(orange),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: orange),
                        onPressed: _loading ? null : _paySecurely,
                        child: const Text('Pay Securely'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'By continuing, you agree to the payment terms and refund policy.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _orderHeader({required int orderId, required String amountText}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1EA), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #ORDER$orderId', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Total amount', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFFFF6A00)),
              ),
              const SizedBox(height: 6),
              Text('Secure gateway', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _optionCard({
    required PaymentOption option,
    required PaymentOption selected,
    required Color orange,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = option == selected;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? orange : const Color(0xFFE7E7E7), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFFF6A00)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? orange : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _digitalWalletForm(Color orange) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Digital wallet', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('Wallet provider', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7E7E7)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _walletProvider,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'QuickPay', child: Text('QuickPay')),
                  DropdownMenuItem(value: 'PayPal', child: Text('PayPal')),
                  DropdownMenuItem(value: 'Google Pay', child: Text('Google Pay')),
                  DropdownMenuItem(value: 'Apple Pay', child: Text('Apple Pay')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _walletProvider = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Wallet ID / phone number', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _walletIdController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '0701234567',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE7E7E7))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE7E7E7))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: orange, width: 2)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You will be asked to confirm this payment in your wallet app.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

