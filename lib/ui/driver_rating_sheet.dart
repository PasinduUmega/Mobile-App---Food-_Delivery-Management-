import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
// test change

/// Call this from any screen where order.status == 'COMPLETED'.
///
/// Example:
/// ```dart
/// await showDriverRatingSheet(
///   context,
///   orderId: order.orderId,
///   driverId: delivery.driverUserId,   // the driver's user ID
///   driverName: delivery.driverName ?? 'Your driver',
///   customerId: currentUser.id,
/// );
/// ```
Future<void> showDriverRatingSheet(
  BuildContext context, {
  required int orderId,
  required int driverId,
  required String driverName,
  int? customerId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DriverRatingSheet(
      orderId: orderId,
      driverId: driverId,
      driverName: driverName,
      customerId: customerId,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal sheet widget
// ─────────────────────────────────────────────────────────────────────────────
class _DriverRatingSheet extends StatefulWidget {
  final int orderId;
  final int driverId;
  final String driverName;
  final int? customerId;

  const _DriverRatingSheet({
    required this.orderId,
    required this.driverId,
    required this.driverName,
    this.customerId,
  });

  @override
  State<_DriverRatingSheet> createState() => _DriverRatingSheetState();
}

class _DriverRatingSheetState extends State<_DriverRatingSheet> {
  final _api = ApiClient();
  final _feedbackCtrl = TextEditingController();

  int _stars = 0; // 0 = not yet selected
  String? _category;
  bool _isAnonymous = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  // Categories the customer can pick
  static const _categories = [
    ('delivery_speed', '⚡ Fast delivery'),
    ('politeness', '😊 Polite & friendly'),
    ('vehicle_condition', '🛵 Good vehicle'),
    ('accuracy', '📦 Order accurate'),
  ];

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() => _error = 'Please select a star rating.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.createDriverRating(
        driverId: widget.driverId,
        orderId: widget.orderId,
        rating: _stars,
        feedback: _feedbackCtrl.text.trim().isEmpty
            ? null
            : _feedbackCtrl.text.trim(),
        category: _category,
        customerId: widget.customerId,
        isAnonymous: _isAnonymous,
      );
      if (mounted)
        setState(() {
          _submitted = true;
          _submitting = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _submitted ? _buildSuccess(cs) : _buildForm(cs, scroll),
      ),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccess(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 72, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Thanks for your feedback!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your rating helps improve the delivery experience.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Rating form ────────────────────────────────────────────────────────────
  Widget _buildForm(ColorScheme cs, ScrollController scroll) {
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),

        // Driver avatar + name
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.primaryContainer,
              child: Text(
                widget.driverName.isNotEmpty ? widget.driverName[0] : '?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rate your driver',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    widget.driverName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Order #${widget.orderId}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Star picker ──────────────────────────────────────────────────────
        const Text(
          'How was your delivery?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _stars;
            return GestureDetector(
              onTap: () => setState(() => _stars = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 44,
                  color: filled ? Colors.amber : Colors.grey[300],
                ),
              ),
            );
          }),
        ),
        if (_stars > 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _starLabel(_stars),
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),

        // ── Category chips ───────────────────────────────────────────────────
        const Text(
          'What stood out? (optional)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final selected = _category == cat.$1;
            return FilterChip(
              label: Text(cat.$2),
              selected: selected,
              onSelected: (_) =>
                  setState(() => _category = selected ? null : cat.$1),
              selectedColor: cs.primaryContainer,
              checkmarkColor: cs.onPrimaryContainer,
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ── Feedback text ────────────────────────────────────────────────────
        const Text(
          'Leave a comment (optional)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _feedbackCtrl,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Tell us more about your experience…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),

        // ── Anonymous toggle ─────────────────────────────────────────────────
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Submit anonymously'),
          subtitle: Text(
            'Your name won\'t be shown to the driver',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          value: _isAnonymous,
          onChanged: (v) => setState(() => _isAnonymous = v),
        ),
        const SizedBox(height: 4),

        // ── Error ────────────────────────────────────────────────────────────
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),

        // ── Submit ───────────────────────────────────────────────────────────
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
              : const Text(
                  'Submit Rating',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip for now'),
        ),
      ],
    );
  }

  String _starLabel(int stars) {
    switch (stars) {
      case 1:
        return 'Very poor';
      case 2:
        return 'Poor';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }
}
