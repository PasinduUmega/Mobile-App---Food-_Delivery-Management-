import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import 'payment_method_screen.dart';

class CartScreen extends StatefulWidget {
  final int userId;
  const CartScreen({super.key, required this.userId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _api = ApiClient();
  bool _loading = true;
  ShoppingCart? _cart;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cart = await _api.getActiveCart(userId: widget.userId);
      if (mounted)
        setState(() {
          _cart = cart;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _updateQty(DatabaseCartItem item, int delta) async {
    if (_cart == null) return;
    final newQty = item.qty + delta;
    if (newQty <= 0) {
      await _remove(item);
      return;
    }
    try {
      final updatedItems = await _api.updateCartItem(
        cartId: _cart!.id,
        itemId: item.id,
        qty: newQty,
      );
      setState(() {
        _cart = ShoppingCart(
          id: _cart!.id,
          userId: _cart!.userId,
          storeId: _cart!.storeId,
          status: _cart!.status,
          createdAt: _cart!.createdAt,
          updatedAt: DateTime.now(),
          items: updatedItems,
        );
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _remove(DatabaseCartItem item) async {
    if (_cart == null) return;
    try {
      final updatedItems = await _api.removeFromCart(
        cartId: _cart!.id,
        itemId: item.id,
      );
      setState(() {
        _cart = ShoppingCart(
          id: _cart!.id,
          userId: _cart!.userId,
          storeId: _cart!.storeId,
          status: _cart!.status,
          createdAt: _cart!.createdAt,
          updatedAt: DateTime.now(),
          items: updatedItems,
        );
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _checkout() async {
    if (_cart == null || _cart!.items.isEmpty) return;

    // Step 1: Ask payment method
    final payNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkout'),
        content: const Text(
          'Choose payment type.\n\n'
          'Cash on delivery: pay the driver when food arrives.\n'
          'Pay now: complete payment in the app.',
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
    if (mounted) setState(() => _loading = true);

    try {
      // Step 2: Create the order
      final createdOrder = await _api.createOrder(
        userId: widget.userId,
        storeId: _cart!.storeId,
        items: _cart!.items
            .map(
              (item) => CartItem(
                productId: item.productId,
                name: item.name,
                qty: item.qty,
                unitPrice: item.unitPrice,
                lineNote: item.lineNote,
              ),
            )
            .toList(),
      );

      if (!mounted) return;

      // Step 3: Clear cart
      try {
        await _api.clearCart(cartId: _cart!.id);
      } catch (_) {}

      if (!mounted) return;

      if (!payNow) {
        // ── CASH ON DELIVERY ──────────────────────────────────────────
        // CRITICAL: must call confirmCod so order status becomes PAID
        // and appears in the admin Assign tab. Without this the order
        // stays PENDING_PAYMENT forever and admin never sees it.
        debugPrint('>>> calling confirmCod for order ${createdOrder.orderId}');
        await _api.confirmCod(orderId: createdOrder.orderId);
        debugPrint('>>> confirmCod SUCCESS - order is now PAID');

        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed! Pay the driver on delivery.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        await _loadCart();
        return;
      }

      // ── PAY NOW ───────────────────────────────────────────────────
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentMethodScreen(order: createdOrder),
        ),
      );
      await _loadCart();
    } catch (e) {
      debugPrint('>>> checkout ERROR: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          IconButton(onPressed: _loadCart, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _cart == null || _cart!.items.isEmpty
          ? _buildEmptyCart()
          : _buildCartList(),
      bottomNavigationBar: _cart != null && _cart!.items.isNotEmpty
          ? _buildBottomBar()
          : null,
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
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cart!.items.length,
      itemBuilder: (ctx, i) {
        final item = _cart!.items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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

  Widget _buildBottomBar() {
    final subtotal = _cart!.getSubtotal();
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
                  'Total',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
                onPressed: _loading ? null : _checkout,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFFF6A00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Checkout Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
