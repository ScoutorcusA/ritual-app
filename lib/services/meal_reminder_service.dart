import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../l10n/ritual_i18n.dart';
import '../models/meal_entry.dart';
import '../models/personal_intention.dart';

enum MealReminderKind { breakfast, lunch, dinner, emptyDay }

enum ReminderPermissionStatus { granted, denied, unavailable }

enum ReminderAction { takePhoto, snooze, skipToday }

class MealReminderResponse {
  const MealReminderResponse({required this.kind, required this.action});

  final MealReminderKind kind;
  final ReminderAction action;
}

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
    PersonalIntention intention = PersonalIntention.mindfulPause,
    DateTime? skippedDay,
  }) {
    final reminders = <MealReminder>[];
    for (var offset = 0; offset < days; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (skippedDay != null && _sameDay(skippedDay, day)) continue;
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
        title: tr('A gentle breakfast check-in'),
        body: _bodyFor(intention, MealReminderKind.breakfast),
      );
      _addMealReminder(
        reminders,
        now: now,
        day: day,
        minutes: schedule.lunchMinutes,
        kind: MealReminderKind.lunch,
        type: MealType.lunch,
        loggedTypes: loggedTypes,
        title: tr('A mindful midday pause'),
        body: _bodyFor(intention, MealReminderKind.lunch),
      );
      _addMealReminder(
        reminders,
        now: now,
        day: day,
        minutes: schedule.dinnerMinutes,
        kind: MealReminderKind.dinner,
        type: MealType.dinner,
        loggedTypes: loggedTypes,
        title: tr('A quiet dinner check-in'),
        body: _bodyFor(intention, MealReminderKind.dinner),
      );

      final night = _atMinutes(day, schedule.emptyDayMinutes);
      if (dayEntries.isEmpty && night.isAfter(now)) {
        reminders.add(
          MealReminder(
            id: _idFor(day, MealReminderKind.emptyDay),
            kind: MealReminderKind.emptyDay,
            scheduledAt: night,
            title: tr('One moment from today?'),
            body: _bodyFor(intention, MealReminderKind.emptyDay),
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

  String _bodyFor(PersonalIntention intention, MealReminderKind kind) {
    final meal = switch (kind) {
      MealReminderKind.breakfast => tr('breakfast'),
      MealReminderKind.lunch => tr('lunch'),
      MealReminderKind.dinner => tr('dinner'),
      MealReminderKind.emptyDay => tr('a meal or snack'),
    };
    return switch (intention) {
      PersonalIntention.rememberMeals => tr(
        'If {meal} happened, add it while it is still fresh.',
        values: {'meal': meal},
      ),
      PersonalIntention.noticeHungerFullness => tr(
        'Pause with {meal} and notice one body cue.',
        values: {'meal': meal},
      ),
      PersonalIntention.understandFeelings => tr(
        'Save {meal} and any feeling that stood out.',
        values: {'meal': meal},
      ),
      PersonalIntention.mindfulPause => tr(
        'Take a quiet moment with {meal}, then save what you noticed.',
        values: {'meal': meal},
      ),
      PersonalIntention.noticeJournalPatterns => tr(
        'Save {meal} and any detail you may want to notice again later.',
        values: {'meal': meal},
      ),
    };
  }
}

abstract class MealReminderScheduler {
  Stream<MealReminderResponse> get responses =>
      const Stream<MealReminderResponse>.empty();
  Future<void> initialize();
  Future<ReminderPermissionStatus> requestPermission();
  Future<void> openNotificationSettings();
  Future<void> sync({
    required List<MealEntry> entries,
    required bool enabled,
    ReminderSchedule schedule = const ReminderSchedule(),
    PersonalIntention intention = PersonalIntention.mindfulPause,
    DateTime? skippedDay,
  });
  Future<MealReminderResponse?> takeInitialResponse() async => null;
  Future<void> snooze(
    MealReminderKind kind, {
    PersonalIntention intention = PersonalIntention.mindfulPause,
  }) async {}
  Future<void> cancelAllReminders();
}

class NoopMealReminderScheduler implements MealReminderScheduler {
  const NoopMealReminderScheduler();

  @override
  Stream<MealReminderResponse> get responses =>
      const Stream<MealReminderResponse>.empty();

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
    PersonalIntention intention = PersonalIntention.mindfulPause,
    DateTime? skippedDay,
  }) async {}

  @override
  Future<MealReminderResponse?> takeInitialResponse() async => null;

  @override
  Future<void> snooze(
    MealReminderKind kind, {
    PersonalIntention intention = PersonalIntention.mindfulPause,
  }) async {}

  @override
  Future<void> cancelAllReminders() async {}
}

class LocalMealReminderService implements MealReminderScheduler {
  LocalMealReminderService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _payloadPrefix = 'ritual-meal-reminder:';
  static const _snoozePayloadPrefix = 'ritual-meal-snooze:';
  static const _takePhotoAction = 'take_photo';
  static const _snoozeAction = 'snooze_30';
  static const _skipTodayAction = 'skip_today';
  NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      'ritual_meal_reminders',
      tr('Meal reminders'),
      channelDescription: tr('Gentle reminders to notice and log meals'),
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      actions: [
        AndroidNotificationAction(
          _takePhotoAction,
          tr('Take a photo'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          _snoozeAction,
          tr('Remind me in 30 minutes'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          _skipTodayAction,
          tr('Skip today'),
          showsUserInterface: true,
        ),
      ],
    ),
    iOS: const DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _notifications;
  final MealReminderPlanner _planner = const MealReminderPlanner();
  bool _ready = false;
  bool _timezoneReady = false;
  final StreamController<MealReminderResponse> _responses =
      StreamController<MealReminderResponse>.broadcast();
  MealReminderResponse? _initialResponse;

  @override
  Stream<MealReminderResponse> get responses => _responses.stream;

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
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
      _ready = true;
      final launch = await _notifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _initialResponse = _responseFrom(launch?.notificationResponse);
      }
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
    PersonalIntention intention = PersonalIntention.mindfulPause,
    DateTime? skippedDay,
  }) async {
    if (!_ready) return;
    await _cancelPending(_payloadPrefix);
    if (!enabled) return;
    if (!_timezoneReady) await _initializeTimezone();
    if (!_timezoneReady) return;

    final now = timezone.TZDateTime.now(timezone.local);
    final reminders = _planner.plan(
      entries: entries,
      now: now,
      schedule: schedule,
      intention: intention,
      skippedDay: skippedDay,
    );
    final todaySkipped =
        skippedDay != null &&
        skippedDay.year == now.year &&
        skippedDay.month == now.month &&
        skippedDay.day == now.day;
    final loggedToday = entries
        .where(
          (entry) =>
              entry.createdAt.year == now.year &&
              entry.createdAt.month == now.month &&
              entry.createdAt.day == now.day,
        )
        .map((entry) => entry.mealType)
        .toSet();
    if (todaySkipped) {
      await _cancelPending(_snoozePayloadPrefix);
    } else {
      for (final kind in MealReminderKind.values) {
        final type = _mealTypeFor(kind);
        if (type != null && loggedToday.contains(type)) {
          await _notifications.cancel(id: _snoozeId(kind));
        }
      }
    }
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
    await _cancelPending(_payloadPrefix);
    await _cancelPending(_snoozePayloadPrefix);
  }

  @override
  Future<MealReminderResponse?> takeInitialResponse() async {
    final value = _initialResponse;
    _initialResponse = null;
    return value;
  }

  @override
  Future<void> snooze(
    MealReminderKind kind, {
    PersonalIntention intention = PersonalIntention.mindfulPause,
  }) async {
    if (!_ready) return;
    if (!_timezoneReady) await _initializeTimezone();
    if (!_timezoneReady) return;
    final scheduledAt = timezone.TZDateTime.now(
      timezone.local,
    ).add(const Duration(minutes: 30));
    await _notifications.zonedSchedule(
      id: _snoozeId(kind),
      title: tr('A gentle check-in'),
      body: _planner._bodyFor(intention, kind),
      scheduledDate: scheduledAt,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$_snoozePayloadPrefix${kind.name}',
    );
  }

  Future<void> _cancelPending(String prefix) async {
    final pending = await _notifications.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith(prefix) ?? false) {
        await _notifications.cancel(id: notification.id);
      }
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final value = _responseFrom(response);
    if (value != null) _responses.add(value);
  }

  MealReminderResponse? _responseFrom(NotificationResponse? response) {
    final payload = response?.payload;
    if (payload == null) return null;
    final prefix = payload.startsWith(_payloadPrefix)
        ? _payloadPrefix
        : payload.startsWith(_snoozePayloadPrefix)
        ? _snoozePayloadPrefix
        : null;
    if (prefix == null) return null;
    final kindName = payload.substring(prefix.length);
    final kind = MealReminderKind.values
        .where((value) => value.name == kindName)
        .firstOrNull;
    if (kind == null) return null;
    final action = switch (response?.actionId) {
      _snoozeAction => ReminderAction.snooze,
      _skipTodayAction => ReminderAction.skipToday,
      _ => ReminderAction.takePhoto,
    };
    return MealReminderResponse(kind: kind, action: action);
  }

  int _snoozeId(MealReminderKind kind) => 770000 + kind.index;

  MealType? _mealTypeFor(MealReminderKind kind) => switch (kind) {
    MealReminderKind.breakfast => MealType.breakfast,
    MealReminderKind.lunch => MealType.lunch,
    MealReminderKind.dinner => MealType.dinner,
    MealReminderKind.emptyDay => null,
  };
}
