import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/cue_task.dart';
import 'api_client.dart';

class TaskStore extends ChangeNotifier {
  TaskStore(this._tasks, {DateTime? today, this.api})
    : _fixedToday = today == null ? null : dateOnly(today);

  factory TaskStore.remote(ApiClient api) => TaskStore([], api: api);

  factory TaskStore.demo() {
    final created = DateTime(2026, 9, 1, 9);

    CueTask task(
      String id,
      String title, {
      String note = '',
      int priority = 2,
      bool important = false,
      DateTime? dueAt,
      DateTime? completedAt,
      double order = 1000,
      String? group,
    }) {
      return CueTask(
        id: id,
        title: title,
        note: note,
        priority: priority,
        important: important,
        sortOrder: order,
        dueAt: dueAt,
        completedAt: completedAt,
        createdAt: created,
        updatedAt: completedAt ?? created,
        group: group,
      );
    }

    return TaskStore([
      // 社会事项
      task('org-rack', '整理机架', priority: 3, group: '社会事项', order: 100),
      task('clean-room', '收拾房间 + 搞卫生', priority: 3, group: '社会事项', order: 200),
      task('okinawa-trip', '冲绳攻略', priority: 3, group: '社会事项', order: 300),
      task(
        'sim-assembly',
        '组装模拟器',
        priority: 3,
        group: '社会事项',
        completedAt: DateTime(2026, 9, 12),
        order: 400,
      ),
      task(
        'fix-bed',
        '修床',
        priority: 3,
        group: '社会事项',
        completedAt: DateTime(2026, 9, 10),
        order: 500,
      ),
      task(
        'exercise-1',
        '运动',
        priority: 3,
        group: '社会事项',
        dueAt: DateTime(2026, 1, 5),
        completedAt: DateTime(2026, 1, 5),
        order: 600,
      ),
      task(
        'duolingo-1',
        '多邻国',
        priority: 3,
        group: '社会事项',
        dueAt: DateTime(2026, 1, 5),
        completedAt: DateTime(2026, 1, 5),
        order: 700,
      ),

      // 研发事项
      task('desk-lamp', '桌面灯设计', priority: 3, group: '研发事项', order: 1000),
      task(
        'phone-rc-ui',
        '手机遥控 UI 设计',
        priority: 3,
        group: '研发事项',
        completedAt: DateTime(2026, 9, 11),
        order: 1100,
      ),
      task(
        'xji-overflow',
        'xji_footage_toolbox 窗口放大缩小后左侧边栏溢出问题解决',
        priority: 3,
        group: '研发事项',
        completedAt: DateTime(2026, 9, 9),
        order: 1200,
      ),
      task(
        'xji-scroll',
        'xji_footage_toolbox list 滚动逻辑',
        priority: 3,
        group: '研发事项',
        completedAt: DateTime(2026, 9, 8),
        order: 1300,
      ),
      task(
        'feishu-docs',
        '优化飞书 docs (预计转 electron)',
        priority: 3,
        group: '研发事项',
        completedAt: DateTime(2026, 9, 7),
        order: 1400,
      ),
      task(
        'pcb-review',
        'Review PCB layout',
        note: 'Check routing, clearances, and the power plane before handoff.',
        priority: 0,
        important: true,
        dueAt: DateTime(2026, 9, 13, 10, 30),
        order: 1500,
        group: '研发事项',
      ),
      task(
        'thermal-simulation',
        'Run thermal simulation',
        note: 'Compare the revised enclosure against the baseline model.',
        priority: 1,
        important: true,
        dueAt: DateTime(2026, 9, 13, 14),
        order: 1600,
        group: '研发事项',
      ),
      task(
        'signal-drift',
        'Analyze signal drift',
        priority: 2,
        important: true,
        dueAt: DateTime(2026, 9, 15),
        order: 1700,
        group: '研发事项',
      ),
      task(
        'requirements',
        'Finalize requirements',
        note: 'Approved for the September build.',
        priority: 2,
        important: true,
        completedAt: DateTime(2026, 9, 13, 9, 15),
        dueAt: DateTime(2026, 9, 13, 9),
        order: 1800,
        group: '研发事项',
      ),

      // 工作
      task('c2c-learning', 'C2C 学习', priority: 1, group: '工作', order: 2000),
      task(
        'parallel-compute',
        '并行计算技术了解',
        priority: 3,
        group: '工作',
        order: 2100,
      ),
      task('ddr5-odt', 'DDR5 odt 技术了解', priority: 3, group: '工作', order: 2200),
      task(
        'rdimm-datasheet',
        '研究一份 RDIMM 的 datasheet',
        priority: 3,
        group: '工作',
        order: 2300,
      ),
      task(
        'ddr5-training',
        'DDR5 training 流程',
        priority: 3,
        group: '工作',
        order: 2400,
      ),
      task(
        'sprint-report',
        'Draft sprint report',
        note: 'Summarize decisions, risks, and next actions.',
        priority: 2,
        dueAt: DateTime(2026, 9, 13, 17),
        order: 2500,
        group: '工作',
      ),
      task(
        'lab-calibration',
        'Book lab calibration',
        note: 'Coordinate the chamber slot with operations.',
        priority: 3,
        dueAt: DateTime(2026, 9, 16),
        order: 2600,
        group: '工作',
      ),

      // 未分组 / 其它
      task(
        'firmware-sync',
        'Sync firmware branch',
        priority: 3,
        completedAt: DateTime(2026, 9, 11),
        dueAt: DateTime(2026, 9, 8),
        order: 7000,
        group: '未分组',
      ),
      task(
        'design-handoff',
        'Prepare design handoff',
        priority: 2,
        important: true,
        dueAt: DateTime(2026, 9, 24),
        order: 8000,
        group: '研发事项',
      ),
      task(
        'october-roadmap',
        'Plan October roadmap',
        priority: 2,
        important: true,
        dueAt: DateTime(2026, 9, 30),
        order: 9000,
        group: '工作',
      ),
      task(
        'email-supplier',
        'Email component supplier',
        priority: 3,
        dueAt: DateTime(2026, 9, 14),
        order: 10000,
        group: '工作',
      ),
      task(
        'archive-notes',
        'Archive old notes',
        priority: 3,
        order: 11000,
        group: '未分组',
      ),
      task(
        'report-templates',
        'Browse report templates',
        priority: 3,
        order: 12000,
        group: '工作',
      ),
    ], today: demoToday);
  }

