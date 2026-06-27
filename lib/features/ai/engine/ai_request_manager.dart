import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/ai_request.dart';
import '../providers/gemini_provider.dart';
import '../providers/groq_provider.dart';
import 'ai_health_monitor.dart';
import 'provider_router.dart';
import 'rate_limit_manager.dart';
import 'request_queue.dart';
import 'response_cache.dart';

// ── Riverpod Provider ────────────────────────────────────────────────────────

final aiRequestManagerProvider = Provider<AiRequestManager>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return AiRequestManager(prefs: prefs);
});

// ── AI Request Manager ───────────────────────────────────────────────────────

/// **The single entry point for every AI request in Orbit.**
///
/// No feature code (pipelines, sync services, etc.) may call providers
/// directly. All requests pass through this manager which handles:
///
/// - Provider selection via [ProviderRouter]
/// - Rate-limit awareness via [RateLimitManager]
/// - Request serialisation via [RequestQueue]
/// - Retry logic (max 3 attempts, only for retriable errors)
/// - Response caching via [ResponseCache]
/// - Health monitoring via [AiHealthMonitor]
/// - Analytics logging (Phase 5)
class AiRequestManager {
  final SharedPreferences _prefs;

  late final RateLimitManager _rateLimitManager;
  late final ProviderRouter _providerRouter;
  late final RequestQueue _requestQueue;
  late final ResponseCache _responseCache;
  late final AiHealthMonitor _healthMonitor;

  static const int _maxRetries = 3;
  static const String _prefKeyAiMode = 'ai_mode'; // 'orbit_default' | 'user_key'
  static const String _prefKeyProvider = 'preferred_provider'; // 'gemini' | 'groq'

