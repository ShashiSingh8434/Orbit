import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/app_logger.dart';

import '../engine/ai_health_monitor.dart';
import '../engine/ai_request_manager.dart';
import '../storage/secure_key_storage.dart';
import '../../providers/shared_preferences_provider.dart';

// ── State Model ──────────────────────────────────────────────────────────────

enum AiMode { orbitDefault, userKey }

class ProviderInfo {
  final String id;
  final String name;
  final String description;
  final String setupUrl;
  final List<String> availableModels;
  final String recommendedModel;
  final ProviderHealthStatus status;
  final bool hasUserKey;

  const ProviderInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.setupUrl,
    required this.availableModels,
    required this.recommendedModel,
    this.status = ProviderHealthStatus.unknown,
    this.hasUserKey = false,
  });

  ProviderInfo copyWith({ProviderHealthStatus? status, bool? hasUserKey}) {
    return ProviderInfo(
      id: id,
      name: name,
      description: description,
      setupUrl: setupUrl,
      availableModels: availableModels,
      recommendedModel: recommendedModel,
      status: status ?? this.status,
      hasUserKey: hasUserKey ?? this.hasUserKey,
    );
  }
}

class AiSettingsState {
  final AiMode mode;
  final Map<String, ProviderInfo> providers;
  final bool isLoading;
  final String? testResult; // 'success', 'failed', or null

  const AiSettingsState({
    this.mode = AiMode.orbitDefault,
    this.providers = const {},
    this.isLoading = false,
    this.testResult,
  });

  AiSettingsState copyWith({
    AiMode? mode,
    Map<String, ProviderInfo>? providers,
    bool? isLoading,
    String? testResult,
  }) {
    return AiSettingsState(
      mode: mode ?? this.mode,
      providers: providers ?? this.providers,
      isLoading: isLoading ?? this.isLoading,
      testResult: testResult,
    );
  }
}

// ── Provider Definitions ─────────────────────────────────────────────────────

const _defaultProviders = {
  'gemini': ProviderInfo(
    id: 'gemini',
    name: 'Google Gemini',
    description: 'Fast, powerful, and great at structured tasks.',
    setupUrl: 'https://aistudio.google.com/app/apikey',
    availableModels: [
      'gemini-3.1-flash-lite',
      'gemini-2.5-flash-lite',
      'gemini-2.5-flash',
      'gemini-3-flash',
    ],
    recommendedModel: 'gemini-3.1-flash-lite',
  ),
  'groq': ProviderInfo(
    id: 'groq',
    name: 'Groq',
    description: 'Ultra-fast inference. Generous free tier.',
    setupUrl: 'https://console.groq.com/keys',
    availableModels: [
      'llama-3.3-70b-versatile',
      'qwen/qwen3.6-27b',
      'llama-3.1-8b-instant',
    ],
    recommendedModel: 'llama-3.3-70b-versatile',
  ),
};

// ── Riverpod Controller ──────────────────────────────────────────────────────

final aiSettingsProvider =
    NotifierProvider<AiSettingsController, AiSettingsState>(
      AiSettingsController.new,
    );

class AiSettingsController extends Notifier<AiSettingsState> {
  Map<String, ProviderInfo>? _loadedProviders;

