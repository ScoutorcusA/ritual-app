import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ritual/controllers/settings_controller.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/models/personal_intention.dart';
import 'package:ritual/services/meal_reminder_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('reflection scale choices persist independently', () async {
    final settings = SettingsController();
    await settings.initialize();

    await settings.setHungerScaleEnabled(true);
    await settings.setCravingScaleEnabled(true);

    final reloaded = SettingsController();
    await reloaded.initialize();

    expect(reloaded.hungerScaleEnabled, isTrue);
    expect(reloaded.cravingScaleEnabled, isTrue);
    expect(reloaded.fullnessScaleEnabled, isFalse);
  });

  test('legacy Ritual PIN users migrate fail-closed to device lock', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString('app_lock_mode', 'pin');
    final secureStorage = _FakeSecureStorage();

    final settings = SettingsController(
      preferences: preferences,
      secureStorage: secureStorage,
    );
    await settings.initialize();

    expect(settings.lockMode, AppLockMode.device);
    expect(await preferences.getString('app_lock_mode'), 'device');
    expect(
      secureStorage.deletedKeys,
      containsAll(<String>['ritual_pin_salt', 'ritual_pin_hash']),
    );
  });

  test(
    'streak display can be disabled without changing other settings',
    () async {
      final settings = SettingsController();
      await settings.initialize();
      expect(settings.streaksEnabled, isTrue);

      await settings.setStreaksEnabled(false);

      final reloaded = SettingsController();
      await reloaded.initialize();
      expect(reloaded.streaksEnabled, isFalse);
      expect(reloaded.hungerScaleEnabled, isFalse);
    },
  );

  test(
    'reminders persist only after notification permission is granted',
    () async {
      final deniedScheduler = _FakeReminderScheduler(
        permission: ReminderPermissionStatus.denied,
      );
      final deniedSettings = SettingsController(
        reminderScheduler: deniedScheduler,
      );
      await deniedSettings.initialize();

      expect(
        await deniedSettings.setMealRemindersEnabled(true),
        ReminderToggleResult.permissionDenied,
      );
      expect(deniedSettings.mealRemindersEnabled, isFalse);

      deniedScheduler.permission = ReminderPermissionStatus.granted;
      expect(
        await deniedSettings.setMealRemindersEnabled(true),
        ReminderToggleResult.enabled,
      );
      expect(deniedSettings.mealRemindersEnabled, isTrue);

      final reloaded = SettingsController(reminderScheduler: deniedScheduler);
      await reloaded.initialize();
      expect(reloaded.mealRemindersEnabled, isTrue);
    },
  );

  test(
    'notification service failure is distinct from permission denial',
    () async {
      final settings = SettingsController(
        reminderScheduler: _FakeReminderScheduler(
          permission: ReminderPermissionStatus.unavailable,
        ),
      );
      await settings.initialize();

      expect(
        await settings.setMealRemindersEnabled(true),
        ReminderToggleResult.unavailable,
      );
      expect(settings.mealRemindersEnabled, isFalse);
    },
  );

  test('custom reminder times and onboarding status persist', () async {
    final settings = SettingsController();
    await settings.initialize();

    expect(settings.onboardingComplete, isFalse);
    await settings.setReminderTime(MealReminderKind.breakfast, 8 * 60 + 15);
    await settings.setReminderTime(MealReminderKind.dinner, 20 * 60 + 5);
    await settings.completeOnboarding();

    final reloaded = SettingsController();
    await reloaded.initialize();
    expect(reloaded.reminderSchedule.breakfastMinutes, 8 * 60 + 15);
    expect(reloaded.reminderSchedule.dinnerMinutes, 20 * 60 + 5);
    expect(reloaded.onboardingComplete, isTrue);
  });

  test('personal intention and adaptive reminder choices persist', () async {
    final settings = SettingsController();
    await settings.initialize();

    await settings.setPersonalIntention(PersonalIntention.understandFeelings);
    await settings.dismissAdaptiveReminderSuggestion(
      MealReminderKind.lunch,
      13 * 60 + 55,
    );
    await settings.skipRemindersToday(DateTime(2026, 8, 16, 18));

    final reloaded = SettingsController();
    await reloaded.initialize();
    expect(reloaded.personalIntention, PersonalIntention.understandFeelings);
    expect(
      reloaded.dismissedAdaptiveTime(MealReminderKind.lunch),
      13 * 60 + 55,
    );
    expect(reloaded.remindersSkippedDay, DateTime(2026, 8, 16));
  });
}

class _FakeSecureStorage extends FlutterSecureStorage {
  final List<String> deletedKeys = <String>[];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deletedKeys.add(key);
  }
}

class _FakeReminderScheduler implements MealReminderScheduler {
  _FakeReminderScheduler({required this.permission});

  ReminderPermissionStatus permission;

  @override
  Stream<MealReminderResponse> get responses =>
      const Stream<MealReminderResponse>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<ReminderPermissionStatus> requestPermission() async => permission;

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
