import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/services/meal_reminder_service.dart';

void main() {
  const planner = MealReminderPlanner();

  test('an empty day receives meal reminders and a night check-in', () {
    final reminders = planner.plan(
      entries: const [],
      now: DateTime(2026, 8, 12, 8),
      days: 1,
    );

    expect(
      reminders.map((reminder) => reminder.kind),
      containsAll(MealReminderKind.values),
    );
    expect(reminders.map((reminder) => reminder.id).toSet(), hasLength(4));
  });

  test('logged meals and the empty-day check-in are suppressed', () {
    final now = DateTime(2026, 8, 12, 8);
    final reminders = planner.plan(
      entries: [_entry(MealType.breakfast, DateTime(2026, 8, 12, 7, 30))],
      now: now,
      days: 1,
    );

    expect(
      reminders.map((reminder) => reminder.kind),
      isNot(contains(MealReminderKind.breakfast)),
    );
    expect(
      reminders.map((reminder) => reminder.kind),
      isNot(contains(MealReminderKind.emptyDay)),
    );
    expect(
      reminders.map((reminder) => reminder.kind),
      containsAll([MealReminderKind.lunch, MealReminderKind.dinner]),
    );
  });

  test('past reminder windows are never scheduled', () {
    final reminders = planner.plan(
      entries: const [],
      now: DateTime(2026, 8, 12, 20),
      days: 1,
    );

    expect(reminders, hasLength(1));
    expect(reminders.single.kind, MealReminderKind.emptyDay);
    expect(reminders.single.scheduledAt, DateTime(2026, 8, 12, 21, 30));
  });

  test('future day reminders are still planned dynamically', () {
    final reminders = planner.plan(
      entries: [_entry(MealType.lunch, DateTime(2026, 8, 13, 12))],
      now: DateTime(2026, 8, 12, 22),
      days: 2,
    );

    expect(
      reminders.where((reminder) => reminder.scheduledAt.day == 13),
      hasLength(2),
    );
    expect(
      reminders
          .where((reminder) => reminder.scheduledAt.day == 13)
          .map((reminder) => reminder.kind),
      containsAll([MealReminderKind.breakfast, MealReminderKind.dinner]),
    );
  });
}

MealEntry _entry(MealType type, DateTime createdAt) => MealEntry(
  id: type.index + 1,
  imagePath: '/private/photo.jpg',
  mealType: type,
  feelings: const [],
  note: '',
  createdAt: createdAt,
);
