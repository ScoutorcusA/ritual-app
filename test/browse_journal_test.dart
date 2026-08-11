import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:ritual/controllers/journal_controller.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/screens/ritual_shell.dart';
import 'package:ritual/theme/ritual_theme.dart';

import 'support/memory_meal_repository.dart';

void main() {
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
    expect(find.text('Calm and happy'), findsOneWidget);

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
