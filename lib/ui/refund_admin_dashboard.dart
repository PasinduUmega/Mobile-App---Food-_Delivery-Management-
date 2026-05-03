import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import 'widgets/app_feedback.dart';
import 'widgets/mobile_partition_card.dart';

/// Admin-only: view and action refund requests (approve / reject / mark processed).
class RefundAdminDashboard extends StatefulWidget {
  const RefundAdminDashboard({super.key});

  @override
  State<RefundAdminDashboard> createState() => _RefundAdminDashboardState();
}

class _RefundAdminDashboardState extends State<RefundAdminDashboard> {
  final _api = ApiClient();
  bool _loading = true;
  String? _error;
  List<RefundRequest> _items = const [];
  final Map<int, String> _noteDrafts = {};
  final Map<int, String> _statusPick = {};

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
      final list = await _api.listRefundRequests();
      if (!mounted) return;
      for (final r in list) {
        if (r.status == 'PENDING') {
          _statusPick[r.id] = 'APPROVED';
        }
        _noteDrafts[r.id] = r.adminNote ?? '';
      }
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _apply(RefundRequest r) async {
    if (r.status != 'PENDING') return;
    final next = _statusPick[r.id] ?? 'APPROVED';
    final note = _noteDrafts[r.id]?.trim();
    try {
      await _api.updateRefundRequestAdmin(
        id: r.id,
        status: next,
        adminNote: note,
      );
      if (mounted) {
        AppFeedback.success(context, 'Refund request updated');
        await _load();
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund requests'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _items.isEmpty
          ? Center(
              child: Text(
                'No refund requests yet.\n'
                'Customers can submit from Orders after payment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final r = _items[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MobilePartitionCard(
                    title: 'Order #${r.orderId} · Request #${r.id}',
                    subtitle: r.statusLabel,
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if ((r.reason ?? '').trim().isNotEmpty) ...[
                          Text(
                            'Customer reason',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.reason!,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'User ID: ${r.userId}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if ((r.adminNote ?? '').isNotEmpty)
                          Text(
                            'Note: ${r.adminNote}',
                            style: theme.textTheme.bodySmall,
                          ),
                        if (r.status == 'PENDING') ...[
                          const SizedBox(height: 12),
                          Text(
                            'Decision (admin only)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _statusPick[r.id] ?? 'APPROVED',
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'APPROVED',
                                child: Text('Approve'),
                              ),
                              DropdownMenuItem(
                                value: 'REJECTED',
                                child: Text('Reject'),
                              ),
                              DropdownMenuItem(
                                value: 'PROCESSED',
                                child: Text('Mark processed (refund done)'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _statusPick[r.id] = v);
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: ValueKey('an-${r.id}-${r.status}'),
                            initialValue: _noteDrafts[r.id] ?? r.adminNote ?? '',
                            onChanged: (v) => _noteDrafts[r.id] = v,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Admin note (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: () => _apply(r),
                            child: const Text('Save decision'),
                          ),
                        ] else
                          Chip(
                            label: Text('Closed · ${r.status}'),
                            backgroundColor: cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                          ),
                        Text(
                          'Created ${_shortDate(r.createdAt)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _shortDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
