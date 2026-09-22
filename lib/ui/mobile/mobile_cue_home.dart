import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task_store.dart';
import '../../state/app_state.dart';
import '../../state/page_state.dart';
import '../../l10n/l10n.dart';
import '../../models/cue_task.dart';
import '../cue_date_picker.dart';
import '../cue_theme.dart';
import '../appearance_menu.dart';
import '../language_menu.dart';

abstract final class _MobileColors {
  static Color get canvas => CueColors.canvas;
  static Color get card => CueColors.card;
  static Color get subtle => CueColors.subtle;
  static Color get selected => CueColors.selected;
  static Color get accent => CueColors.accent;
  static Color get primary => CueColors.primary;
  static Color get secondary => CueColors.secondary;
  static const tertiary = CueColors.tertiary;
  static Color get border => CueColors.border;
  static Color get danger => CueColors.danger;
  static Color get dangerBackground => CueColors.dangerBackground;
  static const orange = CueColors.orange;
  static Color get orangeBackground => CueColors.orangeBackground;
  static const onAccent = CueColors.onAccent;
}

class MobileCueHome extends ConsumerStatefulWidget {
  const MobileCueHome({
    super.key,
    this.userEmail,
    this.onLogout,
    this.serverUrl,
    this.onConfigureServer,
  });

  final String? userEmail;
  final Future<void> Function()? onLogout;
  final String? serverUrl;
  final VoidCallback? onConfigureServer;

  @override
  ConsumerState<MobileCueHome> createState() => _MobileCueHomeState();
}

class _MobileCueHomeState extends ConsumerState<MobileCueHome> {
  TaskStore get _store => ref.read(taskStoreProvider)!;
  MobileDestination get _destination => ref.read(mobileUiProvider).destination;
  bool get _showLater => ref.read(mobileUiProvider).showLater;