  AiRequestManager({required SharedPreferences prefs}) : _prefs = prefs {
    _rateLimitManager = RateLimitManager();
    _providerRouter = ProviderRouter(rateLimitManager: _rateLimitManager);
    _requestQueue = RequestQueue();
    _responseCache = ResponseCache();
    _healthMonitor = AiHealthMonitor();

    _initializeProviders();
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Generate text from a prompt. This is the ONLY method features should call.
  ///
  /// The request is queued, routed to the best provider, retried on transient
  /// failures, and falls back to alternative providers on rate limits.
  Future<AiResponse> generate(AiRequest request) {
    return _requestQueue.enqueue(
      () => _generateWithRetry(request),
      requestId: request.requestId,
    );
  }

  /// The [ProviderRouter] instance, exposed for settings UI to read provider info.
  ProviderRouter get router => _providerRouter;

  /// The [AiHealthMonitor] instance, exposed for settings UI to read health.
  AiHealthMonitor get healthMonitor => _healthMonitor;

  /// The [RateLimitManager] instance, exposed for analytics.
  RateLimitManager get rateLimitManager => _rateLimitManager;

  /// Current AI mode ('orbit_default' or 'user_key').
  String get aiMode => _prefs.getString(_prefKeyAiMode) ?? 'orbit_default';

  /// Current preferred provider ID.
  String get preferredProvider => _prefs.getString(_prefKeyProvider) ?? 'gemini';

  /// Update the AI mode and reinitialize providers.
  Future<void> setAiMode(String mode) async {
    await _prefs.setString(_prefKeyAiMode, mode);
    _initializeProviders();
  }

  /// Update the preferred provider.
  Future<void> setPreferredProvider(String providerId) async {
    await _prefs.setString(_prefKeyProvider, providerId);
    _providerRouter.setPreferred(providerId);
  }

  /// Register or re-register a provider with a new API key.
  void registerProviderWithKey(String providerId, String apiKey) {
    late AiProvider provider;
    switch (providerId) {
      case 'gemini':
        provider = GeminiProvider(apiKey: apiKey);
        break;
      case 'groq':
        provider = GroqProvider(apiKey: apiKey);
        break;
      default:
        debugPrint('AiRequestManager: Unknown provider "$providerId"');
        return;
    }
    _providerRouter.registerProvider(provider);
    _rateLimitManager.resetProvider(providerId);
    _healthMonitor.resetProvider(providerId);
    debugPrint('AiRequestManager: Registered $providerId with user key');
  }

  /// Unregister a provider (e.g. when user removes their key).
  void unregisterProvider(String providerId) {
    _providerRouter.unregisterProvider(providerId);
    _rateLimitManager.resetProvider(providerId);
    _healthMonitor.resetProvider(providerId);
  }

  /// Validate an API key for a specific provider.
  Future<bool> validateApiKey(String providerId, String apiKey) async {
    late AiProvider testProvider;
    switch (providerId) {
      case 'gemini':
        testProvider = GeminiProvider(apiKey: apiKey);
        break;
      case 'groq':
        testProvider = GroqProvider(apiKey: apiKey);
        break;
      default:
        return false;
    }
    return testProvider.validateApiKey(apiKey);
  }

  /// Clear the response cache (e.g. when switching providers).
  void clearCache() => _responseCache.clear();

  // ── Private ─────────────────────────────────────────────────────────────

  void _initializeProviders() {
    // Register Orbit Default providers from .env
    final geminiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    final groqKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';

    if (geminiKey.isNotEmpty) {
      _providerRouter.registerProvider(GeminiProvider(apiKey: geminiKey));
    }

    if (groqKey.isNotEmpty) {
      _providerRouter.registerProvider(GroqProvider(apiKey: groqKey));
    }

    // Set preferred provider from user settings
    final preferred = _prefs.getString(_prefKeyProvider) ?? 'gemini';
    _providerRouter.setPreferred(preferred);

    debugPrint('AiRequestManager: Initialized. Mode=$aiMode, preferred=$preferred');
  }

  Future<AiResponse> _generateWithRetry(AiRequest request) async {
    AiException? lastError;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      // Check cache first (only for non-JSON mode, since JSON responses are structured)
      if (!request.jsonMode) {
        final providerId = preferredProvider;
        final cached = _responseCache.get(request.prompt, providerId);
        if (cached != null) {
          debugPrint('AiRequestManager: Cache hit');
          return AiResponse(
            text: cached,
            providerId: providerId,
            latency: Duration.zero,
          );
        }
      }

      try {
        // Select provider
        final provider = _providerRouter.selectProvider();

        debugPrint(
          'AiRequestManager: Attempt ${attempt + 1}/$_maxRetries '
          'using "${provider.id}" (${provider.model})',
        );

        // Generate
        final response = await provider.generate(request);

        // Success!
        _rateLimitManager.recordSuccess(provider.id);
        _healthMonitor.recordSuccess(provider.id);

        // Cache the response
        if (!request.jsonMode) {
          _responseCache.put(request.prompt, provider.id, response.text);
        }

        return response;
      } on AiException catch (e) {
        lastError = e;
        debugPrint('AiRequestManager: ${e.type} from ${e.providerId}: ${e.message}');

        // Update health & rate limit state
        if (e.providerId != null) {
          _healthMonitor.recordFailure(e.providerId!, e.type);

          if (e.type == AiErrorType.rateLimited) {
            _rateLimitManager.recordRateLimit(
              e.providerId!,
              retryAfter: e.retryAfter,
            );
          } else if (e.isRetriable) {
            _rateLimitManager.recordFailure(e.providerId!);
          }
        }

        // Don't retry non-retriable errors
        if (!e.isRetriable) rethrow;

        // Small backoff between retries
        if (attempt < _maxRetries - 1) {
          final backoff = Duration(milliseconds: 500 * (attempt + 1));
          debugPrint('AiRequestManager: Backing off ${backoff.inMilliseconds}ms');
          await Future.delayed(backoff);
        }
      } on AllProvidersExhaustedException {
        debugPrint('AiRequestManager: All providers exhausted');
        rethrow;
      }
    }

    // All retries exhausted
    throw lastError ??
        const AiException(
          type: AiErrorType.unknown,
          message: 'All retries exhausted',
        );
  }
}
