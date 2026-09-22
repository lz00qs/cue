import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../l10n/l10n.dart';
import 'cue_theme.dart';

class CueDatePickerResult {
  const CueDatePickerResult({
    this.dueAt,
    this.reminder,
    this.recurrence,
    this.cleared = false,
  });

  final DateTime? dueAt;
  final String? reminder;
  final String? recurrence;
  final bool cleared;
}

String cueDueDateTimeLabel(
  BuildContext context,
  DateTime? dueAt, {
  required DateTime today,
}) {
  if (dueAt == null) return context.l10n.noDueDate;
  final date = TaskStore.dateOnly(dueAt);
  final reference = TaskStore.dateOnly(today);
  final dateLabel = TaskStore.isSameDay(date, reference)
      ? context.l10n.today
      : TaskStore.isSameDay(date, reference.add(const Duration(days: 1)))
      ? context.l10n.tomorrow
      : formatShortMonthDay(context, dueAt);
  if (dueAt.hour == 0 && dueAt.minute == 0) return dateLabel;
  final time =
      '${dueAt.hour.toString().padLeft(2, '0')}:'
      '${dueAt.minute.toString().padLeft(2, '0')}';
  return '$dateLabel · $time';
}

Future<CueDatePickerResult?> showCueDatePickerPopover({
  required BuildContext context,
  required DateTime today,
  DateTime? initialDueAt,
  String? initialReminder,
  String? initialRecurrence,
}) {
  return showDialog<CueDatePickerResult>(
    context: context,
    barrierColor: CueColors.modalBarrier,
    builder: (context) => CueDatePickerPopover(
      today: today,
      initialDueAt: initialDueAt,
      initialReminder: initialReminder,
      initialRecurrence: initialRecurrence,
    ),
  );
}

Future<DateTime?> showCueCompletionDatePickerPopover({
  required BuildContext context,
  required DateTime initialCompletedAt,
}) async {
  final result = await showDialog<CueDatePickerResult>(
    context: context,
    barrierColor: CueColors.modalBarrier,
    builder: (context) => CueDatePickerPopover(
      today: DateTime.now(),
      initialDueAt: initialCompletedAt,
      completionMode: true,
    ),
  );
  return result?.dueAt;
}

class CueDatePickerPopover extends StatefulWidget {
  const CueDatePickerPopover({
    super.key,
    required this.today,
    this.initialDueAt,
    this.initialReminder,
    this.initialRecurrence,
    this.completionMode = false,
  });

  final DateTime today;
  final DateTime? initialDueAt;
  final String? initialReminder;
  final String? initialRecurrence;
  final bool completionMode;

  @override
  State<CueDatePickerPopover> createState() => _CueDatePickerPopoverState();
}

class _CueDatePickerPopoverState extends State<CueDatePickerPopover> {
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  late String _selectedReminder;
  late String _selectedRecurrence;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final init = widget.initialDueAt ?? widget.today;
    _selectedDate = DateTime(init.year, init.month, init.day);
    if (widget.initialDueAt != null) {
      _selectedTime = TimeOfDay(
        hour: widget.initialDueAt!.hour,
        minute: widget.initialDueAt!.minute,
      );
    } else {
      _selectedTime = const TimeOfDay(hour: 18, minute: 0);
    }
    _selectedReminder = widget.initialReminder ?? 'none';
    _selectedRecurrence = widget.initialRecurrence ?? 'none';
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  String _reminderLabel(String key) {
    return switch (key) {
      'on_time' => '准时',
      'min_5' => '提前 5 分钟',
      'min_30' => '提前 30 分钟',
      'hour_1' => '提前 1 小时',
      'day_1' => '提前 1 天',
      _ => '无提醒',
    };
  }

