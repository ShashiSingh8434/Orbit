import 'dart:collection';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Simple in-memory LRU cache with TTL for AI responses.
///
/// Prevents redundant API calls when the same prompt is sent multiple times
/// within a short window (e.g. the user navigates back and forth).
class ResponseCache {
  final int maxEntries;
  final Duration ttl;

  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();

  ResponseCache({
    this.maxEntries = 50,
    this.ttl = const Duration(minutes: 5),
  });

  /// Generate a cache key from the prompt and provider.
  String _makeKey(String prompt, String providerId) {
    final input = '$providerId:$prompt';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Try to get a cached response. Returns `null` if not found or expired.
  String? get(String prompt, String providerId) {
    final key = _makeKey(prompt, providerId);
    final entry = _cache[key];
    if (entry == null) return null;

    // Check TTL
    if (DateTime.now().difference(entry.timestamp) > ttl) {
      _cache.remove(key);
      return null;
    }

    // Move to end (most recently used)
    _cache.remove(key);
    _cache[key] = entry;

    return entry.response;
  }

  /// Store a response in the cache.
  void put(String prompt, String providerId, String response) {
    final key = _makeKey(prompt, providerId);

    // Evict oldest if full
    while (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = _CacheEntry(
      response: response,
      timestamp: DateTime.now(),
    );
  }

  /// Clear the entire cache.
  void clear() => _cache.clear();

  /// Number of entries currently in the cache.
  int get size => _cache.length;
}

class _CacheEntry {
  final String response;
  final DateTime timestamp;

  _CacheEntry({required this.response, required this.timestamp});
}
