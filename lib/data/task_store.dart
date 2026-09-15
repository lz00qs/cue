import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/cue_task.dart';
import 'api_client.dart';

class TaskStore extends ChangeNotifier {
  TaskStore(this._tasks, {DateTime? today, this.api})
    : today = dateOnly(today ?? DateTime.now());

  factory TaskStore.remote(ApiClient api) => TaskStore([], api: api);

  factory TaskStore.demo() {
    final created = DateTime(2026, 9, 1, 9);

    CueTask task(
      String id,
      String title, {
      String note = '',
      CueTaskStatus status = CueTaskStatus.todo,
      int priority = 2,
      bool important = false,
      DateTime? dueAt,
      DateTime? completedAt,
      double order = 1000,
    }) {
      return CueTask(
        id: id,
        title: title,
        note: note,
        status: status,
        priority: priority,
        important: important,
        sortOrder: order,
        dueAt: dueAt,
        completedAt: completedAt,
        createdAt: created,
        updatedAt: completedAt ?? created,
      );
    }

    return TaskStore([
      task(
        'pcb-review',
        'Review PCB layout',
        note: 'Check routing, clearances, and the power plane before handoff.',
        priority: 0,
        important: true,
        dueAt: DateTime(2026, 9, 13, 10, 30),
        order: 1000,
      ),
      task(
        'thermal-simulation',
        'Run thermal simulation',
        note: 'Compare the revised enclosure against the baseline model.',
        status: CueTaskStatus.doing,
        priority: 1,
        important: true,
        dueAt: DateTime(2026, 9, 13, 14),
        order: 2000,
      ),
      task(
        'sprint-report',
        'Draft sprint report',
        note: 'Summarize decisions, risks, and next actions.',
        priority: 2,
        dueAt: DateTime(2026, 9, 13, 17),
        order: 3000,
      ),
      task(
        'lab-calibration',
        'Book lab calibration',
        note: 'Coordinate the chamber slot with operations.',
        priority: 3,
        dueAt: DateTime(2026, 9, 16),
        order: 4000,
      ),
      task(
        'requirements',
        'Finalize requirements',
        note: 'Approved for the September build.',
        status: CueTaskStatus.done,
        priority: 2,
        important: true,
        completedAt: DateTime(2026, 9, 13, 9, 15),
        dueAt: DateTime(2026, 9, 13, 9),
        order: 5000,
      ),
      task(
        'signal-drift',
        'Analyze signal drift',
        status: CueTaskStatus.doing,
        priority: 2,
        important: true,
        dueAt: DateTime(2026, 9, 15),
        order: 6000,
      ),
      task(
        'firmware-sync',
        'Sync firmware branch',
        status: CueTaskStatus.done,
        priority: 3,
        completedAt: DateTime(2026, 9, 11),
        dueAt: DateTime(2026, 9, 8),
        order: 7000,
      ),
      task(
        'design-handoff',
        'Prepare design handoff',
        priority: 2,
        important: true,
        dueAt: DateTime(2026, 9, 24),
        order: 8000,
      ),
      task(
        'october-roadmap',
        'Plan October roadmap',
        priority: 2,
        important: true,
        dueAt: DateTime(2026, 9, 30),
        order: 9000,
      ),
      task(
        'email-supplier',
        'Email component supplier',
        priority: 3,
        dueAt: DateTime(2026, 9, 14),
        order: 10000,
      ),
      task('archive-notes', 'Archive old notes', priority: 3, order: 11000),
      task(
        'report-templates',
        'Browse report templates',
        priority: 3,
        order: 12000,
      ),
    ], today: demoToday);
  }

  static final DateTime demoToday = DateTime(2026, 9, 13);

  final List<CueTask> _tasks;
  final ApiClient? api;
  final DateTime today;
  int latestRevision = 0;
  String? lastError;

  bool get isRemote => api != null;
  UnmodifiableListView<CueTask> get tasks => UnmodifiableListView(_tasks);

  Iterable<CueTask> get activeTasks =>
      _tasks.where((task) => task.deletedAt == null && !task.isCompleted);

  Iterable<CueTask> get completedTasks =>
      _tasks.where((task) => task.deletedAt == null && task.isCompleted);

  List<CueTask> get todayTasks {
    final result = _tasks.where((task) {
      final dueToday = task.dueAt != null && isSameDay(task.dueAt!, today);
      final completedToday =
          task.completedAt != null && isSameDay(task.completedAt!, today);
      return task.deletedAt == null && (dueToday || completedToday);
    }).toList();
    result.sort(_taskSort);
    return result;
  }

  List<CueTask> get upcomingTasks {
    final result = activeTasks
        .where(
          (task) => task.dueAt != null && task.dueAt!.isAfter(endOfDay(today)),
        )
        .toList();
    result.sort(_taskSort);
    return result;
  }

  List<CueTask> tasksForStatus(CueTaskStatus status) {
    final result = _tasks
        .where((task) => task.deletedAt == null && task.status == status)
        .toList();
    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }

  List<CueTask> tasksForDay(DateTime day) {
    final result = _tasks
        .where((task) => task.deletedAt == null && task.dueAt != null)
        .where((task) => isSameDay(task.dueAt!, day))
        .toList();
    result.sort(_taskSort);
    return result;
  }

