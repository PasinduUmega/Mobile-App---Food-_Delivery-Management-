import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/cart_manager.dart';
import 'widgets/app_feedback.dart';
import 'auth_screen.dart';
import 'order_management_dashboard.dart';
import 'my_orders_screen.dart';
import 'payment_method_screen.dart';
import 'stores_crud_screen.dart';
import 'users_crud_screen.dart';

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
  late CartManager _cartManager;

  User? _user;
  List<Store> _stores = const [];
  Store? _selectedStore;
  List<MenuItem> _menuItems = const [];

  bool _loading = true;
  String? _error;

  double get _subtotal => _cartManager.subtotal;

  @override
  void initState() {
    super.initState();
    _cartManager = CartManager(api: _api);
    _cartManager.addListener(_onCartChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _cartManager.removeListener(_onCartChanged);
    _cartManager.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    setState(() {});
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

      // Initialize cart for current user if available
      if (widget.user != null) {
        await _cartManager.initializeCart(
          widget.user!.id,
          storeId: selected?.id,
        );
      }

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
    // Initialize cart for the new user
    _cartManager.initializeCart(user.id, storeId: _selectedStore?.id);
  }

  Future<void> _addToCart(MenuItem item) async {
    if (!_cartManager.hasCart) {
      if (!mounted) return;
      AppFeedback.error(context, 'Sign in first so we can save your cart.');
      return;
    }

    await _cartManager.addItem(
      productId: item.id,
      name: item.name,
      qty: 1,
      unitPrice: item.price,
    );

    if (!mounted) return;
    if (_cartManager.error != null) {
      AppFeedback.error(context, _cartManager.error!);
    } else {
      AppFeedback.success(context, '${item.name} added to your cart');
    }
  }

  Future<void> _removeFromCart(MenuItem item) async {
    if (!_cartManager.hasCart) return;

    final cart = _cartManager.cart;
    if (cart == null) return;

    final cartItem = cart.items.cast<DatabaseCartItem?>().firstWhere(
      (i) => i?.productId == item.id,
      orElse: () => null,
    );
    if (cartItem == null) return;

    if (cartItem.qty > 1) {
      await _cartManager.updateItem(cartItem.id, cartItem.qty - 1);
    } else {
      await _cartManager.removeItem(cartItem.id);
    }

    if (!mounted) return;
    if (_cartManager.error != null) {
      AppFeedback.error(context, _cartManager.error!);
    }
  }

  Future<void> _clearCart() async {
    if (!_cartManager.hasCart) return;
    await _cartManager.clearCart();
  }

  Future<void> _checkout() async {
    if (_user == null) {
      if (!mounted) return;
      AppFeedback.error(context, 'Sign in to place an order.');
      return;
    }
    if (_selectedStore == null) {
      if (!mounted) return;
      AppFeedback.error(context, 'Choose a restaurant first.');
      return;
    }
    if (!_cartManager.hasCart || (_cartManager.cart?.items.isEmpty ?? true)) {
      if (!mounted) return;
      AppFeedback.error(context, 'Add something to your cart to continue.');
      return;
    }

    const deliveryFee = 2.50;
    try {
      // Convert DatabaseCartItem to CartItem for API call
      final cart = _cartManager.cart!;
      final cartItems = cart.items
          .map(
            (item) => CartItem(
              productId: item.productId,
              name: item.name,
              qty: item.qty,
              unitPrice: item.unitPrice,
            ),
          )
          .toList();

      final order = await _api.createOrder(
        items: cartItems,
        deliveryFee: deliveryFee,
        currency: 'LKR',
        userId: _user!.id,
        storeId: _selectedStore!.id,
      );

      // Mark cart as checked out after successful order creation
      await _cartManager.checkoutCart();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PaymentMethodScreen(order: order)),
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Could not place order. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const deliveryFee = 2.50;
    final total = _subtotal + deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Rush'),
        actions: [
          IconButton(
            tooltip: 'Refresh menu',
            onPressed: _loading ? null : _loadInitialData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading restaurants…',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loadInitialData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _buildUserProfileCard(cs),
                const SizedBox(height: 16),
                _buildSectionHeader(
                  context,
                  title: 'Restaurants',
                  subtitle: 'Tap one to see its menu',
                ),
                const SizedBox(height: 8),
                _buildRestaurantSelector(),
                const SizedBox(height: 20),
                _buildSectionHeader(
                  context,
                  title: 'Menu',
                  subtitle: _selectedStore != null
                      ? 'From ${_selectedStore!.name}'
                      : 'Pick a restaurant above',
                ),
                const SizedBox(height: 8),
                if (_stores.isEmpty)
                  _buildEmptyHint(
                    context,
                    icon: Icons.storefront_outlined,
                    title: 'No restaurants yet',
                    detail: 'Check back soon or ask an admin to add stores.',
                  )
                else if (_menuItems.isEmpty)
                  _buildEmptyHint(
                    context,
                    icon: Icons.restaurant_menu,
                    title: 'No dishes here',
                    detail: 'This menu is empty. Try another restaurant.',
                  )
                else
                  ..._menuItems.map((item) {
                    final cartItem = _cartManager.cart?.items
                        .cast<DatabaseCartItem?>()
                        .firstWhere(
                          (ci) => ci?.productId == item.id,
                          orElse: () => null,
                        );
                    final qty = cartItem?.qty ?? 0;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'LKR ${item.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Remove one',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: qty > 0
                                  ? () => _removeFromCart(item)
                                  : null,
                            ),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$qty',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Add one',
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _addToCart(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                const Divider(height: 32),
                _buildCartSummary(cs, deliveryFee, total),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _checkout,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Go to checkout'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OrderManagementDashboard(),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Orders & tracking'),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    'Staff & tools',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  subtitle: Text(
                    'For admins — hidden from the main flow',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  children: [
                    OutlinedButton.icon(
                      onPressed: _user == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MyOrdersScreen(user: _user!),
                                ),
                              ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Payments (admin)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UsersCrudScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Users'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StoresCrudScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.store_mall_directory_outlined),
                      label: const Text('Restaurants (stores)'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyHint(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
            ),
          ],
        ),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _stores
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          selected: _selectedStore?.id == s.id,
                          label: Text(s.name),
                          onSelected: (selected) {
                            if (selected) {
                              _loadMenuForStore(s);
                            }
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(ColorScheme cs, double deliveryFee, double total) {
    final cart = _cartManager.cart;
    final items = cart?.items ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'Your cart',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                'Nothing added yet — use + on a dish below.',
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
              )
            else
              ...(items).map(
                (it) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${it.qty} × ${it.name}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        'LKR ${(it.qty * it.unitPrice).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Subtotal: LKR ${_subtotal.toStringAsFixed(2)}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            Text(
              'Delivery: LKR ${deliveryFee.toStringAsFixed(2)}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const Divider(height: 18),
            Text(
              'Total: LKR ${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: items.isEmpty ? null : _clearCart,
              child: const Text('Clear cart'),
            ),
          ],
        ),
      ),
    );
  }
}
