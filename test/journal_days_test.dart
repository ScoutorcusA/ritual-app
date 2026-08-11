import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/utils/journal_days.dart';

void main() {
  test('groups entries into days in source order', () {
    final entries = [
      _entry(1, DateTime(2026, 8, 11, 18), const ['Happy']),
      _entry(2, DateTime(2026, 8, 11, 8), const ['Calm']),
      _entry(3, DateTime(2026, 8, 10, 12), const []),
    ];

    final days = groupEntriesByDay(entries);

    expect(days, hasLength(2));
    expect(days.first.entries, hasLength(2));
    expect(days.first.day, DateTime(2026, 8, 11));
  });

  test('builds a short feelings summary', () {
    final entries = [
      _entry(1, DateTime(2026, 8, 11), const ['Happy', 'Calm']),
      _entry(2, DateTime(2026, 8, 11), const ['Calm', 'Social']),
    ];

    expect(feelingsSummary(entries), 'Calm, happy +1 more');
    expect(
      feelingsSummary([_entry(3, DateTime(2026), const [])]),
      'A day of noticing',
    );
  });
}

MealEntry _entry(int id, DateTime date, List<String> feelings) => MealEntry(
  id: id,
  imagePath: '/tmp/$id.jpg',
  mealType: MealType.breakfast,
  feelings: feelings,
  note: '',
  createdAt: date,
);