  static final DateTime demoToday = DateTime(2026, 9, 13);
  static const String defaultUngrouped = '未分组';

  final List<String> _customGroups = ['社会事项', '研发事项', '工作'];

  List<String> get groups {
    final set = <String>{};
    for (final g in _customGroups) {
      if (g.isNotEmpty) set.add(g);
    }
    for (final task in _tasks) {
      if (task.deletedAt == null &&
          task.group != null &&
          task.group!.trim().isNotEmpty &&
          task.group != defaultUngrouped) {
        set.add(task.group!.trim());
      }
    }
    set.add(defaultUngrouped);
    return set.toList();
  }

  void addGroup(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == defaultUngrouped) return;
    if (!_customGroups.contains(trimmed)) {
      final ungroupedIndex = _customGroups.indexOf(defaultUngrouped);
      if (ungroupedIndex == -1) {
        _customGroups.add(trimmed);
      } else {
        _customGroups.insert(ungroupedIndex, trimmed);
      }
      notifyListeners();
    }
  }

  void moveGroup(String group, String targetGroup) {
    final orderedGroups = groups;
    final oldIndex = orderedGroups.indexOf(group);
    final targetIndex = orderedGroups.indexOf(targetGroup);
    if (oldIndex == -1 || targetIndex == -1 || oldIndex == targetIndex) return;

    final movedGroup = orderedGroups.removeAt(oldIndex);
    orderedGroups.insert(targetIndex, movedGroup);
    _customGroups
      ..clear()
      ..addAll(orderedGroups);
    notifyListeners();
  }

  void renameGroup(String oldName, String newName) {
    final trimmed = newName.trim();
    if (oldName == defaultUngrouped ||
        trimmed.isEmpty ||
        trimmed == defaultUngrouped ||
        oldName == trimmed) {
      return;
    }
    final index = _customGroups.indexOf(oldName);
    if (index != -1) {
      _customGroups[index] = trimmed;
    } else {
      _customGroups.add(trimmed);
    }
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].group == oldName) {
        _tasks[i] = _tasks[i].copyWith(group: trimmed);
      }
    }
    notifyListeners();
  }

  void deleteGroup(String name) {
    if (name == defaultUngrouped) return;
    _customGroups.remove(name);
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].group == name) {
        _tasks[i] = _tasks[i].copyWith(clearGroup: true);
      }
    }
    notifyListeners();
  }

  List<CueTask> activeTasksForGroup(String group) {
    final isUngrouped = group == defaultUngrouped || group.trim().isEmpty;
    final result = activeTasks.where((task) {
      if (isUngrouped) {
        return task.group == null ||
            task.group!.trim().isEmpty ||
            task.group == defaultUngrouped;
      }
      return task.group == group;
    }).toList();
    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }

  List<CueTask> completedTasksForGroup(String group) {
    final isUngrouped = group == defaultUngrouped || group.trim().isEmpty;
    final result = completedTasks.where((task) {
      if (isUngrouped) {
        return task.group == null ||
            task.group!.trim().isEmpty ||
            task.group == defaultUngrouped;
      }
      return task.group == group;
    }).toList();
    result.sort((a, b) {
      final dateA = a.completedAt ?? a.updatedAt;
      final dateB = b.completedAt ?? b.updatedAt;
      return dateB.compareTo(dateA);
    });
    return result;
  }

  final List<CueTask> _tasks;
  final ApiClient? api;
  final DateTime? _fixedToday;
  DateTime get today => _fixedToday ?? dateOnly(DateTime.now());
  int latestRevision = 0;
  String? lastError;
  DateTime? lastSyncedAt;
  bool isSyncing = false;
  Future<void>? _syncInFlight;
  final Set<String> _pendingIds = {};
  final Map<String, CueTask> _deferredChanges = {};

  bool get isRemote => api != null;
  UnmodifiableListView<CueTask> get tasks => UnmodifiableListView(_tasks);

  Iterable<CueTask> get activeTasks =>
      _tasks.where((task) => task.deletedAt == null && !task.isCompleted);

  Iterable<CueTask> get completedTasks =>
      _tasks.where((task) => task.deletedAt == null && task.isCompleted);

  static bool isTaskOnDay(CueTask task, DateTime day) {
    if (task.deletedAt != null || task.dueAt == null) return false;
    final due = dateOnly(task.dueAt!);
    final target = dateOnly(day);

    if (target.isBefore(due)) return false;
    if (isSameDay(due, target)) return true;

    final r = task.recurrence;
    if (r == null || r == 'none') return false;

    return switch (r) {
      'daily' => true,
      'weekly' => target.weekday == due.weekday,
      'monthly' => target.day == due.day,
      'yearly' => target.month == due.month && target.day == due.day,
      'workday' =>
        target.weekday >= DateTime.monday && target.weekday <= DateTime.friday,
      _ => false,
    };
  }

  List<CueTask> get todayTasks {
    final result = _tasks.where((task) {
      if (task.deletedAt != null) return false;
      final dueToday = isTaskOnDay(task, today);
      final completedToday =
          task.completedAt != null && isSameDay(task.completedAt!, today);
      return dueToday || completedToday;
    }).toList();
    result.sort(_taskSort);
    return result;
  }

  List<CueTask> get upcomingTasks {
    final result = activeTasks
        .where(
          (task) =>
              task.dueAt != null &&
              (task.dueAt!.isAfter(endOfDay(today)) ||
                  (task.recurrence != null && task.recurrence != 'none')),
        )
        .toList();
    result.sort(_taskSort);
    return result;
  }

  List<CueTask> tasksForDay(DateTime day) {
    final result = _tasks.where((task) => isTaskOnDay(task, day)).toList();
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
    if (task.recurrence != null && task.recurrence != 'none') {
      for (var i = 0; i <= 2; i++) {
        if (isTaskOnDay(task, today.add(Duration(days: i)))) return true;
      }
    }
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
      lastSyncedAt = DateTime.now();
      notifyListeners();
    } catch (error) {
      lastError = error.toString();
      rethrow;
    }
  }

  Future<void> sync() {
    final active = _syncInFlight;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _performSync().whenComplete(() {
      if (identical(_syncInFlight, operation)) _syncInFlight = null;
    });
    _syncInFlight = operation;
    return operation;
  }

  Future<void> _performSync() async {
    final client = api;
    if (client == null) return;
    isSyncing = true;
    notifyListeners();
    try {
      final result = await client.sync(latestRevision);
      for (final change in result.changes) {
        if (_pendingIds.contains(change.id)) {
          final previous = _deferredChanges[change.id];
          if (previous == null || change.revision > previous.revision) {
            _deferredChanges[change.id] = change;
          }
          continue;
        }
        final index = _tasks.indexWhere((task) => task.id == change.id);
        if (index != -1 && _tasks[index].revision >= change.revision) {
          continue;
        }
        if (change.deletedAt != null) {
          if (index != -1) _tasks.removeAt(index);
        } else if (index == -1) {
          _tasks.add(change);
        } else {
          _tasks[index] = change;
        }
      }
      latestRevision = _max(latestRevision, result.latestRevision);
      lastError = null;
      lastSyncedAt = DateTime.now();
    } catch (error) {
      lastError = error.toString();
      rethrow;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> addTask({
    required String title,
    String note = '',
    int priority = 2,
    bool important = false,
    DateTime? dueAt,
    String? group,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    final normalizedGroup =
        (group == null ||
            group.trim().isEmpty ||
            group.trim() == defaultUngrouped)
        ? null
        : group.trim();
    final task = CueTask(
      id: 'task-local-${now.microsecondsSinceEpoch}',
      title: trimmed,
      note: note.trim(),
      priority: priority,
      important: important,
      sortOrder: _tasks.length * 1000 + 1000,
      dueAt: dueAt,
      createdAt: now,
      updatedAt: now,
      group: normalizedGroup,
    );
    _tasks.add(task);
    notifyListeners();

    final client = api;
    if (client == null) return;
    try {
      final saved = await client.createTask(task);
      final index = _tasks.indexWhere((item) => item.id == task.id);
      final existing = _tasks.indexWhere((item) => item.id == saved.id);
      if (existing != -1) {
        if (saved.revision > _tasks[existing].revision) {
          _tasks[existing] = saved;
        }
        if (index != -1) _tasks.removeAt(index);
      } else if (index != -1) {
        _tasks[index] = saved;
      }
      latestRevision = _max(latestRevision, saved.revision);
      lastError = null;
      lastSyncedAt = DateTime.now();
      notifyListeners();
    } catch (error) {
      _tasks.removeWhere((item) => item.id == task.id);
      lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleComplete(CueTask task) {
    final completedAt = task.isCompleted ? null : DateTime.now();
    return _update(
      task,
      task.copyWith(
        completedAt: completedAt,
        clearCompletedAt: completedAt == null,
      ),
      {'completedAt': completedAt?.toUtc().toIso8601String()},
    );
  }

  Future<void> updateGroup(CueTask task, String? group) {
    final normalized =
        (group == null ||
            group.trim().isEmpty ||
            group.trim() == defaultUngrouped)
        ? null
        : group.trim();
    if (task.group == normalized) return Future.value();
    return _update(
      task,
      task.copyWith(group: normalized, clearGroup: normalized == null),
      {'group': normalized},
    );
  }

  Future<void> toggleImportant(CueTask task) => _update(
    task,
    task.copyWith(important: !task.important),
    {'important': !task.important},
  );

  Future<void> updateNote(CueTask task, String note) =>
      _update(task, task.copyWith(note: note.trim()), {'note': note.trim()});

  Future<void> updateTitle(CueTask task, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed == task.title) return Future.value();
    return _update(task, task.copyWith(title: trimmed), {'title': trimmed});
  }

  Future<void> updatePriority(CueTask task, int priority) {
    if (priority == task.priority) return Future.value();
    return _update(task, task.copyWith(priority: priority), {
      'priority': priority,
    });
  }

  Future<void> updateDueAt(
    CueTask task,
    DateTime? dueAt, {
    String? reminder,
    bool clearReminder = false,
    String? recurrence,
    bool clearRecurrence = false,
  }) {
    if (dueAt?.millisecondsSinceEpoch == task.dueAt?.millisecondsSinceEpoch &&
        (dueAt == null) == (task.dueAt == null) &&
        reminder == task.reminder &&
        recurrence == task.recurrence) {
      return Future.value();
    }
    return _update(
      task,
      task.copyWith(
        dueAt: dueAt,
        clearDueAt: dueAt == null,
        reminder: reminder,
        clearReminder: clearReminder || reminder == null,
        recurrence: recurrence,
        clearRecurrence: clearRecurrence || recurrence == null,
      ),
      {
        'dueAt': dueAt?.toUtc().toIso8601String(),
        'reminder': reminder,
        'recurrence': recurrence,
      },
    );
  }

  Future<void> deleteTask(CueTask task) async {
    if (_pendingIds.contains(task.id)) {
      throw const ApiException('Task is still saving');
    }
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) return;
    _pendingIds.add(task.id);
    _tasks.removeAt(index);
    notifyListeners();
    final client = api;
    if (client == null) {
      _pendingIds.remove(task.id);
      return;
    }
    var deletedRemotely = false;
    try {
      final deleted = await client.deleteTask(task);
      deletedRemotely = true;
      latestRevision = _max(latestRevision, deleted.revision);
      lastError = null;
      lastSyncedAt = DateTime.now();
      notifyListeners();
    } catch (error) {
      _tasks.insert(index.clamp(0, _tasks.length), task);
      lastError = error.toString();
      notifyListeners();
      if (error is ApiException &&
          (error.statusCode == 404 || error.statusCode == 409)) {
        await _refreshAfterConflict();
      }
      rethrow;
    } finally {
      _pendingIds.remove(task.id);
      if (deletedRemotely) {
        _deferredChanges.remove(task.id);
      } else {
        _applyDeferred(task.id);
      }
    }
  }

  Future<void> _update(
    CueTask original,
    CueTask desired,
    Map<String, dynamic> changes,
  ) async {
    if (_pendingIds.contains(original.id)) {
      throw const ApiException('Task is still saving');
    }
    _pendingIds.add(original.id);
    final optimistic = desired.copyWith(
      updatedAt: DateTime.now(),
      version: original.version + 1,
    );
    _replace(original.id, optimistic);
    final client = api;
    if (client == null) {
      _pendingIds.remove(original.id);
      return;
    }
    try {
      final saved = await client.updateTask(original, changes);
      _replace(original.id, saved);
      latestRevision = _max(latestRevision, saved.revision);
      lastError = null;
      lastSyncedAt = DateTime.now();
    } catch (error) {
      _replace(original.id, original);
      lastError = error.toString();
      notifyListeners();
      if (error is ApiException && error.statusCode == 409) {
        await _refreshAfterConflict();
      }
      rethrow;
    } finally {
      _pendingIds.remove(original.id);
      _applyDeferred(original.id);
    }
  }

  void _applyDeferred(String id) {
    final change = _deferredChanges.remove(id);
    if (change == null) return;
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index != -1 && _tasks[index].revision >= change.revision) return;
    if (change.deletedAt != null) {
      if (index != -1) _tasks.removeAt(index);
    } else if (index == -1) {
      _tasks.add(change);
    } else {
      _tasks[index] = change;
    }
    notifyListeners();
  }

  Future<void> _refreshAfterConflict() async {
    try {
      await sync();
    } catch (_) {
      // Preserve the original mutation error; the next lifecycle or timer sync
      // will retry without hiding the conflict that caused this refresh.
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
