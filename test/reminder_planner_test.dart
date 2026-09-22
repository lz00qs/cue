import 'package:cue/data/reminder_planner.dart';
import 'package:cue/models/cue_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = ReminderPlanner();

  test('applies reminder offsets and skips inactive tasks', () {
    final now = DateTime(2026, 9, 22, 9);
    final due = DateTime(2026, 9, 22, 10);
    final active = _task('active', due, reminder: 'min_30');
    final completed = _task(
      'completed',
      due,
      reminder: 'on_time',
      completedAt: now,
    );
    final noReminder = _task('none', due);

    final result = planner.plan(
      [active, completed, noReminder],
      now: now,
    );

    expect(result, hasLength(1));
    expect(result.single.task.id, 'active');
    expect(result.single.scheduledAt, DateTime(2026, 9, 22, 9, 30));
  });

  test('does not emit reminders whose alert time has already passed', () {
    final result = planner.plan(
      [
        _task(
          'past-alert',
          DateTime(2026, 9, 22, 10),
          reminder: 'hour_1',
        ),
      ],
      now: DateTime(2026, 9, 22, 9, 30),
    );

    expect(result, isEmpty);
  });

  test('plans daily recurrences inside the rolling window', () {
    const shortPlanner = ReminderPlanner(horizon: Duration(days: 2));
    final result = shortPlanner.plan(
      [
        _task(
          'daily',
          DateTime(2026, 9, 20, 10),
          reminder: 'min_30',
          recurrence: 'daily',
        ),
      ],
      now: DateTime(2026, 9, 22, 8),
    );

    expect(
      result.map((item) => item.dueAt),
      [
        DateTime(2026, 9, 22, 10),
        DateTime(2026, 9, 23, 10),
        DateTime(2026, 9, 24, 10),
        DateTime(2026, 9, 25, 10),
      ],
    );
  });

  test('workday recurrence excludes weekends after its first day', () {
    final result = planner.plan(
      [
        _task(
          'workday',
          DateTime(2026, 9, 18, 9),
          reminder: 'on_time',
          recurrence: 'workday',
        ),
      ],
      now: DateTime(2026, 9, 18, 9, 1),
    );

    expect(result.first.dueAt, DateTime(2026, 9, 21, 9));
    expect(
      result.take(5).map((item) => item.dueAt.weekday),
      everyElement(inInclusiveRange(DateTime.monday, DateTime.friday)),
    );
  });

  test('keeps the next sparse recurrence beyond the rolling window', () {
    const shortPlanner = ReminderPlanner(horizon: Duration(days: 30));
    final result = shortPlanner.plan(
      [
        _task(
          'annual',
          DateTime(2020, 12, 25, 9),
          reminder: 'day_1',
          recurrence: 'yearly',
        ),
      ],
      now: DateTime(2026, 9, 22),
    );

    expect(result, hasLength(1));
    expect(result.single.dueAt, DateTime(2026, 12, 25, 9));
    expect(result.single.scheduledAt, DateTime(2026, 12, 24, 9));
  });

  test('notification IDs are stable and occurrence-specific', () {
    final task = _task(
      'stable',
      DateTime(2026, 9, 23, 10),
      reminder: 'on_time',
    );
    final first = planner.plan([task], now: DateTime(2026, 9, 22)).single;
    final again = planner.plan([task], now: DateTime(2026, 9, 22)).single;
    final other = ReminderOccurrence(
      task: task,
      dueAt: DateTime(2026, 9, 24, 10),
      scheduledAt: DateTime(2026, 9, 24, 10),
    );

    expect(first.notificationId, again.notificationId);
    expect(first.notificationId, isNot(other.notificationId));
    expect(first.notificationId, greaterThan(0));
  });
}

CueTask _task(
  String id,
  DateTime dueAt, {
  String? reminder,
  String? recurrence,
  DateTime? completedAt,
}) {
  return CueTask(
    id: id,
    title: id,
    note: '',
    priority: 2,
    sortOrder: 1000,
    dueAt: dueAt,
    reminder: reminder,
    recurrence: recurrence,
    completedAt: completedAt,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
}