  List<CueTask> quadrantTasks({required bool important, required bool urgent}) {
    final result = activeTasks.where((task) {
      return task.important == important && isUrgent(task) == urgent;
    }).toList();
    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }

  bool isUrgent(CueTask task) {
    if (task.dueAt == null) return false;
    final deadline = endOfDay(today.add(const Duration(days: 2)));
    return !task.dueAt!.isAfter(deadline);
  }

  Future<void> load() async {
    final client = api;
    if (client == null) return;
    try {
      final remoteTasks = await client.fetchTasks();
      _tasks
        ..clear()
        ..addAll(remoteTasks);
      latestRevision = remoteTasks.fold(
        0,
        (latest, task) => task.revision > latest ? task.revision : latest,
      );
      lastError = null;
      notifyListeners();
    } catch (error) {
      lastError = error.toString();
      rethrow;
    }
  }

  Future<void> sync() async {
    final client = api;
    if (client == null) return;
    try {
      final result = await client.sync(latestRevision);
      for (final change in result.changes) {
        final index = _tasks.indexWhere((task) => task.id == change.id);
        if (change.deletedAt != null) {
          if (index != -1) _tasks.removeAt(index);
        } else if (index == -1) {
          _tasks.add(change);
        } else {
          _tasks[index] = change;
        }
      }
      latestRevision = result.latestRevision;
      lastError = null;
      notifyListeners();
    } catch (error) {
      lastError = error.toString();
      rethrow;
    }
  }

  Future<void> addTask({
    required String title,
    String note = '',
    int priority = 2,
    bool important = false,
    CueTaskStatus status = CueTaskStatus.todo,
    DateTime? dueAt,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    final task = CueTask(
      id: 'task-local-${now.microsecondsSinceEpoch}',
      title: trimmed,
      note: note.trim(),
      status: status,
      priority: priority,
      important: important,
      sortOrder: _tasks.length * 1000 + 1000,
      dueAt: dueAt ?? DateTime(today.year, today.month, today.day, 18),
      completedAt: status == CueTaskStatus.done ? now : null,
      createdAt: now,
      updatedAt: now,
    );
    _tasks.add(task);
    notifyListeners();

    final client = api;
    if (client == null) return;
    try {
      final saved = await client.createTask(task);
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index != -1) _tasks[index] = saved;
      latestRevision = _max(latestRevision, saved.revision);
      lastError = null;
      notifyListeners();
    } catch (error) {
      _tasks.removeWhere((item) => item.id == task.id);
      lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleComplete(CueTask task) {
    final status = task.isCompleted ? CueTaskStatus.todo : CueTaskStatus.done;
    return _update(
      task,
      task.copyWith(
        status: status,
        completedAt: status == CueTaskStatus.done ? DateTime.now() : null,
        clearCompletedAt: status != CueTaskStatus.done,
      ),
      {'status': status.name},
    );
  }

  Future<void> moveToStatus(CueTask task, CueTaskStatus status) {
    if (task.status == status) return Future.value();
    final sortOrder = (tasksForStatus(status).length * 1000 + 1000).toDouble();
    return _update(
      task,
      task.copyWith(
        status: status,
        completedAt: status == CueTaskStatus.done ? DateTime.now() : null,
        clearCompletedAt: status != CueTaskStatus.done,
        sortOrder: sortOrder,
      ),
      {'status': status.name, 'sortOrder': sortOrder},
    );
  }

  Future<void> toggleImportant(CueTask task) => _update(
    task,
    task.copyWith(important: !task.important),
    {'important': !task.important},
  );

  Future<void> deleteTask(CueTask task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) return;
    _tasks.removeAt(index);
    notifyListeners();
    final client = api;
    if (client == null) return;
    try {
      final deleted = await client.deleteTask(task);
      latestRevision = _max(latestRevision, deleted.revision);
      lastError = null;
    } catch (error) {
      _tasks.insert(index.clamp(0, _tasks.length), task);
      lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _update(
    CueTask original,
    CueTask desired,
    Map<String, dynamic> changes,
  ) async {
    final optimistic = desired.copyWith(
      updatedAt: DateTime.now(),
      version: original.version + 1,
    );
    _replace(original.id, optimistic);
    final client = api;
    if (client == null) return;
    try {
      final saved = await client.updateTask(original, changes);
      _replace(original.id, saved);
      latestRevision = _max(latestRevision, saved.revision);
      lastError = null;
    } catch (error) {
      _replace(original.id, original);
      lastError = error.toString();
      rethrow;
    }
  }

  void _replace(String id, CueTask replacement) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;
    _tasks[index] = replacement;
    notifyListeners();
  }

  static int _taskSort(CueTask a, CueTask b) {
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    final priority = a.priority.compareTo(b.priority);
    if (priority != 0) return priority;
    if (a.dueAt == null && b.dueAt != null) return 1;
    if (a.dueAt != null && b.dueAt == null) return -1;
    if (a.dueAt != null && b.dueAt != null) {
      final due = a.dueAt!.compareTo(b.dueAt!);
      if (due != 0) return due;
    }
    return a.sortOrder.compareTo(b.sortOrder);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime day) {
    return DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
  }

  static int _max(int a, int b) => a > b ? a : b;
}
