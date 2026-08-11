class StreakStats {
  const StreakStats({required this.current, required this.longest});

  final int current;
  final int longest;
}

class StreakCalculator {
  const StreakCalculator._();

  static StreakStats calculate(
    Iterable<DateTime> entryDates, {
    DateTime? now,
    int retainedBest = 0,
  }) {
    final today = _day(now ?? DateTime.now());
    final days = entryDates.map(_day).toSet().toList()..sort();
    if (days.isEmpty) {
      return StreakStats(current: 0, longest: retainedBest);
    }

    var longest = 1;
    var run = 1;
    for (var index = 1; index < days.length; index++) {
      if (days[index].difference(days[index - 1]).inDays == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    final latest = days.last;
    final age = today.difference(latest).inDays;
    var current = 0;
    if (age == 0 || age == 1) {
      current = 1;
      for (var index = days.length - 1; index > 0; index--) {
        if (days[index].difference(days[index - 1]).inDays != 1) break;
        current++;
      }
    }

    return StreakStats(
      current: current,
      longest: [retainedBest, longest, current].reduce((a, b) => a > b ? a : b),
    );
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
