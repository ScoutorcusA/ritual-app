import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/ritual_i18n.dart';
import '../models/personal_intention.dart';
import '../services/meal_reminder_service.dart';

enum AppLockMode { off, device }

enum ReminderToggleResult { enabled, disabled, permissionDenied, unavailable }

class SettingsController extends ChangeNotifier {
  SettingsController({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuthentication,
    MealReminderScheduler? reminderScheduler,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _reminderScheduler =
           reminderScheduler ?? const NoopMealReminderScheduler();

  static const _themeKey = 'theme_mode';
  static const _lockModeKey = 'app_lock_mode';
  static const _pinSaltKey = 'ritual_pin_salt';
  static const _pinHashKey = 'ritual_pin_hash';
  static const _mealRemindersKey = 'meal_reminders_enabled';
  static const _streaksKey = 'streaks_enabled';
  static const _hungerScaleKey = 'hunger_scale_enabled';
  static const _fullnessScaleKey = 'fullness_scale_enabled';
  static const _cravingScaleKey = 'craving_scale_enabled';
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _breakfastReminderKey = 'breakfast_reminder_minutes';
  static const _lunchReminderKey = 'lunch_reminder_minutes';
  static const _dinnerReminderKey = 'dinner_reminder_minutes';
  static const _emptyDayReminderKey = 'empty_day_reminder_minutes';
  static const _personalIntentionKey = 'personal_intention';
  static const _skippedReminderDayKey = 'skipped_reminder_day';
  static const _adaptiveDismissedPrefix = 'adaptive_reminder_dismissed_';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuthentication;
  final MealReminderScheduler _reminderScheduler;

  ThemeMode _themeMode = ThemeMode.system;
  AppLockMode _lockMode = AppLockMode.off;
  bool _mealRemindersEnabled = false;
  bool _streaksEnabled = true;
  bool _hungerScaleEnabled = false;
  bool _fullnessScaleEnabled = false;
  bool _cravingScaleEnabled = false;
  bool _onboardingComplete = false;
  ReminderSchedule _reminderSchedule = const ReminderSchedule();
  PersonalIntention _personalIntention = PersonalIntention.mindfulPause;
  DateTime? _remindersSkippedDay;
  final Map<MealReminderKind, int> _dismissedAdaptiveTimes = {};

  ThemeMode get themeMode => _themeMode;
  AppLockMode get lockMode => _lockMode;
  bool get lockEnabled => _lockMode != AppLockMode.off;
  bool get mealRemindersEnabled => _mealRemindersEnabled;
  bool get streaksEnabled => _streaksEnabled;
  bool get hungerScaleEnabled => _hungerScaleEnabled;
  bool get fullnessScaleEnabled => _fullnessScaleEnabled;
  bool get cravingScaleEnabled => _cravingScaleEnabled;
  bool get onboardingComplete => _onboardingComplete;
  ReminderSchedule get reminderSchedule => _reminderSchedule;
  PersonalIntention get personalIntention => _personalIntention;
  DateTime? get remindersSkippedDay => _remindersSkippedDay;

  Future<void> initialize() async {
    final storedTheme = await _preferences.getString(_themeKey);
    _themeMode =
        ThemeMode.values
            .where((mode) => mode.name == storedTheme)
            .firstOrNull ??
        ThemeMode.system;
    final storedLock = await _preferences.getString(_lockModeKey);
    if (storedLock == 'pin') {
      // Earlier versions offered a separate four-digit Ritual PIN. Migrate
      // those users fail-closed to Android device authentication instead of
      // silently removing their journal protection.
      _lockMode = AppLockMode.device;
      await _preferences.setString(_lockModeKey, _lockMode.name);
      await _deleteLegacyPinMaterial();
    } else {
      _lockMode =
          AppLockMode.values
              .where((mode) => mode.name == storedLock)
              .firstOrNull ??
          AppLockMode.off;
    }
    _mealRemindersEnabled =
        await _preferences.getBool(_mealRemindersKey) ?? false;
    _streaksEnabled = await _preferences.getBool(_streaksKey) ?? true;
    _hungerScaleEnabled = await _preferences.getBool(_hungerScaleKey) ?? false;
    _fullnessScaleEnabled =
        await _preferences.getBool(_fullnessScaleKey) ?? false;
    _cravingScaleEnabled =
        await _preferences.getBool(_cravingScaleKey) ?? false;
    _onboardingComplete =
        await _preferences.getBool(_onboardingCompleteKey) ?? false;
    _reminderSchedule = ReminderSchedule(
      breakfastMinutes:
          await _preferences.getInt(_breakfastReminderKey) ?? 9 * 60 + 30,
      lunchMinutes:
          await _preferences.getInt(_lunchReminderKey) ?? 13 * 60 + 30,
      dinnerMinutes:
          await _preferences.getInt(_dinnerReminderKey) ?? 19 * 60 + 30,
      emptyDayMinutes:
          await _preferences.getInt(_emptyDayReminderKey) ?? 21 * 60 + 30,
    );
    final storedIntention = await _preferences.getString(_personalIntentionKey);
    final migratedIntention = storedIntention == 'prepareForClinician'
        ? PersonalIntention.noticeJournalPatterns.name
        : storedIntention;
    _personalIntention =
        PersonalIntention.values
            .where((value) => value.name == migratedIntention)
            .firstOrNull ??
        PersonalIntention.mindfulPause;
    if (storedIntention != null && storedIntention != migratedIntention) {
      await _preferences.setString(_personalIntentionKey, migratedIntention!);
    }
    _remindersSkippedDay = _parseDay(
      await _preferences.getString(_skippedReminderDayKey),
    );
    for (final kind in MealReminderKind.values) {
      final value = await _preferences.getInt(
        '$_adaptiveDismissedPrefix${kind.name}',
      );
      if (value != null) _dismissedAdaptiveTimes[kind] = value;
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    await _preferences.setString(_themeKey, value.name);
  }

  Future<bool> deviceAuthenticationSupported() =>
      _localAuthentication.isDeviceSupported();

  Future<bool> authenticateDevice() async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: tr('Unlock your private Ritual journal'),
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> enableDeviceLock() async {
    if (!await deviceAuthenticationSupported()) return false;
    if (!await authenticateDevice()) return false;
    await _secureStorage.delete(key: _pinSaltKey);
    await _secureStorage.delete(key: _pinHashKey);
    _lockMode = AppLockMode.device;
    notifyListeners();
    await _preferences.setString(_lockModeKey, _lockMode.name);
    return true;
  }

  Future<void> disableLock() async {
    _lockMode = AppLockMode.off;
    notifyListeners();
    await _preferences.setString(_lockModeKey, _lockMode.name);
    await _secureStorage.delete(key: _pinSaltKey);
    await _secureStorage.delete(key: _pinHashKey);
  }

  Future<ReminderToggleResult> setMealRemindersEnabled(bool value) async {
    if (_mealRemindersEnabled == value) {
      return value
          ? ReminderToggleResult.enabled
          : ReminderToggleResult.disabled;
    }
    if (value) {
      final permission = await _reminderScheduler.requestPermission();
      if (permission == ReminderPermissionStatus.denied) {
        return ReminderToggleResult.permissionDenied;
      }
      if (permission == ReminderPermissionStatus.unavailable) {
        return ReminderToggleResult.unavailable;
      }
    }
    _mealRemindersEnabled = value;
    notifyListeners();
    await _preferences.setBool(_mealRemindersKey, value);
    if (!value) await _reminderScheduler.cancelAllReminders();
    return value ? ReminderToggleResult.enabled : ReminderToggleResult.disabled;
  }

  Future<void> openNotificationSettings() =>
      _reminderScheduler.openNotificationSettings();

  Future<void> setReminderTime(MealReminderKind kind, int minutes) async {
    if (minutes < 0 || minutes >= 24 * 60) {
      throw FormatException(tr('Reminder time must be within one day.'));
    }
    final current = _reminderSchedule;
    _reminderSchedule = ReminderSchedule(
      breakfastMinutes: kind == MealReminderKind.breakfast
          ? minutes
          : current.breakfastMinutes,
      lunchMinutes: kind == MealReminderKind.lunch
          ? minutes
          : current.lunchMinutes,
      dinnerMinutes: kind == MealReminderKind.dinner
          ? minutes
          : current.dinnerMinutes,
      emptyDayMinutes: kind == MealReminderKind.emptyDay
          ? minutes
          : current.emptyDayMinutes,
    );
    notifyListeners();
    final key = switch (kind) {
      MealReminderKind.breakfast => _breakfastReminderKey,
      MealReminderKind.lunch => _lunchReminderKey,
      MealReminderKind.dinner => _dinnerReminderKey,
      MealReminderKind.emptyDay => _emptyDayReminderKey,
    };
    await _preferences.setInt(key, minutes);
    _dismissedAdaptiveTimes.remove(kind);
    await _preferences.remove('$_adaptiveDismissedPrefix${kind.name}');
  }

  Future<void> setPersonalIntention(PersonalIntention value) async {
    if (_personalIntention == value) return;
    _personalIntention = value;
    notifyListeners();
    await _preferences.setString(_personalIntentionKey, value.name);
  }

  int? dismissedAdaptiveTime(MealReminderKind kind) =>
      _dismissedAdaptiveTimes[kind];

  Future<void> dismissAdaptiveReminderSuggestion(
    MealReminderKind kind,
    int suggestedMinutes,
  ) async {
    _dismissedAdaptiveTimes[kind] = suggestedMinutes;
    await _preferences.setInt(
      '$_adaptiveDismissedPrefix${kind.name}',
      suggestedMinutes,
    );
  }

  Future<void> skipRemindersToday([DateTime? now]) async {
    final value = now ?? DateTime.now();
    _remindersSkippedDay = DateTime(value.year, value.month, value.day);
    notifyListeners();
    await _preferences.setString(
      _skippedReminderDayKey,
      _formatDay(_remindersSkippedDay!),
    );
  }

  Future<void> completeOnboarding() async {
    if (_onboardingComplete) return;
    _onboardingComplete = true;
    notifyListeners();
    await _preferences.setBool(_onboardingCompleteKey, true);
  }

  Future<void> restartOnboarding() async {
    _onboardingComplete = false;
    notifyListeners();
    await _preferences.setBool(_onboardingCompleteKey, false);
  }

  Future<void> setStreaksEnabled(bool value) async {
    if (_streaksEnabled == value) return;
    _streaksEnabled = value;
    notifyListeners();
    await _preferences.setBool(_streaksKey, value);
  }

  Future<void> setHungerScaleEnabled(bool value) async {
    if (_hungerScaleEnabled == value) return;
    _hungerScaleEnabled = value;
    notifyListeners();
    await _preferences.setBool(_hungerScaleKey, value);
  }

  Future<void> setFullnessScaleEnabled(bool value) async {
    if (_fullnessScaleEnabled == value) return;
    _fullnessScaleEnabled = value;
    notifyListeners();
    await _preferences.setBool(_fullnessScaleKey, value);
  }

  Future<void> setCravingScaleEnabled(bool value) async {
    if (_cravingScaleEnabled == value) return;
    _cravingScaleEnabled = value;
    notifyListeners();
    await _preferences.setBool(_cravingScaleKey, value);
  }

  Future<void> _deleteLegacyPinMaterial() async {
    await _secureStorage.delete(key: _pinSaltKey);
    await _secureStorage.delete(key: _pinHashKey);
  }

  static String _formatDay(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDay(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }
}
