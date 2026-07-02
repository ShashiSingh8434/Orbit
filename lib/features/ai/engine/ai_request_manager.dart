import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/ai_request.dart';
import '../providers/gemini_provider.dart';
import '../providers/groq_provider.dart';
import '../analytics/ai_analytics_service.dart';
import '../analytics/ai_usage_log.dart';
import '../storage/secure_key_storage.dart';
import 'ai_health_monitor.dart';
import 'provider_router.dart';
import '../../../core/utils/app_logger.dart';
import 'rate_limit_manager.dart';
import 'request_queue.dart';
import 'response_cache.dart';

// ── Riverpod Provider ────────────────────────────────────────────────────────

final aiRequestManagerProvider = Provider<AiRequestManager>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final analytics = ref.read(aiAnalyticsServiceProvider);
  return AiRequestManager(prefs: prefs, analytics: analytics, ref: ref);
});

// ── Global AI Status State & Provider ────────────────────────────────────────

class AiStatus {
  final bool isProcessing;
  final String? message;

  const AiStatus({required this.isProcessing, this.message});
}

final aiStatusProvider = StateProvider<AiStatus>(
  (ref) => const AiStatus(isProcessing: false),
);

// ── Model Configurations ─────────────────────────────────────────────────────

class ModelConfig {
  final String model;
  final String id;
  final String name;
  final int priority;

  const ModelConfig({
    required this.model,
    required this.id,
    required this.name,
    required this.priority,
  });
}

const _geminiModels = [
  ModelConfig(
    model: 'gemini-3.1-flash-lite',
    id: 'gemini_3_1_flash_lite',
    name: 'Gemini 3.1 Flash Lite',
    priority: 1,
  ),
  ModelConfig(
    model: 'gemini-2.5-flash-lite',
    id: 'gemini_2_5_flash_lite',
    name: 'Gemini 2.5 Flash Lite',
    priority: 2,
  ),
  ModelConfig(
    model: 'gemini-2.5-flash',
    id: 'gemini_2_5_flash',
    name: 'Gemini 2.5 Flash',
    priority: 3,
  ),
  ModelConfig(
    model: 'gemini-3-flash',
    id: 'gemini_3_flash',
    name: 'Gemini 3 Flash',
    priority: 4,
  ),
];

const _groqModels = [
  ModelConfig(
    model: 'llama-3.1-8b-instant',
    id: 'groq_llama_3_1_8b',
    name: 'Llama 3.1 8B Instant',
    priority: 5,
  ),
  ModelConfig(
    model: 'meta-llama/llama-4-scout-17b-16e-instruct',
    id: 'groq_llama_4_scout',
    name: 'Llama 4 Scout 17B',
    priority: 6,
  ),
  ModelConfig(
    model: 'qwen/qwen3-32b',
    id: 'groq_qwen3_32b',
    name: 'Qwen 3 32B',
    priority: 7,
  ),
  ModelConfig(
    model: 'llama-3.3-70b-versatile',
    id: 'groq_llama_3_3_70b',
    name: 'Llama 3.3 70B',
    priority: 8,
  ),
  ModelConfig(
    model: 'qwen/qwen3.6-27b',
    id: 'groq_qwen3_6_27b',
    name: 'Qwen 3.6 27B',
    priority: 9,
  ),
];

// ── AI Request Manager ───────────────────────────────────────────────────────

class AiRequestManager {
  final SharedPreferences _prefs;
  final Ref _ref;

  late final RateLimitManager _rateLimitManager;
  late final ProviderRouter _providerRouter;
  late final RequestQueue _requestQueue;
  late final ResponseCache _responseCache;
  late final AiHealthMonitor _healthMonitor;
  final AiAnalyticsService _analytics;

  static const int _maxRetries = 8;
  static const String _prefKeyAiMode =
      'ai_mode'; // 'orbit_default' | 'user_key'

  Future<void>? _initFuture;

