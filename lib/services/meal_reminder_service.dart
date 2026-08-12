import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/meal_entry.dart';

enum MealReminderKind { breakfast, lunch, dinner, emptyDay }

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
        hour: 9,
        minute: 30,
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
        hour: 13,
        minute: 30,
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
        hour: 19,
        minute: 30,
        kind: MealReminderKind.dinner,
        type: MealType.dinner,
        loggedTypes: loggedTypes,
        title: 'A quiet dinner check-in',
        body: 'Notice what dinner felt like, without scoring or judging it.',
      );

      final night = DateTime(day.year, day.month, day.day, 21, 30);
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
    required int hour,
    required int minute,
    required MealReminderKind kind,
    required MealType type,
    required Set<MealType> loggedTypes,
    required String title,
    required String body,
  }) {
    final scheduledAt = DateTime(day.year, day.month, day.day, hour, minute);
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
}

abstract class MealReminderScheduler {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> sync({required List<MealEntry> entries, required bool enabled});
  Future<void> cancelAllReminders();
}

class NoopMealReminderScheduler implements MealReminderScheduler {
  const NoopMealReminderScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> sync({
    required List<MealEntry> entries,
    required bool enabled,
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

  @override
  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_launcher'),
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

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        ) ??
        true;
  }

  @override
  Future<void> sync({
    required List<MealEntry> entries,
    required bool enabled,
  }) async {
    if (!_ready) return;
    await cancelAllReminders();
    if (!enabled) return;

    final now = timezone.TZDateTime.now(timezone.local);
    final reminders = _planner.plan(entries: entries, now: now);
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
