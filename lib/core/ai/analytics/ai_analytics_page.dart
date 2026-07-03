import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ai_analytics_service.dart';
import 'ai_usage_log.dart';

/// AI Analytics dashboard page — shows usage stats, model breakdown, trends.
class AiAnalyticsPage extends ConsumerStatefulWidget {
  const AiAnalyticsPage({super.key});

  @override
  ConsumerState<AiAnalyticsPage> createState() => _AiAnalyticsPageState();
}

class _AiAnalyticsPageState extends ConsumerState<AiAnalyticsPage> {
  String _selectedApiSource = 'Orbit API'; // 'Orbit API' | 'My API'
  bool _todayOnly = false; // false = All Time, true = Today

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(aiAnalyticsServiceProvider);
    final stats = service.getStats(
      apiSource: _selectedApiSource,
      todayOnly: _todayOnly,
    );
    final recentLogs = service.getRecentLogs(count: 5);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Analytics'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear Statistics',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Filters ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Orbit API', label: Text('Orbit API')),
                    ButtonSegment(value: 'My API', label: Text('My API')),
                  ],
                  selected: {_selectedApiSource},
                  onSelectionChanged: (val) {
                    setState(() {
                      _selectedApiSource = val.first;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('All Time')),
                    ButtonSegment(value: true, label: Text('Today')),
                  ],
                  selected: {_todayOnly},
                  onSelectionChanged: (val) {
                    setState(() {
                      _todayOnly = val.first;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Overview Cards ──────────────────────────────────────────────
          Text(
            'OVERVIEW',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.send_rounded,
                  label: 'Requests',
                  value: '${stats.totalRequests}',
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.token_rounded,
                  label: 'Tokens',
                  value: _formatNumber(stats.totalTokens),
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.speed_rounded,
                  label: 'Avg Latency',
                  value: '${stats.avgLatencyMs.round()}ms',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Success Rate',
                  value: '${(stats.successRate * 100).round()}%',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Model Usage breakdown ───────────────────────────────────────
          Text(
            'MODEL USAGE',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (stats.requestsByModel.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No model usage data for this filter.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...(stats.requestsByModel.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .map((e) {
                  final maxReq = stats.totalRequests;
                  final fraction = maxReq > 0 ? e.value / maxReq : 0.0;
                  final modelColor = e.key.toLowerCase().contains('gemini')
                      ? colorScheme.primary
                      : colorScheme.tertiary;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.key,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${e.value} requests',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 8,
                            backgroundColor: modelColor.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(modelColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

          const SizedBox(height: 24),

          // ── Daily Trend ─────────────────────────────────────────────────
          if (stats.dailyAggregates.isNotEmpty) ...[
            Text(
              'REQUESTS (LAST 7 DAYS)',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      stats.dailyAggregates.fold<double>(
                        0,
                        (max, e) =>
                            e.requests > max ? e.requests.toDouble() : max,
                      ) *
                      1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= stats.dailyAggregates.length) {
                            return const SizedBox.shrink();
                          }
                          final day = stats.dailyAggregates[idx].date;
                          return Text(
                            '${day.day}/${day.month}',
                            style: theme.textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: List.generate(stats.dailyAggregates.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: stats.dailyAggregates[i].requests.toDouble(),
                          color: colorScheme.primary,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Error Insights ──────────────────────────────────────────────
          Text(
            'ERROR INSIGHTS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.timer_off_rounded,
                  label: 'Rate Limits',
                  value: '${stats.rateLimitOccurrences}',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.error_outline_rounded,
                  label: 'Failures',
                  value: '${stats.failureCount}',
                  color: colorScheme.error,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Recent Activity ─────────────────────────────────────────────
          Text(
            'RECENT ACTIVITY',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (recentLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No recent activity.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...recentLogs.map((log) => _LogTile(log: log)),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Statistics'),
        content: const Text(
          'Are you sure you want to clear all AI analytics statistics? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(aiAnalyticsServiceProvider).clearAll();
              if (mounted) {
                setState(() {});
              }
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final AiUsageLog log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusIcon = log.success
        ? const Icon(Icons.check_circle, size: 16, color: Colors.green)
        : (log.errorType == 'rateLimited' || log.errorType == 'rate_limited'
              ? const Icon(Icons.timer_off, size: 16, color: Colors.orange)
              : Icon(Icons.error_outline, size: 16, color: colorScheme.error));

    final time =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

    return ListTile(
      dense: true,
      leading: statusIcon,
      title: Text(
        '${log.modelName} • ${log.responseTimeMs}ms',
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${log.totalTokens ?? 0} tokens • Wait: ${log.queueWaitTimeMs}ms • $time',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
