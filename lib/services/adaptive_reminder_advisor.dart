import '../models/meal_entry.dart';
import 'meal_reminder_service.dart';

class AdaptiveReminderSuggestion {
  const AdaptiveReminderSuggestion({
    required this.kind,
    required this.typicalMinutes,
    required this.suggestedMinutes,
    required this.currentMinutes,
    required this.sampleDays,
  });

  final MealReminderKind kind;
  final int typicalMinutes;
  final int suggestedMinutes;
  final int currentMinutes;
  final int sampleDays;
}

class AdaptiveReminderAdvisor {
  const AdaptiveReminderAdvisor();

  AdaptiveReminderSuggestion? suggestionFor({
    required List<MealEntry> entries,
    required MealReminderKind kind,
    required int currentMinutes,
    int? dismissedSuggestedMinutes,
    DateTime? now,
  }) {
    final mealType = switch (kind) {
      MealReminderKind.breakfast => MealType.breakfast,
      MealReminderKind.lunch => MealType.lunch,
      MealReminderKind.dinner => MealType.dinner,
      MealReminderKind.emptyDay => null,
    };
    if (mealType == null) return null;

    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 60));
    final byDay = <String, DateTime>{};
    final matching =
        entries
            .where(
              (entry) =>
                  entry.mealType == mealType &&
                  !entry.createdAt.isBefore(cutoff),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final entry in matching) {
      final value = entry.createdAt;
      final key = '${value.year}-${value.month}-${value.day}';
      byDay.putIfAbsent(key, () => value);
    }
    final values =
        byDay.values
            .take(20)
            .map((value) => value.hour * 60 + value.minute)
            .toList()
          ..sort();
    if (values.length < 5) return null;

    final middle = values.length ~/ 2;
    final median = values.length.isOdd
        ? values[middle]
        : ((values[middle - 1] + values[middle]) / 2).round();
    final typical = ((median / 5).round() * 5).clamp(0, 1439);
    final suggested = (typical - 5).clamp(0, 1439);
    if ((suggested - currentMinutes).abs() < 15 ||
        dismissedSuggestedMinutes == suggested) {
      return null;
    }
    return AdaptiveReminderSuggestion(
      kind: kind,
      typicalMinutes: typical,
      suggestedMinutes: suggested,
      currentMinutes: currentMinutes,
      sampleDays: values.length,
    );
  }
}
