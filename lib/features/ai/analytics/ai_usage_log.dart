class AiUsageLog {
  final String provider;
  final String model;
  final String apiMode; // 'orbit_default' | 'user_key'
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;
  final DateTime timestamp;
  final int latencyMs;
  final int retryCount;
  final bool fallbackTriggered;
  final String status; // 'success' | 'failed' | 'rate_limited' | 'invalid_key'

  const AiUsageLog({
    required this.provider,
    required this.model,
    required this.apiMode,
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
    required this.timestamp,
    required this.latencyMs,
    this.retryCount = 0,
    this.fallbackTriggered = false,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'model': model,
    'apiMode': apiMode,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'totalTokens': totalTokens,
    'timestamp': timestamp.toIso8601String(),
    'latencyMs': latencyMs,
    'retryCount': retryCount,
    'fallbackTriggered': fallbackTriggered,
    'status': status,
  };

  factory AiUsageLog.fromJson(Map<String, dynamic> json) => AiUsageLog(
    provider: json['provider'] as String,
    model: json['model'] as String,
    apiMode: json['apiMode'] as String,
    inputTokens: json['inputTokens'] as int?,
    outputTokens: json['outputTokens'] as int?,
    totalTokens: json['totalTokens'] as int?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    latencyMs: json['latencyMs'] as int,
    retryCount: json['retryCount'] as int? ?? 0,
    fallbackTriggered: json['fallbackTriggered'] as bool? ?? false,
    status: json['status'] as String,
  );
}

/// Aggregated analytics stats for display.
class AiAnalyticsStats {
  final int totalRequests;
  final int totalTokens;
  final int totalInputTokens;
  final int totalOutputTokens;
  final double avgLatencyMs;
  final double successRate;
  final Map<String, int> requestsByProvider;
  final Map<String, int> tokensByProvider;
  final int rateLimitOccurrences;
  final int failureCount;
  final List<DailyAggregate> dailyAggregates;

  const AiAnalyticsStats({
    this.totalRequests = 0,
    this.totalTokens = 0,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.avgLatencyMs = 0,
    this.successRate = 0,
    this.requestsByProvider = const {},
    this.tokensByProvider = const {},
    this.rateLimitOccurrences = 0,
    this.failureCount = 0,
    this.dailyAggregates = const [],
  });
}

/// Daily aggregate for trend charts.
class DailyAggregate {
  final DateTime date;
  final int requests;
  final int tokens;
  final double avgLatencyMs;

  const DailyAggregate({
    required this.date,
    this.requests = 0,
    this.tokens = 0,
    this.avgLatencyMs = 0,
  });
}
