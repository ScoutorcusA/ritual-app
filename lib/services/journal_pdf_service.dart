import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;

import '../models/journal_export.dart';
import '../models/meal_entry.dart';
import '../utils/journal_summary.dart';

class JournalPdfResult {
  const JournalPdfResult({
    required this.bytes,
    required this.fileName,
    required this.entryCount,
  });

  final Uint8List bytes;
  final String fileName;
  final int entryCount;
}

class JournalPdfService {
  static const _ink = PdfColor.fromInt(0xff25251f);
  static const _sage = PdfColor.fromInt(0xff63705a);
  static const _paper = PdfColor.fromInt(0xfff7f2e8);
  static const _line = PdfColor.fromInt(0xffd8d1c2);

  Future<JournalPdfResult> createReport(
    List<MealEntry> entries, {
    DateTime? generatedAt,
    JournalExportRange? range,
  }) async {
    final created = generatedAt ?? DateTime.now();
    final effectiveRange = range ?? _rangeFor(entries, created);
    final sorted = effectiveRange.filter(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final days = <String, List<_PdfMeal>>{};
    for (final entry in sorted) {
      final key = DateFormat('yyyy-MM-dd').format(entry.createdAt);
      days
          .putIfAbsent(key, () => [])
          .add(
            _PdfMeal(entry: entry, photo: await _preparePhoto(entry.imagePath)),
          );
    }

    final summary = JournalSummary.fromEntries(sorted);
    final document = pdf.Document(
      title: 'Ritual food journal report',
      author: 'Ritual',
      subject: 'Self-recorded meal reflection journal',
      creator: 'Ritual 1.6',
    );
    document.addPage(
      pdf.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pdf.EdgeInsets.fromLTRB(34, 38, 34, 38),
        theme: pdf.ThemeData.withFont(
          base: pdf.Font.helvetica(),
          bold: pdf.Font.helveticaBold(),
          italic: pdf.Font.helveticaOblique(),
        ),
        header: (context) => context.pageNumber == 1
            ? pdf.SizedBox.shrink()
            : pdf.Container(
                padding: const pdf.EdgeInsets.only(bottom: 5),
                decoration: const pdf.BoxDecoration(
                  border: pdf.Border(bottom: pdf.BorderSide(color: _line)),
                ),
                child: pdf.Row(
                  mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
                  children: [
                    pdf.Text(
                      'RITUAL - FOOD JOURNAL',
                      style: const pdf.TextStyle(
                        color: _sage,
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pdf.Text(
                      DateFormat.yMMMd().format(created),
                      style: const pdf.TextStyle(fontSize: 9, color: _sage),
                    ),
                  ],
                ),
              ),
        footer: (context) => pdf.Container(
          padding: const pdf.EdgeInsets.only(top: 8),
          decoration: const pdf.BoxDecoration(
            border: pdf.Border(top: pdf.BorderSide(color: _line)),
          ),
          child: pdf.Row(
            mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
            children: [
              pdf.Text(
                'Self-recorded reflection log - not a medical diagnosis',
                style: const pdf.TextStyle(fontSize: 8, color: _sage),
              ),
              pdf.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pdf.TextStyle(fontSize: 8, color: _sage),
              ),
            ],
          ),
        ),
        build: (context) => [
          pdf.Text(
            'RITUAL',
            style: const pdf.TextStyle(
              color: _sage,
              fontSize: 12,
              letterSpacing: 3,
            ),
          ),
          pdf.SizedBox(height: 5),
          pdf.Text(
            'Food journal report',
            style: pdf.TextStyle(
              color: _ink,
              fontSize: 25,
              fontWeight: pdf.FontWeight.bold,
            ),
          ),
          pdf.SizedBox(height: 5),
          pdf.Text(
            'Prepared ${DateFormat.yMMMMd().add_jm().format(created)}',
            style: const pdf.TextStyle(color: _sage, fontSize: 11),
          ),
          pdf.SizedBox(height: 2),
          pdf.Text(
            'Journal period ${_pdfSafe(effectiveRange.displayLabel)}',
            style: const pdf.TextStyle(color: _sage, fontSize: 11),
          ),
          pdf.SizedBox(height: 12),
          pdf.Container(
            padding: const pdf.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: pdf.BoxDecoration(
              color: _paper,
              borderRadius: pdf.BorderRadius.circular(10),
            ),
            child: pdf.Row(
              children: [
                _summaryMetric('${summary.totalEntries}', 'Total entries'),
                _summaryMetric('${summary.loggedDays}', 'Logged days'),
                _summaryMetric(
                  summary.mealsPerLoggedDay.toStringAsFixed(1),
                  'Per logged day',
                ),
                _summaryMetric(
                  _pdfSafe(summary.commonFeelingLabel),
                  'Common feeling',
                ),
              ],
            ),
          ),
          pdf.SizedBox(height: 8),
          pdf.Container(
            padding: const pdf.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: pdf.BoxDecoration(
              border: pdf.Border.all(color: _line),
              borderRadius: pdf.BorderRadius.circular(7),
            ),
            child: pdf.RichText(
              text: pdf.TextSpan(
                style: const pdf.TextStyle(fontSize: 8.5, color: _ink),
                children: [
                  pdf.TextSpan(
                    text: 'About this report: ',
                    style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold),
                  ),
                  const pdf.TextSpan(
                    text:
                        'Information is self-recorded. Ratings use an optional 1-to-5 reflection scale. Common feeling is the most frequently selected feeling in this period.',
                  ),
                ],
              ),
            ),
          ),
          pdf.SizedBox(height: 12),
          if (days.isEmpty)
            pdf.Container(
              padding: const pdf.EdgeInsets.all(20),
              decoration: pdf.BoxDecoration(
                border: pdf.Border.all(color: _line),
                borderRadius: pdf.BorderRadius.circular(10),
              ),
              child: pdf.Text('No journal entries were available to include.'),
            )
          else
            for (final day in days.entries) ...[
              ..._dayWidgets(DateTime.parse(day.key), day.value),
            ],
        ],
      ),
    );

    final bytes = await document.save();
    return JournalPdfResult(
      bytes: bytes,
      fileName: 'ritual-journal-${effectiveRange.fileNameRange}.pdf',
      entryCount: sorted.length,
    );
  }

