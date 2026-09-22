import 'package:cue/data/desktop_reminder_service.dart';
import 'package:cue/data/task_store.dart';
import 'package:cue/models/cue_task.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class FakeLocalNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  bool initialized = false;
  DidReceiveNotificationResponseCallback? onNotificationResponse;
  final List<PendingNotificationRequest> scheduled = [];
  final List<int> cancelledIds = [];
  bool cancelAllCalled = false;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized = true;
    onNotificationResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async {
    return null;
  }

  @override
  Future<List<PendingNotificationRequest>>
      pendingNotificationRequests() async {
    return List.unmodifiable(scheduled);
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.removeWhere((item) => item.id == id);
    scheduled.add(
      PendingNotificationRequest(
        id,
        title,
        body,
        payload,
      ),
    );
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledIds.add(id);
    scheduled.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
    scheduled.clear();
  }
}

CueTask _createTask({
  required String id,
  required String title,
  DateTime? dueAt,
  String? reminder,
  String note = '',
  DateTime? completedAt,
}) {
  return CueTask(
    id: id,
    title: title,
    note: note,
    priority: 1,
    sortOrder: 100,
    dueAt: dueAt,
    reminder: reminder,
    completedAt: completedAt,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('DesktopReminderService payload parsing', () {
    test('extracts taskId from valid cue-task payload', () {
      expect(
        DesktopReminderService.parseTaskIdFromPayload('cue-task:task-123:1727000000000'),
        'task-123',
      );
      expect(
        DesktopReminderService.parseTaskIdFromPayload('cue-task:abc-def'),
        'abc-def',
      );
    });

    test('returns null for invalid payloads', () {
      expect(DesktopReminderService.parseTaskIdFromPayload(null), isNull);
      expect(DesktopReminderService.parseTaskIdFromPayload(''), isNull);
      expect(
        DesktopReminderService.parseTaskIdFromPayload('other-plugin:123'),
        isNull,
      );
      expect(DesktopReminderService.parseTaskIdFromPayload('cue-task:'), isNull);
    });
  });

  group('DesktopReminderService lifecycle and scheduling', () {
    test('invokes onNotificationTap callback on notification response', () async {
      final fake = FakeLocalNotificationsPlugin();
      String? tappedTaskId;
      final service = DesktopReminderService(
        notifications: fake,
        onNotificationTap: (id) => tappedTaskId = id,
      );

      final store = TaskStore([]);
      service.bind(store);

      // Let debounce run
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(fake.initialized, isTrue);
      expect(fake.onNotificationResponse, isNotNull);

      fake.onNotificationResponse!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'cue-task:task-abc:1727000000000',
        ),
      );

      expect(tappedTaskId, 'task-abc');
      service.dispose();
    });

    test('reconciles and schedules pending reminders from TaskStore', () async {
      final fake = FakeLocalNotificationsPlugin();
      final service = DesktopReminderService(notifications: fake);

      final futureDue = DateTime.now().add(const Duration(hours: 3));
      final taskWithReminder = _createTask(
        id: 'scheduled-1',
        title: 'Complete documentation',
        note: 'High priority task',
        dueAt: futureDue,
        reminder: 'hour_1',
      );

      final store = TaskStore([taskWithReminder]);
      service.bind(store, languageCode: 'zh');

      // Wait for debounce and async reconcile
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows) {
        expect(fake.scheduled, hasLength(1));
        final pending = fake.scheduled.first;
        expect(pending.title, 'Complete documentation');
        expect(pending.body, contains('到期时间：'));
        expect(pending.body, contains('High priority task'));
        expect(pending.payload, startsWith('cue-task:scheduled-1:'));
      }

      await service.clear();
      expect(fake.scheduled, isEmpty);
      service.dispose();
    });
  });
}
