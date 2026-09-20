import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task_store.dart';
import '../../l10n/l10n.dart';
import '../../models/cue_task.dart';
import '../../state/app_state.dart';
import '../../state/page_state.dart';
import '../cue_theme.dart';
import '../cue_widgets.dart';

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({
    super.key,
    required this.onOpenTask,
    required this.onSelectDay,
  });

  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<DateTime> onSelectDay;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  DateTime _lastScrollTime = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _dueOnly => ref.read(calendarDueOnlyProvider);
  TaskStore get _store => ref.read(taskStoreProvider)!;

  void _handleScroll(PointerScrollEvent event) {
    final now = DateTime.now();
    if (now.difference(_lastScrollTime).inMilliseconds < 250) {
      return;
    }
    if (event.scrollDelta.dy.abs() < 5) {
      return;
    }

    _lastScrollTime = now;
    if (event.scrollDelta.dy > 0) {
      ref.read(calendarFocusedMonthProvider.notifier).nextMonth();
    } else {
      ref.read(calendarFocusedMonthProvider.notifier).previousMonth();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(taskRevisionProvider);
    ref.watch(calendarDueOnlyProvider);
    final focusedMonth = ref.watch(calendarFocusedMonthProvider);
    final today = _store.today;
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final monthEnd = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final scheduled = _store.tasks.where((task) {
      if (task.deletedAt == null && task.dueAt != null) {
        for (var day = monthStart; !day.isAfter(monthEnd); day = day.add(const Duration(days: 1))) {
          if (TaskStore.isTaskOnDay(task, day)) return true;
        }
      }
      return false;
    });
    final dueThisWeek = _store.tasks.where((task) {
      if (task.deletedAt != null || task.dueAt == null || task.isCompleted) return false;
      for (var day = weekStart; day.isBefore(weekEnd); day = day.add(const Duration(days: 1))) {
        if (TaskStore.isTaskOnDay(task, day)) return true;
      }
      return false;
    }).length;
    final month = DateTime(focusedMonth.year, focusedMonth.month);
    final leadingDays = month.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weekCount = ((leadingDays + daysInMonth + 6) ~/ 7);
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          _handleScroll(pointerSignal);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _WeekdayHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: _MonthGrid(
              focusedMonth: focusedMonth,
              store: _store,
              weekCount: weekCount,
              dueOnly: _dueOnly,
              onOpenTask: widget.onOpenTask,
              onSelectDay: widget.onSelectDay,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => formatNarrowWeekday(context, DateTime(2024, 1, index + 1)),
    );
    return SizedBox(
      height: 28,
      child: Row(
        children: days
            .map(
              (day) => Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CueColors.tertiary,
                    fontSize: 11,
                    height: 14 / 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.44,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focusedMonth,
    required this.store,
    required this.weekCount,
    required this.dueOnly,
    required this.onOpenTask,
    required this.onSelectDay,
  });

  final DateTime focusedMonth;
  final TaskStore store;
  final int weekCount;
  final bool dueOnly;
  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final month = DateTime(focusedMonth.year, focusedMonth.month);
    final first = month.subtract(Duration(days: month.weekday - 1));
    final days = List.generate(
      weekCount * 7,
      (index) => first.add(Duration(days: index)),
    );
    return Column(
      children: List.generate(weekCount, (week) {
        return Expanded(
          child: Row(
            children: days.skip(week * 7).take(7).map((day) {
              var tasks = store.tasksForDay(day);
              if (dueOnly) {
                tasks = tasks.where((task) => !task.isCompleted).toList();
              }
              return Expanded(
                child: _CalendarCell(
                  day: day,
                  tasks: tasks,
                  currentMonth: day.month == month.month,
                  selected: TaskStore.isSameDay(day, store.today),
                  onOpenTask: onOpenTask,
                  onTap: () {
                    if (tasks.isNotEmpty) {
                      onOpenTask(tasks.first);
                    } else {
                      onSelectDay(day);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        );
      }),
    );
  }
}

class _CalendarCell extends StatefulWidget {
  const _CalendarCell({
    required this.day,
    required this.tasks,
    required this.currentMonth,
    required this.selected,
    required this.onOpenTask,
    required this.onTap,
  });

  final DateTime day;
  final List<CueTask> tasks;
  final bool currentMonth;
  final bool selected;
  final ValueChanged<CueTask> onOpenTask;
  final VoidCallback onTap;

  @override
  State<_CalendarCell> createState() => _CalendarCellState();
}

class _CalendarCellState extends State<_CalendarCell> {
  bool _hovered = false;

  String get _dateText {
    if (widget.day.day == 1) {
      return '${widget.day.month}月1日';
    }
    return '${widget.day.day}';
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.selected
        ? CueColors.accent
        : _hovered
        ? CueColors.strongBorder
        : CueColors.border;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? CueColors.hover : CueColors.card,
            border: Border.all(
              color: borderColor,
              width: widget.selected ? 2 : 1,
            ),
          ),
          child: Opacity(
            opacity: widget.currentMonth ? 1 : 0.38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateText,
                  style: TextStyle(
                    color: CueColors.primary,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableHeight = constraints.maxHeight;
                      const itemHeight = 21.0;
                      const gap = 3.0;
                      const stride = itemHeight + gap;
                      final total = widget.tasks.length;

                      if (total == 0) return const SizedBox.shrink();

                      int visibleCount;
                      bool showMore = false;
                      int moreCount = 0;

                      if (total * stride - gap <= availableHeight) {
                        visibleCount = total;
                      } else {
                        visibleCount =
                            ((availableHeight - itemHeight + gap) / stride)
                                .floor();
                        if (visibleCount < 1) {
                          visibleCount = availableHeight >= itemHeight ? 1 : 0;
                          showMore = false;
                        } else {
                          showMore = true;
                          moreCount = total - visibleCount;
                        }
                      }

                      final visibleTasks =
                          widget.tasks.take(visibleCount).toList();

                      return ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final task in visibleTasks) ...[
                                _TaskPill(
                                  task: task,
                                  onTap: () => widget.onOpenTask(task),
                                ),
                                const SizedBox(height: gap),
                              ],
                              if (showMore && moreCount > 0)
                                _MoreTasksPill(
                                  count: moreCount,
                                  onTap: widget.onTap,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskPill extends StatelessWidget {
  const _TaskPill({required this.task, required this.onTap});

  final CueTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        key: Key('calendar-task-${task.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 21,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: task.isCompleted ? CueColors.subtle : CueColors.selected,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? CueColors.tertiary
                      : CueColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: task.isCompleted
                        ? CueColors.tertiary
                        : CueColors.accent,
                    fontSize: 11,
                    height: 13 / 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTasksPill extends StatelessWidget {
  const _MoreTasksPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 21,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: CueColors.subtle,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '+$count 更多',
          style: TextStyle(
            color: CueColors.secondary,
            fontSize: 11,
            height: 13 / 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
