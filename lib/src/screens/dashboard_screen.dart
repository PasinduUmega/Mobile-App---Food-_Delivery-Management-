import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/menu_item.dart';
import '../services/api_service.dart';
import '../widgets/menu_item_form_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  List<MenuItemModel> _items = [];
  bool _loading = true;
  String? _errorMessage;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectRealtime();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final items = await _apiService.getMenuItems();
      if (!mounted) {
        return;
      }
      setState(() => _items = items);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = 'Could not load menu items.');
    } finally {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  void _connectRealtime() {
    _channel = _apiService.connectRealtime();
    _wsSubscription = _channel!.stream.listen((event) {
      final data = jsonDecode(event as String) as Map<String, dynamic>;
      if (data['type'] == 'menu-updated') {
        _loadData();
      }
    });
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<MenuItemModel>(
      context: context,
      builder: (_) => const MenuItemFormDialog(),
    );
    if (result == null) {
      return;
    }

    await _apiService.createMenuItem(
      name: result.name,
      category: result.category,
      price: result.price,
      available: result.available,
    );
    await _loadData();
  }

  Future<void> _openEditDialog(MenuItemModel item) async {
    final result = await showDialog<MenuItemModel>(
      context: context,
      builder: (_) => MenuItemFormDialog(initialItem: item),
    );
    if (result == null) {
      return;
    }

    await _apiService.updateMenuItem(result.copyWith(id: item.id));
    await _loadData();
  }

  Future<void> _deleteItem(MenuItemModel item) async {
    await _apiService.deleteMenuItem(item.id);
    await _loadData();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Rush - Restaurant Management'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        label: const Text('Add Item'),
        icon: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('No menu items. Add your first item.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            child: ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${item.category} • LKR ${item.price.toStringAsFixed(2)} • '
                '${item.available ? "Available" : "Out of Stock"}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _openEditDialog(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteItem(item),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
