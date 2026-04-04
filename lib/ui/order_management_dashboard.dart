import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import 'order_tracking_screen.dart';

class OrderManagementDashboard extends StatefulWidget {
  /// When set, only orders for this owner’s stores are listed.
  final int? ownerUserId;

  const OrderManagementDashboard({super.key, this.ownerUserId});

  @override
  State<OrderManagementDashboard> createState() =>
      _OrderManagementDashboardState();
}

class _OrderManagementDashboardState extends State<OrderManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  List<OrderSummary> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await _api.listOrders(limit: 200);
      var list = orders;
      if (widget.ownerUserId != null) {
        final stores =
            await _api.listStores(ownerUserId: widget.ownerUserId);
        final ids = stores.map((s) => s.id).toSet();
        list = orders
            .where(
              (o) => o.storeId != null && ids.contains(o.storeId),
            )
            .toList();
      }
      if (mounted) {
        setState(() {
          _orders = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OrderEditDialog(api: _api),
    );
    if (res == true) _load();
  }

  Future<void> _edit(OrderSummary order) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OrderEditDialog(api: _api, existing: order),
    );
    if (res == true) _load();
  }

  Future<void> _updateStatus(OrderSummary order) async {
    final status = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Update Order Status'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        children:
            [
                  'PENDING_PAYMENT',
                  'PAID',
                  'PREPARING',
                  'READY',
                  'COMPLETED',
                  'CANCELLED',
                  'FAILED',
                ]
                .map(
                  (s) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        s,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
    if (status == null) return;
    try {
      await _api.updateOrder(id: order.orderId, status: status);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _delete(OrderSummary order) async {
    const protectedStatuses = ['PAID', 'COMPLETED', 'PREPARING', 'READY'];
    if (protectedStatuses.contains(order.status)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Protected status. Use CANCELLED or FAILED to delete.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Order?'),
        content: Text(
          'Are you sure you want to delete order #${order.orderId}?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteOrder(id: order.orderId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PAID':
      case 'COMPLETED':
        return const Color(0xFF11A36A);
      case 'PREPARING':
      case 'READY':
        return Colors.blue;
      case 'PENDING_PAYMENT':
        return const Color(0xFFFF6A00);
      case 'CANCELLED':
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ownerUserId != null
              ? 'Orders & carts (my stores)'
              : 'Orders & Cart Management',
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: widget.ownerUserId != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _loading ? null : _create,
              backgroundColor: const Color(0xFFFF6A00),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Order'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text('No orders found'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _orders.length,
              itemBuilder: (ctx, i) {
                final o = _orders[i];
                final statusColor = _getStatusColor(o.status);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _edit(o),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${o.orderId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  o.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                o.createdAt.toString().substring(0, 16),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${o.currency} ${o.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFFFF6A00),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _ActionButton(
                                icon: Icons.location_on_outlined,
                                color: Colors.blue,
                                label: 'Track',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OrderTrackingScreen(order: o),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _ActionButton(
                                icon: Icons.edit_note,
                                color: Colors.orange,
                                label: 'Edit',
                                onTap: () => _edit(o),
                              ),
                              const SizedBox(width: 8),
                              _ActionButton(
                                icon: Icons.sync,
                                color: cs.primary,
                                label: 'Status',
                                onTap: () => _updateStatus(o),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),
                                onPressed:
                                    [
                                      'PAID',
                                      'COMPLETED',
                                      'PREPARING',
                                      'READY',
                                    ].contains(o.status)
                                    ? null
                                    : () => _delete(o),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderEditDialog extends StatefulWidget {
  final OrderSummary? existing;
  final ApiClient api;

  const _OrderEditDialog({this.existing, required this.api});

  @override
  State<_OrderEditDialog> createState() => _OrderEditDialogState();
}

class _OrderEditDialogState extends State<_OrderEditDialog> {
  bool _loading = true;
  bool _submitting = false;

  List<User> _users = [];
  List<Store> _stores = [];
  List<MenuItem> _menuItems = [];

  int? _selectedUserId;
  int? _selectedStoreId;
  String _status = 'PENDING_PAYMENT';
  double? _deliveryLatitude;
  double? _deliveryLongitude;

  final List<Map<String, dynamic>> _cart = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final futures = await Future.wait([
        widget.api.listUsers(),
        widget.api.listStores(),
      ]);
      final users = futures[0] as List<User>;
      final stores = futures[1] as List<Store>;

      if (mounted) {
        setState(() {
          _users = users;
          _stores = stores;
          if (widget.existing == null) {
            _selectedUserId = users.isNotEmpty ? users.first.id : null;
            _selectedStoreId = stores.isNotEmpty ? stores.first.id : null;
          }
          _loading = false;
        });
      }

      if (widget.existing == null && _selectedStoreId != null) {
        await _loadMenu(_selectedStoreId!);
      }

      if (widget.existing != null) {
        _selectedUserId = widget.existing!.userId;
        _selectedStoreId = widget.existing!.storeId;
        _status = widget.existing!.status;
        await _loadExistingDetails(widget.existing!.orderId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to initialize: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadExistingDetails(int orderId) async {
    setState(() => _loading = true);
    try {
      final details = await widget.api.getOrderDetails(id: orderId);
      if (mounted) {
        setState(() {
          _cart.clear();
          if (details.items != null) {
            for (var it in details.items!) {
              _cart.add({
                'productId': it.productId,
                'name': it.name,
                'qty': it.qty,
                'unitPrice': it.unitPrice,
              });
            }
          }
          _loading = false;
        });
        if (_selectedStoreId != null) {
          _loadMenu(_selectedStoreId!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load details: $e')));
      }
    }
  }

  Future<void> _loadMenu(int storeId) async {
    try {
      final menu = await widget.api.getStoreMenu(storeId: storeId);
      if (mounted) setState(() => _menuItems = menu);
    } catch (_) {}
  }

  double get _subtotal => _cart.fold(
    0.0,
    (s, it) => s + (it['qty'] as int) * (it['unitPrice'] as double),
  );

  Future<void> _save() async {
    if (_selectedUserId == null) {
      _showError('Please select a user');
      return;
    }
    if (_selectedStoreId == null) {
      _showError('Please select a store');
      return;
    }
    if (_cart.isEmpty) {
      _showError('Cart is empty');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await widget.api.createOrder(
          userId: _selectedUserId!,
          storeId: _selectedStoreId!,
          items: _cart
              .map(
                (e) => CartItem(
                  productId: e['productId'] as int?,
                  name: e['name'] as String,
                  qty: e['qty'] as int,
                  unitPrice: e['unitPrice'] as double,
                ),
              )
              .toList(),
          deliveryFee: 200.0,
          currency: 'LKR',
          deliveryLatitude: null,
          deliveryLongitude: null,
        );
      } else {
        await widget.api.updateOrder(
          id: widget.existing!.orderId,
          status: _status,
          items: _cart,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showError(e.toString());
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _addMenuItemToCart(MenuItem item) {
    setState(() {
      final existingIndex = _cart.indexWhere((c) => c['productId'] == item.id);
      if (existingIndex >= 0) {
        _cart[existingIndex]['qty'] = (_cart[existingIndex]['qty'] as int) + 1;
      } else {
        _cart.add({
          'productId': item.id,
          'name': item.name,
          'qty': 1,
          'unitPrice': item.price,
        });
      }
    });
  }

  void _updateCartQty(int index, int delta) {
    setState(() {
      final currentQty = _cart[index]['qty'] as int;
      if (currentQty + delta <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index]['qty'] = currentQty + delta;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    final size = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: size.height * 0.92,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: _loading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isNew
                          ? 'New Order (Cart)'
                          : 'Edit Order #${widget.existing!.orderId}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<int>(
                              value: _users.any((u) => u.id == _selectedUserId)
                                  ? _selectedUserId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Customer',
                                prefixIcon: Icon(Icons.person_pin),
                              ),
                              items: _users
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u.id,
                                      child: Text(u.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isNew
                                  ? (v) => setState(() => _selectedUserId = v)
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            DropdownButtonFormField<int>(
                              value:
                                  _stores.any((s) => s.id == _selectedStoreId)
                                  ? _selectedStoreId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Store',
                                prefixIcon: Icon(Icons.storefront),
                              ),
                              items: _stores
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isNew
                                  ? (v) {
                                      setState(() {
                                        _selectedStoreId = v;
                                        _cart.clear();
                                        if (v != null) _loadMenu(v);
                                      });
                                    }
                                  : null,
                            ),

                            if (isNew) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        const Text(
                                          'Delivery Location',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_deliveryLatitude != null &&
                                        _deliveryLongitude != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          '${_deliveryLatitude!.toStringAsFixed(4)}, ${_deliveryLongitude!.toStringAsFixed(4)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Not selected',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],

                            if (!isNew) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value:
                                    [
                                      'PENDING_PAYMENT',
                                      'PAID',
                                      'PREPARING',
                                      'READY',
                                      'COMPLETED',
                                      'CANCELLED',
                                      'FAILED',
                                    ].contains(_status)
                                    ? _status
                                    : 'PENDING_PAYMENT',
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  prefixIcon: Icon(Icons.info_outline),
                                ),
                                items:
                                    [
                                          'PENDING_PAYMENT',
                                          'PAID',
                                          'PREPARING',
                                          'READY',
                                          'COMPLETED',
                                          'CANCELLED',
                                          'FAILED',
                                        ]
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => setState(() => _status = v!),
                              ),
                            ],

                            const Padding(
                              padding: EdgeInsets.only(top: 24, bottom: 8),
                              child: Text(
                                'CART ITEMS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            if (_cart.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Cart is empty. Add items below.',
                                  style: TextStyle(fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _cart.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (ctx, idx) {
                                  final it = _cart[idx];
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            it['name'],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _updateCartQty(idx, -1),
                                        ),
                                        Text('${it['qty']}'),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _updateCartQty(idx, 1),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'LKR ${(it['qty'] * it['unitPrice']).toStringAsFixed(0)}',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  _buildTotalRow(
                                    'Subtotal',
                                    'LKR ${_subtotal.toStringAsFixed(2)}',
                                    false,
                                  ),
                                  _buildTotalRow(
                                    'Delivery',
                                    'LKR 200.00',
                                    false,
                                  ),
                                  const Divider(color: Colors.white24),
                                  _buildTotalRow(
                                    'Total',
                                    'LKR ${(_subtotal + 200).toStringAsFixed(2)}',
                                    true,
                                  ),
                                ],
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.only(top: 24, bottom: 8),
                              child: Text(
                                'ADD FROM MENU',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            if (_selectedStoreId == null)
                              const Text('Select a store first')
                            else if (_menuItems.isEmpty)
                              const Text('No items in menu')
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _menuItems.length,
                                itemBuilder: (ctx, i) {
                                  final item = _menuItems[i];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text('LKR ${item.price}'),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.add_circle,
                                        color: Color(0xFFFF6A00),
                                      ),
                                      onPressed: () => _addMenuItemToCart(item),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _submitting ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6A00),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save Order'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, bool bold) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: bold ? const Color(0xFFFF6A00) : Colors.white,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
