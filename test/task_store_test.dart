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
    expect(store.tasks.single.important, isTrue);

    await store.updatePriority(store.tasks.single, 1);
    expect(store.tasks.single.important, isFalse);

    final tomorrow = DateTime(2026, 9, 16, 18);
    await store.updateDueAt(store.tasks.single, tomorrow);
    expect(store.tasks.single.dueAt, tomorrow);

    await store.updateDueAt(store.tasks.single, null);
    expect(store.tasks.single.dueAt, isNull);
  });

  test('assigns each quadrant to exactly one priority', () {
    final store = TaskStore([
      _task(revision: 1, id: 'p0').copyWith(priority: 0, sortOrder: 4000),
      _task(revision: 2, id: 'p1').copyWith(priority: 1, sortOrder: 3000),
      _task(revision: 3, id: 'p2').copyWith(priority: 2, sortOrder: 2000),
      _task(revision: 4, id: 'p3').copyWith(priority: 3, sortOrder: 1000),
    ]);

    for (var priority = 0; priority < 4; priority++) {
      expect(store.tasksForPriority(priority), hasLength(1));
      expect(store.tasksForPriority(priority).single.priority, priority);
    }
  });

  test('completion syncs completedAt without a task status field', () async {
    final api = _FakeApiClient();
    final store = TaskStore([_task(revision: 1)], api: api);

    final mutation = store.toggleComplete(store.tasks.single);
    final completed = store.tasks.single;

    expect(completed.completedAt, isNotNull);
    expect(api.lastChanges, contains('completedAt'));
    expect(api.lastChanges, isNot(contains('status')));

    api.updateCompleter.complete(completed.copyWith(version: 2, revision: 2));
    await mutation;
    expect(store.tasks.single.isCompleted, isTrue);
  });

  test('toggling a completed task returns it to unfinished', () async {
    final completed = _task(revision: 1)
        .copyWith(completedAt: DateTime(2026, 9, 15, 11));
    final store = TaskStore([completed]);

    await store.toggleComplete(completed);

    expect(store.tasks.single.isCompleted, isFalse);
    expect(store.tasks.single.completedAt, isNull);
  });

  test('corrects and syncs a task completion time', () async {
    final api = _FakeApiClient();
    final completed = _task(revision: 1)
        .copyWith(completedAt: DateTime(2026, 9, 15, 11));
    final store = TaskStore([completed], api: api);
    final corrected = DateTime(2026, 9, 14, 18, 30);

    final mutation = store.updateCompletedAt(completed, corrected);

    expect(store.tasks.single.completedAt, corrected);
    expect(
      api.lastChanges?['completedAt'],
      corrected.toUtc().toIso8601String(),
    );

    api.updateCompleter.complete(
      store.tasks.single.copyWith(version: 2, revision: 2),
    );
    await mutation;
    expect(store.tasks.single.completedAt, corrected);
  });

  test('updates task reminder and recurrence in store', () async {
    final store = TaskStore([_task(revision: 1)]);
    final task = store.tasks.single;

    final due = DateTime(2026, 9, 20, 10);
    await store.updateDueAt(task, due, reminder: 'min_30', recurrence: 'daily');
    expect(store.tasks.single.dueAt, due);
    expect(store.tasks.single.reminder, 'min_30');
    expect(store.tasks.single.recurrence, 'daily');
  });

  test('creates a task with a custom due time and schedule options', () async {
    final store = TaskStore([]);
    final dueAt = DateTime(2026, 10, 8, 9, 45);

    await store.addTask(
      title: 'Custom schedule',
      dueAt: dueAt,
      reminder: 'min_30',
      recurrence: 'weekly',
    );

    expect(store.tasks.single.dueAt, dueAt);
    expect(store.tasks.single.reminder, 'min_30');
    expect(store.tasks.single.recurrence, 'weekly');
  });

  test('groups come from user data rather than fixed demo labels', () {
    final store = TaskStore([]);

    expect(store.groups, [TaskStore.defaultUngrouped]);
    expect(store.groups, isNot(contains('社会事项')));
    expect(store.groups, isNot(contains('研发事项')));
    expect(store.groups, isNot(contains('工作')));

    store.addGroup('Personal');

    expect(store.groups, ['Personal', TaskStore.defaultUngrouped]);
  });

  test('recurring task appears on subsequent matching days', () async {
    final start = DateTime(2026, 9, 20);
    final task = _task(revision: 1).copyWith(dueAt: start, recurrence: 'daily');
    final store = TaskStore([task], today: start);

    // Initial day 9/20
    expect(store.tasksForDay(DateTime(2026, 9, 20)).length, 1);
    // Subsequent days 9/21, 9/22, 9/23
    expect(store.tasksForDay(DateTime(2026, 9, 21)).length, 1);
    expect(store.tasksForDay(DateTime(2026, 9, 22)).length, 1);
    expect(store.tasksForDay(DateTime(2026, 9, 23)).length, 1);
    // Day before start 9/19 -> 0
    expect(store.tasksForDay(DateTime(2026, 9, 19)).length, 0);

    // Weekly recurrence
    final weeklyTask = task.copyWith(recurrence: 'weekly');
    final weeklyStore = TaskStore([weeklyTask], today: start);
    // 9/20 is Sunday
    expect(weeklyStore.tasksForDay(DateTime(2026, 9, 20)).length, 1);
    expect(weeklyStore.tasksForDay(DateTime(2026, 9, 21)).length, 0); // Monday
    expect(
      weeklyStore.tasksForDay(DateTime(2026, 9, 27)).length,
      1,
    ); // Next Sunday
  });

  test(
    'supports task groups, renaming, deleting, and updating task group',
    () async {
      final store = TaskStore([
        _task(revision: 1, id: 't1').copyWith(group: 'Work'),
        _task(revision: 2, id: 't2').copyWith(group: 'Personal'),
      ]);

      expect(
        store.groups,
        containsAll(['Work', 'Personal', TaskStore.defaultUngrouped]),
      );
      expect(store.activeTasksForGroup('Work').length, 1);
      expect(store.activeTasksForGroup('Personal').length, 1);
      expect(store.activeTasksForGroup(TaskStore.defaultUngrouped).length, 0);

      // Add group
      store.addGroup('Finance');
      expect(store.groups, contains('Finance'));

      // Rename group
      store.renameGroup('Work', 'Career');
      expect(store.groups, contains('Career'));
      expect(store.groups, isNot(contains('Work')));
      expect(store.tasks.firstWhere((t) => t.id == 't1').group, 'Career');

      // Reorder groups in either direction, including the ungrouped column.
      store.moveGroup(TaskStore.defaultUngrouped, 'Career');
      expect(
        store.groups.indexOf(TaskStore.defaultUngrouped),
        lessThan(store.groups.indexOf('Career')),
      );
      store.moveGroup('Career', 'Personal');
      expect(
        store.groups.indexOf('Career'),
        greaterThan(store.groups.indexOf('Personal')),
      );

      // Update task group directly
      final task2 = store.tasks.firstWhere((t) => t.id == 't2');
      await store.updateGroup(task2, 'Finance');
      expect(store.tasks.firstWhere((t) => t.id == 't2').group, 'Finance');

      // Delete group
      store.deleteGroup('Finance');
      expect(store.groups, isNot(contains('Finance')));
      // Task previously in deleted group now has null group (falls back to ungrouped)
      expect(store.tasks.firstWhere((t) => t.id == 't2').group, isNull);
      expect(store.activeTasksForGroup(TaskStore.defaultUngrouped).length, 1);
    },
  );
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(TokenStore());

  final syncCompleter = Completer<SyncResult>();
  final updateCompleter = Completer<CueTask>();
  int syncCalls = 0;
  Map<String, dynamic>? lastChanges;

  @override
  Future<SyncResult> sync(int since) {
    syncCalls += 1;
    return syncCompleter.future;
  }

  @override
  Future<CueTask> updateTask(CueTask task, Map<String, dynamic> changes) {
    lastChanges = Map.of(changes);
    return updateCompleter.future;
  }
}

CueTask _task({required int revision, String id = 'synced-task'}) {
  final now = DateTime(2026, 9, 15, 10);
  return CueTask(
    id: id,
    title: 'Synced task',
    note: '',
    priority: 2,
    sortOrder: 1000,
    dueAt: now,
    createdAt: now,
    updatedAt: now,
    version: 1,
    revision: revision,
  );
}
