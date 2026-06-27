import 'package:flutter/foundation.dart';
import '../providers/ai_provider.dart';
import 'rate_limit_manager.dart';

/// Monitors provider health and selects which [AiProvider] to use for a request.
///
/// Selection logic:
/// 1. Try the user's preferred provider (if healthy + not cooling down).
/// 2. If preferred is unavailable, iterate the remaining providers by priority.
/// 3. If no provider is available, throw [AllProvidersExhaustedException].
class ProviderRouter {
  final RateLimitManager _rateLimitManager;
  final Map<String, AiProvider> _providers = {};
  String? _preferredProviderId;

  ProviderRouter({
    required RateLimitManager rateLimitManager,
  }) : _rateLimitManager = rateLimitManager;

  /// Register a provider. Can be called multiple times to add/replace providers.
  void registerProvider(AiProvider provider) {
    _providers[provider.id] = provider;
    debugPrint('ProviderRouter: Registered provider "${provider.id}" (${provider.name})');
  }

  /// Remove a provider (e.g. when user disconnects their key).
  void unregisterProvider(String providerId) {
    _providers.remove(providerId);
    debugPrint('ProviderRouter: Unregistered provider "$providerId"');
  }

  /// Set the user's preferred provider.
  void setPreferred(String providerId) {
    _preferredProviderId = providerId;
    debugPrint('ProviderRouter: Preferred provider set to "$providerId"');
  }

  /// Get the current preferred provider ID.
  String? get preferredProviderId => _preferredProviderId;

  /// All registered provider IDs.
  List<String> get registeredProviderIds => _providers.keys.toList();

  /// Whether a given provider is registered.
  bool hasProvider(String providerId) => _providers.containsKey(providerId);

  /// Select the best available provider for a request.
  ///
  /// Throws [AllProvidersExhaustedException] if none are available.
  AiProvider selectProvider() {
    // 1. Try preferred
    if (_preferredProviderId != null && _providers.containsKey(_preferredProviderId)) {
      final preferred = _providers[_preferredProviderId]!;
      if (_rateLimitManager.canUseProvider(preferred.id)) {
        debugPrint('ProviderRouter: Using preferred provider "${preferred.id}"');
        return preferred;
      }
      debugPrint(
        'ProviderRouter: Preferred "${preferred.id}" is cooling down '
        '(${_rateLimitManager.cooldownRemaining(preferred.id).inSeconds}s remaining)',
      );
    }

    // 2. Try remaining providers sorted by priority
    final sorted = _providers.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final provider in sorted) {
      if (provider.id == _preferredProviderId) continue; // Already tried
      if (_rateLimitManager.canUseProvider(provider.id)) {
        debugPrint('ProviderRouter: Falling back to "${provider.id}"');
        return provider;
      }
    }

    // 3. No providers available
    throw const AllProvidersExhaustedException();
  }

  /// Get a specific provider by ID (for validation, health checks, etc.).
  AiProvider? getProvider(String providerId) => _providers[providerId];
}

/// Thrown when all registered providers are rate-limited or otherwise unavailable.
class AllProvidersExhaustedException implements Exception {
  const AllProvidersExhaustedException();

  @override
  String toString() =>
      'AllProvidersExhaustedException: All AI providers are currently unavailable. '
      'Please try again in a few minutes.';
}
