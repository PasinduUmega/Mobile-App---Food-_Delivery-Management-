import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';

class DriverRatingDashboard extends StatefulWidget {
  /// Filter to show ratings only for a specific driver
  final int? driverId;

  const DriverRatingDashboard({super.key, this.driverId});

  @override
  State<DriverRatingDashboard> createState() => _DriverRatingDashboardState();
}

class _DriverRatingDashboardState extends State<DriverRatingDashboard> {
  final _api = ApiClient();
  bool _loading = false;
  List<DriverRating> _ratings = [];
  List<DriverMetrics> _leaderboard = [];
  String _viewMode = 'ratings'; // ratings or leaderboard

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_viewMode == 'ratings') {
        final ratings = await _api.listDriverRatings(
          driverId: widget.driverId,
          limit: 100,
        );
        if (mounted) {
          setState(() {
            _ratings = ratings;
            _loading = false;
          });
        }
      } else {
        final leaderboard = await _api.getDriverLeaderboard(limit: 50);
        if (mounted) {
          setState(() {
            _leaderboard = leaderboard;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.driverId != null
                    ? 'Driver Ratings'
                    : 'Driver Ratings & Leaderboard',
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.driverId == null) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'ratings',
                        label: Text('Ratings'),
                        icon: Icon(Icons.star),
                      ),
                      ButtonSegment(
                        value: 'leaderboard',
                        label: Text('Leaderboard'),
                        icon: Icon(Icons.trending_up),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (s) {
                      setState(() => _viewMode = s.first);
                      _load();
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _viewMode == 'ratings'
              ? _buildRatingsView()
              : _buildLeaderboardView(),
        ),
      ],
    );
  }

  Widget _buildRatingsView() {
    if (_ratings.isEmpty) {
      return Center(
        child: Text(
          'No ratings yet',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      itemCount: _ratings.length,
      itemBuilder: (ctx, i) {
        final r = _ratings[i];
        return _RatingCard(rating: r);
      },
    );
  }

  Widget _buildLeaderboardView() {
    if (_leaderboard.isEmpty) {
      return Center(
        child: Text(
          'No drivers in leaderboard',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      itemCount: _leaderboard.length,
      itemBuilder: (ctx, i) {
        final m = _leaderboard[i];
        return _LeaderboardCard(metrics: m, rank: i + 1);
      },
    );
  }
}

class _RatingCard extends StatelessWidget {
  final DriverRating rating;

  const _RatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stars = List.generate(5, (i) => i < rating.rating);
    final hasFeedback = rating.feedback != null && rating.feedback!.trim().isNotEmpty;
    final hasCategory = rating.category != null && rating.category!.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasFeedback
            ? () => _showFeedbackDialog(context, rating.feedback!)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.customerName ?? 'Anonymous Customer',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #${rating.orderId}',
                        style: TextStyle(fontSize: 12, color: cs.outline),
                      ),
                    ],
                  ),
                  Row(
                    children: stars
                        .map(
                          (filled) => Icon(
                            Icons.star,
                            size: 20,
                            color: filled
                                ? Colors.amber
                                : cs.outline.withValues(alpha: 0.3),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              if (hasCategory) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rating.category!,
                    style: TextStyle(fontSize: 12, color: cs.primary),
                  ),
                ),
              ],
              if (hasFeedback) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    rating.feedback!,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap to read full feedback',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _formatDate(rating.createdAt),
                style: TextStyle(fontSize: 11, color: cs.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context, String feedback) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer Feedback'),
        content: SingleChildScrollView(
          child: Text(
            feedback,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _LeaderboardCard extends StatelessWidget {
  final DriverMetrics metrics;
  final int rank;

  const _LeaderboardCard({required this.metrics, required this.rank});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTop3 = rank <= 3;
    final rankColor = rank == 1
        ? Colors.amber
        : rank == 2
        ? Colors.grey[400]!
        : rank == 3
        ? Colors.orange[700]!
        : cs.outline;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isTop3 ? rankColor.withValues(alpha: 0.2) : cs.surface,
                shape: BoxShape.circle,
                border: Border.all(color: rankColor),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metrics.driverName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${metrics.averageRating.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${metrics.ratingCount} ratings',
                        style: TextStyle(fontSize: 12, color: cs.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${metrics.completedDeliveries}/${metrics.totalDeliveries}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'deliveries',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
