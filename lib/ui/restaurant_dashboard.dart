import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/cart_manager.dart';
import '../services/validators.dart';
import 'payment_dashboard.dart';
import 'widgets/app_feedback.dart';

/// Restaurant browsing & menu selection dashboard
class RestaurantDashboard extends StatefulWidget {
  final User user;
  final CartManager cartManager;

  const RestaurantDashboard({
    super.key,
    required this.user,
    required this.cartManager,
  });

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  final _api = ApiClient();

  List<Store> _stores = const [];
  Store? _selectedStore;
  List<MenuItem> _menuItems = const [];
  /// Menu item id → stock quantity (when inventory exists for the store).
  Map<int, int> _stockByMenuItemId = const {};

  bool _loading = true;
  String? _error;

  /// Browse specials for this calendar day (admin sets per menu item).
  late DateTime _specialsDay;
  bool _onlyShowSpecials = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _specialsDay = DateTime(n.year, n.month, n.day);
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
    final sameStore = _selectedStore?.id == store.id;
    setState(() {
      _loading = true;
      _selectedStore = store;
    });
    if (!sameStore) {
      await widget.cartManager.ensureActiveCartForStore(widget.user.id, store.id);
    }
    try {
      final menu = await _api.getStoreMenu(storeId: store.id);
      final inv = await _api.listInventory(storeId: store.id);
      final menuIds = menu.map((m) => m.id).toSet();
      final stock = <int, int>{};
      for (final row in inv) {
        if (menuIds.contains(row.menuItemId)) {
          stock[row.menuItemId] = row.quantity;
        }
      }
      setState(() {
        _menuItems = menu;
        _stockByMenuItemId = stock;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  int? _stockFor(MenuItem item) => _stockByMenuItemId[item.id];

  String? _stockHint(MenuItem item) {
    final q = _stockFor(item);
    if (q == null) return null;
    if (q <= 0) return 'Out of stock';
    if (q < 5) return '$q left · order soon';
    return 'In stock';
  }

  bool _isSpecialOnDay(MenuItem m, DateTime day) {
    final s = m.specialForDate;
    if (s == null) return false;
    return s.year == day.year && s.month == day.month && s.day == day.day;
  }

  List<MenuItem> get _menuForGrid {
    if (!_onlyShowSpecials) return _menuItems;
    return _menuItems
        .where((m) => _isSpecialOnDay(m, _specialsDay))
        .toList();
  }

  Future<void> _pickSpecialsDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _specialsDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _specialsDay = DateTime(d.year, d.month, d.day));
    }
  }

  String _formatDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _adjustCartLine(DatabaseCartItem line, int delta) async {
    final nextQty = line.qty + delta;
    if (nextQty <= 0) {
      await widget.cartManager.removeItem(line.id);
    } else {
      final stock = _stockByMenuItemId[line.productId];
      final qErr = Validators.validateCartLineQty(
        nextQty,
        maxStock: stock,
      );
      if (qErr != null) {
        if (mounted) AppFeedback.error(context, qErr);
        return;
      }
      await widget.cartManager.updateItem(
        line.id,
        nextQty,
        maxStock: stock,
      );
    }
    if (widget.cartManager.error != null && mounted) {
      AppFeedback.error(context, widget.cartManager.error!);
    }
  }

  Future<void> _addToCart(MenuItem item) async {
    if (item.price < 0) {
      AppFeedback.error(
        context,
        'This item has an invalid price and cannot be added.',
      );
      return;
    }
    final q = _stockFor(item);
    if (q != null && q <= 0) {
      AppFeedback.error(context, 'This item is out of stock.');
      return;
    }
    if (q != null) {
      DatabaseCartItem? existing;
      for (final e in widget.cartManager.cart?.items ?? const <DatabaseCartItem>[]) {
        if (e.productId == item.id) {
          existing = e;
          break;
        }
      }
      if (existing != null) {
        final addErr = Validators.validateCartLineQty(
          existing.qty + 1,
          maxStock: q,
        );
        if (addErr != null) {
          AppFeedback.error(context, addErr);
          return;
        }
      }
    }
    await widget.cartManager.addItem(
      productId: item.id,
      name: item.name,
      qty: 1,
      unitPrice: item.price,
    );
    if (widget.cartManager.error != null) {
      if (mounted) {
        AppFeedback.error(context, widget.cartManager.error!);
      }
      return;
    }
    if (mounted) {
      AppFeedback.success(context, '${item.name} added to your cart');
    }
  }

