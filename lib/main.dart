import 'package:flutter/material.dart';

import 'controllers/journal_controller.dart';
import 'controllers/settings_controller.dart';
import 'data/meal_repository.dart';
import 'screens/ritual_shell.dart';
import 'theme/ritual_theme.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController();
  await settings.initialize();
  runApp(RitualApp(settings: settings));
}

class RitualApp extends StatefulWidget {
  const RitualApp({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<RitualApp> createState() => _RitualAppState();
}

class _RitualAppState extends State<RitualApp> {
  late final JournalController _controller;

  @override
  void initState() {
    super.initState();
    _controller = JournalController(SqliteMealRepository())..initialize();
  }

  @override
  void dispose() {
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
          child: RitualShell(
            controller: _controller,
            settings: widget.settings,
          ),
        ),
      ),
    );
  }
}