  @override
  Widget build(BuildContext context) {
    ref.watch(taskRevisionProvider);
    ref.watch(mobileUiProvider);
    return Scaffold(
      backgroundColor: _MobileColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(child: _buildPage()),
          if (_destination != MobileDestination.settings)
            Positioned(
              right: 20,
              bottom: 16,
              child: _QuickAddButton(onTap: _showAddTaskSheet),
            ),
        ],
      ),
      bottomNavigationBar: _MobileBottomNavigation(
        destination: _destination,
        onSelect: (destination) {
          ref.read(mobileUiProvider.notifier).selectDestination(destination);
        },
      ),
    );
  }

  CueTask? _liveTask(CueTask? task) {
    if (task == null) return null;
    for (final item in _store.tasks) {
      if (item.id == task.id && item.deletedAt == null) return item;
    }
    return null;
  }

  Widget _buildPage() {
    return switch (_destination) {
      MobileDestination.today => _MobileTodayPage(
        showLater: _showLater,
        onFilterChanged: (value) =>
            ref.read(mobileUiProvider.notifier).showLater(value),
        onOpenTask: _openTask,
        onToggleTask: (task) =>
            _runOperation(() => _store.toggleComplete(task)),
        onOpenBoard: _openBoard,
        onSync: _syncNow,
      ),
      MobileDestination.board => _MobileBoardPage(
        onOpenTask: _openTask,
        onToggleTask: (task) =>
            _runOperation(() => _store.toggleComplete(task)),
        onBackToToday: _openToday,
        onSync: _syncNow,
      ),
      MobileDestination.calendar => _MobileCalendarPage(
        onOpenTask: _openTask,
        onSelectEmptyDay: (day) => _showAddTaskSheet(prefilledDate: day),
        onOpenBoard: _openBoard,
        onSync: _syncNow,
      ),
      MobileDestination.quadrants => _MobileQuadrantsPage(
        onOpenTask: _openTask,
        onOpenBoard: _openBoard,
        onSync: _syncNow,
      ),
      MobileDestination.settings => _MobileSettingsPage(
        email: widget.userEmail,
        onSync: _syncNow,
        onLogout: widget.onLogout,
        serverUrl: widget.serverUrl,
        onConfigureServer: widget.onConfigureServer,
      ),
    };
  }

  Future<void> _openTask(CueTask initialTask) async {
    var task = initialTask;
    await showDialog<void>(
      context: context,
      barrierColor: _MobileColors.canvas.withValues(alpha: 0.68),
      barrierLabel: context.l10n.closeTaskDetails,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            ref.watch(taskRevisionProvider);
            final liveTask = _liveTask(task);
            if (liveTask != null) task = liveTask;

            Future<bool> runAndRefresh(
              Future<void> Function() operation,
            ) async {
              final succeeded = await _runOperation(operation);
              if (!succeeded || !dialogContext.mounted) return succeeded;
              final updatedTask = _liveTask(task);
              if (updatedTask == null) {
                Navigator.pop(dialogContext);
              } else {
                task = updatedTask;
              }
              return succeeded;
            }

            return _TaskDetailsDialog(
              task: task,
              onClose: () => Navigator.pop(dialogContext),
              onRun: runAndRefresh,
            );
          },
        );
      },
    );
  }

  void _openBoard() {
    ref
        .read(mobileUiProvider.notifier)
        .selectDestination(MobileDestination.board);
  }

  void _openToday() {
    ref
        .read(mobileUiProvider.notifier)
        .selectDestination(MobileDestination.today);
  }

  Future<void> _syncNow() => _runOperation(_store.sync);

  Future<bool> _runOperation(Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Future<void> _showAddTaskSheet({DateTime? prefilledDate}) async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    final today = _store.today;
    var priority = 2;
    String? reminder;
    String? recurrence;
    DateTime? dueAt = prefilledDate == null
        ? DateTime(today.year, today.month, today.day, 18)
        : DateTime(
            prefilledDate.year,
            prefilledDate.month,
            prefilledDate.day,
            18,
          );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                padding: CueInsets.mobileForm,
                decoration: BoxDecoration(
                  color: _MobileColors.card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SheetHandle(),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.newTask,
                        style: TextStyle(
                          color: _MobileColors.primary,
                          fontSize: 20,
                          height: 25 / 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MobileTextField(
                        controller: titleController,
                        label: context.l10n.taskTitle,
                        autofocus: true,
                      ),
                      const SizedBox(height: 10),
                      _MobileTextField(
                        controller: noteController,
                        label: context.l10n.notes,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.priorityUpper,
                        style: _mobileEyebrowStyle,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(4, (index) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == 3 ? 0 : CueSpacing.s8,
                              ),
                              child: _MobilePill(
                                label: 'P$index',
                                selected: priority == index,
                                onTap: () =>
                                    setSheetState(() => priority = index),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DateChoice(
                              label: context.l10n.today,
                              selected:
                                  dueAt != null &&
                                  TaskStore.isSameDay(dueAt!, today),
                              onTap: () => setSheetState(
                                () => dueAt = DateTime(
                                  today.year,
                                  today.month,
                                  today.day,
                                  18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DateChoice(
                              label: context.l10n.tomorrow,
                              selected:
                                  dueAt != null &&
                                  TaskStore.isSameDay(
                                    dueAt!,
                                    today.add(const Duration(days: 1)),
                                  ),
                              onTap: () {
                                final tomorrow = today.add(
                                  const Duration(days: 1),
                                );
                                setSheetState(
                                  () => dueAt = DateTime(
                                    tomorrow.year,
                                    tomorrow.month,
                                    tomorrow.day,
                                    18,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        key: const Key('mobile-new-task-duedate-picker'),
                        onTap: () async {
                          final result = await showCueDatePickerPopover(
                            context: context,
                            today: today,
                            initialDueAt: dueAt,
                            initialReminder: reminder,
                            initialRecurrence: recurrence,
                          );
                          if (result == null || !context.mounted) return;
                          setSheetState(() {
                            if (result.cleared) {
                              dueAt = null;
                              reminder = null;
                              recurrence = null;
                            } else {
                              dueAt = result.dueAt;
                              reminder = result.reminder;
                              recurrence = result.recurrence;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CueSpacing.s14,
                            vertical: CueSpacing.s12,
                          ),
                          decoration: BoxDecoration(
                            color: _MobileColors.subtle,
                            border: Border.all(color: _MobileColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: _MobileColors.accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.dueDate,
                                      style: TextStyle(
                                        color: _MobileColors.secondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      cueDueDateTimeLabel(
                                        context,
                                        dueAt,
                                        today: today,
                                      ),
                                      style: TextStyle(
                                        color: _MobileColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: _MobileColors.secondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _MobileColors.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (titleController.text.trim().isEmpty) return;
                            final succeeded = await _runOperation(
                              () => _store.addTask(
                                title: titleController.text,
                                note: noteController.text,
                                priority: priority,
                                dueAt: dueAt,
                                reminder: reminder,
                                recurrence: recurrence,
                              ),
                            );
                            if (succeeded && sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                          child: Text(context.l10n.addTask),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    titleController.dispose();
    noteController.dispose();
  }
}

class _MobileTodayPage extends ConsumerWidget {
  const _MobileTodayPage({
    required this.showLater,
    required this.onFilterChanged,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onOpenBoard,
    required this.onSync,
  });

  final bool showLater;
  final ValueChanged<bool> onFilterChanged;
  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<CueTask> onToggleTask;
  final VoidCallback onOpenBoard;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    final tasks = showLater ? store.upcomingTasks : store.todayTasks;
    final morning = tasks
        .where((task) => task.dueAt != null && task.dueAt!.hour < 12)
        .toList();
    final later = showLater
        ? tasks
        : tasks.where((task) => !morning.contains(task)).toList();
    return RefreshIndicator(
      color: _MobileColors.accent,
      backgroundColor: _MobileColors.card,
      onRefresh: onSync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CueInsets.mobilePage,
        children: [
          _MobileHeader(
            title: showLater ? context.l10n.later : context.l10n.today,
            subtitle: showLater
                ? context.l10n.planWhatComesNext
                : formatLongDate(context, store.today),
            onOpenBoard: onOpenBoard,
            onSync: onSync,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MobilePill(
                label: context.l10n.today,
                selected: !showLater,
                onTap: () => onFilterChanged(false),
              ),
              const SizedBox(width: 8),
              _MobilePill(
                label: context.l10n.later,
                selected: showLater,
                onTap: () => onFilterChanged(true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (showLater)
            _TaskGroup(
              label: context.l10n.upcomingUpper,
              tasks: tasks,
              store: store,
              onOpenTask: onOpenTask,
              onToggleTask: onToggleTask,
            )
          else ...[
            if (morning.isNotEmpty)
              _TaskGroup(
                label: context.l10n.morning,
                tasks: morning,
                store: store,
                onOpenTask: onOpenTask,
                onToggleTask: onToggleTask,
              ),
            if (morning.isNotEmpty && later.isNotEmpty)
              const SizedBox(height: 8),
            if (later.isNotEmpty)
              _TaskGroup(
                label: context.l10n.laterUpper,
                tasks: later,
                store: store,
                onOpenTask: onOpenTask,
                onToggleTask: onToggleTask,
              ),
          ],
          if (tasks.isEmpty) _MobileEmptyState(label: context.l10n.allClear),
        ],
      ),
    );
  }
}

class _TaskGroup extends StatelessWidget {
  const _TaskGroup({
    required this.label,
    required this.tasks,
    required this.store,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final String label;
  final List<CueTask> tasks;
  final TaskStore store;
  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<CueTask> onToggleTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label · ${tasks.length}', style: _mobileEyebrowStyle),
        const SizedBox(height: 8),
        for (var index = 0; index < tasks.length; index++) ...[
          _MobileTaskRow(
            task: tasks[index],
            today: store.today,
            onOpen: () => onOpenTask(tasks[index]),
            onToggle: () => onToggleTask(tasks[index]),
          ),
          if (index != tasks.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MobileBoardPage extends ConsumerWidget {
  const _MobileBoardPage({
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onBackToToday,
    required this.onSync,
  });

  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<CueTask> onToggleTask;
  final VoidCallback onBackToToday;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    return RefreshIndicator(
      color: _MobileColors.accent,
      backgroundColor: _MobileColors.card,
      onRefresh: onSync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CueInsets.mobilePage,
        children: [
          _MobileHeader(
            title: context.l10n.board,
            subtitle: context.l10n.openTaskCount(store.activeTasks.length),
            boardIsOpen: true,
            onOpenBoard: onBackToToday,
            onSync: onSync,
          ),
          const SizedBox(height: 20),
          for (final group in store.groups) ...[
            Builder(
              builder: (context) {
                final tasks = [
                  ...store.activeTasksForGroup(group),
                  ...store.completedTasksForGroup(group),
                ];
                if (tasks.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: CueSpacing.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$group · ${tasks.length}',
                        style: _mobileEyebrowStyle,
                      ),
                      const SizedBox(height: 8),
                      for (var index = 0; index < tasks.length; index++) ...[
                        _MobileTaskRow(
                          task: tasks[index],
                          today: store.today,
                          onOpen: () => onOpenTask(tasks[index]),
                          onToggle: () => onToggleTask(tasks[index]),
                        ),
                        if (index != tasks.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileCalendarPage extends ConsumerWidget {
  const _MobileCalendarPage({
    required this.onOpenTask,
    required this.onSelectEmptyDay,
    required this.onOpenBoard,
    required this.onSync,
  });

  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<DateTime> onSelectEmptyDay;
  final VoidCallback onOpenBoard;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    final month = DateTime(store.today.year, store.today.month);
    final first = month.subtract(Duration(days: month.weekday - 1));
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weekCount = ((month.weekday - 1 + daysInMonth) / 7).ceil();
    final days = List.generate(
      weekCount * 7,
      (index) => first.add(Duration(days: index)),
    );
    final nextTasks =
        store.activeTasks.where((task) => task.dueAt != null).toList()
          ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    return RefreshIndicator(
      color: _MobileColors.accent,
      backgroundColor: _MobileColors.card,
      onRefresh: onSync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CueInsets.mobilePage,
        children: [
          _MobileHeader(
            title: formatMonthName(context, month),
            subtitle: context.l10n.monthOverview(month.year),
            onOpenBoard: onOpenBoard,
            onSync: onSync,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: SizedBox(
                    height: 20,
                    child: Text(
                      formatNarrowWeekday(
                        context,
                        DateTime(2024, 1, index + 1),
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _MobileColors.tertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 8,
              childAspectRatio: 44 / 68,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final tasks = store.tasksForDay(day);
              return _CalendarDay(
                day: day,
                inMonth: day.month == month.month,
                selected: TaskStore.isSameDay(day, store.today),
                hasTasks: tasks.isNotEmpty,
                onTap: () => tasks.isEmpty
                    ? onSelectEmptyDay(day)
                    : onOpenTask(tasks.first),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.nextUp,
            style: TextStyle(
              color: _MobileColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (nextTasks.isNotEmpty)
            _MobileTaskRow(
              task: nextTasks.first,
              today: store.today,
              onOpen: () => onOpenTask(nextTasks.first),
              onToggle: () {},
            )
          else
            _MobileEmptyState(label: context.l10n.nothingScheduled),
        ],
      ),
    );
  }
}

class _MobileQuadrantsPage extends ConsumerWidget {
  const _MobileQuadrantsPage({
    required this.onOpenTask,
    required this.onOpenBoard,
    required this.onSync,
  });

  final ValueChanged<CueTask> onOpenTask;
  final VoidCallback onOpenBoard;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    final panels = [
      (
        context.l10n.doNow,
        context.l10n.importantUrgent,
        _MobileColors.dangerBackground,
        store.tasksForPriority(0),
        0,
      ),
      (
        context.l10n.schedule,
        context.l10n.importantLater,
        _MobileColors.orangeBackground,
        store.tasksForPriority(1),
        1,
      ),
      (
        context.l10n.batch,
        context.l10n.urgentLowerValue,
        CueColors.prioritySelected,
        store.tasksForPriority(2),
        2,
      ),
      (
        context.l10n.reconsider,
        context.l10n.neither,
        _MobileColors.subtle,
        store.tasksForPriority(3),
        3,
      ),
    ];
    return RefreshIndicator(
      color: _MobileColors.accent,
      backgroundColor: _MobileColors.card,
      onRefresh: onSync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CueInsets.mobilePage,
        children: [
          _MobileHeader(
            title: context.l10n.quadrants,
            subtitle: context.l10n.importanceUrgency,
            onOpenBoard: onOpenBoard,
            onSync: onSync,
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: panels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: 170 / 270,
            ),
            itemBuilder: (context, index) {
              final panel = panels[index];
              return _MobileQuadrant(
                title: panel.$1,
                rule: panel.$2,
                color: panel.$3,
                tasks: panel.$4,
                priority: panel.$5,
                onOpenTask: onOpenTask,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MobileSettingsPage extends ConsumerWidget {
  const _MobileSettingsPage({
    required this.email,
    required this.onSync,
    required this.onLogout,
    required this.serverUrl,
    required this.onConfigureServer,
  });

  final String? email;
  final Future<void> Function() onSync;
  final Future<void> Function()? onLogout;
  final String? serverUrl;
  final VoidCallback? onConfigureServer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    final syncDetail = !store.isRemote
        ? context.l10n.localDemo
        : store.isSyncing
        ? context.l10n.syncing
        : store.lastError != null
        ? context.l10n.needsAttention
        : context.l10n.connected;
    final locale = app.locale;
    final languageDetail = locale == null
        ? context.l10n.systemDefault
        : locale.languageCode == 'zh'
        ? context.l10n.chinese
        : context.l10n.english;
    return ListView(
      padding: CueInsets.mobileSettingsPage,
      children: [
        Text(
          context.l10n.settings,
          style: TextStyle(
            color: _MobileColors.primary,
            fontSize: 20,
            height: 25 / 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.personalizeCue,
          style: TextStyle(
            color: _MobileColors.secondary,
            fontSize: 13,
            height: 18 / 13,
          ),
        ),
        const SizedBox(height: 16),
        _ProfileSummary(
          email: email,
          onTap: onLogout == null
              ? null
              : () => _showAccountSheet(context, email, onLogout!),
        ),
        const SizedBox(height: 16),
        Text(context.l10n.preferences, style: _mobileSectionStyle),
        const SizedBox(height: 16),
        _SettingsRow(
          icon: Icons.language_rounded,
          label: context.l10n.language,
          detail: languageDetail,
          onTap: () => showLanguagePicker(context, mobile: true),
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: Icons.contrast,
          label: context.l10n.appearance,
          detail: switch (app.themeMode) {
            ThemeMode.system => context.l10n.systemDefault,
            ThemeMode.dark => context.l10n.dark,
            ThemeMode.light => context.l10n.light,
          },
          onTap: () => showAppearancePicker(context, mobile: true),
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: Icons.schedule_outlined,
          label: context.l10n.dateAndTime,
          detail: context.l10n.system,
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: Icons.notifications_none_rounded,
          label: context.l10n.reminders,
          detail: context.l10n.minutesBefore,
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: Icons.grid_view_rounded,
          label: context.l10n.widgets,
          detail: context.l10n.activeWidgetCount,
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: Icons.auto_awesome_outlined,
          label: context.l10n.aiFeatures,
          detail: context.l10n.on,
        ),
        const SizedBox(height: 16),
        Text(context.l10n.accountAndData, style: _mobileSectionStyle),
        const SizedBox(height: 16),
        _SettingsRow(
          icon: Icons.sync_rounded,
          label: context.l10n.importAndSync,
          detail: syncDetail,
          trailing: store.isSyncing
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _MobileColors.accent,
                  ),
                )
              : null,
          onTap: store.isRemote ? () => _showSyncSheet(context) : null,
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          icon: Icons.help_outline_rounded,
          label: context.l10n.helpAndGuide,
        ),
      ],
    );
  }

  Future<void> _showSyncSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _MobileColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          ref.watch(taskRevisionProvider);
          final store = ref.watch(taskStoreProvider)!;
          return Padding(
            padding: CueInsets.mobileSheet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 20),
                Text(
                  context.l10n.multiDeviceSync,
                  style: TextStyle(
                    color: _MobileColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  store.lastError ?? context.l10n.syncDescription,
                  style: TextStyle(
                    color: store.lastError == null
                        ? _MobileColors.secondary
                        : _MobileColors.danger,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
                const SizedBox(height: 16),
                _SyncFact(
                  label: context.l10n.status,
                  value: store.isSyncing
                      ? context.l10n.syncing
                      : context.l10n.connected,
                ),
                const SizedBox(height: 8),
                _SyncFact(
                  label: context.l10n.revision,
                  value: '${store.latestRevision}',
                ),
                const SizedBox(height: 8),
                _SyncFact(
                  label: context.l10n.lastSynced,
                  value: _syncTime(context, store.lastSyncedAt),
                ),
                if (serverUrl != null) ...[
                  const SizedBox(height: 8),
                  _SyncFact(
                    label: context.l10n.server,
                    value: _serverLabel(serverUrl!),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _MobileColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: store.isSyncing ? null : onSync,
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: Text(context.l10n.syncNow),
                  ),
                ),
                if (onConfigureServer != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _MobileColors.secondary,
                        side: BorderSide(color: _MobileColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        onConfigureServer!();
                      },
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text(context.l10n.changeServer),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showAccountSheet(
    BuildContext context,
    String? email,
    Future<void> Function() onLogout,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _MobileColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: CueInsets.mobileSheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 20),
            Text(
              email ?? context.l10n.cueWorkspace,
              style: TextStyle(
                color: _MobileColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _MobileColors.danger,
                side: BorderSide(color: _MobileColors.border),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                Navigator.pop(sheetContext);
                await onLogout();
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(context.l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.title,
    required this.subtitle,
    required this.onOpenBoard,
    required this.onSync,
    this.boardIsOpen = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onOpenBoard;
  final Future<void> Function() onSync;
  final bool boardIsOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text(
              'CUE',
              style: TextStyle(
                color: _MobileColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.44,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 16,
            child: Text(
              title,
              style: TextStyle(
                color: _MobileColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 52,
            child: Text(
              subtitle,
              style: TextStyle(color: _MobileColors.secondary, fontSize: 12),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: PopupMenuButton<String>(
              color: _MobileColors.card,
              tooltip: context.l10n.more,
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'board') onOpenBoard();
                if (value == 'sync') onSync();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'board',
                  child: Text(
                    boardIsOpen
                        ? context.l10n.backToToday
                        : context.l10n.openBoard,
                    style: TextStyle(color: _MobileColors.primary),
                  ),
                ),
                PopupMenuItem(
                  value: 'sync',
                  child: Text(
                    context.l10n.syncNow,
                    style: TextStyle(color: _MobileColors.primary),
                  ),
                ),
              ],
              child: SizedBox(
                width: 28,
                height: 32,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    '•••',
                    style: TextStyle(
                      color: _MobileColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePill extends StatelessWidget {
  const _MobilePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 36,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: selected
              ? _MobileColors.onAccent
              : _MobileColors.primary,
          backgroundColor: selected
              ? _MobileColors.accent
              : _MobileColors.subtle,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, height: 18 / 13),
        ),
        child: Text(label),
      ),
    );
  }
}

class _MobileTaskRow extends StatelessWidget {
  const _MobileTaskRow({
    required this.task,
    required this.today,
    required this.onOpen,
    required this.onToggle,
  });

  final CueTask task;
  final DateTime today;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: CueSpacing.s16),
        decoration: BoxDecoration(
          color: _MobileColors.card,
          border: Border.all(color: _MobileColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(CueSpacing.s2),
                child: SvgPicture.asset(
                  task.isCompleted
                      ? 'assets/figma/checkbox-completed.svg'
                      : 'assets/figma/checkbox.svg',
                  width: 20,
                  height: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _MobileColors.primary,
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _mobileTaskMeta(context, task, today),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _MobileColors.secondary,
                      fontSize: 13,
                      height: 18 / 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _MobilePriorityBadge(priority: task.priority),
          ],
        ),
      ),
    );
  }
}

class _MobilePriorityBadge extends StatelessWidget {
  const _MobilePriorityBadge({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (priority) {
      0 => (_MobileColors.dangerBackground, _MobileColors.danger),
      1 => (_MobileColors.orangeBackground, _MobileColors.orange),
      2 => (_MobileColors.selected, _MobileColors.accent),
      _ => (_MobileColors.subtle, _MobileColors.secondary),
    };
    return Container(
      width: 40,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'P$priority',
        style: TextStyle(color: foreground, fontSize: 12, height: 16 / 12),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.hasTasks,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool hasTasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: inMonth ? _MobileColors.card : _MobileColors.subtle,
          border: selected
              ? Border.all(color: _MobileColors.accent, width: 2)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: inMonth ? _MobileColors.primary : _MobileColors.tertiary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 4,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: hasTasks ? _MobileColors.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileQuadrant extends StatelessWidget {
  const _MobileQuadrant({
    required this.title,
    required this.rule,
    required this.color,
    required this.tasks,
    required this.priority,
    required this.onOpenTask,
  });

  final String title;
  final String rule;
  final Color color;
  final List<CueTask> tasks;
  final int priority;
  final ValueChanged<CueTask> onOpenTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: CueInsets.card,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _MobileColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'P$priority',
                style: TextStyle(
                  color: _MobileColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            rule,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _MobileColors.secondary, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final task in tasks.take(3)) ...[
                  GestureDetector(
                    onTap: () => onOpenTask(task),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      padding: const EdgeInsets.symmetric(
                        horizontal: CueSpacing.s10,
                      ),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: _MobileColors.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _MobileColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBottomNavigation extends StatelessWidget {
  const _MobileBottomNavigation({
    required this.destination,
    required this.onSelect,
  });

  final MobileDestination destination;
  final ValueChanged<MobileDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        MobileDestination.today,
        Icons.check_circle_outline_rounded,
        context.l10n.today,
      ),
      (
        MobileDestination.calendar,
        Icons.calendar_month_outlined,
        context.l10n.calendar,
      ),
      (
        MobileDestination.quadrants,
        Icons.grid_view_rounded,
        context.l10n.quadrants,
      ),
      (MobileDestination.settings, Icons.tune_rounded, context.l10n.settings),
    ];
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(
        CueSpacing.s12,
        CueSpacing.s8,
        CueSpacing.s12,
        CueSpacing.s20,
      ),
      decoration: BoxDecoration(
        color: _MobileColors.card,
        border: Border(top: BorderSide(color: _MobileColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          final selected =
              destination == item.$1 ||
              (destination == MobileDestination.board &&
                  item.$1 == MobileDestination.today);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(item.$1),
            child: SizedBox(
              width: 82,
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.$2,
                    size: 20,
                    color: selected
                        ? _MobileColors.accent
                        : _MobileColors.secondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: TextStyle(
                      color: selected
                          ? _MobileColors.accent
                          : _MobileColors.secondary,
                      fontSize: 11,
                      height: 14 / 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('mobile-quick-add'),
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _MobileColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x1F1A1C26),
              blurRadius: 28,
              spreadRadius: -8,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SvgPicture.asset(
          'assets/figma/plus.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
            _MobileColors.onAccent,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

class _TaskDetailsDialog extends ConsumerStatefulWidget {
  const _TaskDetailsDialog({
    required this.task,
    required this.onClose,
    required this.onRun,
  });

  final CueTask task;
  final VoidCallback onClose;
  final Future<bool> Function(Future<void> Function()) onRun;

  @override
  ConsumerState<_TaskDetailsDialog> createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends ConsumerState<_TaskDetailsDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _noteFocusNode;
  bool _editingTitle = false;
  bool _editingNote = false;
  CueTask? _currentTask;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _noteController = TextEditingController(text: widget.task.note);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_onTitleFocusChange);
    _noteFocusNode = FocusNode();
    _noteFocusNode.addListener(_onNoteFocusChange);
  }

  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus && _editingTitle) {
      _saveTitle();
    }
  }

  void _onNoteFocusChange() {
    if (!_noteFocusNode.hasFocus && _editingNote) {
      _saveNote();
    }
  }

  Future<void> _saveTitle() async {
    if (!_editingTitle) return;
    final task = _currentTask;
    if (task == null) return;
    final store = ref.read(taskStoreProvider)!;
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != task.title) {
      await widget.onRun(() => store.updateTitle(task, newTitle));
    }
    if (mounted) {
      setState(() => _editingTitle = false);
    }
  }

  Future<void> _saveNote() async {
    if (!_editingNote) return;
    final task = _currentTask;
    if (task == null) return;
    final store = ref.read(taskStoreProvider)!;
    final newNote = _noteController.text.trim();
    if (newNote != task.note) {
      await widget.onRun(() => store.updateNote(task, newNote));
    }
    if (mounted) {
      setState(() => _editingNote = false);
    }
  }

  Future<void> _editDate(TaskStore store, CueTask task) async {
    if (task.completedAt != null) {
      final completedAt = await showCueCompletionDatePickerPopover(
        context: context,
        initialCompletedAt: task.completedAt!,
      );
      if (completedAt != null) {
        await widget.onRun(() => store.updateCompletedAt(task, completedAt));
      }
      return;
    }

    final result = await showCueDatePickerPopover(
      context: context,
      today: store.today,
      initialDueAt: task.dueAt,
      initialReminder: task.reminder,
      initialRecurrence: task.recurrence,
    );
    if (result == null) return;
    if (result.cleared) {
      await widget.onRun(
        () => store.updateDueAt(
          task,
          null,
          clearReminder: true,
          clearRecurrence: true,
        ),
      );
    } else {
      await widget.onRun(
        () => store.updateDueAt(
          task,
          result.dueAt,
          reminder: result.reminder,
          recurrence: result.recurrence,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _titleFocusNode.dispose();
    _noteFocusNode.removeListener(_onNoteFocusChange);
    _noteFocusNode.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    final matches = store.tasks.where((item) => item.id == widget.task.id);
    final task = matches.isEmpty ? widget.task : matches.first;
    _currentTask = task;
    return Dialog(
      key: const Key('task-details-dialog'),
      backgroundColor: _MobileColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: CueSpacing.s20,
        vertical: CueSpacing.s24,
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _MobileColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 350,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 60,
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => widget.onRun(() => store.toggleComplete(task)),
                    child: SvgPicture.asset(
                      task.isCompleted
                          ? 'assets/figma/checkbox-completed.svg'
                          : 'assets/figma/checkbox.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        key: Key(
                          task.isCompleted
                              ? 'mobile-task-completed-at-picker'
                              : 'mobile-task-duedate-picker',
                        ),
                        onTap: () => _editDate(store, task),
                        child: Text(
                          task.completedAt != null
                              ? context.l10n.completedAt(
                                  formatFullDateTime(
                                    context,
                                    task.completedAt!,
                                  ),
                                )
                              : _mobileCompactMeta(context, task, store.today),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: task.isCompleted || task.dueAt != null
                                ? CueColors.accent
                                : _MobileColors.secondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<int>(
                    key: const Key('mobile-task-priority-picker'),
                    tooltip: context.l10n.priority,
                    offset: const Offset(0, 28),
                    color: _MobileColors.card,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: _MobileColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (p) {
                      widget.onRun(() => store.updatePriority(task, p));
                    },
                    itemBuilder: (context) => [
                      for (var p = 0; p < 4; p++)
                        PopupMenuItem<int>(
                          value: p,
                          child: Row(
                            children: [
                              _MobilePriorityBadge(priority: p),
                              const SizedBox(width: 10),
                              Text(
                                'P$p',
                                style: TextStyle(
                                  color: p == task.priority
                                      ? CueColors.accent
                                      : _MobileColors.primary,
                                  fontWeight: p == task.priority
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    child: _MobilePriorityBadge(priority: task.priority),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    color: _MobileColors.secondary,
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: context.l10n.closeTaskDetails,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CueSpacing.s24,
                CueSpacing.s12,
                CueSpacing.s24,
                0,
              ),
              child: _editingTitle
                  ? TextField(
                      key: const Key('mobile-task-title-field'),
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      autofocus: true,
                      style: TextStyle(
                        color: _MobileColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: context.l10n.taskTitle,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: CueSpacing.s10,
                          vertical: CueSpacing.s8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: CueColors.accent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: CueColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onTapOutside: (_) => _saveTitle(),
                      onSubmitted: (_) => _saveTitle(),
                    )
                  : InkWell(
                      key: const Key('mobile-task-title-text'),
                      onTap: () {
                        _titleController.text = task.title;
                        setState(() => _editingTitle = true);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _MobileColors.primary,
                          fontSize: 20,
                          height: 25 / 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CueSpacing.s24,
                CueSpacing.s12,
                CueSpacing.s24,
                0,
              ),
              child: Text(
                '${_area(context, task)} · ${context.l10n.createdOn(_createdLabel(context, task, store.today))}',
                style: TextStyle(color: _MobileColors.secondary, fontSize: 13),
              ),
            ),
            if (_editingNote || task.note.isNotEmpty || !task.isCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CueSpacing.s24,
                  CueSpacing.s12,
                  CueSpacing.s24,
                  0,
                ),
                child: _editingNote
                    ? TextField(
                        key: const Key('mobile-task-note-field'),
                        controller: _noteController,
                        focusNode: _noteFocusNode,
                        autofocus: true,
                        maxLines: 4,
                        style: TextStyle(
                          color: _MobileColors.primary,
                          fontSize: 15,
                          height: 21 / 15,
                        ),
                        decoration: InputDecoration(
                          hintText: context.l10n.note,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: CueSpacing.s10,
                            vertical: CueSpacing.s8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: CueColors.accent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: CueColors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onTapOutside: (_) => _saveNote(),
                        onSubmitted: (_) => _saveNote(),
                      )
                    : InkWell(
                        key: const Key('mobile-task-note-text'),
                        onTap: () {
                          _noteController.text = task.note;
                          setState(() => _editingNote = true);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Text(
                          task.note.isEmpty ? context.l10n.note : task.note,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: task.note.isEmpty
                                ? _MobileColors.secondary
                                : _MobileColors.primary,
                            fontSize: 15,
                            height: 21 / 15,
                          ),
                        ),
                      ),
              ),
            const Spacer(),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: CueSpacing.s12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _MobileColors.border)),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  PopupMenuButton<String>(
                    color: _MobileColors.card,
                    iconColor: _MobileColors.secondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 36),
                    onSelected: (value) async {
                      if (value == 'complete') {
                        await widget.onRun(() => store.toggleComplete(task));
                      }
                      if (value == 'delete') {
                        await widget.onRun(() => store.deleteTask(task));
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'complete',
                        child: Text(
                          context.l10n.toggleComplete,
                          style: TextStyle(color: _MobileColors.primary),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          context.l10n.delete,
                          style: TextStyle(color: _MobileColors.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.email, required this.onTap});

  final String? email;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final monogram = (email?.trim().isNotEmpty ?? false)
        ? email!.trim().substring(0, 1).toUpperCase()
        : 'C';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(
          horizontal: CueSpacing.s16,
          vertical: CueSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: _MobileColors.card,
          border: Border.all(color: _MobileColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _MobileColors.selected,
                shape: BoxShape.circle,
              ),
              child: Text(
                monogram,
                style: TextStyle(
                  color: _MobileColors.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.cueWorkspace,
                    style: TextStyle(
                      color: _MobileColors.primary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email ?? context.l10n.focusStreak,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _MobileColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _MobileColors.secondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.detail,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.only(
          left: CueSpacing.s16,
          right: CueSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: _MobileColors.card,
          border: Border.all(color: _MobileColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _MobileColors.selected,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: _MobileColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _MobileColors.primary,
                      fontSize: 15,
                      height: 21 / 15,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: TextStyle(
                        color: _MobileColors.secondary,
                        fontSize: 13,
                        height: 18 / 13,
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: _MobileColors.secondary,
                  size: 16,
                ),
          ],
        ),
      ),
    );
  }
}

class _SyncFact extends StatelessWidget {
  const _SyncFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: _MobileColors.secondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: _MobileColors.primary, fontSize: 13),
        ),
      ],
    );
  }
}

class _MobileTextField extends StatelessWidget {
  const _MobileTextField({
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      style: TextStyle(color: _MobileColors.primary),
      cursorColor: _MobileColors.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _MobileColors.secondary),
        filled: true,
        fillColor: _MobileColors.subtle,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _MobileColors.border),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _MobileColors.accent),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? _MobileColors.primary
            : _MobileColors.secondary,
        backgroundColor: selected
            ? _MobileColors.selected
            : _MobileColors.subtle,
        side: BorderSide(
          color: selected ? _MobileColors.accent : _MobileColors.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: _MobileColors.tertiary,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _MobileEmptyState extends StatelessWidget {
  const _MobileEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CueSpacing.s40),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: _MobileColors.tertiary, fontSize: 13),
        ),
      ),
    );
  }
}

const _mobileEyebrowStyle = TextStyle(
  color: _MobileColors.tertiary,
  fontSize: 11,
  height: 16 / 11,
  fontWeight: FontWeight.w600,
);

TextStyle get _mobileSectionStyle => TextStyle(
  color: _MobileColors.secondary,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.1,
);

String _mobileTaskMeta(BuildContext context, CueTask task, DateTime today) {
  final l10n = context.l10n;
  if (task.isCompleted && task.completedAt != null) {
    return l10n.completedAt(_time(task.completedAt!));
  }
  if (task.dueAt == null) return l10n.noTime;
  final time = _hasTime(task.dueAt!) ? _time(task.dueAt!) : null;
  if (TaskStore.isSameDay(task.dueAt!, today)) {
    return '${time ?? l10n.today} · ${_area(context, task)}';
  }
  return '${formatShortMonthDay(context, task.dueAt!)} · ${_area(context, task)}';
}

String _mobileCompactMeta(BuildContext context, CueTask task, DateTime today) {
  final l10n = context.l10n;
  if (task.isCompleted && task.completedAt != null) {
    return l10n.completedAt(_time(task.completedAt!));
  }
  if (task.dueAt == null) return l10n.noDueDate;
  if (TaskStore.isSameDay(task.dueAt!, today)) {
    return '${l10n.today}${_hasTime(task.dueAt!) ? ', ${_time(task.dueAt!)}' : ''}';
  }
  return formatShortMonthDay(context, task.dueAt!);
}

String _createdLabel(BuildContext context, CueTask task, DateTime today) {
  if (TaskStore.isSameDay(task.createdAt, today)) {
    return context.l10n.createdToday;
  }
  return formatShortMonthDay(context, task.createdAt);
}

String _syncTime(BuildContext context, DateTime? date) {
  if (date == null) return context.l10n.notYet;
  return _time(date);
}

String _serverLabel(String serverUrl) {
  final uri = Uri.tryParse(serverUrl);
  if (uri == null || uri.host.isEmpty) return serverUrl;
  return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}

String _area(BuildContext context, CueTask task) {
  final l10n = context.l10n;
  final title = task.title.toLowerCase();
  if (title.contains('pcb')) return l10n.hardware;
  if (title.contains('thermal') || title.contains('signal')) {
    return l10n.simulation;
  }
  if (title.contains('report')) return l10n.writing;
  if (title.contains('lab')) return l10n.operations;
  return l10n.product;
}

bool _hasTime(DateTime date) => date.hour != 0 || date.minute != 0;

String _time(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
