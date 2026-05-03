import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';

/// Lets signed-in customers rate the app and leave feedback; lists their past entries.
class CustomerRatingFeedbackScreen extends StatefulWidget {
  const CustomerRatingFeedbackScreen({super.key});

  @override
  State<CustomerRatingFeedbackScreen> createState() =>
      _CustomerRatingFeedbackScreenState();
}

class _CustomerRatingFeedbackScreenState
    extends State<CustomerRatingFeedbackScreen> {
  final _api = ApiClient();
  final _feedbackCtrl = TextEditingController();
  List<CustomerFeedbackEntry> _items = const [];
  bool _loading = true;
  bool _submitting = false;
  int _rating = 5;
  String _category = 'General';

  static const _categories = [
    'General',
    'Ordering',
    'Delivery',
    'Payments',
    'App experience',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.listMyCustomerFeedback();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a short feedback message.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.createCustomerFeedback(
        rating: _rating,
        feedback: text,
        category: _category,
      );
      _feedbackCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you — your feedback was saved.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Rating & feedback'),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: cs.primary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'How are we doing?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your ratings help us improve ordering, delivery, and the app.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Rating',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(5, (i) {
                              final star = i + 1;
                              return IconButton(
                                onPressed: () =>
                                    setState(() => _rating = star),
                                icon: Icon(
                                  star <= _rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: const Color(0xFFFF6A00),
                                  size: 32,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _category,
                            decoration: const InputDecoration(
                              labelText: 'Topic',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _category = v);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _feedbackCtrl,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Your feedback',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _submitting ? 'Sending…' : 'Submit feedback',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Your previous feedback',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Nothing here yet — submit your first note above.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    ..._items.map(_entryTile),
                ],
              ),
            ),
    );
  }

  Widget _entryTile(CustomerFeedbackEntry e) {
    final date =
        '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          '${List.filled(e.rating.clamp(0, 5), '★').join()} · ${e.category ?? 'General'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(e.feedback),
        ),
        isThreeLine: e.feedback.length > 80,
        trailing: Text(
          date,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ),
    );
  }
}
