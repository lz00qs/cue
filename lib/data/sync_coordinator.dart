import 'dart:async';

import 'task_store.dart';

class SyncCoordinator {
  SyncCoordinator(
    this.store, {
    this.fallbackInterval = const Duration(minutes: 1),
    this.initialReconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
  });

  final TaskStore store;
  final Duration fallbackInterval;
  final Duration initialReconnectDelay;
  final Duration maxReconnectDelay;

  StreamSubscription<int>? _events;
  Timer? _fallbackTimer;
  Timer? _reconnectTimer;
  late Duration _reconnectDelay = initialReconnectDelay;
  bool _started = false;
  bool _paused = false;
  bool _disposed = false;

  void start() {
    if (_started || _disposed || !store.isRemote) return;
    _started = true;
    _fallbackTimer = Timer.periodic(fallbackInterval, (_) {
      if (!_paused) unawaited(_syncSilently());
    });
    _connect();
  }

  void resume() {
    if (!_started || _disposed) return;
    _paused = false;
    unawaited(_syncSilently());
    _connect();
  }

  void pause() {
    if (!_started || _disposed) return;
    _paused = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final events = _events;
    _events = null;
    if (events != null) unawaited(events.cancel());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _fallbackTimer?.cancel();
    _reconnectTimer?.cancel();
    final events = _events;
    _events = null;
    if (events != null) unawaited(events.cancel());
  }

  void _connect() {
    if (_disposed || _paused || _events != null || !store.isRemote) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _events = store.api!.watchRevisions().listen(
      (revision) {
        _reconnectDelay = initialReconnectDelay;
        if (revision == 0) {
          unawaited(_syncSilently());
        } else if (revision > store.latestRevision) {
          unawaited(_syncSilently(requiredRevision: revision));
        }
      },
      onError: (_) => _disconnected(),
      onDone: _disconnected,
    );
  }

  void _disconnected() {
    final events = _events;
    _events = null;
    if (events != null) unawaited(events.cancel());
    if (_disposed || _paused || _reconnectTimer != null) return;
    final delay = _reconnectDelay;
    _reconnectDelay = Duration(
      milliseconds: (_reconnectDelay.inMilliseconds * 2).clamp(
        initialReconnectDelay.inMilliseconds,
        maxReconnectDelay.inMilliseconds,
      ),
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _connect();
    });
  }

  Future<void> _syncSilently({int? requiredRevision}) async {
    try {
      await store.sync();
      // A notification may arrive while a prior sync is already in flight.
      // Coalescing that request is safe only if the result includes the signal.
      if (requiredRevision != null &&
          requiredRevision > store.latestRevision &&
          !_disposed &&
          !_paused) {
        await store.sync();
      }
    } catch (_) {
      // The store exposes sync errors; the SSE listener and fallback keep going.
    }
  }
}
