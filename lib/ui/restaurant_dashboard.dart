import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import 'payment_dashboard.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to cart'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.qty * i.unitPrice);
  double get _deliveryFee => 2.50;
  double get _total => _subtotal + _deliveryFee;

  @override
  Widget build(BuildContext context) {
    if (_loading && _stores.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Restaurants')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Restaurants')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadStores, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Rush'),
        elevation: 1,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        children: [
          // Stores list
          if (_stores.isNotEmpty)
            SizedBox(
              height: 120,
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
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.store,
                                size: 32,
                                color: isSelected ? Colors.white : null,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 80,
                                child: Text(
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // Menu items
          Expanded(
            child: _menuItems.isEmpty
                ? const Center(child: Text('No items available'))
                : GridView.builder(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    '\$${item.price.toStringAsFixed(2)}',
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
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                      child: const Text('Add'),
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
          ),
          // Cart summary and checkout button
          if (_cart.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '\$${_subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Delivery:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '\$${_deliveryFee.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '\$${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PaymentDashboard(
                              user: _user,
                              selectedStore: _selectedStore!,
                              cartItems: _cart,
                              subtotal: _subtotal,
                              deliveryFee: _deliveryFee,
                            ),
                          ),
                        );
                      },
                      child: const Text('Proceed to Payment'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Placeholder - should be passed from parent
  User get _user => User(
    id: 0,
    name: 'Guest',
    email: 'guest@example.com',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
