import 'package:intl/intl.dart';

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
      return DateFormat.yMMMd().format(start);
    }
    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat.MMMd().format(start)}–${DateFormat.d().format(end)}, ${end.year}';
    }
    if (start.year == end.year) {
      return '${DateFormat.MMMd().format(start)}–${DateFormat.MMMd().format(end)}, ${end.year}';
    }
    return '${DateFormat.yMMMd().format(start)}–${DateFormat.yMMMd().format(end)}';
  }
}
