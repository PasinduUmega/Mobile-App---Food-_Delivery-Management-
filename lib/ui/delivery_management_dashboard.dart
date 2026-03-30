import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import 'delivery_map_screen.dart';

class DeliveryManagementDashboard extends StatefulWidget {
  const DeliveryManagementDashboard({super.key});

  @override
  State<DeliveryManagementDashboard> createState() => _DeliveryManagementDashboardState();
}

class _DeliveryManagementDashboardState extends State<DeliveryManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  List<DeliveryInfo> _deliveries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.listDeliveries();
      if (mounted) setState(() { _deliveries = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final res = await _showEditDialog();
    if (res == true) _load();
  }

  Future<void> _edit(DeliveryInfo delivery) async {
    final res = await _showEditDialog(existing: delivery);
    if (res == true) _load();
  }

  Future<void> _delete(DeliveryInfo delivery) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Delivery?'),
        content: Text('Are you sure you want to delete delivery for order #${delivery.orderId}?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteDelivery(id: delivery.id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showEditDialog({DeliveryInfo? existing}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DeliveryEditDialog(existing: existing, api: _api),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DELIVERED':
        return const Color(0xFF11A36A);
      case 'OUT_FOR_DELIVERY':
      case 'PICKED_UP':
        return Colors.blue;
      case 'PENDING':
        return const Color(0xFFFF6A00);
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery & Logistics'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: const Color(0xFFFF6A00),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Delivery'),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : _deliveries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delivery_dining_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No deliveries tracked yet'),
                ],
              ),
            )
          : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: _deliveries.length,
            itemBuilder: (ctx, i) {
              final d = _deliveries[i];
              final statusColor = _getStatusColor(d.status);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _edit(d),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6A00).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delivery_dining, color: Color(0xFFFF6A00)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${d.orderId}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Driver: ${d.driverName ?? 'Unassigned'}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                d.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final order = await _api.getOrderDetails(id: d.orderId);
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DeliveryMapScreen(delivery: d, order: order)),
                                  );
                                }
                              },
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('Live Map'),
                              style: TextButton.styleFrom(foregroundColor: Colors.green),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _edit(d),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _delete(d),
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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

class _DeliveryEditDialog extends StatefulWidget {
  final DeliveryInfo? existing;
  final ApiClient api;
  const _DeliveryEditDialog({this.existing, required this.api});

  @override
  State<_DeliveryEditDialog> createState() => _DeliveryEditDialogState();
}

class _DeliveryEditDialogState extends State<_DeliveryEditDialog> {
  late final TextEditingController _driverNameCtrl;
  late final TextEditingController _driverPhoneCtrl;
  String _status = 'PENDING';
  int? _selectedOrderId;
  bool _loading = false;
  bool _submitting = false;
  List<OrderSummary> _availableOrders = [];

  @override
  void initState() {
    super.initState();
    _driverNameCtrl = TextEditingController(text: widget.existing?.driverName ?? '');
    _driverPhoneCtrl = TextEditingController(text: widget.existing?.driverPhone ?? '');
    _status = widget.existing?.status ?? 'PENDING';
    _selectedOrderId = widget.existing?.orderId;
    
    // Ensure the status is valid
    const validStatuses = ['PENDING', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED'];
    if (!validStatuses.contains(_status)) {
      _status = 'PENDING';
    }

    if (widget.existing == null) {
      _loadAvailableOrders();
    }
  }

  Future<void> _loadAvailableOrders() async {
    setState(() => _loading = true);
    try {
      // Fetch orders that are PAID or PREPARING and don't have a delivery yet
      final allOrders = await widget.api.listOrders();
      final allDeliveries = await widget.api.listDeliveries();
      final deliveredOrderIds = allDeliveries.map((e) => e.orderId).toSet();

      if (mounted) {
        setState(() {
          _availableOrders = allOrders.where((o) {
            return (o.status == 'PAID' || o.status == 'PREPARING' || o.status == 'READY') &&
                   !deliveredOrderIds.contains(o.orderId);
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an Order')));
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await widget.api.createDelivery(
          orderId: _selectedOrderId!,
          driverName: _driverNameCtrl.text.trim(),
          driverPhone: _driverPhoneCtrl.text.trim(),
        );
      } else {
        await widget.api.updateDelivery(
          id: widget.existing!.id,
          status: _status,
          driverName: _driverNameCtrl.text.trim(),
          driverPhone: _driverPhoneCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading 
          ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isNew ? 'Create Delivery' : 'Edit Delivery',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                if (isNew) ...[
                  if (_availableOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No orders are currently awaiting delivery assignment.', style: TextStyle(color: Colors.redAccent)),
                    )
                  else
                    DropdownButtonFormField<int>(
                      value: _selectedOrderId,
                      decoration: const InputDecoration(labelText: 'Select Order', prefixIcon: Icon(Icons.shopping_bag_outlined)),
                      items: _availableOrders.map((o) => DropdownMenuItem(
                        value: o.orderId,
                        child: Text('Order #${o.orderId} (${o.status})'),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedOrderId = v),
                    ),
                  const SizedBox(height: 16),
                ] else ...[
                  Text('Order #${widget.existing!.orderId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _driverNameCtrl, 
                  decoration: const InputDecoration(labelText: 'Driver Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _driverPhoneCtrl, 
                  decoration: const InputDecoration(labelText: 'Driver Phone', prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Delivery Status', prefixIcon: Icon(Icons.info_outline)),
                  items: ['PENDING', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
                
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _submitting ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting || (isNew && _availableOrders.isEmpty) ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6A00),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _submitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                          : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ),
    );
  }
}
