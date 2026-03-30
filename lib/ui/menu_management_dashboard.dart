import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';

class MenuManagementDashboard extends StatefulWidget {
  const MenuManagementDashboard({super.key});

  @override
  State<MenuManagementDashboard> createState() => _MenuManagementDashboardState();
}

class _MenuManagementDashboardState extends State<MenuManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  String? _error;
  List<Store> _stores = [];
  Store? _selectedStore;
  List<MenuItem> _menuItems = [];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stores = await _api.listStores();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        if (_stores.isNotEmpty) {
          _selectedStore = _stores.first;
          _loadMenu();
        } else {
          _loading = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMenu() async {
    if (_selectedStore == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _api.getStoreMenu(storeId: _selectedStore!.id);
      if (!mounted) return;
      setState(() { _menuItems = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _create() async {
    if (_selectedStore == null) return;
    final res = await _showEditDialog();
    if (res == true) _loadMenu();
  }

  Future<void> _edit(MenuItem item) async {
    final res = await _showEditDialog(existing: item);
    if (res == true) _loadMenu();
  }

  Future<void> _delete(MenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu Item?'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteMenuItem(id: item.id);
      _loadMenu();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showEditDialog({MenuItem? existing}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _MenuItemEditDialog(
        storeId: _selectedStore!.id,
        existing: existing,
        api: _api,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          IconButton(onPressed: _loadMenu, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedStore == null ? null : _create,
        backgroundColor: const Color(0xFFFF6A00),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<Store>(
              value: _selectedStore,
              decoration: const InputDecoration(labelText: 'Select Store', border: OutlineInputBorder()),
              items: _stores.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
              onChanged: (s) {
                setState(() { _selectedStore = s; });
                _loadMenu();
              },
            ),
          ),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Text(_error!))
                : _menuItems.isEmpty
                  ? const Center(child: Text('No menu items for this store'))
                  : ListView.builder(
                      itemCount: _menuItems.length,
                      itemBuilder: (ctx, i) {
                        final item = _menuItems[i];
                        return ListTile(
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item.description ?? 'No description'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('LKR ${item.price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF11A36A), fontWeight: FontWeight.bold)),
                              IconButton(onPressed: () => _edit(item), icon: const Icon(Icons.edit)),
                              IconButton(onPressed: () => _delete(item), icon: const Icon(Icons.delete, color: Colors.red)),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemEditDialog extends StatefulWidget {
  final int storeId;
  final MenuItem? existing;
  final ApiClient api;
  const _MenuItemEditDialog({required this.storeId, this.existing, required this.api});

  @override
  State<_MenuItemEditDialog> createState() => _MenuItemEditDialogState();
}

class _MenuItemEditDialogState extends State<_MenuItemEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _priceCtrl = TextEditingController(text: widget.existing?.price.toString() ?? '');
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    if (name.isEmpty || price <= 0) return;

    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await widget.api.createMenuItem(storeId: widget.storeId, name: name, price: price, description: desc);
      } else {
        await widget.api.updateMenuItem(id: widget.existing!.id, name: name, price: price, description: desc);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Menu Item' : 'Edit Menu Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description')),
          TextField(controller: _priceCtrl, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submitting ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