  JournalExportRange _rangeFor(List<MealEntry> entries, DateTime fallback) {
    if (entries.isEmpty) {
      return JournalExportRange(start: fallback, end: fallback);
    }
    var earliest = entries.first.createdAt;
    var latest = entries.first.createdAt;
    for (final entry in entries.skip(1)) {
      if (entry.createdAt.isBefore(earliest)) earliest = entry.createdAt;
      if (entry.createdAt.isAfter(latest)) latest = entry.createdAt;
    }
    return JournalExportRange(start: earliest, end: latest);
  }

  pdf.Widget _summaryMetric(String value, String label) => pdf.Expanded(
    child: pdf.Column(
      children: [
        pdf.Text(
          value,
          style: pdf.TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: pdf.FontWeight.bold,
          ),
        ),
        pdf.SizedBox(height: 1),
        pdf.Text(
          label,
          textAlign: pdf.TextAlign.center,
          style: const pdf.TextStyle(color: _sage, fontSize: 7.5),
        ),
      ],
    ),
  );

  pdf.Widget _dayHeading(DateTime day, int count) => pdf.Container(
    padding: const pdf.EdgeInsets.fromLTRB(10, 6, 10, 6),
    decoration: const pdf.BoxDecoration(
      color: _ink,
      borderRadius: pdf.BorderRadius.all(pdf.Radius.circular(7)),
    ),
    child: pdf.Row(
      mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
      children: [
        pdf.Text(
          DateFormat('EEEE, MMMM d, yyyy').format(day),
          style: pdf.TextStyle(
            color: PdfColors.white,
            fontSize: 10.5,
            fontWeight: pdf.FontWeight.bold,
          ),
        ),
        pdf.Text(
          '$count ${count == 1 ? 'entry' : 'entries'}',
          style: const pdf.TextStyle(color: _paper, fontSize: 8),
        ),
      ],
    ),
  );

  List<pdf.Widget> _dayWidgets(DateTime day, List<_PdfMeal> meals) {
    final widgets = <pdf.Widget>[
      pdf.Inseparable(
        child: pdf.Column(
          crossAxisAlignment: pdf.CrossAxisAlignment.start,
          children: [
            _dayHeading(day, meals.length),
            pdf.SizedBox(height: 5),
            _mealCard(meals.first),
          ],
        ),
      ),
      pdf.SizedBox(height: 5),
    ];
    for (final meal in meals.skip(1)) {
      widgets.add(_mealCard(meal));
      widgets.add(pdf.SizedBox(height: 5));
    }
    widgets.add(pdf.SizedBox(height: 5));
    return widgets;
  }

  pdf.Widget _mealCard(_PdfMeal meal) {
    final entry = meal.entry;
    final details = <pdf.Widget>[
      pdf.Row(
        mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
        children: [
          pdf.Text(
            entry.mealType.label,
            style: pdf.TextStyle(
              fontSize: 11.5,
              fontWeight: pdf.FontWeight.bold,
            ),
          ),
          pdf.Text(
            DateFormat.jm().format(entry.createdAt),
            style: const pdf.TextStyle(color: _sage, fontSize: 8.5),
          ),
        ],
      ),
    ];
    final ratings = <String>[
      if (entry.hungerLevel != null) 'Hunger before ${entry.hungerLevel}/5',
      if (entry.cravingLevel != null) 'Craving before ${entry.cravingLevel}/5',
      if (entry.fullnessLevel != null)
        'Fullness after ${entry.fullnessLevel}/5',
    ];
    if (ratings.isNotEmpty) {
      details.addAll([
        pdf.SizedBox(height: 4),
        pdf.Text(
          ratings.join('  |  '),
          style: pdf.TextStyle(
            color: _sage,
            fontSize: 8,
            fontWeight: pdf.FontWeight.bold,
          ),
        ),
      ]);
    }
    if (entry.feelings.isNotEmpty) {
      details.addAll([
        pdf.SizedBox(height: 4),
        _labeledText('Feelings', entry.feelings.join(', ')),
      ]);
    }
    if (entry.note.trim().isNotEmpty) {
      details.addAll([
        pdf.SizedBox(height: 4),
        _labeledText('Reflection', entry.note.trim()),
      ]);
    }
    final place =
        entry.locationLabel ??
        (entry.hasLocation
            ? '${entry.latitude!.toStringAsFixed(4)}, ${entry.longitude!.toStringAsFixed(4)}'
            : null);
    if (place != null) {
      details.addAll([pdf.SizedBox(height: 4), _labeledText('Place', place)]);
    }

    return pdf.Container(
      padding: const pdf.EdgeInsets.all(7),
      decoration: pdf.BoxDecoration(
        border: pdf.Border.all(color: _line),
        borderRadius: pdf.BorderRadius.circular(9),
      ),
      child: pdf.Row(
        crossAxisAlignment: pdf.CrossAxisAlignment.start,
        children: [
          pdf.Container(
            width: 82,
            height: 61,
            decoration: pdf.BoxDecoration(
              color: _paper,
              borderRadius: pdf.BorderRadius.circular(7),
            ),
            child: meal.photo == null
                ? pdf.Center(
                    child: pdf.Text(
                      'Photo unavailable',
                      style: const pdf.TextStyle(color: _sage, fontSize: 7),
                    ),
                  )
                : pdf.ClipRRect(
                    horizontalRadius: 7,
                    verticalRadius: 7,
                    child: pdf.Image(meal.photo!, fit: pdf.BoxFit.cover),
                  ),
          ),
          pdf.SizedBox(width: 9),
          pdf.Expanded(
            child: pdf.Column(
              crossAxisAlignment: pdf.CrossAxisAlignment.start,
              children: details,
            ),
          ),
        ],
      ),
    );
  }

  pdf.Widget _labeledText(String label, String value) => pdf.RichText(
    text: pdf.TextSpan(
      style: const pdf.TextStyle(fontSize: 8.2, color: _ink),
      children: [
        pdf.TextSpan(
          text: '$label: ',
          style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold),
        ),
        pdf.TextSpan(text: _pdfSafe(value)),
      ],
    ),
  );

  Future<pdf.MemoryImage?> _preparePhoto(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = image.decodeImage(bytes);
      if (decoded == null) return null;
      final resized = decoded.width > 720
          ? image.copyResize(decoded, width: 720)
          : decoded;
      return pdf.MemoryImage(
        Uint8List.fromList(image.encodeJpg(resized, quality: 78)),
      );
    } catch (_) {
      return null;
    }
  }

  String _pdfSafe(String value) {
    final normalized = value
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('…', '...');
    return String.fromCharCodes(
      normalized.runes.map((rune) {
        if (rune == 10 || rune == 13 || rune == 9) return rune;
        return rune >= 32 && rune <= 126 ? rune : 63;
      }),
    );
  }
}

class _PdfMeal {
  const _PdfMeal({required this.entry, required this.photo});

  final MealEntry entry;
  final pdf.MemoryImage? photo;
}
