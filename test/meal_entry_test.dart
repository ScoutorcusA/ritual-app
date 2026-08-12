import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/models/meal_entry.dart';

void main() {
  test('manual place can be saved without coordinates', () {
    final entry = MealEntry(
      id: 1,
      imagePath: '/private/photo.jpg',
      mealType: MealType.lunch,
      feelings: const [],
      note: '',
      createdAt: DateTime(2026, 8, 12),
      latitude: 40,
      longitude: -83,
      locationLabel: 'Old place',
    );

    final updated = entry.copyWith(
      locationLabel: 'Home',
      clearCoordinates: true,
    );

    expect(updated.latitude, isNull);
    expect(updated.longitude, isNull);
    expect(updated.locationLabel, 'Home');
  });
}