  // ignore: use_first_where - extension not available
  List<CartItem> get _orderLines {
    final items = widget.cartManager.cart?.items;
    if (items == null) return [];
    return items
        .map(
          (i) => CartItem(
            productId: i.productId,
            name: i.name,
            qty: i.qty,
            unitPrice: i.unitPrice,
            lineNote: i.lineNote,
          ),
        )
        .toList();
  }

  int get _cartItemCount => widget.cartManager.itemCount;

  String? get _cartError => Validators.validateCartSubtotal(_orderLines);

  double get _subtotal => widget.cartManager.subtotal;
  double get _deliveryFee => 2.50;
  double get _total => _subtotal + _deliveryFee;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _stores.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Home')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Finding restaurants near you…',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Home')),
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

    final addressLine = widget.user.address?.trim();
    final deliverTo =
        (addressLine != null && addressLine.isNotEmpty) ? addressLine : 'Add delivery address in profile';

    return ListenableBuilder(
      listenable: widget.cartManager,
      builder: (context, __) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Home'),
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
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_pin,
                              size: 22,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delivery · now',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    deliverTo,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.grey[600],
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Search dishes, cuisines, restaurants…',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'Restaurants',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                  // Stores list — large horizontal cards (Uber-style)
                  if (_stores.isNotEmpty)
                    SizedBox(
                      height: 196,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _stores.length,
                        itemBuilder: (context, idx) {
                          final store = _stores[idx];
                          final isSelected = _selectedStore?.id == store.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: GestureDetector(
                              onTap: () => _loadMenuForStore(store),
                              child: Container(
                                width: 210,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? cs.primary
                                        : cs.outlineVariant,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _StoreCardImage(
                                        imageUrl: store.imageUrl,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          8,
                                          10,
                                          8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              store.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                height: 1.2,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '25–40 min · LKR ${_deliveryFee.toStringAsFixed(0)} delivery',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_menuItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          tilePadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          title: Text(
                            'Daily specials (optional)',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Tap to filter — keep closed for a simpler home',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickSpecialsDay,
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                  ),
                                  label: Text(_formatDay(_specialsDay)),
                                ),
                                FilterChip(
                                  label: const Text('Only specials on this day'),
                                  selected: _onlyShowSpecials,
                                  onSelected: (v) =>
                                      setState(() => _onlyShowSpecials = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Menu',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
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
                      : _menuForGrid.isEmpty && !_loading
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No daily specials for ${_formatDay(_specialsDay)}. Choose another date or show the full menu.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        )
                      : _menuForGrid.isEmpty
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
                          itemCount: _menuForGrid.length,
                          itemBuilder: (context, idx) {
                            final item = _menuForGrid[idx];
                            final stockHint = _stockHint(item);
                            final out = _stockFor(item) != null &&
                                _stockFor(item)! <= 0;
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAEAEA),
                                      ),
                                      child: Icon(
                                        Icons.fastfood_outlined,
                                        size: 40,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_isSpecialOnDay(item, _specialsDay))
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              'Special ${_formatDay(_specialsDay)}',
                                              style: TextStyle(
                                                color: cs.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
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
                                        if (stockHint != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            stockHint,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: out
                                                  ? cs.error
                                                  : cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton(
                                            onPressed: out
                                                ? null
                                                : () => _addToCart(item),
                                            style: FilledButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                            ),
                                            child: Text(
                                              out ? 'Unavailable' : 'Add',
                                            ),
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
          // Cart summary and checkout button (synced to DB via [CartManager])
          if (_orderLines.isNotEmpty)
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
                      ...(widget.cartManager.cart?.items ?? const <DatabaseCartItem>[]).map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _adjustCartLine(c, -1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                '${c.qty}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _adjustCartLine(c, 1),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_cartError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _cartError!,
                          style: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
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
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _cartError != null ? cs.error : cs.onSurface,
                            ),
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
                          onPressed: (_cartError != null ||
                                  _selectedStore == null)
                              ? null
                              : () {
                                  final store = _selectedStore;
                                  if (store == null) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PaymentDashboard(
                                        user: widget.user,
                                        selectedStore: store,
                                        cartItems: _orderLines,
                                        subtotal: _subtotal,
                                        deliveryFee: _deliveryFee,
                                        cartManager: widget.cartManager,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                          label: const Text('Go to checkout'),
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
      },
    );
  }
}

/// Hero image on restaurant tiles (Uber Eats–style card top).
class _StoreCardImage extends StatelessWidget {
  final String? imageUrl;

  const _StoreCardImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE8E8E8),
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_rounded,
        size: 44,
        color: Colors.grey[500],
      ),
    );
  }
}

