import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/validators.dart';

class StoresCrudScreen extends StatefulWidget {
  const StoresCrudScreen({super.key});

  @override
  State<StoresCrudScreen> createState() => _StoresCrudScreenState();
}

class _StoresCrudScreenState extends State<StoresCrudScreen> {
  final _api = ApiClient();
  bool _loading = false;
  String? _error;
  List<Store> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listStores();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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
        title: const Text('Delete store?'),
        content: Text('${s.name}${s.address != null ? ' - ${s.address}' : ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deleteStore(id: s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showEditDialog({Store? existing}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _StoreEditDialog(existing: existing, api: _api),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stores (CRUD)'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _create,
        backgroundColor: const Color(0xFFFF6A00),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 34),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _items.isEmpty
          ? const Center(child: Text('No stores yet. Tap + to create one.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = _items[i];
                return Card(
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text(s.address ?? ''),
                    onTap: () => _edit(s),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _edit(s);
                        if (v == 'delete') _delete(s);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StoreEditDialog extends StatefulWidget {
  final Store? existing;
  final ApiClient api;

  const _StoreEditDialog({this.existing, required this.api});

  @override
  State<_StoreEditDialog> createState() => _StoreEditDialogState();
}

class _StoreEditDialogState extends State<_StoreEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _latCtrl = TextEditingController(text: s?.latitude?.toString() ?? '');
    _lngCtrl = TextEditingController(text: s?.longitude?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  String? _validateForm() {
    final name = _nameCtrl.text;
    final address = _addressCtrl.text;
    final lat = _latCtrl.text;
    final lng = _lngCtrl.text;

    // Validate name
    var error = Validators.validateName(name);
    if (error != null) return error;

    // Validate address if provided
    error = Validators.validateAddress(address);
    if (error != null) return error;

    // Validate latitude if provided
    error = Validators.validateLatitude(lat.isEmpty ? null : lat);
    if (error != null) return error;

    // Validate longitude if provided
    error = Validators.validateLongitude(lng.isEmpty ? null : lng);
    if (error != null) return error;

    return null;
  }

  Future<void> _submit() async {
    final validationError = _validateForm();
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);

    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await widget.api.createStore(
          name: name,
          address: address.isEmpty ? null : address,
          latitude: lat,
          longitude: lng,
        );
      } else {
        await widget.api.updateStore(
          id: widget.existing!.id,
          name: name,
          address: address.isEmpty ? null : address,
          latitude: lat,
          longitude: lng,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Create store' : 'Edit store'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Store name (min 2 chars)',
              errorText: _nameCtrl.text.isNotEmpty
                  ? Validators.validateName(_nameCtrl.text)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _addressCtrl,
            decoration: InputDecoration(
              labelText: 'Address',
              hintText: 'Full address (optional)',
              errorText: _addressCtrl.text.isNotEmpty
                  ? Validators.validateAddress(_addressCtrl.text)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latCtrl,
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    hintText: '-90 to 90',
                    errorText: _latCtrl.text.isNotEmpty
                        ? Validators.validateLatitude(_latCtrl.text)
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _lngCtrl,
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    hintText: '-180 to 180',
                    errorText: _lngCtrl.text.isNotEmpty
                        ? Validators.validateLongitude(_lngCtrl.text)
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
