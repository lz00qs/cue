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

class CueDatePickerPopover extends StatefulWidget {
  const CueDatePickerPopover({
    super.key,
    required this.today,
    this.initialDueAt,
    this.initialReminder,
    this.initialRecurrence,
  });

  final DateTime today;
  final DateTime? initialDueAt;
  final String? initialReminder;
  final String? initialRecurrence;

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
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday % 7; // 0 for Sunday

    return Dialog(
      key: const Key('cue-date-picker-popover'),
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
          padding: const EdgeInsets.all(16),
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
                    '设置日期',
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick preset bar: Sun (Today), Sunrise (Tomorrow), +7 (Next week), Moon (Later)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: CueColors.subtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      tooltip: context.l10n.today,
                      icon: Icon(Icons.wb_sunny_outlined, size: 20, color: CueColors.accent),
                      onPressed: () {
                        setState(() {
                          _selectedDate = widget.today;
                          _displayedMonth = DateTime(widget.today.year, widget.today.month);
                        });
                      },
                    ),
                    IconButton(
                      tooltip: context.l10n.tomorrow,
                      icon: const Icon(Icons.wb_twilight, size: 20, color: CueColors.orange),
                      onPressed: () {
                        final tom = widget.today.add(const Duration(days: 1));
                        setState(() {
                          _selectedDate = tom;
                          _displayedMonth = DateTime(tom.year, tom.month);
                        });
                      },
                    ),
                    IconButton(
                      tooltip: '下周',
                      icon: Icon(Icons.add_alert_outlined, size: 20, color: CueColors.primary),
                      onPressed: () {
                        final nextW = widget.today.add(const Duration(days: 7));
                        setState(() {
                          _selectedDate = nextW;
                          _displayedMonth = DateTime(nextW.year, nextW.month);
                        });
                      },
                    ),
                    IconButton(
                      tooltip: '稍后 (20:00)',
                      icon: const Icon(Icons.nightlight_round, size: 20, color: CueColors.tertiary),
                      onPressed: () {
                        setState(() {
                          _selectedDate = widget.today;
                          _selectedTime = const TimeOfDay(hour: 20, minute: 0);
                          _displayedMonth = DateTime(widget.today.year, widget.today.month);
                        });
                      },
                    ),
                  ],
                ),
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
                            _displayedMonth = DateTime(widget.today.year, widget.today.month);
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
                  final isSelected = TaskStore.isSameDay(cellDate, _selectedDate);
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

              // 1. Time (截止时间) row
              PopupMenuButton<TimeOfDay?>(
                tooltip: '选择时间',
                offset: const Offset(0, 36),
                color: CueColors.card,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: CueColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (time) {
                  setState(() => _selectedTime = time);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<TimeOfDay?>(
                    value: null,
                    child: Text('全天 (无具体时间)'),
                  ),
                  for (final t in [
                    const TimeOfDay(hour: 9, minute: 0),
                    const TimeOfDay(hour: 9, minute: 30),
                    const TimeOfDay(hour: 10, minute: 0),
                    const TimeOfDay(hour: 10, minute: 30),
                    const TimeOfDay(hour: 11, minute: 0),
                    const TimeOfDay(hour: 11, minute: 30),
                    const TimeOfDay(hour: 12, minute: 0),
                    const TimeOfDay(hour: 13, minute: 0),
                    const TimeOfDay(hour: 14, minute: 0),
                    const TimeOfDay(hour: 15, minute: 0),
                    const TimeOfDay(hour: 16, minute: 0),
                    const TimeOfDay(hour: 17, minute: 0),
                    const TimeOfDay(hour: 18, minute: 0),
                    const TimeOfDay(hour: 19, minute: 0),
                    const TimeOfDay(hour: 20, minute: 0),
                  ])
                    PopupMenuItem<TimeOfDay?>(
                      value: t,
                      child: Text(
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 18, color: CueColors.secondary),
                      const SizedBox(width: 10),
                      Text('时间', style: TextStyle(color: CueColors.primary, fontSize: 14)),
                      const Spacer(),
                      Text(
                        _selectedTime != null
                            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                            : '全天',
                        style: TextStyle(
                          color: _selectedTime != null ? CueColors.accent : CueColors.secondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: CueColors.tertiary),
                    ],
                  ),
                ),
              ),

              // 2. Reminder (提醒时间) row
              PopupMenuButton<String>(
                tooltip: '提醒时间',
                offset: const Offset(0, 36),
                color: CueColors.card,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: CueColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (key) {
                  setState(() => _selectedReminder = key);
                },
                itemBuilder: (context) => [
                  for (final key in ['none', 'on_time', 'min_5', 'min_30', 'hour_1', 'day_1'])
                    PopupMenuItem<String>(
                      value: key,
                      child: Text(
                        _reminderLabel(key),
                        style: TextStyle(
                          color: key == _selectedReminder ? CueColors.accent : CueColors.primary,
                        ),
                      ),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_none, size: 18, color: CueColors.secondary),
                      const SizedBox(width: 10),
                      Text('提醒', style: TextStyle(color: CueColors.primary, fontSize: 14)),
                      const Spacer(),
                      Text(
                        _reminderLabel(_selectedReminder),
                        style: TextStyle(
                          color: _selectedReminder != 'none' ? CueColors.accent : CueColors.secondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: CueColors.tertiary),
                    ],
                  ),
                ),
              ),

              // 3. Recurrence (重复) row
              PopupMenuButton<String>(
                tooltip: '重复规则',
                offset: const Offset(0, 36),
                color: CueColors.card,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: CueColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (key) {
                  setState(() => _selectedRecurrence = key);
                },
                itemBuilder: (context) => [
                  for (final key in ['none', 'daily', 'weekly', 'monthly', 'yearly', 'workday'])
                    PopupMenuItem<String>(
                      value: key,
                      child: Text(
                        _recurrenceLabel(key),
                        style: TextStyle(
                          color: key == _selectedRecurrence ? CueColors.accent : CueColors.primary,
                        ),
                      ),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, size: 18, color: CueColors.secondary),
                      const SizedBox(width: 10),
                      Text('重复', style: TextStyle(color: CueColors.primary, fontSize: 14)),
                      const Spacer(),
                      Text(
                        _recurrenceLabel(_selectedRecurrence),
                        style: TextStyle(
                          color: _selectedRecurrence != 'none' ? CueColors.accent : CueColors.secondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: CueColors.tertiary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom action buttons: Clear (清除) & Confirm (确定)
              Row(
                children: [
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
                        Navigator.pop(context, const CueDatePickerResult(cleared: true));
                      },
                      child: const Text('清除'),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        final hour = _selectedTime?.hour ?? 18;
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
                            reminder: _selectedReminder == 'none' ? null : _selectedReminder,
                            recurrence: _selectedRecurrence == 'none' ? null : _selectedRecurrence,
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