  AiRequestManager({
    required this._prefs,
    required this._analytics,
    required this._ref,
  }) {
    _rateLimitManager = RateLimitManager();
    _healthMonitor = AiHealthMonitor();
    _providerRouter = ProviderRouter(
      rateLimitManager: _rateLimitManager,
      healthMonitor: _healthMonitor,
    );
    _requestQueue = RequestQueue();
    _responseCache = ResponseCache();

    ensureInitialized();
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Wait for asynchronous provider initialization.
  Future<void> ensureInitialized() {
    return _initFuture ??= _initializeProviders();
  }

  /// Generate text from a prompt. This is the ONLY method features should call.
  Future<AiResponse> generate(AiRequest request) async {
    await ensureInitialized();

    if (aiMode == 'user_key' && _providerRouter.registeredProviderIds.isEmpty) {
      throw const NoApiKeyException();
    }

    _updateStatus(true, request.label ?? 'AI is working...');
    try {
      return await _requestQueue.enqueue(
        (queueWaitTime) => _generateWithRetry(request, queueWaitTime),
        requestId: request.requestId,
      );
    } finally {
      if (_requestQueue.queueLength == 0 && _requestQueue.activeCount <= 1) {
        _updateStatus(false, null);
      }
    }
  }

  /// Exposes the ProviderRouter
  ProviderRouter get router => _providerRouter;

  /// Exposes the AiHealthMonitor
  AiHealthMonitor get healthMonitor => _healthMonitor;

  /// Exposes the RateLimitManager
  RateLimitManager get rateLimitManager => _rateLimitManager;

  /// Current AI mode ('orbit_default' or 'user_key').
  String get aiMode => _prefs.getString(_prefKeyAiMode) ?? 'orbit_default';

  /// Update the AI mode and reinitialize providers.
  Future<void> setAiMode(String mode) async {
    await _prefs.setString(_prefKeyAiMode, mode);
    _initFuture = null; // force reload
    await ensureInitialized();
  }

  /// Register a provider (saves key and reinitializes).
  Future<void> registerProviderWithKey(String providerId, String apiKey) async {
    for (final id in _providerRouter.registeredProviderIds) {
      if (id.startsWith(providerId)) {
        _rateLimitManager.resetProvider(id);
        _healthMonitor.resetProvider(id);
      }
    }
    _initFuture = null; // force reload
    await ensureInitialized();
    AppLogger.debug('AiRequestManager: Registered $providerId with user key');
  }

  /// Unregister a provider (e.g. when user removes their key).
  Future<void> unregisterProvider(String providerId) async {
    final toRemove = _providerRouter.registeredProviderIds
        .where((id) => id.startsWith(providerId))
        .toList();
    for (final id in toRemove) {
      _rateLimitManager.resetProvider(id);
      _healthMonitor.resetProvider(id);
    }
    _initFuture = null; // force reload
    await ensureInitialized();
    AppLogger.debug('AiRequestManager: Unregistered provider $providerId');
  }

  /// Validate an API key for a specific provider.
  Future<bool> validateApiKey(String providerId, String apiKey) async {
    late AiProvider testProvider;
    switch (providerId) {
      case 'gemini':
        testProvider = GeminiProvider(
          apiKey: apiKey,
          model: 'gemini-2.5-flash',
          id: 'test',
          name: 'test',
          priority: 1,
        );
        break;
      case 'groq':
        testProvider = GroqProvider(
          apiKey: apiKey,
          model: 'llama-3.1-8b-instant',
          id: 'test',
          name: 'test',
          priority: 1,
        );
        break;
      default:
        return false;
    }
    return testProvider.validateApiKey(apiKey);
  }

  /// Validate health of a user provider.
  Future<bool> testProviderConnection(String providerId) async {
    await ensureInitialized();
    final providerIds = _providerRouter.registeredProviderIds
        .where((id) => id.startsWith(providerId))
        .toList();
    if (providerIds.isEmpty) return false;
    final userProviderId = providerIds.firstWhere(
      (id) => id.endsWith('_user'),
      orElse: () => providerIds.first,
    );
    final provider = _providerRouter.getProvider(userProviderId);
    if (provider == null) return false;
    return provider.healthCheck();
  }

  /// Clear the response cache.
  void clearCache() => _responseCache.clear();

  // ── Private ─────────────────────────────────────────────────────────────

  Future<void> _initializeProviders() async {
    // Clear currently registered providers
    final existingIds = List<String>.from(
      _providerRouter.registeredProviderIds,
    );
    for (final id in existingIds) {
      _providerRouter.unregisterProvider(id);
    }

    final orbitGeminiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    final orbitGroqKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';

    if (aiMode == 'user_key') {
      final userGeminiKey = await SecureKeyStorage.getKey('gemini');
      final userGroqKey = await SecureKeyStorage.getKey('groq');

      // Register Gemini
      if (userGeminiKey != null && userGeminiKey.trim().isNotEmpty) {
        _registerGeminiModels(userGeminiKey.trim(), isUser: true);
        if (orbitGeminiKey.isNotEmpty) {
          _registerGeminiModels(
            orbitGeminiKey,
            isUser: false,
            priorityOffset: 10,
          );
        }
      } else {
        if (orbitGeminiKey.isNotEmpty) {
          _registerGeminiModels(orbitGeminiKey, isUser: false);
        }
      }

      // Register Groq
      if (userGroqKey != null && userGroqKey.trim().isNotEmpty) {
        _registerGroqModels(userGroqKey.trim(), isUser: true);
        if (orbitGroqKey.isNotEmpty) {
          _registerGroqModels(orbitGroqKey, isUser: false, priorityOffset: 10);
        }
      } else {
        if (orbitGroqKey.isNotEmpty) {
          _registerGroqModels(orbitGroqKey, isUser: false);
        }
      }
    } else {
      // Orbit Default Mode
      if (orbitGeminiKey.isNotEmpty) {
        _registerGeminiModels(orbitGeminiKey, isUser: false);
      }
      if (orbitGroqKey.isNotEmpty) {
        _registerGroqModels(orbitGroqKey, isUser: false);
      }
    }

    AppLogger.debug(
      'AiRequestManager: Provider registration completed. Mode=$aiMode',
    );
  }

  void _registerGroqModels(
    String apiKey, {
    required bool isUser,
    int priorityOffset = 0,
  }) {
    for (final cfg in _groqModels) {
      final suffix = isUser ? '_user' : '_orbit';
      _providerRouter.registerProvider(
        GroqProvider(
          apiKey: apiKey,
          model: cfg.model,
          id: '${cfg.id}$suffix',
          name: '${cfg.name}${isUser ? '' : ' (Orbit)'}',
          priority: cfg.priority + priorityOffset,
        ),
      );
    }
  }

  void _registerGeminiModels(
    String apiKey, {
    required bool isUser,
    int priorityOffset = 0,
  }) {
    for (final cfg in _geminiModels) {
      final suffix = isUser ? '_user' : '_orbit';
      _providerRouter.registerProvider(
        GeminiProvider(
          apiKey: apiKey,
          model: cfg.model,
          id: '${cfg.id}$suffix',
          name: '${cfg.name}${isUser ? '' : ' (Orbit)'}',
          priority: cfg.priority + priorityOffset,
        ),
      );
    }
  }

  void _updateStatus(bool isProcessing, String? message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ref.read(aiStatusProvider.notifier).state = AiStatus(
        isProcessing: isProcessing,
        message: message,
      );
    });
  }

  Future<AiResponse> _generateWithRetry(
    AiRequest request,
    Duration queueWaitTime,
  ) async {
    AiException? lastError;
    final failedIds = <String>{};
    final processingStart = DateTime.now();

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      // Check cache first (only for non-JSON mode)
      if (!request.jsonMode) {
        try {
          final candidate = _providerRouter.selectProvider(
            excludeIds: failedIds,
          );
          final cached = _responseCache.get(request.prompt, candidate.id);
          if (cached != null) {
            AppLogger.debug('AiRequestManager: Cache hit');
            final processingTime = DateTime.now().difference(processingStart);
            final totalTime = queueWaitTime + processingTime;

            _analytics.logRequest(
              AiUsageLog(
                provider: candidate.id.contains('gemini') ? 'Gemini' : 'Groq',
                modelName: candidate.name,
                modelId: candidate.id,
                aiMode: aiMode == 'user_key' ? 'User' : 'Orbit',
                apiSource: candidate.id.endsWith('_user')
                    ? 'My API'
                    : 'Orbit API',
                timestamp: DateTime.now(),
                success: true,
                retryCount: attempt,
                responseTimeMs: totalTime.inMilliseconds,
                cached: true,
                queueWaitTimeMs: queueWaitTime.inMilliseconds,
                processingTimeMs: processingTime.inMilliseconds,
              ),
            );

            return AiResponse(
              text: cached,
              providerId: candidate.id,
              latency: Duration.zero,
            );
          }
        } catch (_) {}
      }

      try {
        final provider = _providerRouter.selectProvider(excludeIds: failedIds);

        AppLogger.info(
          'AiRequestManager: Attempt ${attempt + 1}/$_maxRetries '
          'using "${provider.id}" (${provider.model})',
        );

        final response = await provider.generate(request);

        // Success!
        _rateLimitManager.recordSuccess(provider.id);
        _healthMonitor.recordSuccess(provider.id);

        if (!request.jsonMode) {
          _responseCache.put(request.prompt, provider.id, response.text);
        }

        final processingTime = DateTime.now().difference(processingStart);
        final totalTime = queueWaitTime + processingTime;

        _analytics.logRequest(
          AiUsageLog(
            provider: provider.id.contains('gemini') ? 'Gemini' : 'Groq',
            modelName: provider.name,
            modelId: provider.id,
            aiMode: aiMode == 'user_key' ? 'User' : 'Orbit',
            apiSource: provider.id.endsWith('_user') ? 'My API' : 'Orbit API',
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens,
            totalTokens: response.totalTokens,
            timestamp: DateTime.now(),
            responseTimeMs: totalTime.inMilliseconds,
            retryCount: attempt,
            success: true,
            cached: false,
            queueWaitTimeMs: queueWaitTime.inMilliseconds,
            processingTimeMs: processingTime.inMilliseconds,
          ),
        );

        return response;
      } on AiException catch (e) {
        lastError = e;
        final failedProviderId = e.providerId ?? '';
        AppLogger.warning(
          'AiRequestManager: ${e.type} from $failedProviderId: ${e.message}',
          e,
        );

        if (failedProviderId.isNotEmpty) {
          failedIds.add(failedProviderId);
          _healthMonitor.recordFailure(failedProviderId, e.type);

          if (e.type == AiErrorType.rateLimited) {
            _rateLimitManager.recordRateLimit(
              failedProviderId,
              retryAfter: e.retryAfter,
            );
          } else {
            _rateLimitManager.recordFailure(failedProviderId);
          }

          final providerObj = _providerRouter.getProvider(failedProviderId);
          final processingTime = DateTime.now().difference(processingStart);
          final totalTime = queueWaitTime + processingTime;

          _analytics.logRequest(
            AiUsageLog(
              provider: failedProviderId.contains('gemini') ? 'Gemini' : 'Groq',
              modelName: providerObj?.name ?? 'unknown',
              modelId: failedProviderId,
              aiMode: aiMode == 'user_key' ? 'User' : 'Orbit',
              apiSource: failedProviderId.endsWith('_user')
                  ? 'My API'
                  : 'Orbit API',
              timestamp: DateTime.now(),
              responseTimeMs: totalTime.inMilliseconds,
              retryCount: attempt,
              success: false,
              errorType: e.type.toString().split('.').last,
              cached: false,
              queueWaitTimeMs: queueWaitTime.inMilliseconds,
              processingTimeMs: processingTime.inMilliseconds,
            ),
          );
        }

        if (attempt < _maxRetries - 1) {
          final backoff = Duration(milliseconds: 500 * (attempt + 1));
          AppLogger.warning(
            'AiRequestManager: Backing off ${backoff.inMilliseconds}ms',
          );
          await Future.delayed(backoff);
        }
      } on AllProvidersExhaustedException {
        AppLogger.error('AiRequestManager: All providers exhausted');
        rethrow;
      }
    }

    throw lastError ??
        const AiException(
          type: AiErrorType.unknown,
          message: 'All retries exhausted',
        );
  }
}

class NoApiKeyException implements Exception {
  final String message;
  const NoApiKeyException([
    this.message =
        'No API keys configured. Please configure your Google Gemini or Groq API key in Settings.',
  ]);

  @override
  String toString() => message;
}
