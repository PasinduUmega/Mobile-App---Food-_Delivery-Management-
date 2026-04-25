import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';

class DriverFeedbackScreen extends StatefulWidget {
  /// The driver to rate
  final DeliveryInfo delivery;
  final int customerId;

  const DriverFeedbackScreen({
    super.key,
    required this.delivery,
    required this.customerId,
  });

  @override
  State<DriverFeedbackScreen> createState() => _DriverFeedbackScreenState();
}

class _DriverFeedbackScreenState extends State<DriverFeedbackScreen> {
  final _api = ApiClient();
  int _rating = 5;
  String? _category;
  final _feedbackCtrl = TextEditingController();
  bool _anonymous = false;
  bool _submitting = false;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<int?> _resolveDriverUserId() async {
    final phone = (widget.delivery.driverPhone ?? '').trim();
    final name = (widget.delivery.driverName ?? '').trim().toLowerCase();
    final drivers = await _api.listDrivers(limit: 500);
    for (final d in drivers) {
      final dPhone = (d.phone ?? '').trim();
      final dName = d.name.trim().toLowerCase();
      if (phone.isNotEmpty && dPhone == phone) return d.id;
      if (name.isNotEmpty && dName == name) return d.id;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final driverUserId = await _resolveDriverUserId();
      if (driverUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not match this delivery to a driver account'),
            ),
          );
        }
        return;
      }
      await _api.createDriverRating(
        driverId: driverUserId,
        orderId: widget.delivery.orderId,
        customerId: widget.customerId,
        rating: _rating,
        feedback: _feedbackCtrl.text.trim().isEmpty
            ? null
            : _feedbackCtrl.text.trim(),
        category: _category,
        isAnonymous: _anonymous,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final driverName = widget.delivery.driverName ?? 'Driver';

    return Scaffold(
      appBar: AppBar(title: const Text('Rate Your Driver'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: cs.primary,
                      child: Text(
                        driverName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (widget.delivery.driverPhone != null)
                            Text(
                              widget.delivery.driverPhone!,
                              style: TextStyle(fontSize: 12, color: cs.outline),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Rating Section
            Text(
              'How would you rate your delivery experience?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final starIndex = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.star,
                            size: 48,
                            color: starIndex <= _rating
                                ? Colors.amber
                                : cs.outline.withValues(alpha: 0.3),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRatingLabel(_rating),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Category Selection
            Text(
              'What did you want to rate?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                        'Delivery Speed',
                        'Politeness',
                        'Vehicle Condition',
                        'Accuracy',
                      ]
                      .map(
                        (cat) => FilterChip(
                          label: Text(cat),
                          selected: _category == cat,
                          onSelected: (selected) {
                            setState(() => _category = selected ? cat : null);
                          },
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 24),

            // Feedback Text
            Text(
              'Additional feedback (optional)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _feedbackCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Anonymous Checkbox
            CheckboxListTile(
              dense: true,
              title: const Text('Submit feedback anonymously'),
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v ?? false),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _submitting ? 'Submitting...' : 'Submit Feedback',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}

/// Simplified dialog version for inline feedback collection
class DriverFeedbackDialog extends StatefulWidget {
  final DeliveryInfo delivery;
  final int customerId;
  final VoidCallback? onSuccess;

  const DriverFeedbackDialog({
    super.key,
    required this.delivery,
    required this.customerId,
    this.onSuccess,
  });

  @override
  State<DriverFeedbackDialog> createState() => _DriverFeedbackDialogState();
}

class _DriverFeedbackDialogState extends State<DriverFeedbackDialog> {
  final _api = ApiClient();
  int _rating = 4;
  String? _category;
  final _feedbackCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<int?> _resolveDriverUserId() async {
    final phone = (widget.delivery.driverPhone ?? '').trim();
    final name = (widget.delivery.driverName ?? '').trim().toLowerCase();
    final drivers = await _api.listDrivers(limit: 500);
    for (final d in drivers) {
      final dPhone = (d.phone ?? '').trim();
      final dName = d.name.trim().toLowerCase();
      if (phone.isNotEmpty && dPhone == phone) return d.id;
      if (name.isNotEmpty && dName == name) return d.id;
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final driverUserId = await _resolveDriverUserId();
      if (driverUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not match this delivery to a driver account'),
            ),
          );
        }
        return;
      }
      await _api.createDriverRating(
        driverId: driverUserId,
        orderId: widget.delivery.orderId,
        customerId: widget.customerId,
        rating: _rating,
        feedback: _feedbackCtrl.text.trim().isEmpty
            ? null
            : _feedbackCtrl.text.trim(),
        category: _category,
      );

      if (mounted) {
        Navigator.pop(context, true);
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Rate Your Delivery'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How was your experience with the delivery driver?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = starIndex),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.star,
                        size: 32,
                        color: starIndex <= _rating
                            ? Colors.amber
                            : cs.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _feedbackCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Any feedback? (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Submitting...' : 'Submit'),
        ),
      ],
    );
  }
}
