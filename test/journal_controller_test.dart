import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/controllers/journal_controller.dart';
import 'package:ritual/models/meal_entry.dart';

import 'support/memory_meal_repository.dart';

void main() {
  test('daily highlight is selected once and persisted', () async {
    final day = DateTime(2026, 8, 11, 8);
    final repository = MemoryMealRepository(
      entries: [_entry(1, day), _entry(2, day.add(const Duration(hours: 4)))],
    );
    final controller = JournalController(repository);
    await controller.initialize();

    final firstHighlight = controller.highlightForDay(day)!;
    expect([1, 2], contains(firstHighlight.id));
    expect(repository.highlights.values.single, firstHighlight.id);

    await controller.addEntry(
      MealDraft(
        imagePath: '/tmp/3.jpg',
        mealType: MealType.dinner,
        feelings: const [],
        note: '',
        createdAt: day.add(const Duration(hours: 9)),
      ),
    );
    expect(controller.highlightForDay(day)!.id, firstHighlight.id);

    final reloaded = JournalController(repository);
    await reloaded.initialize();
    expect(reloaded.highlightForDay(day)!.id, firstHighlight.id);
  });

  test('deleted highlight is safely replaced', () async {
    final day = DateTime(2026, 8, 11, 8);
    final repository = MemoryMealRepository(
      entries: [
        _entry(1, day),
        _entry(2, day.add(const Duration(hours: 4))),
        _entry(3, day.add(const Duration(hours: 8))),
      ],
    );
    final controller = JournalController(repository);
    await controller.initialize();
    final selected = controller.highlightForDay(day)!;

    await controller.deleteEntry(selected);

    final replacement = controller.highlightForDay(day)!;
    expect(replacement.id, isNot(selected.id));
    expect(repository.highlights.values.single, replacement.id);
  });

  test('only the first manually added entry reports firstEntryToday', () async {
    final repository = MemoryMealRepository();
    final controller = JournalController(repository);
    await controller.initialize();
    final now = DateTime.now();

    final first = await controller.addEntry(_draft(now));
    final second = await controller.addEntry(
      _draft(now.add(const Duration(minutes: 2))),
    );

    expect(first.firstEntryToday, isTrue);
    expect(second.firstEntryToday, isFalse);
  });
}

MealEntry _entry(int id, DateTime createdAt) => MealEntry(
  id: id,
  imagePath: '/tmp/$id.jpg',
  mealType: MealType.values[(id - 1) % MealType.values.length],
  feelings: const [],
  note: '',
  createdAt: createdAt,
);

MealDraft _draft(DateTime createdAt) => MealDraft(
  imagePath: '/tmp/new.jpg',
  mealType: MealType.breakfast,
  feelings: const [],
  note: '',
  createdAt: createdAt,
);
