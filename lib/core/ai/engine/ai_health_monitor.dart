import '../../utils/app_logger.dart';

import '../providers/ai_request.dart';

/// Maintains real-time health status for each registered provider.
///
/// The [ProviderRouter] reads this to avoid routing requests to unhealthy providers.
class AiHealthMonitor {
  final Map<String, ProviderHealthStatus> _statuses = {};

  /// Get the current health status of a provider.
  ProviderHealthStatus getStatus(String providerId) {
    return _statuses[providerId] ?? ProviderHealthStatus.healthy;
  }

  /// Update health based on a successful response.
  void recordSuccess(String providerId) {
    _statuses[providerId] = ProviderHealthStatus.healthy;
    AppLogger.debug('AiHealthMonitor: $providerId → healthy');
  }

  /// Update health based on a failure.
  void recordFailure(String providerId, AiErrorType errorType) {
    switch (errorType) {
      case AiErrorType.rateLimited:
        _statuses[providerId] = ProviderHealthStatus.rateLimited;
        break;
      case AiErrorType.invalidApiKey:
        _statuses[providerId] = ProviderHealthStatus.invalidKey;
        break;
      case AiErrorType.networkError:
      case AiErrorType.serverError:
        _statuses[providerId] = ProviderHealthStatus.offline;
        break;
      default:
        // Don't change status on unknown/bad-request errors
        break;
    }
    AppLogger.debug('AiHealthMonitor: $providerId → ${_statuses[providerId]}');
  }

  /// Manually set a provider's status (e.g. after key validation).
  void setStatus(String providerId, ProviderHealthStatus status) {
    _statuses[providerId] = status;
  }

  /// Reset a provider's health (e.g. after key change).
  void resetProvider(String providerId) {
    _statuses.remove(providerId);
  }
}

/// Possible health states for a provider.
enum ProviderHealthStatus {
  /// Last request succeeded — provider is fully operational.
  healthy,

  /// Provider returned a 429 — cooling down.
  rateLimited,

  /// Too many consecutive network/server failures.
  offline,

  /// API key is invalid or expired.
  invalidKey,

  /// Provider has never been tested.
  unknown,
}
