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

  test(
    'preserves an in-flight edit until a conflicting remote change is resolved',
    () async {
      final api = _FakeApiClient();
      final store = TaskStore([_task(revision: 1)], api: api);

      final mutation = store.toggleComplete(store.tasks.single);
      expect(store.tasks.single.isCompleted, isTrue);

      final sync = store.sync();
      api.syncCompleter.complete(
        SyncResult(
          changes: [
            _task(revision: 2).copyWith(title: 'Changed on phone', version: 2),
          ],
          latestRevision: 2,
        ),
      );
      await sync;
      expect(store.tasks.single.isCompleted, isTrue);

      final assertion = expectLater(mutation, throwsA(isA<ApiException>()));
      api.updateCompleter.completeError(
        const ApiException('Conflict', statusCode: 409),
      );
      await assertion;
      expect(store.tasks.single.title, 'Changed on phone');
      expect(store.tasks.single.version, 2);
    },
  );

  test('updates task title, priority, and due date in store', () async {
    final store = TaskStore([_task(revision: 1)]);
    final task = store.tasks.single;

    await store.updateTitle(task, 'New Title');
    expect(store.tasks.single.title, 'New Title');

    await store.updatePriority(store.tasks.single, 0);
    expect(store.tasks.single.priority, 0);

    final tomorrow = DateTime(2026, 9, 16, 18);
    await store.updateDueAt(store.tasks.single, tomorrow);
    expect(store.tasks.single.dueAt, tomorrow);

    await store.updateDueAt(store.tasks.single, null);
    expect(store.tasks.single.dueAt, isNull);
  });

  test('updates task reminder and recurrence in store', () async {
    final store = TaskStore([_task(revision: 1)]);
    final task = store.tasks.single;

    final due = DateTime(2026, 9, 20, 10);
    await store.updateDueAt(
      task,
      due,
      reminder: 'min_30',
      recurrence: 'daily',
    );
    expect(store.tasks.single.dueAt, due);
    expect(store.tasks.single.reminder, 'min_30');
    expect(store.tasks.single.recurrence, 'daily');
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(TokenStore());

  final syncCompleter = Completer<SyncResult>();
  final updateCompleter = Completer<CueTask>();
  int syncCalls = 0;

  @override
  Future<SyncResult> sync(int since) {
    syncCalls += 1;
    return syncCompleter.future;
  }

  @override
  Future<CueTask> updateTask(CueTask task, Map<String, dynamic> changes) {
    return updateCompleter.future;
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
