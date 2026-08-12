import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/controllers/settings_controller.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/services/meal_reminder_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
}

class _FakeReminderScheduler implements MealReminderScheduler {
  _FakeReminderScheduler({required this.permission});

  ReminderPermissionStatus permission;

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
  }) async {}

  @override
  Future<void> cancelAllReminders() async {}
}
