import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:cue/data/api_client.dart';
import 'package:cue/data/sync_coordinator.dart';
import 'package:cue/data/task_store.dart';
import 'package:cue/data/token_store.dart';

void main() {
  test(
    'parses revision events across HTTP chunks and ignores heartbeats',
    () async {
      final chunks = [
        'event: cha',
        'nge\ndata: {"revision":7}\n\n',
        'event: heartbeat\ndata: {}\n\n',
        'event: change\ndata: {"revision":8}\n\n',
      ].map(utf8.encode);

      expect(await parseSseRevisions(Stream.fromIterable(chunks)).toList(), [
        7,
        8,
      ]);
    },
  );

  test('SSE revision triggers incremental sync only when newer', () async {
    final api = _EventApiClient();
    final store = TaskStore.remote(api);
    final coordinator = SyncCoordinator(store);
    final synced = Completer<void>();
    store.addListener(() {
      if (store.latestRevision == 7 && !synced.isCompleted) synced.complete();
    });
    addTearDown(() async {
      coordinator.dispose();
      await api.events.close();
      store.dispose();
    });

    coordinator.start();
    api.events.add(7);
    await synced.future.timeout(const Duration(seconds: 2));
    expect(api.syncCalls, 1);
    expect(store.latestRevision, 7);

    api.events.add(7);
    await Future<void>.delayed(Duration.zero);
    expect(api.syncCalls, 1);

    coordinator.pause();
    api.events.add(8);
    await Future<void>.delayed(Duration.zero);
    expect(api.syncCalls, 1);

    coordinator.resume();
    await Future<void>.delayed(Duration.zero);
    expect(api.syncCalls, 2);
  });

  test(
    'notification during an in-flight sync triggers a follow-up fetch',
    () async {
      final api = _RacingApiClient();
      final store = TaskStore.remote(api);
      final coordinator = SyncCoordinator(store);
      addTearDown(() async {
        coordinator.dispose();
        await api.events.close();
        store.dispose();
      });

      coordinator.start();
      api.events.add(7);
      await api.firstStarted.future.timeout(const Duration(seconds: 2));
      api.events.add(8);
      await Future<void>.delayed(Duration.zero);
      api.first.complete(const SyncResult(changes: [], latestRevision: 7));

      await api.secondStarted.future.timeout(const Duration(seconds: 2));
      expect(api.syncCalls, 2);
      api.second.complete(const SyncResult(changes: [], latestRevision: 8));
    },
  );

  test('reconnects after the SSE stream closes', () async {
    final api = _ReconnectingApiClient();
    final store = TaskStore.remote(api);
    final coordinator = SyncCoordinator(
      store,
      fallbackInterval: const Duration(hours: 1),
      initialReconnectDelay: const Duration(milliseconds: 10),
      maxReconnectDelay: const Duration(milliseconds: 20),
    );
    addTearDown(() async {
      coordinator.dispose();
      await api.second.close();
      store.dispose();
    });

    coordinator.start();
    expect(api.watchCalls, 1);
    await api.first.close();
    await api.reconnected.future.timeout(const Duration(seconds: 2));
    expect(api.watchCalls, 2);
  });
}

class _EventApiClient extends ApiClient {
  _EventApiClient() : super(TokenStore());

  final events = StreamController<int>.broadcast();
  int syncCalls = 0;

  @override
  Stream<int> watchRevisions() => events.stream;

  @override
  Future<SyncResult> sync(int since) async {
    syncCalls++;
    return SyncResult(changes: const [], latestRevision: 7);
  }
}

class _RacingApiClient extends ApiClient {
  _RacingApiClient() : super(TokenStore());

  final events = StreamController<int>.broadcast();
  final first = Completer<SyncResult>();
  final second = Completer<SyncResult>();
  final firstStarted = Completer<void>();
  final secondStarted = Completer<void>();
  int syncCalls = 0;

  @override
  Stream<int> watchRevisions() => events.stream;

  @override
  Future<SyncResult> sync(int since) {
    syncCalls++;
    if (syncCalls == 1) {
      firstStarted.complete();
      return first.future;
    }
    secondStarted.complete();
    return second.future;
  }
}

class _ReconnectingApiClient extends ApiClient {
  _ReconnectingApiClient() : super(TokenStore());

  final first = StreamController<int>();
  final second = StreamController<int>();
  final reconnected = Completer<void>();
  int watchCalls = 0;

  @override
  Stream<int> watchRevisions() {
    watchCalls++;
    if (watchCalls == 1) return first.stream;
    if (!reconnected.isCompleted) reconnected.complete();
    return second.stream;
  }

  @override
  Future<SyncResult> sync(int since) async =>
      SyncResult(changes: const [], latestRevision: since);
}
