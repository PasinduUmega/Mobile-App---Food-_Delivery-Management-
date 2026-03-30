import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import 'order_tracking_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  final User user;
  const MyOrdersScreen({super.key, required this.user});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _api = ApiClient();
  bool _loading = true;
  List<OrderSummary> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.listOrders();
      // Filter for current user only
      if (mounted) {
        setState(() {
          _orders = items.where((o) => o.userId == widget.user.id).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('You have no orders yet.'))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (ctx, i) {
                    final o = _orders[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Text('#${o.orderId}', style: const TextStyle(fontSize: 10)),
                        ),
                        title: Text('Status: ${o.status}'),
                        subtitle: Text('Total: ${o.currency} ${o.total.toStringAsFixed(2)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.location_on, color: Colors.blue),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: o)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
