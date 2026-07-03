import '../../utils/app_logger.dart';

/// Tracks per-provider rate-limit state and enforces exponential backoff cooldowns.
///
/// When a provider returns a 429 (rate limited), the manager puts it into a
/// cooldown period. Cooldown durations escalate with consecutive failures:
///   1 min → 5 min → 15 min → 30 min
class RateLimitManager {
  final Map<String, _ProviderRateState> _states = {};

  static const List<Duration> _cooldownLadder = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  /// Whether [providerId] is currently available (not cooling down).
  bool canUseProvider(String providerId) {
    final state = _states[providerId];
    if (state == null) return true;
    if (state.cooldownExpiry == null) return true;
    if (DateTime.now().isAfter(state.cooldownExpiry!)) {
      // Cooldown has expired — provider is usable again.
      return true;
    }
    return false;
  }

  /// How long until the provider is available again, or [Duration.zero] if ready.
  Duration cooldownRemaining(String providerId) {
    final state = _states[providerId];
    if (state == null) return Duration.zero;
    if (state.cooldownExpiry == null) return Duration.zero;
    final remaining = state.cooldownExpiry!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Call after a successful request to reset the failure counter.
  void recordSuccess(String providerId) {
    final state = _getOrCreate(providerId);
    state.consecutiveFailures = 0;
    state.cooldownExpiry = null;
    state.lastSuccess = DateTime.now();
    state.requestsThisMinute++;
    AppLogger.debug('RateLimitManager: $providerId success (streak reset)');
  }

  /// Call when a provider returns a rate-limit error.
  /// Optionally pass a [retryAfter] hint from the provider.
  void recordRateLimit(String providerId, {Duration? retryAfter}) {
    final state = _getOrCreate(providerId);
    state.consecutiveFailures++;

    // Use provider hint if available, otherwise escalate via the ladder.
    final ladderIndex = (state.consecutiveFailures - 1).clamp(
      0,
      _cooldownLadder.length - 1,
    );
    final cooldown = retryAfter ?? _cooldownLadder[ladderIndex];

    state.cooldownExpiry = DateTime.now().add(cooldown);
    AppLogger.warning(
      'RateLimitManager: $providerId rate-limited. '
      'Failures=${state.consecutiveFailures}, cooldown=${cooldown.inSeconds}s',
    );
  }

  /// Call on non-rate-limit errors (server error, network timeout) to track streaks.
  void recordFailure(String providerId) {
    final state = _getOrCreate(providerId);
    state.consecutiveFailures++;
    AppLogger.warning(
      'RateLimitManager: $providerId failure #${state.consecutiveFailures}',
    );
  }

  /// Number of consecutive failures for a provider.
  int consecutiveFailures(String providerId) {
    return _states[providerId]?.consecutiveFailures ?? 0;
  }

  /// Reset all state (e.g. on provider key change).
  void resetProvider(String providerId) {
    _states.remove(providerId);
  }

  _ProviderRateState _getOrCreate(String providerId) {
    return _states.putIfAbsent(providerId, () => _ProviderRateState());
  }
}

class _ProviderRateState {
  int requestsThisMinute = 0;
  int consecutiveFailures = 0;
  DateTime? lastSuccess;
  DateTime? cooldownExpiry;
}
