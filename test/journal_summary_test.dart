import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/utils/journal_summary.dart';

void main() {
  test('summarizes entries per logged day and median same-day gap', () {
    final entries = [
      _entry(1, DateTime(2026, 8, 10, 8)),
      _entry(2, DateTime(2026, 8, 10, 12)),
      _entry(3, DateTime(2026, 8, 10, 18)),
      _entry(4, DateTime(2026, 8, 11, 9)),
      _entry(5, DateTime(2026, 8, 11, 14)),
    ];

    final summary = JournalSummary.fromEntries(entries);

    expect(summary.totalEntries, 5);
    expect(summary.loggedDays, 2);
    expect(summary.mealsPerLoggedDay, 2.5);
    expect(summary.typicalSameDayGap, const Duration(hours: 5));
    expect(summary.typicalGapLabel, '5h');
  });

  test('does not treat overnight time as a meal gap', () {
    final summary = JournalSummary.fromEntries([
      _entry(1, DateTime(2026, 8, 10, 20)),
      _entry(2, DateTime(2026, 8, 11, 8)),
    ]);

    expect(summary.typicalSameDayGap, isNull);
    expect(summary.typicalGapLabel, '—');
  });
}

MealEntry _entry(int id, DateTime createdAt) => MealEntry(
  id: id,
  imagePath: '/private/$id.jpg',
  mealType: MealType.values[id % MealType.values.length],
  feelings: const [],
  note: '',
  createdAt: createdAt,
);
