/// Unified request/response models for all AI providers.

/// Represents a single request to any AI provider.
class AiRequest {
  /// The prompt text to send.
  final String prompt;

  /// If true, the provider should return JSON.
  final bool jsonMode;

  /// Optional Gemini-specific response schema (other providers ignore this).
  final dynamic responseSchema;

  /// Unique ID for deduplication. If two requests share the same
  /// [requestId] while one is still in-flight, the second is discarded.
  final String? requestId;

  const AiRequest({
    required this.prompt,
    this.jsonMode = false,
    this.responseSchema,
    this.requestId,
  });

  @override
  String toString() =>
      'AiRequest(jsonMode=$jsonMode, requestId=$requestId, promptLen=${prompt.length})';
}

/// The result returned by any AI provider after a successful generation.
class AiResponse {
  /// The generated text.
  final String text;

  /// Which provider produced this response (e.g. 'gemini', 'groq').
  final String providerId;

  /// Token counts (may be null if the provider doesn't report them).
  final int? inputTokens;
  final int? outputTokens;
  int? get totalTokens => (inputTokens != null && outputTokens != null)
      ? inputTokens! + outputTokens!
      : null;

  /// Wall-clock time the generation took.
  final Duration latency;

  const AiResponse({
    required this.text,
    required this.providerId,
    this.inputTokens,
    this.outputTokens,
    required this.latency,
  });
}

/// Categorises failures so the retry / fallback logic can decide what to do.
enum AiErrorType {
  /// 429 — rate limit exceeded. Retriable after cooldown.
  rateLimited,

  /// 401 / 403 — invalid or expired API key. NOT retriable.
  invalidApiKey,

  /// Network timeout or DNS failure. Retriable.
  networkError,

  /// 5xx server error. Retriable.
  serverError,

  /// Malformed prompt or bad request (4xx other than 429/401/403). NOT retriable.
  badRequest,

  /// Catch-all for unexpected errors. NOT retriable.
  unknown,
}

/// Exception thrown by providers so the infrastructure can handle it.
class AiException implements Exception {
  final AiErrorType type;
  final String message;
  final String? providerId;
  final Duration?
  retryAfter; // Hint from the provider (e.g. Retry-After header)

  const AiException({
    required this.type,
    required this.message,
    this.providerId,
    this.retryAfter,
  });

  /// Whether the request manager should retry this error.
  bool get isRetriable =>
      type == AiErrorType.rateLimited ||
      type == AiErrorType.networkError ||
      type == AiErrorType.serverError;

  @override
  String toString() => 'AiException($type, $message, provider=$providerId)';
}
