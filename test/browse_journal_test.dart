import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:ritual/controllers/journal_controller.dart';
import 'package:ritual/controllers/settings_controller.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/screens/meal_editor_screen.dart';
import 'package:ritual/screens/ritual_shell.dart';
import 'package:ritual/theme/ritual_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_meal_repository.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('journal bundles a day and opens its daily journal', (
    tester,
  ) async {
    final now = DateTime.now();
    final controller = JournalController(
      MemoryMealRepository(
        entries: [
          _entry(1, now, MealType.breakfast, const ['Calm']),
          _entry(
            2,
            now.subtract(const Duration(hours: 1)),
            MealType.lunch,
            const ['Happy'],
          ),
        ],
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: ritualTheme(),
        home: RitualShell(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('EEEE, MMMM d').format(now)), findsOneWidget);
    expect(find.text('2 moments'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.text('Calm and happy'), findsOneWidget);
    expect(find.text('Total moments'), findsOneWidget);
    expect(find.text('Per logged day'), findsOneWidget);
    expect(find.text('Typical gap'), findsOneWidget);

    await tester.tap(find.text(DateFormat('EEEE, MMMM d').format(now)));
    await tester.pumpAndSettle();
    expect(find.text('Breakfast'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Lunch'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('journal hides streak progress when streaks are disabled', (
    tester,
  ) async {
    final controller = JournalController(MemoryMealRepository());
    await controller.initialize();
    final settings = SettingsController();
    await settings.initialize();
    await settings.setStreaksEnabled(false);

    await tester.pumpWidget(
      MaterialApp(
        theme: ritualTheme(),
        home: RitualShell(controller: controller, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Begin with one mindful meal'), findsNothing);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    expect(find.text('Notice what nourishes you'), findsOneWidget);
  });

  testWidgets('Browse exposes gallery and calendar with dark-safe filters', (
    tester,
  ) async {
    final now = DateTime.now();
    final controller = JournalController(
      MemoryMealRepository(
        entries: [
          _entry(1, now, MealType.breakfast, const ['Calm']),
        ],
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: ritualTheme(),
        darkTheme: ritualDarkTheme(),
        themeMode: ThemeMode.dark,
        home: RitualShell(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    final allChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'All'),
    );
    expect(allChip.selectedColor, const Color(0xFF3B3A34));
    expect(allChip.labelStyle?.color, RitualColors.paper);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text(DateFormat.yMMMM().format(now)), findsOneWidget);
    final day = find.byKey(
      ValueKey('calendar-day-${now.year}-${now.month}-${now.day}'),
    );
    await tester.ensureVisible(day);
    await tester.pumpAndSettle();
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(find.text('Breakfast'), findsOneWidget);
  });

  testWidgets('new-entry labels stay readable in dark mode', (tester) async {
    final controller = JournalController(MemoryMealRepository());
    await controller.initialize();
    final darkTheme = ritualDarkTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: ritualTheme(),
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: MealEditorScreen(
          controller: controller,
          imagePath: '/tmp/new-entry.jpg',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final mealChips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(mealChips, hasLength(MealType.values.length));
    for (final chip in mealChips) {
      expect(
        chip.labelStyle?.color,
        chip.selected ? RitualColors.paper : darkTheme.colorScheme.onSurface,
      );
    }
    await tester.scrollUntilVisible(
      find.text('Happy'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    final feelingChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Happy'),
    );
    expect(feelingChip.labelStyle?.color, darkTheme.colorScheme.onSurface);
  });
}

MealEntry _entry(
  int id,
  DateTime createdAt,
  MealType type,
  List<String> feelings,
) => MealEntry(
  id: id,
  imagePath: '/tmp/$id.jpg',
  mealType: type,
  feelings: feelings,
  note: '',
  createdAt: createdAt,
);
