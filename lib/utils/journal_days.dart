import '../models/meal_entry.dart';

class JournalDay {
  const JournalDay({required this.day, required this.entries});

  final DateTime day;
  final List<MealEntry> entries;
}

List<JournalDay> groupEntriesByDay(List<MealEntry> entries) {
  final groups = <DateTime, List<MealEntry>>{};
  for (final entry in entries) {
    final day = dateOnly(entry.createdAt);
    groups.putIfAbsent(day, () => []).add(entry);
  }
  return groups.entries
      .map((group) => JournalDay(day: group.key, entries: group.value))
      .toList(growable: false);
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String feelingsSummary(List<MealEntry> entries) {
  final counts = <String, int>{};
  for (final entry in entries) {
    for (final feeling in entry.feelings.toSet()) {
      counts.update(feeling, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) return 'A day of noticing';
  final feelings = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  if (feelings.length == 1) return 'Felt ${feelings.first.toLowerCase()}';
  if (feelings.length == 2) {
    return '${feelings.first} and ${feelings[1].toLowerCase()}';
  }
  return '${feelings[0]}, ${feelings[1].toLowerCase()} '
      '+${feelings.length - 2} more';
}
