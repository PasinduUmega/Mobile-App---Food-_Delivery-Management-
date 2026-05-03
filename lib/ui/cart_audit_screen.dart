import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';

/// Admin: shows all [carts] rows from MySQL (with line_count) so past carts stay visible
/// after the app marks them ABANDONED without deleting [cart_items] lines.
class CartAuditScreen extends StatefulWidget {
  const CartAuditScreen({super.key});

  @override
  State<CartAuditScreen> createState() => _CartAuditScreenState();
}

class _CartAuditScreenState extends State<CartAuditScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _error;
  List<CartAuditRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listCartsAudit(limit: 300);
      if (mounted) {
        setState(() {
          _rows = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carts (database audit)'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _rows.isEmpty
          ? const Center(
              child: Text('No cart rows in the database yet'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = _rows[i];
                return Card(
                  child: ListTile(
                    isThreeLine: true,
                    title: Text(
                      'Cart #${r.id} · user ${r.userId}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Store: ${r.storeId ?? "—"}\n'
                      'Status: ${r.status} · lines in DB: ${r.lineCount}\n'
                      'Created: ${r.createdAt.toString().substring(0, 16)}',
                    ),
                    trailing: Icon(
                      r.status == 'ACTIVE' ? Icons.shopping_cart : Icons.archive_outlined,
                      color: r.status == 'ACTIVE'
                          ? const Color(0xFFFF6A00)
                          : Colors.grey,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
