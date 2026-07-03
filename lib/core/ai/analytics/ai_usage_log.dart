class AiUsageLog {
  final String provider;
  final String modelName;
  final String modelId;
  final String aiMode; // 'Orbit' | 'User'
  final String apiSource; // 'Orbit API' | 'My API'
  final DateTime timestamp;
  final bool success;
  final String? errorType; // e.g. 'rateLimited', 'invalidApiKey', etc.
  final int retryCount;
  final int responseTimeMs;
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;
  final bool cached;
  final int queueWaitTimeMs;
  final int processingTimeMs;

  const AiUsageLog({
    required this.provider,
    required this.modelName,
    required this.modelId,
    required this.aiMode,
    required this.apiSource,
    required this.timestamp,
    required this.success,
    this.errorType,
    required this.retryCount,
    required this.responseTimeMs,
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
    required this.cached,
    required this.queueWaitTimeMs,
    required this.processingTimeMs,
  });

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'modelName': modelName,
    'modelId': modelId,
    'aiMode': aiMode,
    'apiSource': apiSource,
    'timestamp': timestamp.toIso8601String(),
    'success': success,
    'errorType': errorType,
    'retryCount': retryCount,
    'responseTimeMs': responseTimeMs,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'totalTokens': totalTokens,
    'cached': cached,
    'queueWaitTimeMs': queueWaitTimeMs,
    'processingTimeMs': processingTimeMs,
  };

  factory AiUsageLog.fromJson(Map<String, dynamic> json) => AiUsageLog(
    provider: json['provider'] as String? ?? 'unknown',
    modelName:
        json['modelName'] as String? ?? json['model'] as String? ?? 'unknown',
    modelId:
        json['modelId'] as String? ?? json['model'] as String? ?? 'unknown',
    aiMode:
        json['aiMode'] as String? ??
        (json['apiMode'] == 'user_key' ? 'User' : 'Orbit'),
    apiSource:
        json['apiSource'] as String? ??
        (json['apiMode'] == 'user_key' ? 'My API' : 'Orbit API'),
    timestamp: DateTime.parse(json['timestamp'] as String),
    success: json['success'] as bool? ?? (json['status'] == 'success'),
    errorType:
        json['errorType'] as String? ??
        (json['status'] != 'success' && json['status'] != null
            ? json['status'] as String
            : null),
    retryCount: json['retryCount'] as int? ?? 0,
    responseTimeMs:
        json['responseTimeMs'] as int? ?? json['latencyMs'] as int? ?? 0,
    inputTokens: json['inputTokens'] as int?,
    outputTokens: json['outputTokens'] as int?,
    totalTokens: json['totalTokens'] as int?,
    cached: json['cached'] as bool? ?? false,
    queueWaitTimeMs: json['queueWaitTimeMs'] as int? ?? 0,
    processingTimeMs:
        json['processingTimeMs'] as int? ?? json['latencyMs'] as int? ?? 0,
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
  final Map<String, int> requestsByModel; // New model-level usage field
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
    this.requestsByModel = const {},
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
