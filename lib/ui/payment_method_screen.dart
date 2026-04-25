import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/pdf_service.dart';
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
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  String _walletProvider = 'QuickPay';

  @override
  void dispose() {
    _walletIdController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  double get _finalTotal {
    if (_selected == PaymentOption.card) {
      return widget.order.total * 0.95; // 5% discount
    }
    return widget.order.total;
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
        await _openReceiptThenFinish(receipt);
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
      await _openReceiptThenFinish(receipt);
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
      await _openReceiptThenFinish(receipt);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openReceiptThenFinish(ReceiptResponse receipt) async {
    try {
      final fullOrder = await _api.getOrderDetails(id: widget.order.orderId);
      await PdfService.generateAndDownloadReceipt(fullOrder);
    } catch (_) {
      // Receipt screen still gives a manual PDF button if auto-generation fails.
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _paySecurely() async {
    FocusScope.of(context).unfocus();
    switch (_selected) {
      case PaymentOption.cashOnDelivery:
        return _payWithCod();
      case PaymentOption.card:
        // Validate card fields
        final cardErr = Validators.validateCardNumber(_cardNumberController.text);
        if (cardErr != null) {
          _showSnackBar(cardErr);
          return;
        }
        final expiryErr = Validators.validateCardExpiry(_expiryController.text);
        if (expiryErr != null) {
          _showSnackBar(expiryErr);
          return;
        }
        final cvvErr = Validators.validateCardCVV(_cvvController.text);
        if (cvvErr != null) {
          _showSnackBar(cvvErr);
          return;
        }

        // Apply discount and proceed
        return _payWithPayPal(); // PayPal UI will handle the actual card capture or we can simulate
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

    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text('Payment'),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: _loading ? null : () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: AbsorbPointer(
            absorbing: _loading,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _orderHeader(
                  orderId: order.orderId,
                  amountText: '${_finalTotal.toStringAsFixed(2)} ${order.currency}',
                  hasDiscount: _selected == PaymentOption.card,
                  originalAmount: order.total,
                ),
                const SizedBox(height: 18),
                Text(
                  'Payment Method',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
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
                if (_selected == PaymentOption.card) _cardPaymentForm(orange),
                if (_selected == PaymentOption.digitalWallet) _digitalWalletForm(orange),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Material(
              color: theme.scaffoldBackgroundColor,
              elevation: 8,
              shadowColor: const Color(0x22000000),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                    const SizedBox(height: 8),
                    Text(
                      'By continuing, you agree to the payment terms and refund policy.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _orderHeader({
    required int orderId,
    required String amountText,
    bool hasDiscount = false,
    double? originalAmount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: hasDiscount ? [const Color(0xFFE8F5E9), Colors.white] : [const Color(0xFFFFF1EA), Colors.white],
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
              if (hasDiscount)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                  child: const Text('5% CARD DISCOUNT APPLIED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Text('Total amount', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasDiscount && originalAmount != null)
                Text(
                  'LKR ${originalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 12, color: Colors.grey),
                ),
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: hasDiscount ? const Color(0xFF11A36A) : const Color(0xFFFF6A00),
                ),
              ),
              const SizedBox(height: 6),
              Text('Secure gateway', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardPaymentForm(Color orange) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Card Details', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _paymentField(
            controller: _cardNumberController,
            label: 'Card Number',
            hint: '0000 0000 0000 0000',
            icon: Icons.credit_card,
            type: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _paymentField(
                  controller: _expiryController,
                  label: 'Expiry',
                  hint: 'MM/YY',
                  icon: Icons.calendar_month,
                  type: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _paymentField(
                  controller: _cvvController,
                  label: 'CVV',
                  hint: '123',
                  icon: Icons.lock_outline,
                  type: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType type,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE7E7E7))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE7E7E7))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFFF6A00), width: 2)),
          ),
        ),
      ],
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
    final onVar = Theme.of(context).colorScheme.onSurfaceVariant;
    final surface = Theme.of(context).colorScheme.surface;
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? orange : const Color(0xFFE7E7E7),
              width: isSelected ? 2 : 1,
            ),
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
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: onVar, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? orange : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _digitalWalletForm(Color orange) {
    final theme = Theme.of(context);
    final fill = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Digital wallet', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('Wallet provider', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _walletProvider,
            isExpanded: true,
            decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
              ),
            ),
            menuMaxHeight: 320,
            itemHeight: 48,
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