  String _recurrenceLabel(String key) {
    return switch (key) {
      'daily' => '每天',
      'weekly' => '每周',
      'monthly' => '每月',
      'yearly' => '每年',
      'workday' => '每工作日',
      _ => '不重复',
    };
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday % 7; // 0 for Sunday

    return Dialog(
      key: Key(
        widget.completionMode
            ? 'cue-completion-date-picker-popover'
            : 'cue-date-picker-popover',
      ),
      backgroundColor: CueColors.popover,
      surfaceTintColor: Colors.transparent,
      elevation: 20,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: CueColors.strongBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CueSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header title
              Row(
                children: [
                  Icon(Icons.event, size: 18, color: CueColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    widget.completionMode ? '更正完成时间' : '设置日期',
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Month navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_displayedMonth.year}年${_displayedMonth.month}月',
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        color: CueColors.secondary,
                        onPressed: () {
                          setState(() {
                            _displayedMonth = DateTime(
                              _displayedMonth.year,
                              _displayedMonth.month - 1,
                            );
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.circle_outlined, size: 14),
                        color: CueColors.secondary,
                        onPressed: () {
                          setState(() {
                            _displayedMonth = DateTime(
                              widget.today.year,
                              widget.today.month,
                            );
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        color: CueColors.secondary,
                        onPressed: () {
                          setState(() {
                            _displayedMonth = DateTime(
                              _displayedMonth.year,
                              _displayedMonth.month + 1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Weekday header (日 一 二 三 四 五 六)
              Row(
                children: const ['日', '一', '二', '三', '四', '五', '六']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: CueColors.tertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),

              // Days grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: startWeekday + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  if (index < startWeekday) {
                    return const SizedBox.shrink();
                  }
                  final dayNumber = index - startWeekday + 1;
                  final cellDate = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month,
                    dayNumber,
                  );
                  final isSelected = TaskStore.isSameDay(
                    cellDate,
                    _selectedDate,
                  );
                  final isToday = TaskStore.isSameDay(cellDate, widget.today);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDate = cellDate;
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CueColors.accent
                            : isToday
                            ? CueColors.selected
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isToday && !isSelected
                            ? Border.all(color: CueColors.accent, width: 1)
                            : null,
                      ),
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          color: isSelected
                              ? CueColors.onAccent
                              : isToday
                              ? CueColors.accent
                              : CueColors.primary,
                          fontSize: 13,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 8),

              // 1. Time (截止时间) row -> Native TimePicker dialog
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: CueSpacing.s8,
                  horizontal: CueSpacing.s4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: CueColors.secondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '时间',
                      style: TextStyle(color: CueColors.primary, fontSize: 14),
                    ),
                    const Spacer(),
                    InkWell(
                      key: const Key('cue-date-picker-time'),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              _selectedTime ??
                              const TimeOfDay(hour: 18, minute: 0),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme
                                    .copyWith(
                                      primary: CueColors.accent,
                                      surface: CueColors.popover,
                                      onSurface: CueColors.primary,
                                    ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CueSpacing.s8,
                          vertical: CueSpacing.s4,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedTime != null
                              ? CueColors.selected
                              : CueColors.subtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedTime != null
                                  ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                  : '全天',
                              style: TextStyle(
                                color: _selectedTime != null
                                    ? CueColors.accent
                                    : CueColors.secondary,
                                fontSize: 13,
                                fontWeight: _selectedTime != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_calendar,
                              size: 14,
                              color: CueColors.tertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedTime != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedTime = null);
                        },
                        child: Icon(
                          Icons.cancel,
                          size: 16,
                          color: CueColors.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 2. Reminder (提醒时间) row -> Right-aligned PopupMenu
              if (!widget.completionMode)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: CueSpacing.s8,
                    horizontal: CueSpacing.s4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 18,
                        color: CueColors.secondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '提醒',
                        style: TextStyle(
                          color: CueColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: '提醒时间',
                        position: PopupMenuPosition.under,
                        color: CueColors.card,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: CueColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (key) {
                          setState(() => _selectedReminder = key);
                        },
                        itemBuilder: (context) => [
                          for (final key in [
                            'none',
                            'on_time',
                            'min_5',
                            'min_30',
                            'hour_1',
                            'day_1',
                          ])
                            PopupMenuItem<String>(
                              value: key,
                              child: Text(
                                _reminderLabel(key),
                                style: TextStyle(
                                  color: key == _selectedReminder
                                      ? CueColors.accent
                                      : CueColors.primary,
                                ),
                              ),
                            ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _reminderLabel(_selectedReminder),
                              style: TextStyle(
                                color: _selectedReminder != 'none'
                                    ? CueColors.accent
                                    : CueColors.secondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: CueColors.tertiary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 3. Recurrence (重复) row -> Right-aligned PopupMenu
              if (!widget.completionMode)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: CueSpacing.s8,
                    horizontal: CueSpacing.s4,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, size: 18, color: CueColors.secondary),
                      const SizedBox(width: 10),
                      Text(
                        '重复',
                        style: TextStyle(
                          color: CueColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: '重复规则',
                        position: PopupMenuPosition.under,
                        color: CueColors.card,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: CueColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (key) {
                          setState(() => _selectedRecurrence = key);
                        },
                        itemBuilder: (context) => [
                          for (final key in [
                            'none',
                            'daily',
                            'weekly',
                            'monthly',
                            'yearly',
                            'workday',
                          ])
                            PopupMenuItem<String>(
                              value: key,
                              child: Text(
                                _recurrenceLabel(key),
                                style: TextStyle(
                                  color: key == _selectedRecurrence
                                      ? CueColors.accent
                                      : CueColors.primary,
                                ),
                              ),
                            ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _recurrenceLabel(_selectedRecurrence),
                              style: TextStyle(
                                color: _selectedRecurrence != 'none'
                                    ? CueColors.accent
                                    : CueColors.secondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: CueColors.tertiary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Bottom action buttons: Clear (清除) & Confirm (确定)
              Row(
                children: [
                  if (!widget.completionMode) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CueColors.secondary,
                          side: BorderSide(color: CueColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(
                            context,
                            const CueDatePickerResult(cleared: true),
                          );
                        },
                        child: const Text('清除'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: CueColors.accent,
                        foregroundColor: CueColors.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final hour = _selectedTime?.hour ?? 0;
                        final minute = _selectedTime?.minute ?? 0;
                        final finalDueAt = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          hour,
                          minute,
                        );
                        Navigator.pop(
                          context,
                          CueDatePickerResult(
                            dueAt: finalDueAt,
                            reminder: _selectedReminder == 'none'
                                ? null
                                : _selectedReminder,
                            recurrence: _selectedRecurrence == 'none'
                                ? null
                                : _selectedRecurrence,
                          ),
                        );
                      },
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
