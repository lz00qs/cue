import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_planner.dart';
import 'task_store.dart';

class AppReminderService {
  AppReminderService({
    FlutterLocalNotificationsPlugin? notifications,
    this._planner = const ReminderPlanner(),
    this.onNotificationTap,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _payloadPrefix = 'cue-task:';
  static const _windowsGuid = 'b19ecf99-bf3f-48de-8090-d5354c8c9a83';

  final FlutterLocalNotificationsPlugin _notifications;
  final ReminderPlanner _planner;
  final Map<int, Timer> _linuxTimers = {};

  void Function(String taskId)? onNotificationTap;

  TaskStore? _store;
  Timer? _debounce;
  Future<void>? _initializing;
  Future<void> _operation = Future.value();
  bool _initialized = false;
  bool _disposed = false;
  bool _permissionRequested = false;
  bool _permissionGranted = false;
  String _languageCode = 'en';

  static bool get isSupportedPlatform =>
      !kIsWeb;

  bool get isPermissionGranted => _permissionGranted;

  static String? parseTaskIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
    final rest = payload.substring(_payloadPrefix.length);
    final colonIndex = rest.indexOf(':');
    if (colonIndex == -1) {
      return rest.isNotEmpty ? rest : null;
    }
    final id = rest.substring(0, colonIndex);
    return id.isNotEmpty ? id : null;
  }

  void bind(TaskStore store, {String? languageCode}) {
    if (!isSupportedPlatform || _disposed) return;
    _store?.removeListener(_onStoreChanged);
    _store = store;
    _languageCode = languageCode ?? _languageCode;
    store.addListener(_onStoreChanged);
    _queueReconcile();
  }

  void setLanguageCode(String? languageCode) {
    final next = languageCode ?? 'en';
    if (next == _languageCode) return;
    _languageCode = next;
    _queueReconcile();
  }

  void refresh() => _queueReconcile();

  Future<void> clear() async {
    _store?.removeListener(_onStoreChanged);
    _store = null;
    _debounce?.cancel();
    _cancelLinuxTimers();
    if (!isSupportedPlatform || _disposed) return;
    await _ensureInitialized();
    await _removeCueNotifications();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _store?.removeListener(_onStoreChanged);
    _store = null;
    _debounce?.cancel();
    _cancelLinuxTimers();
  }

  void _onStoreChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _queueReconcile);
  }

  void _queueReconcile() {
    if (_disposed || !isSupportedPlatform) return;
    _operation = _operation.then((_) => _reconcile()).catchError((Object error) {
      debugPrint('Unable to schedule Cue reminders: $error');
    });
  }

  Future<void> _ensureInitialized() {
    if (_initialized) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      final now = DateTime.now();
      tz.setLocalLocation(
        tz.Location('Cue/Local', const [], const [], [
          tz.TimeZone(
            now.timeZoneOffset,
            isDst: now.isUtc == false && now.timeZoneName.contains('DT'),
            abbreviation: now.timeZoneName,
          ),
        ]),
      );
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentBadge: false,
      ),
      linux: LinuxInitializationSettings(defaultActionName: 'Open Cue'),
      windows: WindowsInitializationSettings(
        appName: 'Cue',
        appUserModelId: 'top.hylcreative.Cue',
        guid: _windowsGuid,
      ),
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final taskId = parseTaskIdFromPayload(response.payload);
        if (taskId != null) {
          onNotificationTap?.call(taskId);
        }
      },
    );

    _initialized = true;
    _permissionGranted = defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android;

    try {
      final launchDetails =
          await _notifications.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse != null) {
        final taskId = parseTaskIdFromPayload(
          launchDetails.notificationResponse?.payload,
        );
        if (taskId != null) {
          onNotificationTap?.call(taskId);
        }
      }
    } catch (error) {
      debugPrint('Error checking notification app launch details: $error');
    }
  }

  Future<void> _reconcile() async {
    final store = _store;
    if (store == null || _disposed) return;
    await _ensureInitialized();
    if (_disposed || !identical(store, _store)) return;

    final occurrences = _planner.plan(store.tasks, now: DateTime.now());
    if (occurrences.isEmpty) {
      await _removeCueNotifications();
      _cancelLinuxTimers();
      return;
    }

    if (!await _ensurePermission()) return;
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _scheduleLinuxTimers(occurrences);
      return;
    }
    await _syncSystemSchedule(occurrences);
  }

  Future<bool> requestPermission() async {
    if (!isSupportedPlatform || _disposed) return false;
    await _ensureInitialized();
    _permissionRequested = true;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _permissionGranted = await _notifications
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      _permissionGranted = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission();
      _permissionGranted = granted ?? true;
    } else {
      _permissionGranted = true;
    }

    if (_permissionGranted) {
      _queueReconcile();
    }
    return _permissionGranted;
  }

  Future<bool> _ensurePermission() async {
    if (_permissionGranted) return true;
    if (defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    if (_permissionRequested) return false;
    return requestPermission();
  }

  Future<void> _syncSystemSchedule(
    List<ReminderOccurrence> occurrences,
  ) async {
    final desired = <int, _DesiredNotification>{};
    for (final occurrence in occurrences) {
      var id = occurrence.notificationId;
      while (desired.containsKey(id)) {
        id = id == 0x7fffffff ? 1 : id + 1;
      }
      desired[id] = _notificationFor(id, occurrence);
    }

    final pending = await _notifications.pendingNotificationRequests();
    final current = {
      for (final item in pending)
        if (item.payload?.startsWith(_payloadPrefix) ?? false) item.id: item,
    };

    for (final entry in current.entries) {
      final wanted = desired[entry.key];
      final existing = entry.value;
      if (wanted == null ||
          wanted.payload != existing.payload ||
          wanted.title != existing.title ||
          wanted.body != existing.body) {
        await _notifications.cancel(id: entry.key);
      } else {
        desired.remove(entry.key);
      }
    }

    for (final notification in desired.values) {
      await _notifications.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: _asLocalTz(notification.scheduledAt),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'cue_reminders_channel',
            'Cue Reminders',
            channelDescription: 'Notifications for upcoming tasks in Cue',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFF3A63F3),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
            threadIdentifier: 'cue-reminders',
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
            threadIdentifier: 'cue-reminders',
          ),
          windows: WindowsNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: notification.payload,
      );
    }
  }

  void _scheduleLinuxTimers(List<ReminderOccurrence> occurrences) {
    _cancelLinuxTimers();
    final now = DateTime.now();
    for (final occurrence in occurrences) {
      final notification = _notificationFor(
        occurrence.notificationId,
        occurrence,
      );
      final delay = notification.scheduledAt.difference(now);
      if (delay <= Duration.zero) continue;
      _linuxTimers[notification.id] = Timer(delay, () async {
        _linuxTimers.remove(notification.id);
        await _notifications.show(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            linux: LinuxNotificationDetails(),
          ),
          payload: notification.payload,
        );
        _queueReconcile();
      });
    }
  }

  _DesiredNotification _notificationFor(
    int id,
    ReminderOccurrence occurrence,
  ) {
    return _DesiredNotification(
      id: id,
      title: occurrence.task.title,
      body: null,
      scheduledAt: occurrence.scheduledAt,
      payload:
          '$_payloadPrefix${occurrence.task.id}:'
          '${occurrence.dueAt.toUtc().millisecondsSinceEpoch}',
    );
  }

  tz.TZDateTime _asLocalTz(DateTime value) => tz.TZDateTime(
    tz.local,
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );

  Future<void> _removeCueNotifications() async {
    if (!_initialized || defaultTargetPlatform == TargetPlatform.linux) return;
    final pending = await _notifications.pendingNotificationRequests();
    for (final item in pending) {
      if (item.payload?.startsWith(_payloadPrefix) ?? false) {
        await _notifications.cancel(id: item.id);
      }
    }
  }

  void _cancelLinuxTimers() {
    for (final timer in _linuxTimers.values) {
      timer.cancel();
    }
    _linuxTimers.clear();
  }
}

class _DesiredNotification {
  const _DesiredNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });

  final int id;
  final String title;
  final String? body;
  final DateTime scheduledAt;
  final String payload;
}
