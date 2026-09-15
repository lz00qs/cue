import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/task_store.dart';
import '../../models/cue_task.dart';
import '../cue_theme.dart';
import '../cue_widgets.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.store,
    required this.onOpenTask,
    required this.onSelectDay,
  });

  final TaskStore store;
  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<DateTime> onSelectDay;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  bool _dueOnly = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              CueViewTab(label: 'Month', selected: true, onTap: () {}),
              const SizedBox(width: 8),
              CueViewTab(
                label: 'Due only',
                selected: _dueOnly,
                onTap: () => setState(() => _dueOnly = !_dueOnly),
              ),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width >= 720)
                Text(
                  '12 scheduled · 4 due this week',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: CueColors.tertiary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final calendarWidth = math.max(840.0, constraints.maxWidth);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: calendarWidth,
                child: Column(
                  children: [
                    const _WeekdayHeader(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 792,
                      child: _MonthGrid(
                        width: calendarWidth,
                        store: widget.store,
                        dueOnly: _dueOnly,
                        onOpenTask: widget.onOpenTask,
                        onSelectDay: widget.onSelectDay,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
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
    required this.width,
    required this.store,
    required this.dueOnly,
    required this.onOpenTask,
    required this.onSelectDay,
  });

  final double width;
  final TaskStore store;
  final bool dueOnly;
  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final month = DateTime(store.today.year, store.today.month);
    final first = month.subtract(Duration(days: month.weekday - 1));
    final days = List.generate(42, (index) => first.add(Duration(days: index)));
    return Column(
      children: List.generate(6, (week) {
        return SizedBox(
          height: 132,
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
    required this.onTap,
  });

  final DateTime day;
  final List<CueTask> tasks;
  final bool currentMonth;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CalendarCell> createState() => _CalendarCellState();
}

class _CalendarCellState extends State<_CalendarCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.selected
        ? CueColors.accent
        : _hovered
        ? const Color(0xFFCAD1E8)
        : CueColors.border;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFFBFBFD) : CueColors.canvas,
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
                  '${widget.day.day}',
                  style: const TextStyle(
                    color: CueColors.primary,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 12),
                for (final task in widget.tasks.take(2)) ...[
                  _TaskPill(task: task),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskPill extends StatelessWidget {
  const _TaskPill({required this.task});

  final CueTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 24,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: CueColors.selected,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: CueColors.accent,
          fontSize: 11,
          height: 14 / 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
