import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import 'ai_usage_log.dart';

/// Service for persisting and aggregating AI usage analytics.
///
/// Uses SharedPreferences with JSON for MVP storage. Can be upgraded to
/// Hive or SQLite later for better performance at scale.
class AiAnalyticsService {
  final SharedPreferences _prefs;
  static const String _storageKey = 'ai_analytics_logs';
  static const int _maxLogs = 500; // Keep last 500 logs

  AiAnalyticsService({required SharedPreferences prefs}) : _prefs = prefs;

  /// Log a request.
  Future<void> logRequest(AiUsageLog log) async {
    final logs = _loadLogs();
    logs.add(log);

    // Trim to max
    while (logs.length > _maxLogs) {
      logs.removeAt(0);
    }

    await _saveLogs(logs);
    debugPrint('AiAnalytics: Logged ${log.provider} request (${log.status})');
  }

  /// Get aggregated stats for the given time range.
  AiAnalyticsStats getStats({int days = 7}) {
    final logs = _loadLogs();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final filtered = logs.where((l) => l.timestamp.isAfter(cutoff)).toList();

    if (filtered.isEmpty) return const AiAnalyticsStats();

    // Basic aggregates
    int totalTokens = 0;
    int totalInput = 0;
    int totalOutput = 0;
    int totalLatency = 0;
    int successCount = 0;
    int rateLimitCount = 0;
    int failCount = 0;
    final reqByProvider = <String, int>{};
    final tokByProvider = <String, int>{};

    for (final log in filtered) {
      totalTokens += log.totalTokens ?? 0;
      totalInput += log.inputTokens ?? 0;
      totalOutput += log.outputTokens ?? 0;
      totalLatency += log.latencyMs;

      if (log.status == 'success') successCount++;
      if (log.status == 'rate_limited') rateLimitCount++;
      if (log.status == 'failed') failCount++;

      reqByProvider[log.provider] = (reqByProvider[log.provider] ?? 0) + 1;
      tokByProvider[log.provider] =
          (tokByProvider[log.provider] ?? 0) + (log.totalTokens ?? 0);
    }

    // Daily aggregates
    final dailyMap = <String, _DailyAcc>{};
    for (final log in filtered) {
      final key =
          '${log.timestamp.year}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')}';
      final acc = dailyMap.putIfAbsent(key, () => _DailyAcc());
      acc.requests++;
      acc.tokens += log.totalTokens ?? 0;
      acc.totalLatency += log.latencyMs;
    }

    final dailyAggregates = dailyMap.entries.map((e) {
      final parts = e.key.split('-');
      return DailyAggregate(
        date: DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        requests: e.value.requests,
        tokens: e.value.tokens,
        avgLatencyMs: e.value.requests > 0
            ? e.value.totalLatency / e.value.requests
            : 0,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return AiAnalyticsStats(
      totalRequests: filtered.length,
      totalTokens: totalTokens,
      totalInputTokens: totalInput,
      totalOutputTokens: totalOutput,
      avgLatencyMs:
          filtered.isNotEmpty ? totalLatency / filtered.length : 0,
      successRate:
          filtered.isNotEmpty ? successCount / filtered.length : 0,
      requestsByProvider: reqByProvider,
      tokensByProvider: tokByProvider,
      rateLimitOccurrences: rateLimitCount,
      failureCount: failCount,
      dailyAggregates: dailyAggregates,
    );
  }

  /// Get the last N log entries.
  List<AiUsageLog> getRecentLogs({int count = 10}) {
    final logs = _loadLogs();
    final start = (logs.length - count).clamp(0, logs.length);
    return logs.sublist(start).reversed.toList();
  }

  /// Clear all analytics data.
  Future<void> clearAll() async {
    await _prefs.remove(_storageKey);
  }

  // ── Storage ─────────────────────────────────────────────────────────────

  List<AiUsageLog> _loadLogs() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AiUsageLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('AiAnalytics: Error loading logs: $e');
      return [];
    }
  }

  Future<void> _saveLogs(List<AiUsageLog> logs) async {
    final json = jsonEncode(logs.map((l) => l.toJson()).toList());
    await _prefs.setString(_storageKey, json);
  }
}

class _DailyAcc {
  int requests = 0;
  int tokens = 0;
  int totalLatency = 0;
}

// ── Riverpod Provider ────────────────────────────────────────────────────────

final aiAnalyticsServiceProvider = Provider<AiAnalyticsService>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return AiAnalyticsService(prefs: prefs);
});
