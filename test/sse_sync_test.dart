import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:cue/data/api_client.dart';
import 'package:cue/data/app_storage.dart';
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

  test('treats an interrupted SSE response as a reconnectable close', () async {
    final body = StreamController<List<int>>();
    final storage = _MemoryStorage();
    final tokens = TokenStore(storage: storage);
    await tokens.save(
      accessToken: 'access',
      refreshToken: 'refresh',
      email: 'admin@cue.local',
    );
    final api = ApiClient(
      tokens,
      baseUrl: 'http://cue.test',
      sseClientFactory: () => MockClient.streaming((request, bodyStream) async {
        expect(request.url.path, '/api/sync/events');
        return http.StreamedResponse(
          body.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    final revisions = api.watchRevisions().toList();
    await Future<void>.delayed(Duration.zero);
    body.add(utf8.encode('event: change\ndata: {"revision":7}\n\n'));
    body.addError(
      http.ClientException(
        'Connection closed while receiving data',
        Uri.parse('http://cue.test/api/sync/events'),
      ),
    );
    await body.close();

    expect(await revisions, [0, 7]);
  });

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

  test('does not leak a subscription cancellation error', () async {
    final api = _CancelFailureApiClient();
    final store = TaskStore.remote(api);
    final coordinator = SyncCoordinator(store);
    addTearDown(() async {
      coordinator.dispose();
      await api.events.close();
      store.dispose();
    });

    coordinator.start();
    coordinator.pause();
    await Future<void>.delayed(Duration.zero);
  });
}

class _MemoryStorage implements AppStorage {
  final values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
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

class _CancelFailureApiClient extends ApiClient {
  _CancelFailureApiClient() : super(TokenStore());

  late final StreamController<int> events = StreamController<int>(
    onCancel: () async => throw StateError('simulated socket close race'),
  );

  @override
  Stream<int> watchRevisions() => events.stream;
}
