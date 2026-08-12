import '../models/meal_entry.dart';

class JournalSummary {
  const JournalSummary({
    required this.totalEntries,
    required this.loggedDays,
    required this.mealsPerLoggedDay,
    required this.typicalSameDayGap,
  });

  final int totalEntries;
  final int loggedDays;
  final double mealsPerLoggedDay;
  final Duration? typicalSameDayGap;

  factory JournalSummary.fromEntries(List<MealEntry> entries) {
    if (entries.isEmpty) {
      return const JournalSummary(
        totalEntries: 0,
        loggedDays: 0,
        mealsPerLoggedDay: 0,
        typicalSameDayGap: null,
      );
    }

    final byDay = <String, List<DateTime>>{};
    for (final entry in entries) {
      final value = entry.createdAt;
      final key = '${value.year}-${value.month}-${value.day}';
      byDay.putIfAbsent(key, () => []).add(value);
    }

    final gaps = <Duration>[];
    for (final times in byDay.values) {
      times.sort();
      for (var index = 1; index < times.length; index++) {
        gaps.add(times[index].difference(times[index - 1]));
      }
    }
    gaps.sort();

    Duration? typicalGap;
    if (gaps.isNotEmpty) {
      final middle = gaps.length ~/ 2;
      typicalGap = gaps.length.isOdd
          ? gaps[middle]
          : Duration(
              milliseconds:
                  (gaps[middle - 1].inMilliseconds +
                      gaps[middle].inMilliseconds) ~/
                  2,
            );
    }

    return JournalSummary(
      totalEntries: entries.length,
      loggedDays: byDay.length,
      mealsPerLoggedDay: entries.length / byDay.length,
      typicalSameDayGap: typicalGap,
    );
  }

  String get typicalGapLabel {
    final gap = typicalSameDayGap;
    if (gap == null) return '—';
    final hours = gap.inHours;
    final minutes = gap.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}
