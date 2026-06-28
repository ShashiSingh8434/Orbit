import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// A serial FIFO queue that ensures only one AI request is in-flight at a time.
///
/// This prevents accidental rate limits caused by concurrent requests
/// (e.g. paragraph + bullet summary firing simultaneously).
class RequestQueue {
  final int _maxConcurrency;
  int _activeCount = 0;
  final Queue<_QueuedTask> _queue = Queue();

  /// The maximum time a single request is allowed to take before it is
  /// considered timed out and the next request in the queue is processed.
  final Duration timeout;

  RequestQueue({
    this._maxConcurrency = 1,
    this.timeout = const Duration(seconds: 60),
  });

  /// Number of items currently waiting in the queue.
  int get queueLength => _queue.length;

  /// Number of requests currently being processed.
  int get activeCount => _activeCount;

  /// Enqueue a task and wait for its result.
  ///
  /// The [task] callback is a Future-returning function that performs the
  /// actual AI call. It will be executed when the queue slot is available.
  Future<T> enqueue<T>(Future<T> Function() task, {String? requestId}) async {
    // Deduplication: if a request with the same ID is already queued, skip it.
    if (requestId != null) {
      final existing = _queue.where((q) => q.requestId == requestId);
      if (existing.isNotEmpty) {
        debugPrint('RequestQueue: Deduplicating request "$requestId"');
        return existing.first.completer.future as Future<T>;
      }
    }

    final completer = Completer<T>();
    _queue.add(
      _QueuedTask(
        execute: () async {
          try {
            final result = await task().timeout(timeout);
            completer.complete(result);
          } catch (e, s) {
            completer.completeError(e, s);
          }
        },
        completer: completer,
        requestId: requestId,
      ),
    );

    _processNext();
    return completer.future;
  }

  void _processNext() {
    if (_activeCount >= _maxConcurrency) return;
    if (_queue.isEmpty) return;

    final next = _queue.removeFirst();
    _activeCount++;

    next.execute().whenComplete(() {
      _activeCount--;
      _processNext();
    });
  }
}

class _QueuedTask {
  final Future<void> Function() execute;
  final Completer completer;
  final String? requestId;

  _QueuedTask({required this.execute, required this.completer, this.requestId});
}
