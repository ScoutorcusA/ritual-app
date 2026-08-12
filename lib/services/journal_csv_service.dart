import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../models/journal_export.dart';
import '../models/meal_entry.dart';

class JournalCsvResult {
  const JournalCsvResult({
    required this.bytes,
    required this.fileName,
    required this.entryCount,
  });

  final Uint8List bytes;
  final String fileName;
  final int entryCount;
}

class JournalCsvService {
  JournalCsvResult createReport(
    List<MealEntry> entries, {
    required JournalExportRange range,
  }) {
    final sorted = range.filter(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final rows = <List<_CsvCell>>[
      const [
        _CsvCell.text('Date'),
        _CsvCell.text('Time'),
        _CsvCell.text('Recorded at'),
        _CsvCell.text('Meal type'),
        _CsvCell.text('Feelings'),
        _CsvCell.text('Reflection'),
        _CsvCell.text('Place'),
        _CsvCell.text('Latitude'),
        _CsvCell.text('Longitude'),
        _CsvCell.text('Hunger before (1-5)'),
        _CsvCell.text('Craving before (1-5)'),
        _CsvCell.text('Fullness after (1-5)'),
      ],
      for (final entry in sorted)
        [
          _CsvCell.text(DateFormat('yyyy-MM-dd').format(entry.createdAt)),
          _CsvCell.text(DateFormat('HH:mm').format(entry.createdAt)),
          _CsvCell.text(entry.createdAt.toIso8601String()),
          _CsvCell.text(entry.mealType.label),
          _CsvCell.text(entry.feelings.join('; ')),
          _CsvCell.text(entry.note.trim()),
          _CsvCell.text(entry.locationLabel?.trim() ?? ''),
          _CsvCell.number(entry.latitude?.toStringAsFixed(6) ?? ''),
          _CsvCell.number(entry.longitude?.toStringAsFixed(6) ?? ''),
          _CsvCell.number(entry.hungerLevel?.toString() ?? ''),
          _CsvCell.number(entry.cravingLevel?.toString() ?? ''),
          _CsvCell.number(entry.fullnessLevel?.toString() ?? ''),
        ],
    ];
    final csv = '${rows.map(_encodeRow).join('\r\n')}\r\n';
    return JournalCsvResult(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileName: 'ritual-journal-${range.fileNameRange}.csv',
      entryCount: sorted.length,
    );
  }

  String _encodeRow(List<_CsvCell> row) => row
      .map((cell) => cell.isText ? _encodeText(cell.value) : cell.value)
      .join(',');

  String _encodeText(String value) {
    final firstNonWhitespace = value.trimLeft();
    final protected =
        firstNonWhitespace.isNotEmpty &&
            const {
              '=',
              '+',
              '-',
              '@',
              '\t',
              '\r',
            }.contains(firstNonWhitespace[0])
        ? "'$value"
        : value;
    return '"${protected.replaceAll('"', '""')}"';
  }
}

class _CsvCell {
  const _CsvCell.text(this.value) : isText = true;
  const _CsvCell.number(this.value) : isText = false;

  final String value;
  final bool isText;
}
