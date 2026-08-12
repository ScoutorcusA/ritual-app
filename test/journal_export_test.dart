import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/models/journal_export.dart';
import 'package:ritual/models/meal_entry.dart';

void main() {
  test('last seven days includes both complete boundary days', () {
    final range = JournalExportRange.lastDays(
      today: DateTime(2026, 8, 12, 17),
      days: 7,
    );
    final entries = [
      _entry(1, DateTime(2026, 8, 5, 23, 59, 59)),
      _entry(2, DateTime(2026, 8, 6)),
      _entry(3, DateTime(2026, 8, 12, 23, 59, 59)),
      _entry(4, DateTime(2026, 8, 13)),
    ];

    expect(range.start, DateTime(2026, 8, 6));
    expect(range.end, DateTime(2026, 8, 12));
    expect(range.filter(entries).map((entry) => entry.id), [2, 3]);
  });

  test('custom range count and labels are inclusive', () {
    final range = JournalExportRange(
      start: DateTime(2025, 12, 31),
      end: DateTime(2026, 1, 2),
    );

    expect(
      range.count([
        _entry(1, DateTime(2025, 12, 31, 8)),
        _entry(2, DateTime(2026, 1, 2, 21)),
      ]),
      2,
    );
    expect(range.fileNameRange, '2025-12-31-to-2026-01-02');
    expect(range.displayLabel, 'Dec 31, 2025–Jan 2, 2026');
  });
}

MealEntry _entry(int id, DateTime createdAt) => MealEntry(
  id: id,
  imagePath: '/private/$id.jpg',
  mealType: MealType.snack,
  feelings: const [],
  note: '',
  createdAt: createdAt,
);
