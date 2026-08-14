import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/meal_entry.dart';

enum MealReminderKind { breakfast, lunch, dinner, emptyDay }

enum ReminderPermissionStatus { granted, denied, unavailable }

class ReminderSchedule {
  const ReminderSchedule({
    this.breakfastMinutes = 9 * 60 + 30,
    this.lunchMinutes = 13 * 60 + 30,
    this.dinnerMinutes = 19 * 60 + 30,
    this.emptyDayMinutes = 21 * 60 + 30,
  });

  final int breakfastMinutes;
  final int lunchMinutes;
  final int dinnerMinutes;
  final int emptyDayMinutes;
}

class MealReminder {
  const MealReminder({
    required this.id,
    required this.kind,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  final int id;
  final MealReminderKind kind;
  final DateTime scheduledAt;
  final String title;
  final String body;
}

class MealReminderPlanner {
  const MealReminderPlanner();

  static const scheduleDays = 14;

  List<MealReminder> plan({
    required List<MealEntry> entries,
    required DateTime now,
    int days = scheduleDays,
    ReminderSchedule schedule = const ReminderSchedule(),
  }) {
    final reminders = <MealReminder>[];
    for (var offset = 0; offset < days; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final dayEntries = entries
          .where((entry) => _sameDay(entry.createdAt, day))
          .toList(growable: false);
      final loggedTypes = dayEntries.map((entry) => entry.mealType).toSet();

      _addMealReminder(
        reminders,
        now: now,
        day: day,
        minutes: schedule.breakfastMinutes,
        kind: MealReminderKind.breakfast,
        type: MealType.breakfast,
        loggedTypes: loggedTypes,
        title: 'A gentle breakfast check-in',
        body: 'If you’ve eaten, take a moment to notice and add it to Ritual.',
      );
      _addMealReminder(
        reminders,
        now: now,
        day: day,
        minutes: schedule.lunchMinutes,
        kind: MealReminderKind.lunch,
        type: MealType.lunch,
        loggedTypes: loggedTypes,
        title: 'A mindful midday pause',
        body: 'If lunch happened, save one small moment from it.',
      );
      _addMealReminder(
        reminders,
        now: now,
        day: day,
        minutes: schedule.dinnerMinutes,
        kind: MealReminderKind.dinner,
        type: MealType.dinner,
        loggedTypes: loggedTypes,
        title: 'A quiet dinner check-in',
        body: 'Notice what dinner felt like, without scoring or judging it.',
      );

      final night = _atMinutes(day, schedule.emptyDayMinutes);
      if (dayEntries.isEmpty && night.isAfter(now)) {
        reminders.add(
          MealReminder(
            id: _idFor(day, MealReminderKind.emptyDay),
            kind: MealReminderKind.emptyDay,
            scheduledAt: night,
            title: 'One moment from today?',
            body:
                'Nothing is logged yet. Add a meal if you’d like to remember the day.',
          ),
        );
      }
    }
    return reminders;
  }

  void _addMealReminder(
    List<MealReminder> reminders, {
    required DateTime now,
    required DateTime day,
    required int minutes,
    required MealReminderKind kind,
    required MealType type,
    required Set<MealType> loggedTypes,
    required String title,
    required String body,
  }) {
    final scheduledAt = _atMinutes(day, minutes);
    if (loggedTypes.contains(type) || !scheduledAt.isAfter(now)) return;
    reminders.add(
      MealReminder(
        id: _idFor(day, kind),
        kind: kind,
        scheduledAt: scheduledAt,
        title: title,
        body: body,
      ),
    );
  }

  int _idFor(DateTime day, MealReminderKind kind) {
    final dateId = day.year * 10000 + day.month * 100 + day.day;
    return dateId * 10 + kind.index;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _atMinutes(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
}

abstract class MealReminderScheduler {
  Future<void> initialize();
  Future<ReminderPermissionStatus> requestPermission();
  Future<void> openNotificationSettings();
  Future<void> sync({
    required List<MealEntry> entries,
    required bool enabled,
    ReminderSchedule schedule = const ReminderSchedule(),
  });
  Future<void> cancelAllReminders();
}

class NoopMealReminderScheduler implements MealReminderScheduler {
  const NoopMealReminderScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<ReminderPermissionStatus> requestPermission() async =>
      ReminderPermissionStatus.unavailable;

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> sync({
    required List<MealEntry> entries,
    required bool enabled,
    ReminderSchedule schedule = const ReminderSchedule(),
  }) async {}

  @override
  Future<void> cancelAllReminders() async {}
}

class LocalMealReminderService implements MealReminderScheduler {
  LocalMealReminderService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _payloadPrefix = 'ritual-meal-reminder:';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'ritual_meal_reminders',
      'Meal reminders',
      channelDescription: 'Gentle reminders to notice and log meals',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _notifications;
  final MealReminderPlanner _planner = const MealReminderPlanner();
  bool _ready = false;
  bool _timezoneReady = false;

  @override
  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    await _initializeTimezone();
    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_ritual'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> _initializeTimezone() async {
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
      _timezoneReady = true;
    } catch (_) {
      _timezoneReady = false;
    }
  }

  @override
  Future<ReminderPermissionStatus> requestPermission() async {
    if (!_ready) return ReminderPermissionStatus.unavailable;
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        if (await android.areNotificationsEnabled() ?? false) {
          return ReminderPermissionStatus.granted;
        }
        final granted = await android.requestNotificationsPermission() ?? false;
        return granted
            ? ReminderPermissionStatus.granted
            : ReminderPermissionStatus.denied;
      }
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: false,
        sound: true,
      );
      return granted == false
          ? ReminderPermissionStatus.denied
          : ReminderPermissionStatus.granted;
    } catch (_) {
      return ReminderPermissionStatus.unavailable;
    }
  }

  @override
  Future<void> openNotificationSettings() async {
    if (!_ready) return;
    await _notifications.openAppNotificationSettings();
  }

  @override
  Future<void> sync({
    required List<MealEntry> entries,
    required bool enabled,
    ReminderSchedule schedule = const ReminderSchedule(),
  }) async {
    if (!_ready) return;
    await cancelAllReminders();
    if (!enabled) return;
    if (!_timezoneReady) await _initializeTimezone();
    if (!_timezoneReady) return;

    final now = timezone.TZDateTime.now(timezone.local);
    final reminders = _planner.plan(
      entries: entries,
      now: now,
      schedule: schedule,
    );
    for (final reminder in reminders) {
      final value = reminder.scheduledAt;
      final scheduledAt = timezone.TZDateTime(
        timezone.local,
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
      );
      await _notifications.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: scheduledAt,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$_payloadPrefix${reminder.kind.name}',
      );
    }
  }

  @override
  Future<void> cancelAllReminders() async {
    if (!_ready) return;
    final pending = await _notifications.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith(_payloadPrefix) ?? false) {
        await _notifications.cancel(id: notification.id);
      }
    }
  }
}
