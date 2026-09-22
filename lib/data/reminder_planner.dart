import '../models/cue_task.dart';

class ReminderOccurrence {
  const ReminderOccurrence({
    required this.task,
    required this.dueAt,
    required this.scheduledAt,
  });

  final CueTask task;
  final DateTime dueAt;
  final DateTime scheduledAt;

  int get notificationId {
    // FNV-1a gives us a stable, non-negative 31-bit ID across app launches.
    final source = '${task.id}:${dueAt.toUtc().millisecondsSinceEpoch}';
    var hash = 0x811c9dc5;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final id = hash & 0x7fffffff;
    return id == 0 ? 1 : id;
  }
}

class ReminderPlanner {
  const ReminderPlanner({
    this.horizon = const Duration(days: 90),
    this.maxOccurrences = 60,
  });

  final Duration horizon;
  final int maxOccurrences;

  static const Map<String, Duration> reminderOffsets = {
    'on_time': Duration.zero,
    'min_5': Duration(minutes: 5),
    'min_30': Duration(minutes: 30),
    'hour_1': Duration(hours: 1),
    'day_1': Duration(days: 1),
  };

  List<ReminderOccurrence> plan(
    Iterable<CueTask> tasks, {
    required DateTime now,
  }) {
    final occurrences = <ReminderOccurrence>[];
    for (final task in tasks) {
      occurrences.addAll(_forTask(task, now));
    }
    occurrences.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (occurrences.length <= maxOccurrences) return occurrences;
    return occurrences.sublist(0, maxOccurrences);
  }

  List<ReminderOccurrence> _forTask(CueTask task, DateTime now) {
    final dueAt = task.dueAt;
    final offset = reminderOffsets[task.reminder];
    if (task.deletedAt != null ||
        task.isCompleted ||
        dueAt == null ||
        offset == null) {
      return const [];
    }

    final recurrence = task.recurrence;
    if (recurrence == null || recurrence == 'none') {
      final scheduledAt = dueAt.subtract(offset);
      return scheduledAt.isAfter(now)
          ? [
              ReminderOccurrence(
                task: task,
                dueAt: dueAt,
                scheduledAt: scheduledAt,
              ),
            ]
          : const [];
    }

    final result = <ReminderOccurrence>[];
    final horizonEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).add(horizon);
    final scanEnd = now.add(const Duration(days: 366 * 5));
    var day = _dateOnly(now);
    final firstDay = _dateOnly(dueAt);
    if (day.isBefore(firstDay)) day = firstDay;

    // If the recurrence starts more than five years out, its first occurrence
    // is still worth scheduling even though it is outside the rolling window.
    if (day.isAfter(scanEnd)) {
      final scheduledAt = dueAt.subtract(offset);
      return scheduledAt.isAfter(now)
          ? [
              ReminderOccurrence(
                task: task,
                dueAt: dueAt,
                scheduledAt: scheduledAt,
              ),
            ]
          : const [];
    }

    while (!day.isAfter(scanEnd)) {
      if (_matches(task, day)) {
        final occurrenceDueAt = DateTime(
          day.year,
          day.month,
          day.day,
          dueAt.hour,
          dueAt.minute,
          dueAt.second,
          dueAt.millisecond,
          dueAt.microsecond,
        );
        final scheduledAt = occurrenceDueAt.subtract(offset);
        if (scheduledAt.isAfter(now)) {
          result.add(
            ReminderOccurrence(
              task: task,
              dueAt: occurrenceDueAt,
              scheduledAt: scheduledAt,
            ),
          );
          // Keep a dense rolling window, plus the first sparse occurrence
          // beyond it (for example next year's annual reminder).
          if (occurrenceDueAt.isAfter(horizonEnd)) break;
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return result;
  }

  static bool _matches(CueTask task, DateTime day) {
    final first = _dateOnly(task.dueAt!);
    final target = _dateOnly(day);
    if (target.isBefore(first)) return false;
    if (_sameDay(first, target)) return true;

    return switch (task.recurrence) {
      'daily' => true,
      'weekly' =>
        DateTime.utc(target.year, target.month, target.day)
                    .difference(
                      DateTime.utc(first.year, first.month, first.day),
                    )
                    .inDays %
                7 ==
            0,
      'monthly' => target.day == first.day,
      'yearly' => target.month == first.month && target.day == first.day,
      'workday' =>
        target.weekday >= DateTime.monday &&
            target.weekday <= DateTime.friday,
      _ => false,
    };
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
