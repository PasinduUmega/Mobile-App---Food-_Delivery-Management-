import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/validators.dart';
import 'menu_management_dashboard.dart';

class RestaurantManagementDashboard extends StatefulWidget {
  const RestaurantManagementDashboard({super.key});

  @override
  State<RestaurantManagementDashboard> createState() =>
      _RestaurantManagementDashboardState();
}

class _RestaurantManagementDashboardState
    extends State<RestaurantManagementDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  List<Store> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });
    try {
      final items = await _api.listStores();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await _showEditDialog();
    if (created == null) return;
    await _reload();
  }

  Future<void> _edit(Store s) async {
    final ok = await _showEditDialog(existing: s);
    if (ok == null) return;
    await _reload();
  }

  Future<void> _delete(Store s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete restaurant?'),
        content: Text('${s.name}'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deleteStore(id: s.id);
      _reload();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showEditDialog({Store? existing}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RestaurantEditDialog(existing: existing, api: _api),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Fleet'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: const Color(0xFFFF6A00),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Restaurant'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Top Statistics Grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Active Stores',
                            _items.length.toString(),
                            Icons.store,
                            const Color(0xFFFF6A00),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Avg Rating',
                            '4.8',
                            Icons.star,
                            Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Feature Status Table (From Screenshot)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'FLEET STATUS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          _buildStatusRow('Store CRUD', 'Completed', true),
                          _buildStatusRow('Menu Syncing', 'Completed', true),
                          _buildStatusRow('Status Toggles', 'Completed', true),
                          _buildStatusRow(
                            'Image Uploads',
                            'In Progress',
                            false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(top: 24)),

                // Restaurant Cards
                _items.isEmpty
                    ? SliverFillRemaining(
                        child: Center(child: Text('No restaurants registered')),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildRestaurantCard(_items[i]),
                            childCount: _items.length,
                          ),
                        ),
                      ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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

  Widget _buildStatusRow(String feature, String status, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            feature,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.sync,
                size: 12,
                color: completed
                    ? const Color(0xFF11A36A)
                    : const Color(0xFFFF6A00),
              ),
              const SizedBox(width: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: completed
                      ? const Color(0xFF11A36A)
                      : const Color(0xFFFF6A00),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(Store store) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Image/Icon
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              image: store.imageUrl != null && store.imageUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(store.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: store.imageUrl == null || store.imageUrl!.isEmpty
                ? Center(
                    child: Icon(
                      Icons.restaurant,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                  )
                : null,
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        store.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _edit(store),
                          icon: const Icon(
                            Icons.edit,
                            size: 14,
                            color: Color(0xFFFF6A00),
                          ),
                          label: const Text(
                            'EDIT',
                            style: TextStyle(
                              color: Color(0xFFFF6A00),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: const Color(
                              0xFFFF6A00,
                            ).withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _delete(store),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    const Text(
                      '4.8 (120+ ratings)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9FFF3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Color(0xFF11A36A),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (store.address != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      store.address!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),

                const Divider(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MenuManagementDashboard(),
                      ),
                    ),
                    icon: const Icon(Icons.restaurant_menu, size: 18),
                    label: const Text('MANAGE STORE MENU'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantEditDialog extends StatefulWidget {
  final Store? existing;
  final ApiClient api;
  const _RestaurantEditDialog({this.existing, required this.api});
  @override
  State<_RestaurantEditDialog> createState() => _RestaurantEditDialogState();
}

class _RestaurantEditDialogState extends State<_RestaurantEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  bool _submitting = false;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImage = image);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    final nameError = Validators.validateName(name);
    if (nameError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nameError)),
        );
      }
      return;
    }

    final addressParam = address.isEmpty ? null : address;
    final addressError = Validators.validateAddress(addressParam);
    if (addressError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(addressError)),
        );
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        final s = await widget.api.createStore(
          name: name,
          address: addressParam,
        );
        if (_selectedImage != null) {
          await widget.api.uploadStoreImage(
            storeId: s.id,
            imageBytes: await _selectedImage!.readAsBytes(),
            fileName: _selectedImage!.name,
          );
        }
      } else {
        await widget.api.updateStore(
          id: widget.existing!.id,
          name: name,
          address: addressParam,
        );
        if (_selectedImage != null) {
          await widget.api.uploadStoreImage(
            storeId: widget.existing!.id,
            imageBytes: await _selectedImage!.readAsBytes(),
            fileName: _selectedImage!.name,
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'New Restaurant' : 'Edit Profile',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 24),

            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(File(_selectedImage!.path)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImage == null
                    ? const Icon(Icons.add_a_photo, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Store Name',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
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
                        ? const CircularProgressIndicator(color: Colors.white)
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
