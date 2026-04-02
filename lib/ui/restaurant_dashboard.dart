import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import 'payment_dashboard.dart';
import 'widgets/app_feedback.dart';

/// Restaurant browsing & menu selection dashboard
class RestaurantDashboard extends StatefulWidget {
  final User user;

  const RestaurantDashboard({super.key, required this.user});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  final _api = ApiClient();

  List<Store> _stores = const [];
  Store? _selectedStore;
  List<MenuItem> _menuItems = const [];
  List<CartItem> _cart = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stores = await _api.listStores();
      setState(() {
        _stores = stores;
        if (stores.isNotEmpty) {
          _selectedStore = stores.first;
        }
      });
      if (_selectedStore != null) {
        await _loadMenuForStore(_selectedStore!);
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMenuForStore(Store store) async {
    setState(() {
      _loading = true;
      _selectedStore = store;
      _cart = [];
    });
    try {
      final menu = await _api.getStoreMenu(storeId: store.id);
      setState(() => _menuItems = menu);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _addToCart(MenuItem item) {
    final idx = _cart.indexWhere((c) => c.productId == item.id);
    if (idx >= 0) {
      final existing = _cart[idx];
      _cart[idx] = CartItem(
        productId: existing.productId,
        name: existing.name,
        qty: existing.qty + 1,
        unitPrice: existing.unitPrice,
      );
    } else {
      _cart.add(
        CartItem(
          productId: item.id,
          name: item.name,
          qty: 1,
          unitPrice: item.price,
        ),
      );
    }
    setState(() {});
    AppFeedback.success(context, '${item.name} added to your cart');
  }

  int get _cartItemCount =>
      _cart.fold(0, (sum, c) => sum + c.qty);

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.qty * i.unitPrice);
  double get _deliveryFee => 2.50;
  double get _total => _subtotal + _deliveryFee;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _stores.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Food Rush')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading restaurants…',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Food Rush')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  'We couldn’t load restaurants',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loadStores,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Rush'),
        elevation: 1,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadStores,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Choose a restaurant',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Swipe sideways, then browse the menu below.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Stores list
                  if (_stores.isNotEmpty)
                    SizedBox(
                      height: 132,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _stores.length,
                        itemBuilder: (context, idx) {
                          final store = _stores[idx];
                          final isSelected = _selectedStore?.id == store.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: () => _loadMenuForStore(store),
                              child: Card(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white,
                                child: SizedBox(
                                  width: 98,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Icon(
                                          Icons.store,
                                          size: 28,
                                          color: isSelected ? Colors.white : null,
                                        ),
                                        Text(
                                          store.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Menu',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        if (_loading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  _menuItems.isEmpty && !_loading
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.restaurant_menu,
                                    size: 40,
                                    color: cs.outline,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No dishes here yet',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try another restaurant or pull to refresh.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : _menuItems.isEmpty
                      ? const SizedBox.shrink()
                      : GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: _menuItems.length,
                          itemBuilder: (context, idx) {
                            final item = _menuItems[idx];
                            return Card(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(18),
                                          topRight: Radius.circular(18),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.food_bank,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'LKR ${item.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton(
                                            onPressed: () => _addToCart(item),
                                            style: FilledButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                            ),
                                            child: const Text('Add to cart'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          // Cart summary and checkout button
          if (_cart.isNotEmpty)
            Material(
              elevation: 8,
              shadowColor: Colors.black26,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: cs.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cart · $_cartItemCount items',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'LKR ${_subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delivery',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'LKR ${_deliveryFee.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            'LKR ${_total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PaymentDashboard(
                                  user: widget.user,
                                  selectedStore: _selectedStore!,
                                  cartItems: _cart,
                                  subtotal: _subtotal,
                                  deliveryFee: _deliveryFee,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.lock_outline, size: 20),
                          label: const Text('Continue to checkout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

}
