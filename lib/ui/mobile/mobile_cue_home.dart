import 'package:flutter/foundation.dart';
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
import '../account_settings.dart';
import '../about_cue.dart';
import '../appearance_menu.dart';
import '../default_view_menu.dart';
import '../language_menu.dart';

class MobileCueHome extends ConsumerStatefulWidget {
  const MobileCueHome({
    super.key,
    this.createTaskRequests,
    this.userEmail,
    this.onLogout,
    this.onUpdateAccount,
    this.serverUrl,
    this.onConfigureServer,
  });

  final String? userEmail;
  final ValueListenable<int>? createTaskRequests;
  final Future<void> Function()? onLogout;
  final AccountUpdater? onUpdateAccount;
  final String? serverUrl;
  final VoidCallback? onConfigureServer;

  @override
  ConsumerState<MobileCueHome> createState() => _MobileCueHomeState();
}

class _MobileCueHomeState extends ConsumerState<MobileCueHome> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  TaskStore get _store => ref.read(taskStoreProvider)!;
  MobileDestination get _destination => ref.read(mobileUiProvider).destination;
  bool get _showLater => ref.read(mobileUiProvider).showLater;

  @override
  void initState() {
    super.initState();
    widget.createTaskRequests?.addListener(_onTrayCreateTask);
  }

  @override
  void didUpdateWidget(MobileCueHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.createTaskRequests != widget.createTaskRequests) {
      oldWidget.createTaskRequests?.removeListener(_onTrayCreateTask);
      widget.createTaskRequests?.addListener(_onTrayCreateTask);
    }
  }

  @override
  void dispose() {
    widget.createTaskRequests?.removeListener(_onTrayCreateTask);
    super.dispose();
  }

  void _onTrayCreateTask() {
    if (mounted) _showQuickAdd();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(taskRevisionProvider);
    ref.watch(mobileUiProvider);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CueColors.canvas,
      drawerScrimColor: CueMobileNavigationTokens.drawerScrim,
      drawerEnableOpenDragGesture:
          _destination == MobileDestination.today ||
          _destination == MobileDestination.board,
      drawer: _MobileNavigationDrawer(
        destination: _destination,
        onSelect: _selectPrimaryView,
      ),
      body: SafeArea(
        key: const Key('mobile-content-safe-area'),
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: _buildPage()),
            if (_destination != MobileDestination.settings)
              Positioned(
                right: 20,
                bottom: 16,
                child: _QuickAddButton(onTap: _showQuickAdd),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _MobileBottomNavigation(
        destination: _destination,
        onSelect: (destination) {
          navigateToMobileDestination(ref, destination);
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
        onOpenDrawer: _openDrawer,
        onSync: _syncNow,
      ),
      MobileDestination.board => _MobileBoardPage(
        onOpenTask: _openTask,
        onToggleTask: (task) =>
            _runOperation(() => _store.toggleComplete(task)),
        onOpenDrawer: _openDrawer,
        onSync: _syncNow,
      ),
      MobileDestination.calendar => _MobileCalendarPage(
        onOpenTask: _openTask,
        onToggleTask: (task) =>
            _runOperation(() => _store.toggleComplete(task)),
        onSync: _syncNow,
      ),
      MobileDestination.quadrants => _MobileQuadrantsPage(
        onOpenTask: _openTask,
        onSync: _syncNow,
      ),
      MobileDestination.settings => _MobileSettingsPage(
        email: widget.userEmail,
        onSync: _syncNow,
        onLogout: widget.onLogout,
        onUpdateAccount: widget.onUpdateAccount,
        serverUrl: widget.serverUrl,
        onConfigureServer: widget.onConfigureServer,
      ),
    };
  }

  Future<void> _openTask(CueTask initialTask) async {
    var task = initialTask;
    await showDialog<void>(
      context: context,
      barrierColor: CueColors.modalBarrier,
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

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _selectPrimaryView(MobileDestination destination) {
    Navigator.of(context).pop();
    navigateToMobileDestination(ref, destination);
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

  void _showQuickAdd() {
    String? prefilledGroup;
    if (_destination == MobileDestination.board) {
      final groups = _store.groups;
      final selection = ref.read(mobileBoardGroupProvider);
      final selectedGroup = groups.contains(selection)
          ? selection!
          : groups.first;
      if (selectedGroup != TaskStore.defaultUngrouped) {
        prefilledGroup = selectedGroup;
      }
    }
    _showAddTaskSheet(prefilledGroup: prefilledGroup);
  }

  Future<void> _showAddTaskSheet({
    DateTime? prefilledDate,
    String? prefilledGroup,
  }) async {
    var title = '';
    var note = '';
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
                  color: CueColors.card,
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
                          color: CueColors.primary,
                          fontSize: 20,
                          height: 25 / 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MobileTextField(
                        label: context.l10n.taskTitle,
                        autofocus: true,
                        onChanged: (value) =>
                            setSheetState(() => title = value),
                      ),
                      const SizedBox(height: 10),
                      _MobileTextField(
                        label: context.l10n.notes,
                        maxLines: 3,
                        onChanged: (value) => note = value,
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
                              child: _PriorityPill(
                                priority: index,
                                selected: priority == index,
                                onTap: () =>
                                    setSheetState(() => priority = index),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
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
                            color: CueColors.subtle,
                            border: Border.all(color: CueColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: CueColors.accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.dueDate,
                                      style: TextStyle(
                                        color: CueColors.secondary,
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
                                        color: CueColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: CueColors.secondary,
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
                            backgroundColor: CueColors.accent,
                            foregroundColor: CueColors.onAccent,
                            disabledBackgroundColor: CueColors.subtle,
                            disabledForegroundColor: CueColors.tertiary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: title.trim().isEmpty
                              ? null
                              : () async {
                                  final succeeded = await _runOperation(
                                    () => _store.addTask(
                                      title: title,
                                      note: note,
                                      priority: priority,
                                      dueAt: dueAt,
                                      reminder: reminder,
                                      recurrence: recurrence,
                                      group: prefilledGroup,
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
  }
}

class _MobileTodayPage extends ConsumerWidget {
  const _MobileTodayPage({
    required this.showLater,
    required this.onFilterChanged,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onOpenDrawer,
    required this.onSync,
  });

  final bool showLater;
  final ValueChanged<bool> onFilterChanged;
  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<CueTask> onToggleTask;
  final VoidCallback onOpenDrawer;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    final tasks = showLater ? store.upcomingTasks : store.todayTasks;
    return RefreshIndicator(
      color: CueColors.accent,
      backgroundColor: CueColors.card,
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
            onOpenDrawer: onOpenDrawer,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MobilePill(
                key: const Key('mobile-today-filter-today'),
                label: context.l10n.today,
                selected: !showLater,
                onTap: () => onFilterChanged(false),
              ),
              const SizedBox(width: 8),
              _MobilePill(
                key: const Key('mobile-today-filter-later'),
                label: context.l10n.later,
                selected: showLater,
                onTap: () => onFilterChanged(true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (tasks.isNotEmpty)
            _TaskGroup(
              label: '',
              showLabel: false,
              tasks: tasks,
              store: store,
              onOpenTask: onOpenTask,
              onToggleTask: onToggleTask,
            ),
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
    this.labelIncludesCount = false,
    this.showLabel = true,
  });

  final String label;
  final List<CueTask> tasks;
  final TaskStore store;
  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<CueTask> onToggleTask;
  final bool labelIncludesCount;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            labelIncludesCount ? label : '$label · ${tasks.length}',
            style: _mobileEyebrowStyle,
          ),
          const SizedBox(height: 8),
        ],
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
    required this.onOpenDrawer,
    required this.onSync,
  });

  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<CueTask> onToggleTask;
  final VoidCallback onOpenDrawer;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    final groups = store.groups;
    final selection = ref.watch(mobileBoardGroupProvider);
    final selectedGroup = groups.contains(selection)
        ? selection!
        : groups.first;
    final activeTasks = store.activeTasksForGroup(selectedGroup);
    final completedTasks = store.completedTasksForGroup(selectedGroup);

    return RefreshIndicator(
      color: CueColors.accent,
      backgroundColor: CueColors.card,
      onRefresh: onSync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CueInsets.mobilePage,
        children: [
          _MobileHeader(
            title: context.l10n.board,
            subtitle: context.l10n.openTaskCount(store.activeTasks.length),
            onOpenDrawer: onOpenDrawer,
          ),
          const SizedBox(height: CueMobileBoardTokens.headerToGroupsGap),
          _MobileBoardGroupSwitcher(
            groups: groups,
            selectedGroup: selectedGroup,
            onSelect: (group) =>
                ref.read(mobileBoardGroupProvider.notifier).select(group),
            onAddGroup: () => _showAddGroupDialog(context, ref, store),
          ),
          const SizedBox(height: CueMobileBoardTokens.groupsToTasksGap),
          if (activeTasks.isNotEmpty)
            _TaskGroup(
              label: context.l10n.openTasksLabel(activeTasks.length),
              labelIncludesCount: true,
              tasks: activeTasks,
              store: store,
              onOpenTask: onOpenTask,
              onToggleTask: onToggleTask,
            ),
          if (activeTasks.isNotEmpty && completedTasks.isNotEmpty)
            const SizedBox(height: CueMobileBoardTokens.sectionGap),
          if (completedTasks.isNotEmpty)
            _TaskGroup(
              label: context.l10n.completed,
              tasks: completedTasks,
              store: store,
              onOpenTask: onOpenTask,
              onToggleTask: onToggleTask,
            ),
          if (activeTasks.isEmpty && completedTasks.isEmpty)
            _MobileEmptyState(label: context.l10n.emptyList),
        ],
      ),
    );
  }

  Future<void> _showAddGroupDialog(
    BuildContext context,
    WidgetRef ref,
    TaskStore store,
  ) async {
    var name = '';

    void submit(BuildContext dialogContext) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;
      store.addGroup(trimmed);
      ref.read(mobileBoardGroupProvider.notifier).select(trimmed);
      Navigator.pop(dialogContext);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.addGroup),
        content: TextField(
          key: const Key('mobile-add-group-name-field'),
          autofocus: true,
          maxLength: 100,
          onChanged: (value) => name = value,
          onSubmitted: (_) => submit(dialogContext),
          decoration: InputDecoration(hintText: context.l10n.enterGroupName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('mobile-add-group-submit'),
            onPressed: () => submit(dialogContext),
            child: Text(context.l10n.addGroup),
          ),
        ],
      ),
    );
  }
}

class _MobileBoardGroupSwitcher extends StatelessWidget {
  const _MobileBoardGroupSwitcher({
    required this.groups,
    required this.selectedGroup,
    required this.onSelect,
    required this.onAddGroup,
  });

  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onSelect;
  final VoidCallback onAddGroup;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CueMobileBoardTokens.groupHeight,
      child: ListView.separated(
        key: const Key('mobile-board-group-switcher'),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length + 1,
        separatorBuilder: (_, _) =>
            const SizedBox(width: CueMobileBoardTokens.groupGap),
        itemBuilder: (context, index) {
          if (index == groups.length) {
            return SizedBox(
              width: CueMobileBoardTokens.groupHeight,
              height: CueMobileBoardTokens.groupHeight,
              child: IconButton(
                key: const Key('mobile-board-add-group'),
                tooltip: context.l10n.addGroup,
                onPressed: onAddGroup,
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.add_rounded,
                  size: CueMobileBoardTokens.groupAddIconSize,
                  color: CueMobileBoardTokens.addGroupForeground,
                ),
              ),
            );
          }
          final group = groups[index];
          final selected = group == selectedGroup;
          final foreground = selected
              ? CueMobileBoardTokens.selectedForeground
              : CueMobileBoardTokens.foreground;
          return Semantics(
            button: true,
            selected: selected,
            child: Material(
              key: ValueKey('mobile-board-group-$group'),
              color: selected
                  ? CueMobileBoardTokens.selectedBackground
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                CueMobileBoardTokens.groupRadius,
              ),
              child: InkWell(
                onTap: () => onSelect(group),
                borderRadius: BorderRadius.circular(
                  CueMobileBoardTokens.groupRadius,
                ),
                child: Padding(
                  padding: CueMobileBoardTokens.groupPadding,
                  child: Center(
                    child: Text(
                      group,
                      style: TextStyle(
                        color: foreground,
                        fontSize: CueMobileBoardTokens.groupLabelFontSize,
                        height: 20 / CueMobileBoardTokens.groupLabelFontSize,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileCalendarPage extends ConsumerStatefulWidget {
  const _MobileCalendarPage({
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onSync,
  });

  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<CueTask> onToggleTask;
  final Future<void> Function() onSync;

  @override
  ConsumerState<_MobileCalendarPage> createState() =>
      _MobileCalendarPageState();
}

class _MobileCalendarPageState extends ConsumerState<_MobileCalendarPage>
    with TickerProviderStateMixin {
  late DateTime _selectedDay;

  // The "committed" current month (what the user sees when no swipe is in progress).
  late DateTime _currentMonth;

  // While a swipe is settling we keep a reference to the incoming month so we
  // can render it before the provider is updated.
  DateTime? _pendingMonth;

  // Raw finger offset in logical pixels, updated on every DragUpdate.
  double _dragOffset = 0;

  // -1 = dragging / settling towards previous month (finger moving right)
  //  1 = dragging / settling towards next month     (finger moving left)
  int _swipeDirection = 0;

  // Controls the settle animation after the finger lifts.
  late AnimationController _settleController;
  late Animation<double> _settleAnimation;

  // Width of the calendar grid, captured via LayoutBuilder.
  double _gridWidth = 0;

  @override
  void initState() {
    super.initState();
    final store = ref.read(taskStoreProvider)!;
    final today = store.today;
    final focusedMonth = ref.read(calendarFocusedMonthProvider);
    _currentMonth = DateTime(focusedMonth.year, focusedMonth.month);
    final isTodayMonth =
        focusedMonth.year == today.year && focusedMonth.month == today.month;
    _selectedDay = DateTime(
      focusedMonth.year,
      focusedMonth.month,
      isTodayMonth ? today.day : 1,
    );

    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _settleAnimation = const AlwaysStoppedAnimation(0);
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  void _selectDay(DateTime day) {
    final selected = DateTime(day.year, day.month, day.day);
    final focused = ref.read(calendarFocusedMonthProvider);
    if (selected.year != focused.year || selected.month != focused.month) {
      ref.read(calendarFocusedMonthProvider.notifier).setMonth(selected);
    }
    setState(() => _selectedDay = selected);
  }

  /// Returns the day to pre-select when navigating to [month].
  /// Selects today if [month] is the current calendar month, otherwise day 1.
  int _initialDayForMonth(DateTime month) {
    final today = ref.read(taskStoreProvider)!.today;
    if (month.year == today.year && month.month == today.month) {
      return today.day;
    }
    return 1;
  }

  // ── gesture handlers ────────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails _) {
    _settleController.stop();
    _dragOffset = 0;
    _swipeDirection = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta ?? 0;
      // positive drag (→) = going to prev month (-1)
      // negative drag (←) = going to next month (+1)
      _swipeDirection = _dragOffset < 0 ? 1 : -1;
      _pendingMonth = _swipeDirection == 1
          ? DateTime(_currentMonth.year, _currentMonth.month + 1)
          : DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final width = _gridWidth > 0 ? _gridWidth : 300.0;

    // Commit when dragged ≥35% of width or flicked fast enough.
    final commitSwipe =
        (_dragOffset.abs() >= width * 0.35) ||
        (velocity.abs() >= 400 && _dragOffset.sign == -velocity.sign);

    // Gap between the two month grids during the slide animation.
    const gap = 24.0;

    if (commitSwipe && _pendingMonth != null) {
      _animateSettle(
        from: _dragOffset,
        to: _dragOffset < 0 ? -(width + gap) : (width + gap),
        onComplete: () {
          final next = _pendingMonth!;
          ref.read(calendarFocusedMonthProvider.notifier).setMonth(next);
          setState(() {
            _currentMonth = next;
            _selectedDay = DateTime(
              next.year,
              next.month,
              _initialDayForMonth(next),
            );
            _dragOffset = 0;
            _pendingMonth = null;
            _swipeDirection = 0;
          });
        },
      );
    } else {
      _animateSettle(
        from: _dragOffset,
        to: 0,
        onComplete: () {
          setState(() {
            _dragOffset = 0;
            _pendingMonth = null;
            _swipeDirection = 0;
          });
        },
      );
    }
  }

  void _animateSettle({
    required double from,
    required double to,
    required VoidCallback onComplete,
  }) {
    final tween = Tween<double>(begin: from, end: to);
    _settleAnimation = tween.animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutCubic),
    );
    _settleController.reset();
    _settleController.forward().whenCompleteOrCancel(() {
      if (!mounted) return;
      onComplete();
    });
  }

  // Called by the month picker sheet or header.
  void _moveToMonth(DateTime month) {
    if (_settleController.isAnimating) return;
    final normalizedMonth = DateTime(month.year, month.month);
    final direction = normalizedMonth.isBefore(_currentMonth) ? -1 : 1;
    final width = _gridWidth > 0 ? _gridWidth : 300.0;

    setState(() {
      _swipeDirection = direction;
      _pendingMonth = normalizedMonth;
      _dragOffset = 0;
    });

    const gap = 24.0;
    _animateSettle(
      from: 0,
      to: direction == 1 ? -(width + gap) : (width + gap),
      onComplete: () {
        ref
            .read(calendarFocusedMonthProvider.notifier)
            .setMonth(normalizedMonth);
        setState(() {
          _currentMonth = normalizedMonth;
          _selectedDay = DateTime(
            normalizedMonth.year,
            normalizedMonth.month,
            _initialDayForMonth(normalizedMonth),
          );
          _dragOffset = 0;
          _pendingMonth = null;
          _swipeDirection = 0;
        });
      },
    );
  }

  Future<void> _openMonthPicker() async {
    final store = ref.read(taskStoreProvider)!;
    final selection = await showModalBottomSheet<_MobileMonthPickerResult>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MobileMonthPickerSheet(
        focusedMonth: _currentMonth,
        today: store.today,
      ),
    );
    if (!mounted || selection == null) return;
    if (selection.selectToday) {
      ref.read(calendarFocusedMonthProvider.notifier).resetToToday();
      final today = store.today;
      setState(() {
        _selectedDay = today;
        _currentMonth = DateTime(today.year, today.month);
      });
      return;
    }
    _moveToMonth(selection.month);
  }

  // ── grid builder ─────────────────────────────────────────────────────────────

  /// Builds the day grid for [month], translated by [offsetX] pixels.
  Widget _buildMonthGrid(
    TaskStore store,
    DateTime month,
    double offsetX,
    bool isInteractive,
  ) {
    final first = month.subtract(Duration(days: month.weekday - 1));
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weekCount = ((month.weekday - 1 + daysInMonth) / 7).ceil();
    final days = List.generate(
      weekCount * 7,
      (i) => first.add(Duration(days: i)),
    );

    return Transform.translate(
      offset: Offset(offsetX, 0),
      child: GridView.builder(
        key: ValueKey('calendar-grid-${month.year}-${month.month}'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: days.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: 6,
          mainAxisSpacing: 8,
          childAspectRatio: 44 / 46,
        ),
        itemBuilder: (context, index) {
          final day = days[index];
          final tasks = store.tasksForDay(day);
          final hasOverdueTasks = TaskStore.dateOnly(day).isBefore(TaskStore.dateOnly(store.today)) && tasks.any((t) => !t.isCompleted);
          return _CalendarDay(
            day: day,
            inMonth: day.month == month.month,
            selected: isInteractive && TaskStore.isSameDay(day, _selectedDay),
            isToday: TaskStore.isSameDay(day, store.today),
            hasTasks: tasks.isNotEmpty,
            hasOverdueTasks: hasOverdueTasks,
            onTap: isInteractive ? () => _selectDay(day) : null,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    final selectedTasks = store.tasksForDay(_selectedDay);

    return RefreshIndicator(
      color: CueColors.accent,
      backgroundColor: CueColors.card,
      onRefresh: widget.onSync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CueInsets.mobilePage,
        children: [
          _MobileCalendarHeader(
            title: formatMonthName(context, _currentMonth),
            subtitle: context.l10n.monthOverview(_currentMonth.year),
            onTitleTap: _openMonthPicker,
          ),
          const SizedBox(height: 20),
          // Weekday labels row
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
                        color: CueColors.tertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Follow-the-finger swipeable calendar grid ────────────────────
          GestureDetector(
            key: const Key('mobile-calendar-month-grid'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onHorizontalDragCancel: () {
              _animateSettle(
                from: _dragOffset,
                to: 0,
                onComplete: () => setState(() {
                  _dragOffset = 0;
                  _pendingMonth = null;
                  _swipeDirection = 0;
                }),
              );
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                _gridWidth = constraints.maxWidth;

                return AnimatedBuilder(
                  animation: _settleController,
                  builder: (context, _) {
                    // During active drag use _dragOffset directly;
                    // during the settle animation interpolate via _settleAnimation.
                    final liveOffset = _settleController.isAnimating
                        ? _settleAnimation.value
                        : _dragOffset;

                    final width = _gridWidth;
                    final hasPending =
                        _pendingMonth != null && liveOffset != 0;

                    // The incoming grid sits one full width + gap away,
                    // so there is always visual breathing room between months.
                    const gap = 24.0;
                    final pendingOffsetX = hasPending
                        ? liveOffset +
                            (_swipeDirection == 1
                                ? width + gap
                                : -(width + gap))
                        : 0.0;

                    return ClipRect(
                      child: Stack(
                        children: [
                          // Current month moves with the finger.
                          _buildMonthGrid(
                            store,
                            _currentMonth,
                            liveOffset,
                            true,
                          ),
                          // Incoming month trails just behind the edge.
                          if (hasPending)
                            _buildMonthGrid(
                              store,
                              _pendingMonth!,
                              pendingOffsetX,
                              false,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${formatMonthDay(context, _selectedDay)} · '
            '${context.l10n.taskCount(selectedTasks.length)}',
            key: const Key('mobile-calendar-selected-date-label'),
            style: TextStyle(
              color: CueColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (selectedTasks.isNotEmpty)
            for (var index = 0; index < selectedTasks.length; index++) ...[
              _MobileTaskRow(
                key: ValueKey(
                  'mobile-calendar-task-${selectedTasks[index].id}',
                ),
                task: selectedTasks[index],
                today: store.today,
                onOpen: () => widget.onOpenTask(selectedTasks[index]),
                onToggle: () => widget.onToggleTask(selectedTasks[index]),
              ),
              if (index != selectedTasks.length - 1)
                const SizedBox(height: CueSpacing.s8),
            ]
          else
            _MobileEmptyState(label: context.l10n.nothingScheduled),
        ],
      ),
    );
  }
}

class _MobileCalendarHeader extends StatelessWidget {
  const _MobileCalendarHeader({
    required this.title,
    required this.subtitle,
    required this.onTitleTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTitleTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CueMobileNavigationTokens.headerHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              button: true,
              child: GestureDetector(
                key: const Key('mobile-calendar-title-picker-trigger'),
                behavior: HitTestBehavior.opaque,
                onTap: onTitleTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CueMobileNavigationTokens.pageTitleTextStyle,
                          ),
                        ),
                        const SizedBox(width: CueSpacing.s4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: CueColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: CueSpacing.s2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CueMobileNavigationTokens.secondaryForeground,
                        fontSize: CueMobileNavigationTokens.subtitleFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileMonthPickerResult {
  const _MobileMonthPickerResult(this.month, {this.selectToday = false});

  final DateTime month;
  final bool selectToday;
}

class _MobileMonthPickerSheet extends StatefulWidget {
  const _MobileMonthPickerSheet({
    required this.focusedMonth,
    required this.today,
  });

  final DateTime focusedMonth;
  final DateTime today;

  @override
  State<_MobileMonthPickerSheet> createState() =>
      _MobileMonthPickerSheetState();
}

class _MobileMonthPickerSheetState extends State<_MobileMonthPickerSheet> {
  late int _displayedYear;

  @override
  void initState() {
    super.initState();
    _displayedYear = widget.focusedMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('mobile-month-picker-sheet'),
        padding: CueInsets.mobileSheet,
        decoration: BoxDecoration(
          color: CueColors.popover,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const SizedBox(height: CueSpacing.s16),
            Row(
              children: [
                Text(
                  '$_displayedYear',
                  key: const Key('mobile-month-picker-displayed-year'),
                  style: TextStyle(
                    color: CueColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('mobile-month-picker-prev-year'),
                  tooltip: MaterialLocalizations.of(context)
                      .previousPageTooltip,
                  onPressed: () => setState(() => _displayedYear--),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: CueColors.secondary,
                ),
                IconButton(
                  key: const Key('mobile-month-picker-today'),
                  tooltip: context.l10n.today,
                  onPressed: () => Navigator.pop(
                    context,
                    _MobileMonthPickerResult(widget.today, selectToday: true),
                  ),
                  icon: const Icon(Icons.panorama_fish_eye_rounded, size: 18),
                  color: CueColors.secondary,
                ),
                IconButton(
                  key: const Key('mobile-month-picker-next-year'),
                  tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  onPressed: () => setState(() => _displayedYear++),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: CueColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: CueSpacing.s16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: CueSpacing.s8,
                crossAxisSpacing: CueSpacing.s8,
                childAspectRatio: 2.2,
              ),
              itemBuilder: (context, index) {
                final month = index + 1;
                final selected =
                    widget.focusedMonth.year == _displayedYear &&
                    widget.focusedMonth.month == month;
                return Material(
                  color: selected ? CueColors.accent : CueColors.subtle,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('mobile-month-picker-item-$month'),
                    onTap: () => Navigator.pop(
                      context,
                      _MobileMonthPickerResult(DateTime(_displayedYear, month)),
                    ),
                    child: Center(
                      child: Text(
                        formatMonthName(context, DateTime(2024, month)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? CueColors.onAccent
                              : CueColors.primary,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileQuadrantsPage extends ConsumerWidget {
  const _MobileQuadrantsPage({required this.onOpenTask, required this.onSync});

  final ValueChanged<CueTask> onOpenTask;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(taskRevisionProvider);
    final store = ref.watch(taskStoreProvider)!;
    final panels = [
      (context.l10n.doNow, store.tasksForPriority(0), 0),
      (context.l10n.schedule, store.tasksForPriority(1), 1),
      (context.l10n.batch, store.tasksForPriority(2), 2),
      (context.l10n.reconsider, store.tasksForPriority(3), 3),
    ];
    return RefreshIndicator(
      color: CueColors.accent,
      backgroundColor: CueColors.card,
      onRefresh: onSync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CueInsets.mobilePage,
        children: [
          _MobileHeader(
            title: context.l10n.quadrants,
            subtitle: context.l10n.importanceUrgency,
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: panels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: CueQuadrantTokens.panelGap,
              mainAxisSpacing: CueQuadrantTokens.panelGap,
              childAspectRatio: 170 / 270,
            ),
            itemBuilder: (context, index) {
              final panel = panels[index];
              return _MobileQuadrant(
                title: panel.$1,
                tasks: panel.$2,
                priority: panel.$3,
                today: store.today,
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
    required this.onUpdateAccount,
    required this.serverUrl,
    required this.onConfigureServer,
  });

  final String? email;
  final Future<void> Function() onSync;
  final Future<void> Function()? onLogout;
  final AccountUpdater? onUpdateAccount;
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
          key: const Key('mobile-settings-title'),
          style: CueMobileNavigationTokens.pageTitleTextStyle,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.personalizeCue,
          style: TextStyle(
            color: CueColors.secondary,
            fontSize: 13,
            height: 18 / 13,
          ),
        ),
        const SizedBox(height: 16),
        _ProfileSummary(
          email: email,
          onTap: onLogout == null && onUpdateAccount == null
              ? null
              : () => _showAccountSheet(
                  context,
                  email,
                  onUpdateAccount,
                  onLogout,
                ),
        ),
        const SizedBox(height: 16),
        Text(context.l10n.preferences, style: _mobileSectionStyle),
        const SizedBox(height: 16),
        _SettingsRow(
          icon: Icons.home_outlined,
          label: context.l10n.defaultView,
          detail: startupViewLabel(context, mobileStartupView(app.startupView)),
          onTap: () => showDefaultViewPicker(context, mobile: true),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),
        Text(context.l10n.accountAndData, style: _mobileSectionStyle),
        const SizedBox(height: 16),
        if (onUpdateAccount != null && email != null) ...[
          _SettingsRow(
            icon: Icons.manage_accounts_outlined,
            label: context.l10n.accountSettings,
            detail: email,
            onTap: () => showAccountSettings(
              context,
              email: email!,
              onSave: onUpdateAccount!,
              mobile: true,
            ),
          ),
          const SizedBox(height: 8),
        ],
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
                    color: CueColors.accent,
                  ),
                )
              : null,
          onTap: store.isRemote ? () => _showSyncSheet(context) : null,
        ),
        const SizedBox(height: 16),
        Text(context.l10n.aboutCue, style: _mobileSectionStyle),
        const SizedBox(height: 16),
        _SettingsRow(
          key: const Key('mobile-about-cue'),
          icon: Icons.info_outline_rounded,
          label: context.l10n.aboutCue,
          detail: context.l10n.aboutCueDescription,
          onTap: () => showCueAbout(context, mobile: true),
        ),
      ],
    );
  }

  Future<void> _showSyncSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: CueColors.card,
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
                    color: CueColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  store.lastError ?? context.l10n.syncDescription,
                  style: TextStyle(
                    color: store.lastError == null
                        ? CueColors.secondary
                        : CueColors.danger,
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
                      backgroundColor: CueColors.accent,
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
                        foregroundColor: CueColors.secondary,
                        side: BorderSide(color: CueColors.border),
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
    AccountUpdater? onUpdateAccount,
    Future<void> Function()? onLogout,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: CueColors.card,
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
                color: CueColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (onUpdateAccount != null && email != null) ...[
              FilledButton.icon(
                key: const Key('mobile-account-settings'),
                style: FilledButton.styleFrom(
                  backgroundColor: CueColors.accent,
                  foregroundColor: CueColors.onAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  showAccountSettings(
                    context,
                    email: email,
                    onSave: onUpdateAccount,
                    mobile: true,
                  );
                },
                icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: Text(context.l10n.accountSettings),
              ),
              const SizedBox(height: 8),
            ],
            if (onLogout != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: CueColors.danger,
                  side: BorderSide(color: CueColors.border),
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

class _MobileNavigationDrawer extends StatelessWidget {
  const _MobileNavigationDrawer({
    required this.destination,
    required this.onSelect,
  });

  final MobileDestination destination;
  final ValueChanged<MobileDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('mobile-navigation-drawer'),
      width: CueMobileNavigationTokens.drawerWidth,
      backgroundColor: CueMobileNavigationTokens.drawerSurface,
      surfaceTintColor: CueMobileNavigationTokens.surfaceTint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(CueMobileNavigationTokens.drawerRadius),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: CueMobileNavigationTokens.drawerPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: CueMobileNavigationTokens.drawerHeaderHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: CueMobileNavigationTokens.itemPadding,
                    child: Text(
                      'Cue',
                      style: CueMobileNavigationTokens.brandTextStyle,
                    ),
                  ),
                ),
              ),
              _MobileNavigationItem(
                key: const Key('mobile-drawer-today'),
                icon: Icons.today_outlined,
                label: context.l10n.today,
                selected: destination == MobileDestination.today,
                onTap: () => onSelect(MobileDestination.today),
              ),
              const SizedBox(height: CueMobileNavigationTokens.itemGap),
              _MobileNavigationItem(
                key: const Key('mobile-drawer-board'),
                icon: Icons.view_column_outlined,
                label: context.l10n.board,
                selected: destination == MobileDestination.board,
                onTap: () => onSelect(MobileDestination.board),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavigationItem extends StatelessWidget {
  const _MobileNavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? CueMobileNavigationTokens.selectedForeground
        : CueMobileNavigationTokens.foreground;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? CueMobileNavigationTokens.selectedBackground
            : CueMobileNavigationTokens.unselectedBackground,
        borderRadius: BorderRadius.circular(
          CueMobileNavigationTokens.itemRadius,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            CueMobileNavigationTokens.itemRadius,
          ),
          child: SizedBox(
            height: CueMobileNavigationTokens.itemHeight,
            child: Padding(
              padding: CueMobileNavigationTokens.itemPadding,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: CueMobileNavigationTokens.itemIconSize,
                    color: foreground,
                  ),
                  const SizedBox(
                    width: CueMobileNavigationTokens.itemContentGap,
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: CueMobileNavigationTokens.itemLabelStyle(
                        selected: selected,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.title,
    required this.subtitle,
    this.onOpenDrawer,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CueMobileNavigationTokens.headerHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onOpenDrawer != null) ...[
            SizedBox(
              width: CueMobileNavigationTokens.headerActionSize,
              height: CueMobileNavigationTokens.headerActionSize,
              child: IconButton(
                key: const Key('mobile-drawer-button'),
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                onPressed: onOpenDrawer,
                padding: EdgeInsets.zero,
                alignment: CueMobileNavigationTokens.headerLeadingIconAlignment,
                icon: Icon(
                  Icons.menu_rounded,
                  size: CueMobileNavigationTokens.headerIconSize,
                  color: CueMobileNavigationTokens.foreground,
                ),
              ),
            ),
            const SizedBox(width: CueMobileNavigationTokens.headerTitleGap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CueMobileNavigationTokens.pageTitleTextStyle,
                ),
                const SizedBox(height: CueSpacing.s2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CueMobileNavigationTokens.secondaryForeground,
                    fontSize: CueMobileNavigationTokens.subtitleFontSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePill extends StatelessWidget {
  const _MobilePill({
    super.key,
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
      height: 36,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: selected ? CueColors.onAccent : CueColors.primary,
          backgroundColor: selected ? CueColors.accent : CueColors.subtle,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final int priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (priority) {
      0 => (CueColors.dangerBackground, CueColors.danger),
      1 => (CueColors.orangeBackground, CueColors.orange),
      2 => (CueColors.selected, CueColors.accent),
      _ => (CueColors.subtle, CueColors.secondary),
    };

    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: fg,
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: selected
                ? BorderSide(color: fg, width: 1.5)
                : BorderSide.none,
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text('P$priority'),
      ),
    );
  }
}


class _MobileTaskRow extends StatelessWidget {
  const _MobileTaskRow({
    super.key,
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
    final isOverdue = !task.isCompleted &&
        task.dueAt != null &&
        TaskStore.dateOnly(task.dueAt!).isBefore(TaskStore.dateOnly(today));

    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: CueSpacing.s16),
        decoration: BoxDecoration(
          color: CueColors.card,
          border: Border.all(color: CueColors.border),
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
                      color: CueColors.primary,
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOverdue) ...[
                        Icon(
                          Icons.error_outline_rounded,
                          size: 13,
                          color: CueColors.danger,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          _mobileTaskMeta(context, task, today),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isOverdue ? CueColors.danger : CueColors.secondary,
                            fontSize: 13,
                            height: 18 / 13,
                          ),
                        ),
                      ),
                    ],
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
      0 => (CueColors.dangerBackground, CueColors.danger),
      1 => (CueColors.orangeBackground, CueColors.orange),
      2 => (CueColors.selected, CueColors.accent),
      _ => (CueColors.subtle, CueColors.secondary),
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
    required this.isToday,
    required this.hasTasks,
    this.hasOverdueTasks = false,
    this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool isToday;
  final bool hasTasks;
  final bool hasOverdueTasks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Visual priority:
    //   isToday              → filled blue background + bold accent border
    //   selected (non-today) → transparent background + thin muted border
    //   otherwise            → card / subtle background, no border
    final bg = isToday
        ? CueColors.selected
        : inMonth
        ? CueColors.card
        : CueColors.subtle;

    final border = isToday
        ? Border.all(color: CueColors.accent, width: 2)
        : selected
        ? Border.all(color: CueColors.accent.withValues(alpha: 0.35), width: 1.5)
        : null;

    return GestureDetector(
      key: ValueKey(
        'mobile-calendar-day-'
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}',
      ),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: isToday
                    ? CueColors.accent
                    : inMonth
                    ? CueColors.primary
                    : CueColors.tertiary,
                fontSize: 12,
                fontWeight: isToday || selected
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 4,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: hasOverdueTasks
                      ? CueColors.danger
                      : hasTasks
                          ? CueColors.accent
                          : Colors.transparent,
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
    required this.tasks,
    required this.priority,
    required this.today,
    required this.onOpenTask,
  });

  final String title;
  final List<CueTask> tasks;
  final int priority;
  final DateTime today;
  final ValueChanged<CueTask> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final accentColor = CueQuadrantTokens.accentForPriority(priority);
    return Container(
      key: ValueKey('mobile-quadrant-panel-$priority'),
      padding: CueQuadrantTokens.panelPadding,
      decoration: BoxDecoration(
        color: CueQuadrantTokens.panelBackground,
        border: Border.all(color: CueQuadrantTokens.panelBorder),
        borderRadius: BorderRadius.circular(CueQuadrantTokens.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  key: ValueKey('mobile-quadrant-title-$priority'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: accentColor),
                ),
              ),
              Text(
                'P$priority',
                key: ValueKey('mobile-quadrant-priority-$priority'),
                style: CueQuadrantTokens.priorityLabelStyle,
              ),
            ],
          ),
          const SizedBox(height: CueQuadrantTokens.headerToTasksGap),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final task in tasks.take(3)) ...[
                  Builder(
                    builder: (context) {
                      final isOverdue = !task.isCompleted &&
                          task.dueAt != null &&
                          TaskStore.dateOnly(task.dueAt!).isBefore(TaskStore.dateOnly(today));

                      return GestureDetector(
                        onTap: () => onOpenTask(task),
                        child: Container(
                          key: ValueKey('mobile-quadrant-task-${task.id}'),
                          width: double.infinity,
                          height: CueQuadrantTokens.taskHeight,
                          padding: CueQuadrantTokens.taskPadding,
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: isOverdue 
                                ? CueColors.danger.withValues(alpha: 0.05) 
                                : CueQuadrantTokens.taskBackground,
                            border: Border.all(
                              color: isOverdue 
                                  ? CueColors.danger.withValues(alpha: 0.2) 
                                  : CueQuadrantTokens.taskBorder,
                            ),
                            borderRadius: BorderRadius.circular(
                              CueQuadrantTokens.taskRadius,
                            ),
                          ),
                          child: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CueQuadrantTokens.taskTitleStyle.copyWith(
                              color: isOverdue ? CueColors.danger : CueColors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: CueQuadrantTokens.taskGap),
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
        color: CueColors.card,
        border: Border(top: BorderSide(color: CueColors.border)),
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
                    color: selected ? CueColors.accent : CueColors.secondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: TextStyle(
                      color: selected ? CueColors.accent : CueColors.secondary,
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
          color: CueColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: CueColors.shadow.withValues(alpha: 0.12),
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
            CueColors.onAccent,
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
      backgroundColor: CueColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: CueSpacing.s20,
        vertical: CueSpacing.s24,
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: CueColors.border),
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
                                : CueColors.secondary,
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
                    color: CueColors.card,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: CueColors.border),
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
                                      : CueColors.primary,
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
                    color: CueColors.secondary,
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
                        color: CueColors.primary,
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
                          color: CueColors.primary,
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
                style: TextStyle(color: CueColors.secondary, fontSize: 13),
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
                          color: CueColors.primary,
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
                                ? CueColors.secondary
                                : CueColors.primary,
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
                border: Border(top: BorderSide(color: CueColors.border)),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  PopupMenuButton<String>(
                    color: CueColors.card,
                    iconColor: CueColors.secondary,
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
                          style: TextStyle(color: CueColors.primary),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          context.l10n.delete,
                          style: TextStyle(color: CueColors.danger),
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
          color: CueColors.card,
          border: Border.all(color: CueColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CueColors.selected,
                shape: BoxShape.circle,
              ),
              child: Text(
                monogram,
                style: TextStyle(
                  color: CueColors.accent,
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
                    style: TextStyle(color: CueColors.primary, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email ?? context.l10n.focusStreak,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: CueColors.secondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: CueColors.secondary,
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
    super.key,
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
          color: CueColors.card,
          border: Border.all(color: CueColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CueColors.selected,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: CueColors.accent),
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
                      color: CueColors.primary,
                      fontSize: 15,
                      height: 21 / 15,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: TextStyle(
                        color: CueColors.secondary,
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
                  color: CueColors.secondary,
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
        Text(label, style: TextStyle(color: CueColors.secondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(color: CueColors.primary, fontSize: 13)),
      ],
    );
  }
}

class _MobileTextField extends StatelessWidget {
  const _MobileTextField({
    required this.label,
    required this.onChanged,
    this.autofocus = false,
    this.maxLines = 1,
  });

  final String label;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      autofocus: autofocus,
      maxLines: maxLines,
      style: TextStyle(color: CueColors.primary),
      cursorColor: CueColors.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: CueColors.secondary),
        filled: true,
        fillColor: CueColors.subtle,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: CueColors.border),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: CueColors.accent),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
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
          color: CueColors.tertiary,
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
          style: const TextStyle(color: CueColors.tertiary, fontSize: 13),
        ),
      ),
    );
  }
}

const _mobileEyebrowStyle = TextStyle(
  color: CueColors.tertiary,
  fontSize: 11,
  height: 16 / 11,
  fontWeight: FontWeight.w600,
);

TextStyle get _mobileSectionStyle => TextStyle(
  color: CueColors.secondary,
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
  if (!task.isCompleted && TaskStore.dateOnly(task.dueAt!).isBefore(TaskStore.dateOnly(today))) {
    return '${formatShortYearMonthDay(context, task.dueAt!)} · ${_area(context, task)}';
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
