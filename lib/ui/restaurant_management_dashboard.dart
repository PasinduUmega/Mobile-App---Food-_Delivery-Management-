import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/pdf_service.dart';
import '../services/validators.dart';
import 'menu_management_dashboard.dart';

class RestaurantManagementDashboard extends StatefulWidget {
  /// When set, only stores owned by this user are listed and new stores are assigned to them.
  final int? ownerUserId;
  final bool readOnly;

  const RestaurantManagementDashboard({
    super.key,
    this.ownerUserId,
    this.readOnly = false,
  });

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
      final items =
          await _api.listStores(ownerUserId: widget.ownerUserId);
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

  Future<void> _downloadFleetPdf() async {
    if (_items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No restaurants to export yet')),
        );
      }
      return;
    }
    try {
      await PdfService.generateRestaurantFleetPdf(
        stores: _items,
        titleSuffix: widget.ownerUserId != null ? 'My fleet' : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _showStoreDetailsSheet(Store store) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  store.name,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ID #${store.id}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow(ctx, 'Address', store.address ?? '—'),
                _detailRow(
                  ctx,
                  'Location',
                  store.latitude != null && store.longitude != null
                      ? '${store.latitude}, ${store.longitude}'
                      : '—',
                ),
                if (store.ownerUserId != null)
                  _detailRow(ctx, 'Owner user ID', '${store.ownerUserId}'),
                _detailRow(
                  ctx,
                  'Updated',
                  store.updatedAt.toString().substring(0, 16),
                ),
                if (store.imageUrl != null && store.imageUrl!.isNotEmpty)
                  _detailRow(ctx, 'Image', store.imageUrl!),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await PdfService.generateStoreDetailsPdf(store);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Download as PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showEditDialog({Store? existing}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RestaurantEditDialog(
        existing: existing,
        api: _api,
        defaultOwnerUserId: widget.ownerUserId,
        peerStores: _items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.readOnly
              ? 'Restaurant dashboard (view only)'
              : 'Restaurant dashboard',
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _downloadFleetPdf,
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download fleet report (PDF)',
          ),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.small(
              onPressed: _create,
              tooltip: 'Add restaurant',
              backgroundColor: const Color(0xFFFF6A00),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add, size: 20),
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
                            'Restaurants',
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
                          _buildStatusRow(
                            'Per-store inventory',
                            'Active',
                            true,
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
                const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
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
                        IconButton(
                          onPressed: () => _showStoreDetailsSheet(store),
                          icon: const Icon(Icons.info_outline, size: 20),
                          tooltip: 'Details & download',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.withOpacity(0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (!widget.readOnly) ...[
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

                Tooltip(
                  message: 'Edit dishes and prices for this store',
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MenuManagementDashboard(
                            ownerUserId: widget.ownerUserId,
                            initialStoreId: store.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.restaurant_menu, size: 16),
                      label: const Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
  final int? defaultOwnerUserId;
  /// Other locations for the same owner — used to enforce unique names in the fleet.
  final List<Store> peerStores;

  const _RestaurantEditDialog({
    this.existing,
    required this.api,
    this.defaultOwnerUserId,
    required this.peerStores,
  });
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
    _nameCtrl.addListener(() => setState(() {}));
  }

  String? _duplicateNameError(String name) {
    final t = name.trim();
    if (t.isEmpty) return null;
    final key = t.toLowerCase();
    for (final s in widget.peerStores) {
      if (widget.existing != null && s.id == widget.existing!.id) continue;
      if (s.name.trim().toLowerCase() == key) {
        return 'You already have a restaurant with this name';
      }
    }
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImage = image);
  }

  String? _nameFieldError() {
    final v = Validators.validateName(_nameCtrl.text);
    if (v != null) return v;
    return _duplicateNameError(_nameCtrl.text);
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
    final dup = _duplicateNameError(name);
    if (dup != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dup)),
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
          ownerUserId: widget.defaultOwnerUserId,
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
              decoration: InputDecoration(
                labelText: 'Store Name',
                prefixIcon: const Icon(Icons.store),
                helperText: 'Must be unique among your restaurants',
                errorText: _nameCtrl.text.isNotEmpty ? _nameFieldError() : null,
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
                    onPressed: (_submitting || _nameFieldError() != null)
                        ? null
                        : _save,
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
