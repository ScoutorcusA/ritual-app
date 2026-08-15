import '../models/meal_entry.dart';

class JournalSummary {
  const JournalSummary({
    required this.totalEntries,
    required this.loggedDays,
    required this.mealsPerLoggedDay,
    required this.commonFeeling,
  });

  final int totalEntries;
  final int loggedDays;
  final double mealsPerLoggedDay;
  final String? commonFeeling;

  factory JournalSummary.fromEntries(List<MealEntry> entries) {
    if (entries.isEmpty) {
      return const JournalSummary(
        totalEntries: 0,
        loggedDays: 0,
        mealsPerLoggedDay: 0,
        commonFeeling: null,
      );
    }

    final byDay = <String, List<DateTime>>{};
    for (final entry in entries) {
      final value = entry.createdAt;
      final key = '${value.year}-${value.month}-${value.day}';
      byDay.putIfAbsent(key, () => []).add(value);
    }

    final feelingCounts = <String, int>{};
    for (final entry in entries) {
      for (final feeling in entry.feelings.toSet()) {
        if (feeling.trim().isNotEmpty) {
          feelingCounts.update(
            feeling,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }
    final rankedFeelings = feelingCounts.entries.toList()
      ..sort((left, right) {
        final byCount = right.value.compareTo(left.value);
        return byCount != 0 ? byCount : left.key.compareTo(right.key);
      });

    return JournalSummary(
      totalEntries: entries.length,
      loggedDays: byDay.length,
      mealsPerLoggedDay: entries.length / byDay.length,
      commonFeeling: rankedFeelings.firstOrNull?.key,
    );
  }

  String get commonFeelingLabel => commonFeeling ?? '—';
}
