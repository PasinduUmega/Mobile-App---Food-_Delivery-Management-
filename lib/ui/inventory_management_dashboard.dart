import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/validators.dart';

class InventoryManagementDashboard extends StatefulWidget {
  /// When set, only inventory rows for this owner’s stores are shown.
  final int? ownerUserId;
  final bool readOnly;
  /// When set, load and show stock only for this restaurant (multi-store owners).
  final int? initialStoreId;

  const InventoryManagementDashboard({
    super.key,
    this.ownerUserId,
    this.readOnly = false,
    this.initialStoreId,
  });

  @override
  State<InventoryManagementDashboard> createState() =>
      _InventoryManagementDashboardState();
}

class _InventoryManagementDashboardState
    extends State<InventoryManagementDashboard> {
  static const int _kLowStockThreshold = 5;

  final _api = ApiClient();
  bool _loading = false;
  List<InventoryItem> _inventory = [];
  String? _filterStoreLabel;
  /// Menu item id → current menu price (for retail value on balance sheet).
  Map<int, double> _itemPriceById = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var items = await _api.listInventory(storeId: widget.initialStoreId);
      String? storeLabel;
      final ownerId = widget.ownerUserId;
      if (ownerId != null) {
        final stores = await _api.listStores(ownerUserId: ownerId);
        final storeIds = stores.map((s) => s.id).toSet();
        items = items
            .where(
              (i) => i.storeId != null && storeIds.contains(i.storeId),
            )
            .toList();
        if (widget.initialStoreId != null) {
          try {
            storeLabel = stores
                .firstWhere((x) => x.id == widget.initialStoreId)
                .name;
          } catch (_) {
            storeLabel = null;
          }
        }
      } else if (widget.initialStoreId != null) {
        storeLabel = items.isNotEmpty
            ? (items.first.storeName ?? 'Store #${widget.initialStoreId}')
            : 'Store #${widget.initialStoreId}';
      }
      final prices = items.isEmpty
          ? <int, double>{}
          : await _loadMenuPrices(items);
      if (mounted) {
        setState(() {
          _inventory = items;
          _itemPriceById = prices;
          _filterStoreLabel = storeLabel;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<int, double>> _loadMenuPrices(List<InventoryItem> items) async {
    final storeIds = items.map((i) => i.storeId).whereType<int>().toSet();
    final prices = <int, double>{};
    for (final sid in storeIds) {
      try {
        final menu = await _api.getStoreMenu(storeId: sid);
        for (final m in menu) {
          prices[m.id] = m.price;
        }
      } catch (_) {}
    }
    return prices;
  }

  double _lineRetail(InventoryItem i) {
    return i.quantity * (_itemPriceById[i.menuItemId] ?? 0);
  }

  int get _totalUnits => _inventory.fold(0, (s, e) => s + e.quantity);

  double get _totalRetailValue =>
      _inventory.fold(0.0, (s, e) => s + _lineRetail(e));

  double get _atRiskRetailValue => _inventory
      .where((e) => e.quantity < _kLowStockThreshold)
      .fold(0.0, (s, e) => s + _lineRetail(e));

  List<InventoryItem> get _lossAlertItems {
    final list = _inventory
        .where((e) => e.quantity < _kLowStockThreshold)
        .toList();
    list.sort((a, b) => a.quantity.compareTo(b.quantity));
    return list;
  }

  String _titleWithStore(String base) {
    final label = _filterStoreLabel;
    if (label == null || label.isEmpty) return base;
    return '$base · $label';
  }

  Future<void> _updateQuantity(InventoryItem item) async {
    final ctrl = TextEditingController(text: item.quantity.toString());
    final newQty = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Adjust Stock: ${item.menuItemName ?? 'Item'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Quantity: ${item.quantity}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'New Stock Level',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  errorText: ctrl.text.isNotEmpty
                      ? Validators.validateNonNegativeInt(ctrl.text, 'Quantity')
                      : null,
                ),
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  ctrl.text.isNotEmpty &&
                      Validators.validateNonNegativeInt(
                            ctrl.text,
                            'Quantity',
                          ) ==
                          null
                  ? () => Navigator.pop(ctx, int.tryParse(ctrl.text))
                  : null,
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    if (newQty == null) return;
    try {
      await _api.updateInventory(id: item.id, quantity: newQty);
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(InventoryItem item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Tracking?'),
        content: Text(
          'Stop tracking stock for "${item.menuItemName}"? This won\'t delete the item itself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deleteInventory(id: item.id);
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _create() async {
    final stores = await _api.listStores(ownerUserId: widget.ownerUserId);
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddInventoryDialog(
        stores: stores,
        api: _api,
        preselectedStoreId: widget.initialStoreId,
      ),
    );

    if (result != null) {
      try {
        await _api.createInventory(
          menuItemId: result['menuItemId'],
          quantity: result['quantity'],
        );
        _load();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleWithStore(
            widget.readOnly
                ? 'Stock & Inventory (view only)'
                : 'Stock & Inventory',
          ),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: const Color(0xFFFF6A00),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Add Tracking'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          // ... (rest of build remains same, but I need to add the delete button to items)
          : CustomScrollView(
              slivers: [
                // Statistics
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total SKU',
                            _inventory.length.toString(),
                            Icons.inventory_2,
                            const Color(0xFFFF6A00),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Loss alerts',
                            _inventory
                                .where(
                                  (e) => e.quantity < _kLowStockThreshold,
                                )
                                .length
                                .toString(),
                            Icons.warning_amber_rounded,
                            Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_inventory.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _buildBalanceSheetCard(),
                    ),
                  ),

                if (_lossAlertItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _buildLossAlertsCard(),
                    ),
                  ),

                if (widget.initialStoreId != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Material(
                        color: const Color(0xFFFFF4ED),
                        borderRadius: BorderRadius.circular(16),
                        child: const ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.info_outline,
                            color: Color(0xFFFF6A00),
                          ),
                          title: Text(
                            'Per-restaurant stock',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Counts here apply to this location only. Open Stock & '
                            'Inventory from another restaurant in your fleet to manage it.',
                            style: TextStyle(fontSize: 12, height: 1.3),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Inventory List
                _inventory.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: Text('No inventory records found'),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                            final inv = _inventory[i];
                            final isLow = inv.quantity < _kLowStockThreshold;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: isLow
                                      ? Colors.redAccent.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.1),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color:
                                            (isLow
                                                    ? Colors.redAccent
                                                    : const Color(0xFFFF6A00))
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.fastfood_outlined,
                                        color: isLow
                                            ? Colors.redAccent
                                            : const Color(0xFFFF6A00),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            inv.menuItemName ??
                                                'Item #${inv.menuItemId}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            'Store: ${inv.storeName ?? 'Generic'}',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${inv.quantity}',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: isLow
                                                ? Colors.red
                                                : const Color(0xFF11A36A),
                                          ),
                                        ),
                                        Text(
                                          isLow ? 'LOW STOCK' : 'IN STOCK',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isLow
                                                ? Colors.red
                                                : const Color(0xFF11A36A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    if (!widget.readOnly) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_note,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () => _updateQuantity(inv),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _delete(inv),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }, childCount: _inventory.length),
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_outlined, color: Colors.grey[800], size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Balance sheet (retail)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Menu price × on-hand quantity. At-risk = value in lines that are low or out.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3),
            ),
            const SizedBox(height: 14),
            _balanceRow('Total units on hand', '$_totalUnits'),
            _balanceRow(
              'Est. retail value',
              'LKR ${_totalRetailValue.toStringAsFixed(2)}',
              emphasize: true,
            ),
            _balanceRow(
              'Value at risk (low / out of stock lines)',
              'LKR ${_atRiskRetailValue.toStringAsFixed(2)}',
              valueColor: const Color(0xFFE65100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceRow(
    String label,
    String value, {
    bool emphasize = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 16 : 14,
              fontWeight: FontWeight.w800,
              color: valueColor ?? const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLossAlertsCard() {
    final items = _lossAlertItems;
    return Card(
      elevation: 0,
      color: const Color(0xFFFFF5F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red[800], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Loss & stock alerts',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Below $_kLowStockThreshold units — restock to reduce lost sales.',
              style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.3),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (inv) => _lossAlertRow(inv),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lossAlertRow(InventoryItem inv) {
    final oos = inv.quantity <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: oos ? Colors.red : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              oos ? 'OUT' : 'LOW',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.menuItemName ?? 'Item #${inv.menuItemId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (inv.storeName != null)
                  Text(
                    inv.storeName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '× ${inv.quantity}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Color(0xFFC62828),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddInventoryDialog extends StatefulWidget {
  final List<Store> stores;
  final ApiClient api;
  final int? preselectedStoreId;
  const _AddInventoryDialog({
    required this.stores,
    required this.api,
    this.preselectedStoreId,
  });

  @override
  State<_AddInventoryDialog> createState() => _AddInventoryDialogState();
}

class _AddInventoryDialogState extends State<_AddInventoryDialog> {
  Store? _selectedStore;
  MenuItem? _selectedItem;
  List<MenuItem> _items = [];
  bool _loadingItems = false;
  final _qtyCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    final pre = widget.preselectedStoreId;
    if (pre != null) {
      for (final s in widget.stores) {
        if (s.id == pre) {
          _selectedStore = s;
          _loadItems(s);
          break;
        }
      }
    }
  }

  Future<void> _loadItems(Store store) async {
    setState(() {
      _loadingItems = true;
      _selectedItem = null;
    });
    try {
      final items = await widget.api.getStoreMenu(storeId: store.id);
      if (mounted)
        setState(() {
          _items = items;
          _loadingItems = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loadingItems = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Stock Tracking'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Store>(
              value: _selectedStore,
              decoration: const InputDecoration(labelText: 'Restaurant'),
              items: widget.stores
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (s) {
                if (s != null) {
                  setState(() => _selectedStore = s);
                  _loadItems(s);
                }
              },
            ),
            const SizedBox(height: 16),
            if (_loadingItems)
              const CircularProgressIndicator()
            else if (_items.isNotEmpty)
              DropdownButtonFormField<MenuItem>(
                value: _selectedItem,
                decoration: const InputDecoration(labelText: 'Menu Item'),
                items: _items
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                    .toList(),
                onChanged: (m) => setState(() => _selectedItem = m),
              )
            else if (_selectedStore != null)
              const Text(
                'No items found for this store',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Initial Quantity',
                hintText: 'Must be >= 0',
                errorText: _qtyCtrl.text.isNotEmpty
                    ? Validators.validateNonNegativeInt(
                        _qtyCtrl.text,
                        'Quantity',
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              (_selectedItem == null ||
                  _qtyCtrl.text.isEmpty ||
                  Validators.validateNonNegativeInt(
                        _qtyCtrl.text,
                        'Quantity',
                      ) !=
                      null)
              ? null
              : () {
                  Navigator.pop(context, {
                    'menuItemId': _selectedItem!.id,
                    'quantity': int.parse(_qtyCtrl.text),
                  });
                },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
