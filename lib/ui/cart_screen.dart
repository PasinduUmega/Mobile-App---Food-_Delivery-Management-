import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/cart_manager.dart';
import '../services/validators.dart';
import 'payment_method_screen.dart';

class CartScreen extends StatefulWidget {
  final int userId;
  final CartManager cartManager;

  const CartScreen({
    super.key,
    required this.userId,
    required this.cartManager,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.cartManager.refreshCart();
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _updateQty(DatabaseCartItem item, int delta) async {
    final cart = widget.cartManager.cart;
    if (cart == null) return;
    final newQty = item.qty + delta;
    if (newQty <= 0) {
      await widget.cartManager.removeItem(item.id);
    } else {
      final qtyErr = Validators.validateCartLineQty(newQty);
      if (qtyErr != null) {
        _showError(qtyErr);
        return;
      }
      await widget.cartManager.updateItem(item.id, newQty);
    }
    if (widget.cartManager.error != null && mounted) {
      _showError(widget.cartManager.error!);
    }
  }

  Future<void> _checkout() async {
    final cart = widget.cartManager.cart;
    if (cart == null || cart.items.isEmpty) return;
    if (cart.storeId == null) {
      _showError('Select a restaurant on Home and add items before checkout.');
      return;
    }
    final cartItemsForValidation = cart.items
        .map(
          (i) => CartItem(
            productId: i.productId,
            name: i.name,
            qty: i.qty,
            unitPrice: i.unitPrice,
            lineNote: i.lineNote,
          ),
        )
        .toList(growable: false);
    final cartErr = Validators.validateCartSubtotal(cartItemsForValidation);
    if (cartErr != null) {
      _showError(cartErr);
      return;
    }
    try {
      final payNow = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Checkout'),
          content: const Text(
            'Choose payment type.\n\n'
            '• Cash on delivery: pay the driver when food arrives.\n'
            '• Pay now: use credit/debit, digital wallet, or PayPal in the next screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cash on delivery'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pay now'),
            ),
          ],
        ),
      );
      if (payNow == null) return;

      const deliveryFee = 2.5;
      final createdOrder = await _api.createOrder(
        userId: widget.userId,
        storeId: cart.storeId!,
        items: cartItemsForValidation,
        deliveryFee: deliveryFee,
        currency: 'LKR',
        cartId: cart.id,
      );
      if (!mounted) return;
      await widget.cartManager.afterOrderPlaced(widget.userId, cart.storeId!);

      if (!mounted) return;

      if (!payNow) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed. Pay the driver cash on delivery.'),
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentMethodScreen(order: createdOrder),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.cartManager,
      builder: (context, __) {
        final cart = widget.cartManager.cart;
        final loading = widget.cartManager.isLoading;
        final err = widget.cartManager.error;
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Cart'),
            actions: [
              IconButton(
                onPressed: loading
                    ? null
                    : () => widget.cartManager.refreshCart(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: loading && cart == null
              ? const Center(child: CircularProgressIndicator())
              : err != null && cart == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(err),
                      ),
                    )
                  : cart == null || cart.items.isEmpty
                      ? _buildEmptyCart()
                      : _buildCartList(cart),
          bottomNavigationBar: cart != null && cart.items.isNotEmpty
              ? _buildBottomBar(cart)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Add dishes from Home — your cart is saved in the app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList(ShoppingCart cart) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cart.items.length,
      itemBuilder: (ctx, i) {
        final item = cart.items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (item.lineNote != null)
                        Text(
                          item.lineNote!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'LKR ${item.unitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFFFF6A00)),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _updateQty(item, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '${item.qty}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => _updateQty(item, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => _remove(item),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _remove(DatabaseCartItem item) async {
    await widget.cartManager.removeItem(item.id);
    if (widget.cartManager.error != null && mounted) {
      _showError(widget.cartManager.error!);
    }
  }

  Widget _buildBottomBar(ShoppingCart cart) {
    final subtotal = cart.getSubtotal();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal + delivery on Home',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'LKR ${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6A00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _checkout,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFFF6A00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Checkout now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
