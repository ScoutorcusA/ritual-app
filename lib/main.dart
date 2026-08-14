import 'dart:async';

import 'package:flutter/material.dart';

import 'controllers/journal_controller.dart';
import 'controllers/settings_controller.dart';
import 'data/meal_repository.dart';
import 'screens/ritual_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/meal_reminder_service.dart';
import 'theme/ritual_theme.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final reminders = LocalMealReminderService();
  await reminders.initialize();
  final settings = SettingsController(reminderScheduler: reminders);
  await settings.initialize();
  runApp(RitualApp(settings: settings, reminders: reminders));
}

class RitualApp extends StatefulWidget {
  const RitualApp({super.key, required this.settings, required this.reminders});

  final SettingsController settings;
  final MealReminderScheduler reminders;

  @override
  State<RitualApp> createState() => _RitualAppState();
}

class _RitualAppState extends State<RitualApp> with WidgetsBindingObserver {
  late final JournalController _controller;
  bool _syncingReminders = false;
  bool _reminderSyncQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = JournalController(SqliteMealRepository());
    _controller.addListener(_requestReminderSync);
    widget.settings.addListener(_requestReminderSync);
    unawaited(_controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _requestReminderSync();
  }

  void _requestReminderSync() {
    _reminderSyncQueued = true;
    if (!_syncingReminders) unawaited(_drainReminderSyncs());
  }

  Future<void> _drainReminderSyncs() async {
    _syncingReminders = true;
    try {
      while (_reminderSyncQueued) {
        _reminderSyncQueued = false;
        if (_controller.loading) continue;
        try {
          await widget.reminders.sync(
            entries: _controller.entries,
            enabled: widget.settings.mealRemindersEnabled,
            schedule: widget.settings.reminderSchedule,
          );
        } catch (_) {
          // A notification scheduling failure must never block the journal.
        }
      }
    } finally {
      _syncingReminders = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_requestReminderSync);
    widget.settings.removeListener(_requestReminderSync);
    _controller.dispose();
    widget.settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => MaterialApp(
        title: 'Ritual',
        debugShowCheckedModeBanner: false,
        theme: ritualTheme(),
        darkTheme: ritualDarkTheme(),
        themeMode: widget.settings.themeMode,
        home: AppLockGate(
          settings: widget.settings,
          child: widget.settings.onboardingComplete
              ? RitualShell(controller: _controller, settings: widget.settings)
              : WelcomeScreen(settings: widget.settings),
        ),
      ),
    );
  }
}
