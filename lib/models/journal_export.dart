import 'package:intl/intl.dart';

import '../l10n/ritual_i18n.dart';
import 'meal_entry.dart';

enum JournalExportFormat { pdf, csv }

enum JournalExportRangePreset { last7Days, last30Days, custom }

class JournalExportRange {
  JournalExportRange({required DateTime start, required DateTime end})
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError.value(end, 'end', 'must not be before start');
    }
  }

  factory JournalExportRange.lastDays({
    required DateTime today,
    required int days,
  }) {
    if (days < 1) {
      throw ArgumentError.value(days, 'days', 'must be at least 1');
    }
    final end = DateTime(today.year, today.month, today.day);
    return JournalExportRange(
      start: end.subtract(Duration(days: days - 1)),
      end: end,
    );
  }

  final DateTime start;
  final DateTime end;

  DateTime get endExclusive => end.add(const Duration(days: 1));

  bool contains(DateTime dateTime) =>
      !dateTime.isBefore(start) && dateTime.isBefore(endExclusive);

  List<MealEntry> filter(Iterable<MealEntry> entries) =>
      entries.where((entry) => contains(entry.createdAt)).toList();

  int count(Iterable<MealEntry> entries) =>
      entries.where((entry) => contains(entry.createdAt)).length;

  String get fileNameRange =>
      '${DateFormat('yyyy-MM-dd').format(start)}-to-${DateFormat('yyyy-MM-dd').format(end)}';

  String get displayLabel {
    if (start == end) {
      return DateFormat.yMMMd(RitualI18n.localeName).format(start);
    }
    if (start.year == end.year && start.month == end.month) {
      return tr(
        '{start}–{end}, {year}',
        values: {
          'start': DateFormat.MMMd(RitualI18n.localeName).format(start),
          'end': DateFormat.d(RitualI18n.localeName).format(end),
          'year': end.year,
        },
      );
    }
    if (start.year == end.year) {
      return tr(
        '{start}–{end}, {year}',
        values: {
          'start': DateFormat.MMMd(RitualI18n.localeName).format(start),
          'end': DateFormat.MMMd(RitualI18n.localeName).format(end),
          'year': end.year,
        },
      );
    }
    return tr(
      '{start}–{end}',
      values: {
        'start': DateFormat.yMMMd(RitualI18n.localeName).format(start),
        'end': DateFormat.yMMMd(RitualI18n.localeName).format(end),
      },
    );
  }
}
