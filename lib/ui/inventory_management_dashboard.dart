import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/validators.dart';

class InventoryManagementDashboard extends StatefulWidget {
  const InventoryManagementDashboard({super.key});

  @override
  State<InventoryManagementDashboard> createState() =>
      _InventoryManagementDashboardState();
}

class _InventoryManagementDashboardState
    extends State<InventoryManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  List<InventoryItem> _inventory = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.listInventory();
      if (mounted)
        setState(() {
          _inventory = items;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
    final stores = await _api.listStores();
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddInventoryDialog(stores: stores, api: _api),
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
        title: const Text('Stock & Inventory'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
                            'Low Stock',
                            _inventory
                                .where((e) => e.quantity < 5)
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
                            final isLow = inv.quantity < 5;
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
}

class _AddInventoryDialog extends StatefulWidget {
  final List<Store> stores;
  final ApiClient api;
  const _AddInventoryDialog({required this.stores, required this.api});

  @override
  State<_AddInventoryDialog> createState() => _AddInventoryDialogState();
}

class _AddInventoryDialogState extends State<_AddInventoryDialog> {
  Store? _selectedStore;
  MenuItem? _selectedItem;
  List<MenuItem> _items = [];
  bool _loadingItems = false;
  final _qtyCtrl = TextEditingController(text: '0');

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
