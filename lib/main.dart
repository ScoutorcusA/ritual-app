import 'package:flutter/material.dart';

import 'controllers/journal_controller.dart';
import 'data/meal_repository.dart';
import 'screens/ritual_shell.dart';
import 'theme/ritual_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RitualApp());
}

class RitualApp extends StatefulWidget {
  const RitualApp({super.key});

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ritual',
      debugShowCheckedModeBanner: false,
      theme: ritualTheme(),
      home: RitualShell(controller: _controller),
    );
  }
}
