import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/controllers/journal_controller.dart';
import 'package:ritual/controllers/settings_controller.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/screens/settings_screen.dart';
import 'package:ritual/theme/ritual_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_meal_repository.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('settings exposes privacy warnings, reminders, and delete all', (
    tester,
  ) async {
    final journal = JournalController(
      MemoryMealRepository(
        entries: [
          MealEntry(
            id: 1,
            imagePath: '/private/photo.jpg',
            mealType: MealType.breakfast,
            feelings: const ['Happy'],
            note: '',
            createdAt: DateTime(2026, 8, 12),
          ),
        ],
      ),
    );
    await journal.initialize();
    final settings = _FakeSettingsController();

    await tester.pumpWidget(
      MaterialApp(
        theme: ritualTheme(),
        home: SettingsScreen(settings: settings, journal: journal),
      ),
    );

    expect(find.text('RECOMMENDED'), findsOneWidget);
    expect(find.text('Hunger before eating'), findsOneWidget);
    expect(find.text('Craving before eating'), findsOneWidget);
    expect(find.text('Fullness after eating'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Mindful meal reminders'), 300);
    await tester.tap(find.text('Mindful meal reminders'));
    await tester.pump();
    expect(settings.mealRemindersEnabled, isTrue);

    await tester.scrollUntilVisible(find.text('Export journal'), 300);
    expect(find.text('Export clinician PDF'), findsOneWidget);
    await tester.tap(find.text('Export journal'));
    await tester.pumpAndSettle();
    expect(find.text('This ZIP is not encrypted'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Export clinician PDF'), 300);
    await tester.tap(find.text('Export clinician PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Export a private health report?'), findsOneWidget);
    expect(find.textContaining('It is not encrypted'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Delete all journal data'), 300);
    await tester.tap(find.text('Delete all journal data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all journal data?'), findsOneWidget);
    expect(find.textContaining('Your theme, app lock, PIN'), findsOneWidget);

    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();
    expect(journal.entries, isEmpty);
  });
}

class _FakeSettingsController extends SettingsController {
  bool _reminders = false;

  @override
  bool get mealRemindersEnabled => _reminders;

  @override
  Future<bool> setMealRemindersEnabled(bool value) async {
    _reminders = value;
    notifyListeners();
    return true;
  }
}
