import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/insights/insight_engine.dart';
import 'package:ritual/models/meal_entry.dart';

void main() {
  final now = DateTime(2026, 8, 11, 18);

  test('creates a deterministic recent meal run insight', () {
    final entries = List.generate(
      5,
      (index) => _entry(
        index,
        now.subtract(Duration(hours: index)),
        mealType: MealType.breakfast,
      ),
    );

    final insights = InsightEngine.build(entries, now: now);

    expect(insights.first.kind, InsightKind.repetition);
    expect(insights.first.message, contains('last 5 entries'));
    expect(insights.first.message, contains('breakfast'));
  });

  test('counts meal feelings by distinct days in the trailing week', () {
    final entries = [
      _entry(1, DateTime(2026, 8, 11, 8), feelings: const ['Happy']),
      _entry(2, DateTime(2026, 8, 11, 9), feelings: const ['Happy']),
      _entry(3, DateTime(2026, 8, 10, 8), feelings: const ['Happy']),
      _entry(4, DateTime(2026, 8, 9, 8), feelings: const ['Happy']),
      _entry(5, DateTime(2026, 8, 1, 8), feelings: const ['Happy']),
    ];

    final insights = InsightEngine.build(entries, now: now);
    final feeling = insights.singleWhere(
      (item) => item.kind == InsightKind.feeling,
    );

    expect(feeling.message, 'Breakfast felt happy on 3 days this past week.');
  });

  test('creates a meal and place insight for distinct days in thirty days', () {
    final entries = [
      _entry(1, DateTime(2026, 8, 11), locationLabel: 'Ohio'),
      _entry(2, DateTime(2026, 8, 3), locationLabel: 'Ohio'),
      _entry(3, DateTime(2026, 7, 20), locationLabel: 'Ohio'),
      _entry(4, DateTime(2026, 6, 1), locationLabel: 'Ohio'),
    ];

    final insights = InsightEngine.build(entries, now: now);
    final place = insights.singleWhere(
      (item) => item.kind == InsightKind.place,
    );

    expect(
      place.message,
      'You had breakfast in Ohio on 3 days this past month.',
    );
  });

  test('does not emit rules before their static thresholds', () {
    final entries = [
      _entry(1, DateTime(2026, 8, 11), feelings: const ['Happy']),
      _entry(2, DateTime(2026, 8, 10), feelings: const ['Happy']),
    ];

    expect(InsightEngine.build(entries, now: now), isEmpty);
  });
}

MealEntry _entry(
  int id,
  DateTime createdAt, {
  MealType mealType = MealType.breakfast,
  List<String> feelings = const [],
  String? locationLabel,
}) => MealEntry(
  id: id,
  imagePath: '/tmp/$id.jpg',
  mealType: mealType,
  feelings: feelings,
  note: '',
  createdAt: createdAt,
  latitude: locationLabel == null ? null : 40,
  longitude: locationLabel == null ? null : -83,
  locationLabel: locationLabel,
);
