import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models.dart';
import '../services/api.dart';
import 'auth_screen.dart';
import 'order_management_dashboard.dart';
import 'my_orders_screen.dart';
import 'payment_method_screen.dart';
import 'payments_crud_screen.dart';
import 'stores_crud_screen.dart';
import 'users_crud_screen.dart';

import 'location_picker_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  final User? user;
  final VoidCallback? onSignOut;
  final ValueChanged<bool>? onThemeChanged;

  const HomeScreen({super.key, this.user, this.onSignOut, this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient();

  User? _user;
  List<Store> _stores = const [];
  Store? _selectedStore;
  List<MenuItem> _menuItems = const [];
  List<CartItem> _cart = [];

  bool _loading = true;
  String? _error;

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.qty * i.unitPrice);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stores = await _api.listStores();
      final selected = stores.isNotEmpty ? stores.first : null;
      final List<MenuItem> menu = selected != null
          ? await _api.getStoreMenu(storeId: selected.id)
          : const [];
      setState(() {
        _stores = stores;
        _selectedStore = selected;
        _menuItems = menu;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadMenuForStore(Store store) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedStore = store;
      _cart = [];
    });
    try {
      final menu = await _api.getStoreMenu(storeId: store.id);
      setState(() {
        _menuItems = menu;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _setUser(User user) {
    setState(() {
      _user = user;
    });
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
  }

  void _removeFromCart(MenuItem item) {
    final idx = _cart.indexWhere((c) => c.productId == item.id);
    if (idx < 0) return;
    final existing = _cart[idx];
    if (existing.qty > 1) {
      _cart[idx] = CartItem(
        productId: existing.productId,
        name: existing.name,
        qty: existing.qty - 1,
        unitPrice: existing.unitPrice,
      );
    } else {
      _cart.removeAt(idx);
    }
    setState(() {});
  }

  void _clearCart() {
    setState(() {
      _cart = [];
    });
  }

  Future<void> _checkout() async {
    if (_user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
      return;
    }
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a restaurant')),
      );
      return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty')));
      return;
    }

    const deliveryFee = 2.50;
    try {
      Position? defaultPos;
      try {
        defaultPos = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      if (!mounted) return;
      final selectedLocation = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            initialLocation: defaultPos != null
                ? LatLng(defaultPos.latitude, defaultPos.longitude)
                : null,
          ),
        ),
      );

      if (selectedLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checkout cancelled: Please select a delivery location')),
          );
        }
        return;
      }

      final order = await _api.createOrder(
        items: _cart,
        deliveryFee: deliveryFee,
        currency: 'LKR',
        userId: _user!.id,
        storeId: _selectedStore!.id,
        deliveryLatitude: selectedLocation.latitude,
        deliveryLongitude: selectedLocation.longitude,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PaymentMethodScreen(order: order)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const deliveryFee = 2.50;
    final total = _subtotal + deliveryFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Food Rush')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 36,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _loadInitialData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildUserProfileCard(cs),
                const SizedBox(height: 12),
                _buildRestaurantSelector(),
                const SizedBox(height: 14),
                const Text(
                  'Menu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._menuItems
                    .map(
                      (item) => Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '\$${item.price.toStringAsFixed(2)} USD',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _removeFromCart(item),
                              ),
                              Text(
                                '${_cart.where((c) => c.productId == item.id).fold<int>(0, (sum, c) => sum + c.qty)}',
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _addToCart(item),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
                const Divider(height: 26),
                _buildCartSummary(cs, deliveryFee, total),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _checkout,
                  child: const Text('Checkout'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OrderManagementDashboard()),
                  ),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View My Orders & Track'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    if (_user != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MyOrdersScreen(user: _user!)),
                      );
                    }
                  },
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Payments CRUD (Admin)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UsersCrudScreen()),
                  ),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('User Management (CRUD)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StoresCrudScreen()),
                  ),
                  icon: const Icon(Icons.store_mall_directory_outlined),
                  label: const Text('Restaurant Management (CRUD)'),
                ),
              ],
            ),
    );
  }

  Widget _buildUserProfileCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(
                _user?.name.isNotEmpty == true
                    ? _user!.name[0].toUpperCase()
                    : '?',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user?.name ?? 'Guest',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user?.email ?? 'Please sign in',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () async {
                final user = await Navigator.of(context).push<User?>(
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(
                      onUserAuthenticated: (signedInUser) {
                        _setUser(signedInUser);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                );
                if (user != null) _setUser(user);
              },
              child: Text(_user == null ? 'Sign in/up' : 'Switch'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Restaurant',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButton<Store>(
              isExpanded: true,
              value: _selectedStore,
              items: _stores
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (store) {
                if (store != null) _loadMenuForStore(store);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(ColorScheme cs, double deliveryFee, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cart', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_cart.isEmpty)
              const Text('Cart is empty.')
            else
              ..._cart.map(
                (it) => Text(
                  '${it.qty} � ${it.name} = ${(it.qty * it.unitPrice).toStringAsFixed(2)}',
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Subtotal: \$${_subtotal.toStringAsFixed(2)}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            Text(
              'Delivery: \$${deliveryFee.toStringAsFixed(2)}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const Divider(height: 18),
            Text(
              'Total: \$${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _cart.isEmpty ? null : _clearCart,
              child: const Text('Clear cart'),
            ),
          ],
        ),
      ),
    );
  }
}
