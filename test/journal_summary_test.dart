import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/utils/journal_summary.dart';

void main() {
  test('summarizes entries per logged day and common feeling', () {
    final entries = [
      _entry(1, DateTime(2026, 8, 10, 8), const ['Calm']),
      _entry(2, DateTime(2026, 8, 10, 12), const ['Happy', 'Calm']),
      _entry(3, DateTime(2026, 8, 10, 18), const ['Calm']),
      _entry(4, DateTime(2026, 8, 11, 9), const ['Happy']),
      _entry(5, DateTime(2026, 8, 11, 14), const []),
    ];

    final summary = JournalSummary.fromEntries(entries);

    expect(summary.totalEntries, 5);
    expect(summary.loggedDays, 2);
    expect(summary.mealsPerLoggedDay, 2.5);
    expect(summary.commonFeeling, 'Calm');
    expect(summary.commonFeelingLabel, 'Calm');
  });

  test('shows a dash when no feelings have been recorded', () {
    final summary = JournalSummary.fromEntries([
      _entry(1, DateTime(2026, 8, 10, 20)),
      _entry(2, DateTime(2026, 8, 11, 8)),
    ]);

    expect(summary.commonFeeling, isNull);
    expect(summary.commonFeelingLabel, '—');
  });
}

MealEntry _entry(
  int id,
  DateTime createdAt, [
  List<String> feelings = const [],
]) => MealEntry(
  id: id,
  imagePath: '/private/$id.jpg',
  mealType: MealType.values[id % MealType.values.length],
  feelings: feelings,
  note: '',
  createdAt: createdAt,
);