  @override
  AiSettingsState build() {
    final manager = ref.read(aiRequestManagerProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    // Load initial state
    final mode = manager.aiMode == 'user_key'
        ? AiMode.userKey
        : AiMode.orbitDefault;

    // Load provider statuses
    final providers =
        _loadedProviders ?? Map<String, ProviderInfo>.from(_defaultProviders);
    for (final id in providers.keys) {
      final hasKey = prefs.getBool('has_user_key_$id') ?? false;
      final health = manager.healthMonitor.getStatus(id);
      providers[id] = providers[id]!.copyWith(
        hasUserKey: hasKey,
        status: health,
      );
    }

    if (_loadedProviders == null) {
      _loadUserKeyStatus();
    }

    return AiSettingsState(mode: mode, providers: providers);
  }

  Future<void> _loadUserKeyStatus() async {
    final manager = ref.read(aiRequestManagerProvider);
    final providers = Map<String, ProviderInfo>.from(state.providers);
    final prefs = ref.read(sharedPreferencesProvider);

    for (final id in providers.keys) {
      final key = await SecureKeyStorage.getKey(id);
      final hasKey = key != null && key.isNotEmpty;

      await prefs.setBool('has_user_key_$id', hasKey);
      providers[id] = providers[id]!.copyWith(hasUserKey: hasKey);

      if (hasKey && manager.aiMode == 'user_key') {
        await manager.registerProviderWithKey(id, key);
      }
    }
    _loadedProviders = providers;
    state = state.copyWith(providers: providers);
    await manager.ensureInitialized();
  }

  /// Switch between Orbit Default and User API Key mode.
  Future<void> setMode(AiMode mode) async {
    final manager = ref.read(aiRequestManagerProvider);
    final modeStr = mode == AiMode.userKey ? 'user_key' : 'orbit_default';
    await manager.setAiMode(modeStr);
    state = state.copyWith(mode: mode);
    AppLogger.info('AiSettings: Mode set to $modeStr');
  }

  /// Connect a provider with a user-supplied API key.
  Future<bool> connectProvider(String providerId, String apiKey) async {
    state = state.copyWith(isLoading: true, testResult: null);

    final manager = ref.read(aiRequestManagerProvider);
    final isValid = await manager.validateApiKey(providerId, apiKey);

    if (isValid) {
      // Store securely
      await SecureKeyStorage.saveKey(providerId, apiKey);

      // Save connection status flag in SharedPreferences
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('has_user_key_$providerId', true);

      // Register with the manager
      await manager.registerProviderWithKey(providerId, apiKey);

      // Update state
      final providers = Map<String, ProviderInfo>.from(state.providers);
      providers[providerId] = providers[providerId]!.copyWith(
        hasUserKey: true,
        status: ProviderHealthStatus.healthy,
      );

      _loadedProviders = providers;
      state = state.copyWith(
        providers: providers,
        isLoading: false,
        testResult: 'success',
      );
      return true;
    } else {
      final providers = Map<String, ProviderInfo>.from(state.providers);
      providers[providerId] = providers[providerId]!.copyWith(
        status: ProviderHealthStatus.invalidKey,
      );

      _loadedProviders = providers;
      state = state.copyWith(
        providers: providers,
        isLoading: false,
        testResult: 'failed',
      );
      return false;
    }
  }

  /// Disconnect a provider (remove user's API key).
  Future<void> disconnectProvider(String providerId) async {
    await SecureKeyStorage.deleteKey(providerId);

    // Save connection status flag in SharedPreferences
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('has_user_key_$providerId', false);

    final manager = ref.read(aiRequestManagerProvider);
    await manager.unregisterProvider(providerId);

    final providers = Map<String, ProviderInfo>.from(state.providers);
    providers[providerId] = providers[providerId]!.copyWith(
      hasUserKey: false,
      status: ProviderHealthStatus.unknown,
    );
    _loadedProviders = providers;
    state = state.copyWith(providers: providers, testResult: null);
  }

  /// Test connection for a specific provider.
  Future<void> testConnection(String providerId) async {
    state = state.copyWith(isLoading: true, testResult: null);

    final manager = ref.read(aiRequestManagerProvider);
    try {
      final healthy = await manager.testProviderConnection(providerId);
      final providers = Map<String, ProviderInfo>.from(state.providers);
      providers[providerId] = providers[providerId]!.copyWith(
        status: healthy
            ? ProviderHealthStatus.healthy
            : ProviderHealthStatus.offline,
      );
      _loadedProviders = providers;
      state = state.copyWith(
        providers: providers,
        isLoading: false,
        testResult: healthy ? 'success' : 'failed',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, testResult: 'failed');
    }
  }

  /// Clear the test result message.
  void clearTestResult() {
    state = state.copyWith(testResult: null);
  }
}
