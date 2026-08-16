import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/services/adaptive_reminder_advisor.dart';
import 'package:ritual/services/meal_reminder_service.dart';

void main() {
  const advisor = AdaptiveReminderAdvisor();

  test('suggests five minutes before a stable recent meal time', () {
    final entries = [
      for (var day = 1; day <= 6; day++)
        _entry(day, DateTime(2026, 8, day, 14, day.isEven ? 2 : 0)),
    ];

    final suggestion = advisor.suggestionFor(
      entries: entries,
      kind: MealReminderKind.lunch,
      currentMinutes: 13 * 60 + 30,
      now: DateTime(2026, 8, 10),
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.typicalMinutes, 14 * 60);
    expect(suggestion.suggestedMinutes, 13 * 60 + 55);
    expect(suggestion.sampleDays, 6);
  });

  test('does not suggest from fewer than five distinct days', () {
    final entries = [
      for (var day = 1; day <= 4; day++)
        _entry(day, DateTime(2026, 8, day, 14)),
    ];

    expect(
      advisor.suggestionFor(
        entries: entries,
        kind: MealReminderKind.lunch,
        currentMinutes: 13 * 60 + 30,
        now: DateTime(2026, 8, 10),
      ),
      isNull,
    );
  });

  test('respects a dismissed suggestion and a close existing time', () {
    final entries = [
      for (var day = 1; day <= 6; day++)
        _entry(day, DateTime(2026, 8, day, 14)),
    ];

    expect(
      advisor.suggestionFor(
        entries: entries,
        kind: MealReminderKind.lunch,
        currentMinutes: 13 * 60 + 55,
        now: DateTime(2026, 8, 10),
      ),
      isNull,
    );
    expect(
      advisor.suggestionFor(
        entries: entries,
        kind: MealReminderKind.lunch,
        currentMinutes: 13 * 60 + 30,
        dismissedSuggestedMinutes: 13 * 60 + 55,
        now: DateTime(2026, 8, 10),
      ),
      isNull,
    );
  });
}

MealEntry _entry(int id, DateTime createdAt) => MealEntry(
  id: id,
  imagePath: '/private/$id.jpg',
  mealType: MealType.lunch,
  feelings: const [],
  note: '',
  createdAt: createdAt,
);
