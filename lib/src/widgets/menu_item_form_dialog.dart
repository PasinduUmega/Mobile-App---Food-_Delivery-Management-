import 'package:flutter/material.dart';

import '../models/menu_item.dart';

class MenuItemFormDialog extends StatefulWidget {
  const MenuItemFormDialog({super.key, this.initialItem});

  final MenuItemModel? initialItem;

  @override
  State<MenuItemFormDialog> createState() => _MenuItemFormDialogState();
}

class _MenuItemFormDialogState extends State<MenuItemFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  bool _available = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialItem?.name ?? '');
    _categoryController = TextEditingController(
      text: widget.initialItem?.category ?? '',
    );
    _priceController = TextEditingController(
      text: widget.initialItem?.price.toString() ?? '',
    );
    _available = widget.initialItem?.available ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialItem == null ? 'Add Menu Item' : 'Edit Menu Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            SwitchListTile(
              title: const Text('Available'),
              value: _available,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _available = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final price = double.tryParse(_priceController.text.trim());
            if (_nameController.text.trim().isEmpty ||
                _categoryController.text.trim().isEmpty ||
                price == null) {
              return;
            }

            final item = MenuItemModel(
              id: widget.initialItem?.id ?? 0,
              name: _nameController.text.trim(),
              category: _categoryController.text.trim(),
              price: price,
              available: _available,
            );

            Navigator.pop(context, item);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
