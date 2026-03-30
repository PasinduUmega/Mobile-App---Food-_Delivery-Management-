import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';

class InventoryManagementDashboard extends StatefulWidget {
  const InventoryManagementDashboard({super.key});

  @override
  State<InventoryManagementDashboard> createState() => _InventoryManagementDashboardState();
}

class _InventoryManagementDashboardState extends State<InventoryManagementDashboard> {
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
      if (mounted) setState(() { _inventory = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateQuantity(InventoryItem item) async {
    final ctrl = TextEditingController(text: item.quantity.toString());
    final newQty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Stock: ${item.menuItemName ?? 'Item'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Quantity: ${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: 'New Stock Level', prefixIcon: Icon(Icons.inventory_2_outlined)),
              autofocus: true,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)), child: const Text('Update')),
        ],
      ),
    );
    if (newQty == null) return;
    try {
      await _api.updateInventory(id: item.id, quantity: newQty);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock & Inventory'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
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
                          _inventory.where((e) => e.quantity < 5).length.toString(), 
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
                ? const SliverFillRemaining(child: Center(child: Text('No inventory records found')))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final inv = _inventory[i];
                          final isLow = inv.quantity < 5;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: isLow ? Colors.redAccent.withOpacity(0.3) : Colors.grey.withOpacity(0.1)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: (isLow ? Colors.redAccent : const Color(0xFFFF6A00)).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.fastfood_outlined, 
                                      color: isLow ? Colors.redAccent : const Color(0xFFFF6A00),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          inv.menuItemName ?? 'Item #${inv.menuItemId}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          'Store: ${inv.storeName ?? 'Generic'}',
                                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${inv.quantity}',
                                        style: TextStyle(
                                          fontSize: 20, 
                                          fontWeight: FontWeight.w900, 
                                          color: isLow ? Colors.red : const Color(0xFF11A36A),
                                        ),
                                      ),
                                      Text(
                                        isLow ? 'LOW STOCK' : 'IN STOCK',
                                        style: TextStyle(
                                          fontSize: 9, 
                                          fontWeight: FontWeight.bold, 
                                          color: isLow ? Colors.red : const Color(0xFF11A36A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: Colors.blue),
                                    onPressed: () => _updateQuantity(inv),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _inventory.length,
                      ),
                    ),
                  ),
            ],
          ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
