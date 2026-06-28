import 'package:flutter/foundation.dart';
import '../providers/ai_provider.dart';
import 'ai_health_monitor.dart';
import 'rate_limit_manager.dart';

/// Monitors provider health and selects which [AiProvider] to use for a request.
///
/// Selection logic:
/// 1. Iterate providers sorted by priority.
/// 2. If provider is in excludeIds, skip it.
/// 3. If provider is not usable (rate limited, cooling down, invalid key, or offline), skip it.
/// 4. Return the first available provider, or throw [AllProvidersExhaustedException].
class ProviderRouter {
  final RateLimitManager _rateLimitManager;
  final AiHealthMonitor _healthMonitor;
  final Map<String, AiProvider> _providers = {};

  ProviderRouter({
    required RateLimitManager rateLimitManager,
    required AiHealthMonitor healthMonitor,
  })  : _rateLimitManager = rateLimitManager,
        _healthMonitor = healthMonitor;

  /// Register a provider. Can be called multiple times to add/replace providers.
  void registerProvider(AiProvider provider) {
    _providers[provider.id] = provider;
    debugPrint(
      'ProviderRouter: Registered provider "${provider.id}" (${provider.name})',
    );
  }

  /// Remove a provider (e.g. when user disconnects their key).
  void unregisterProvider(String providerId) {
    _providers.remove(providerId);
    debugPrint('ProviderRouter: Unregistered provider "$providerId"');
  }

  /// All registered provider IDs.
  List<String> get registeredProviderIds => _providers.keys.toList();

  /// Whether a given provider is registered.
  bool hasProvider(String providerId) => _providers.containsKey(providerId);

  /// Helper to determine if a provider is usable.
  bool isUsable(String providerId) {
    if (!_rateLimitManager.canUseProvider(providerId)) return false;
    final health = _healthMonitor.getStatus(providerId);
    if (health == ProviderHealthStatus.invalidKey ||
        health == ProviderHealthStatus.offline) {
      return false;
    }
    return true;
  }

  /// Select the best available provider for a request.
  ///
  /// Throws [AllProvidersExhaustedException] if none are available.
  AiProvider selectProvider({Set<String>? excludeIds}) {
    final candidates = _providers.values.where((provider) {
      if (excludeIds != null && excludeIds.contains(provider.id)) {
        return false;
      }
      return isUsable(provider.id);
    }).toList();

    if (candidates.isEmpty) {
      throw const AllProvidersExhaustedException();
    }

    candidates.sort((a, b) => a.priority.compareTo(b.priority));
    return candidates.first;
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
