import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:cue/data/api_client.dart';
import 'package:cue/data/task_store.dart';
import 'package:cue/data/token_store.dart';
import 'package:cue/models/cue_task.dart';

void main() {
  test('coalesces incremental sync requests and records sync state', () async {
    final api = _FakeApiClient();
    final store = TaskStore.remote(api);

    final first = store.sync();
    final second = store.sync();

    expect(identical(first, second), isTrue);
    expect(api.syncCalls, 1);
    expect(store.isSyncing, isTrue);

    api.syncCompleter.complete(
      SyncResult(changes: [_task(revision: 7)], latestRevision: 7),
    );
    await first;

    expect(store.isSyncing, isFalse);
    expect(store.latestRevision, 7);
    expect(store.tasks.single.title, 'Synced task');
    expect(store.lastSyncedAt, isNotNull);
    expect(store.lastError, isNull);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(TokenStore());

  final syncCompleter = Completer<SyncResult>();
  int syncCalls = 0;

  @override
  Future<SyncResult> sync(int since) {
    syncCalls += 1;
    return syncCompleter.future;
  }
}

CueTask _task({required int revision}) {
  final now = DateTime(2026, 9, 15, 10);
  return CueTask(
    id: 'synced-task',
    title: 'Synced task',
    note: '',
    status: CueTaskStatus.todo,
    priority: 2,
    important: false,
    sortOrder: 1000,
    dueAt: now,
    createdAt: now,
    updatedAt: now,
    version: 1,
    revision: revision,
  );
}
