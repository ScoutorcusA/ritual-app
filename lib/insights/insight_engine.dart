import '../l10n/ritual_i18n.dart';
import '../models/meal_entry.dart';
import '../models/personal_intention.dart';

enum InsightKind { repetition, feeling, place, consistency }

class JournalInsight {
  const JournalInsight({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
  });

  final String id;
  final InsightKind kind;
  final String title;
  final String message;
}

abstract final class InsightEngine {
  static List<JournalInsight> build(
    List<MealEntry> entries, {
    DateTime? now,
    PersonalIntention? intention,
  }) {
    if (entries.isEmpty) return const [];
    final ordered = [...entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final today = _dateOnly(now ?? DateTime.now());
    final insights = <JournalInsight>[];

    final recentType = ordered.first.mealType;
    var sameTypeRun = 0;
    for (final entry in ordered) {
      if (entry.mealType != recentType) break;
      sameTypeRun++;
    }
    if (sameTypeRun >= 4) {
      insights.add(
        JournalInsight(
          id: 'run-${recentType.name}-$sameTypeRun',
          kind: InsightKind.repetition,
          title: tr('A pattern is taking shape'),
          message: tr(
            'Your last {count} entries have all been {mealType}.',
            values: {
              'count': sameTypeRun,
              'mealType': recentType.label.toLowerCase(),
            },
          ),
        ),
      );
    }

    final weekStart = today.subtract(const Duration(days: 6));
    final feelingDays = <String, Set<DateTime>>{};
    for (final entry in ordered) {
      final day = _dateOnly(entry.createdAt);
      if (day.isBefore(weekStart) || day.isAfter(today)) continue;
      for (final feeling in entry.feelings) {
        feelingDays
            .putIfAbsent('${entry.mealType.name}\u0000$feeling', () => {})
            .add(day);
      }
    }
    final bestFeeling =
        feelingDays.entries.where((entry) => entry.value.length >= 3).toList()
          ..sort((a, b) {
            final count = b.value.length.compareTo(a.value.length);
            return count != 0 ? count : a.key.compareTo(b.key);
          });
    if (bestFeeling.isNotEmpty) {
      final parts = bestFeeling.first.key.split('\u0000');
      final type = MealType.values.byName(parts.first);
      final feeling = parts.last;
      final count = bestFeeling.first.value.length;
      insights.add(
        JournalInsight(
          id: 'feeling-${type.name}-${feeling.toLowerCase()}-$count',
          kind: InsightKind.feeling,
          title: tr('You noticed how it felt'),
          message: tr(
            '{mealType} felt {feeling} on {count} days this past week.',
            values: {
              'mealType': type.label,
              'feeling': tr(feeling).toLowerCase(),
              'count': count,
            },
          ),
        ),
      );
    }

    final monthStart = today.subtract(const Duration(days: 29));
    final placeDays = <String, Set<DateTime>>{};
    for (final entry in ordered) {
      final label = entry.locationLabel?.trim();
      final day = _dateOnly(entry.createdAt);
      if (label == null ||
          label.isEmpty ||
          day.isBefore(monthStart) ||
          day.isAfter(today)) {
        continue;
      }
      placeDays
          .putIfAbsent('${entry.mealType.name}\u0000$label', () => {})
          .add(day);
    }
    final bestPlace =
        placeDays.entries.where((entry) => entry.value.length >= 3).toList()
          ..sort((a, b) {
            final count = b.value.length.compareTo(a.value.length);
            return count != 0 ? count : a.key.compareTo(b.key);
          });
    if (bestPlace.isNotEmpty) {
      final separator = bestPlace.first.key.indexOf('\u0000');
      final type = MealType.values.byName(
        bestPlace.first.key.substring(0, separator),
      );
      final label = bestPlace.first.key.substring(separator + 1);
      final count = bestPlace.first.value.length;
      insights.add(
        JournalInsight(
          id: 'place-${type.name}-${label.toLowerCase()}-$count',
          kind: InsightKind.place,
          title: tr('A familiar place'),
          message: tr(
            'You had {mealType} in {place} on {count} days this past month.',
            values: {
              'mealType': type.label.toLowerCase(),
              'place': label,
              'count': count,
            },
          ),
        ),
      );
    }

    final journalDays = ordered
        .map((entry) => _dateOnly(entry.createdAt))
        .where((day) => !day.isBefore(weekStart) && !day.isAfter(today))
        .toSet()
        .length;
    if (journalDays >= 4) {
      insights.add(
        JournalInsight(
          id: 'consistency-$journalDays',
          kind: InsightKind.consistency,
          title: tr('Days worth remembering'),
          message: tr(
            'You paused to notice a meal on {count} days this week.',
            values: {'count': journalDays},
          ),
        ),
      );
    }
    if (insights.isNotEmpty && intention != null) {
      final first = insights.first;
      insights[0] = JournalInsight(
        id: first.id,
        kind: first.kind,
        title: first.title,
        message: tr(
          '{insight} {nudge}',
          values: {'insight': first.message, 'nudge': intention.insightNudge},
        ),
      );
    }
    return insights;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
