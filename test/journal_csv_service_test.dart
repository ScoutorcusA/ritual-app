import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/models/journal_export.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/services/journal_csv_service.dart';

void main() {
  test('exports selected entries and every non-photo field as CSV', () {
    final range = JournalExportRange(
      start: DateTime(2026, 8, 6),
      end: DateTime(2026, 8, 12),
    );
    final result = JournalCsvService().createReport([
      MealEntry(
        id: 1,
        imagePath: '/private/secret-photo.jpg',
        mealType: MealType.lunch,
        feelings: const ['Happy', 'Satisfied'],
        note: 'Soup, salad\nand tea',
        createdAt: DateTime(2026, 8, 12, 12, 30),
        latitude: 40.1234567,
        longitude: -83.1234567,
        locationLabel: 'Cafe "Ritual"',
        hungerLevel: 4,
        cravingLevel: 2,
        fullnessLevel: 3,
      ),
      MealEntry(
        id: 2,
        imagePath: '/private/old.jpg',
        mealType: MealType.breakfast,
        feelings: const [],
        note: '',
        createdAt: DateTime(2026, 8, 5, 8),
      ),
    ], range: range);
    final csv = utf8.decode(result.bytes);

    expect(result.entryCount, 1);
    expect(result.fileName, 'ritual-journal-2026-08-06-to-2026-08-12.csv');
    expect(csv, startsWith('"Date","Time","Recorded at"'));
    expect(csv, contains('"Hunger before (1-5)"'));
    expect(csv, contains('"Happy; Satisfied"'));
    expect(csv, contains('"Cafe ""Ritual"""'));
    expect(csv, contains('"Soup, salad\nand tea"'));
    expect(csv, contains('40.123457,-83.123457,4,2,3'));
    expect(csv, isNot(contains('secret-photo.jpg')));
    expect(csv, isNot(contains('2026-08-05')));
  });

  test('neutralizes spreadsheet formulas in user-authored text', () {
    final range = JournalExportRange(
      start: DateTime(2026, 8, 12),
      end: DateTime(2026, 8, 12),
    );
    final result = JournalCsvService().createReport([
      MealEntry(
        id: 1,
        imagePath: '/private/photo.jpg',
        mealType: MealType.snack,
        feelings: const ['@unsafe'],
        note: '=HYPERLINK("bad")',
        createdAt: DateTime(2026, 8, 12),
        locationLabel: '+SUM(1,1)',
      ),
    ], range: range);
    final csv = utf8.decode(result.bytes);

    expect(csv, contains('"\'@unsafe"'));
    expect(csv, contains('"\'=HYPERLINK(""bad"")"'));
    expect(csv, contains('"\'+SUM(1,1)"'));
  });
}
