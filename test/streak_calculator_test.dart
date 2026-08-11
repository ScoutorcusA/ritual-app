import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/utils/streak_calculator.dart';

void main() {
  final today = DateTime(2026, 8, 11);

  test('starts at one on the first recorded day', () {
    final stats = StreakCalculator.calculate([today], now: today);

    expect(stats.current, 1);
    expect(stats.longest, 1);
  });

  test('counts one day once even with multiple meals', () {
    final stats = StreakCalculator.calculate([
      DateTime(2026, 8, 10, 8),
      DateTime(2026, 8, 11, 9),
      DateTime(2026, 8, 11, 19),
    ], now: today);

    expect(stats.current, 2);
    expect(stats.longest, 2);
  });

  test('resets after a missed day', () {
    final stats = StreakCalculator.calculate(
      [DateTime(2026, 8, 8), today],
      now: today,
      retainedBest: 4,
    );

    expect(stats.current, 1);
    expect(stats.longest, 4);
  });

  test('keeps an active streak alive through the following day', () {
    final stats = StreakCalculator.calculate([
      DateTime(2026, 8, 9),
      DateTime(2026, 8, 10),
    ], now: today);

    expect(stats.current, 2);
  });
}
