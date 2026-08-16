import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;

import '../l10n/ritual_i18n.dart';
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
    final overview = _JournalOverview.fromEntries(sorted, effectiveRange);
    final document = pdf.Document(
      title: tr('Ritual food journal report'),
      author: tr('Ritual'),
      subject: tr('Self-recorded meal reflection journal'),
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
                      tr('RITUAL - FOOD JOURNAL'),
                      style: const pdf.TextStyle(
                        color: _sage,
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pdf.Text(
                      DateFormat.yMMMd(RitualI18n.localeName).format(created),
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
                tr('Self-recorded reflection log - not a medical diagnosis'),
                style: const pdf.TextStyle(fontSize: 8, color: _sage),
              ),
              pdf.Text(
                tr(
                  'Page {page} of {pages}',
                  values: {
                    'page': context.pageNumber,
                    'pages': context.pagesCount,
                  },
                ),
                style: const pdf.TextStyle(fontSize: 8, color: _sage),
              ),
            ],
          ),
        ),
        build: (context) => [
          ..._overviewWidgets(
            created: created,
            range: effectiveRange,
            summary: summary,
            overview: overview,
          ),
          if (days.isNotEmpty) ...[
            pdf.NewPage(),
            ..._patternWidgets(entries: sorted, range: effectiveRange),
            pdf.NewPage(),
            _sectionHeading(
              tr('Complete journal'),
              tr(
                'Every recorded photo, rating, feeling, place, and reflection is included below.',
              ),
            ),
            pdf.SizedBox(height: 10),
            for (final day in days.entries) ...[
              ..._dayWidgets(DateTime.parse(day.key), day.value),
            ],
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

  List<pdf.Widget> _overviewWidgets({
    required DateTime created,
    required JournalExportRange range,
    required JournalSummary summary,
    required _JournalOverview overview,
  }) => [
    pdf.Text(
      tr('RITUAL'),
      style: const pdf.TextStyle(color: _sage, fontSize: 12, letterSpacing: 3),
    ),
    pdf.SizedBox(height: 5),
    pdf.Text(
      tr('Journal patterns'),
      style: pdf.TextStyle(
        color: _ink,
        fontSize: 23,
        fontWeight: pdf.FontWeight.bold,
      ),
    ),
    pdf.SizedBox(height: 5),
    pdf.Text(
      tr(
        'Prepared {date}',
        values: {
          'date': DateFormat.yMMMMd(
            RitualI18n.localeName,
          ).add_jm().format(created),
        },
      ),
      style: const pdf.TextStyle(color: _sage, fontSize: 10.5),
    ),
    pdf.SizedBox(height: 2),
    pdf.Text(
      tr(
        'Journal period {dateRange}',
        values: {'dateRange': _pdfSafe(range.displayLabel)},
      ),
      style: const pdf.TextStyle(color: _sage, fontSize: 10.5),
    ),
    pdf.SizedBox(height: 10),
    pdf.Container(
      padding: const pdf.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pdf.BoxDecoration(
        border: pdf.Border.all(color: _line),
        borderRadius: pdf.BorderRadius.circular(7),
      ),
      child: pdf.Text(
        tr(
          'Self-recorded observations from this journal. This is not a diagnosis, nutritional assessment, or complete record of food intake.',
        ),
        style: pdf.TextStyle(fontSize: 8.3, color: _ink),
      ),
    ),
    pdf.SizedBox(height: 11),
    pdf.Container(
      padding: const pdf.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: pdf.BoxDecoration(
        color: _paper,
        borderRadius: pdf.BorderRadius.circular(10),
      ),
      child: pdf.Row(
        children: [
          _summaryMetric(
            tr(
              '{logged} of {total}',
              values: {
                'logged': summary.loggedDays,
                'total': overview.periodDays,
              },
            ),
            tr('Days with entries'),
          ),
          _summaryMetric('${summary.totalEntries}', tr('Total entries')),
          _summaryMetric(
            summary.loggedDays == 0
                ? '0%'
                : '${overview.coveragePercent.round()}%',
            tr('Period coverage'),
          ),
          _summaryMetric(
            summary.loggedDays == 0
                ? '0.0'
                : summary.mealsPerLoggedDay.toStringAsFixed(1),
            tr('Per logged day'),
          ),
        ],
      ),
    ),
    pdf.SizedBox(height: 12),
    _smallSectionTitle(tr('Entry distribution')),
    pdf.SizedBox(height: 5),
    pdf.Row(
      children: [
        for (final type in MealType.values)
          _compactMetric(
            '${overview.mealCounts[type] ?? 0}',
            type == MealType.snack ? tr('Snacks') : type.label,
          ),
      ],
    ),
    pdf.SizedBox(height: 12),
    _smallSectionTitle(tr('Optional reflection scales')),
    pdf.SizedBox(height: 5),
    pdf.Row(
      crossAxisAlignment: pdf.CrossAxisAlignment.start,
      children: [
        _ratingMetric(tr('Hunger before'), overview.hunger),
        pdf.SizedBox(width: 7),
        _ratingMetric(tr('Craving before'), overview.craving),
        pdf.SizedBox(width: 7),
        _ratingMetric(tr('Fullness after'), overview.fullness),
      ],
    ),
    pdf.SizedBox(height: 12),
    pdf.Row(
      crossAxisAlignment: pdf.CrossAxisAlignment.start,
      children: [
        pdf.Expanded(
          child: pdf.Column(
            crossAxisAlignment: pdf.CrossAxisAlignment.start,
            children: [
              _smallSectionTitle(tr('Common feelings')),
              pdf.SizedBox(height: 5),
              _overviewPanel(
                overview.topFeelings.isEmpty
                    ? tr('No feelings were recorded.')
                    : overview.topFeelings
                          .map(
                            (item) => tr(
                              '{feeling} - {entries}',
                              values: {
                                'feeling': _pdfSafe(tr(item.label)),
                                'entries': trPlural(
                                  item.count,
                                  one: '{count} entry',
                                  other: '{count} entries',
                                ),
                              },
                            ),
                          )
                          .join('\n'),
              ),
            ],
          ),
        ),
        pdf.SizedBox(width: 8),
        pdf.Expanded(
          child: pdf.Column(
            crossAxisAlignment: pdf.CrossAxisAlignment.start,
            children: [
              _smallSectionTitle(tr('Typical timing')),
              pdf.SizedBox(height: 5),
              _overviewPanel(
                MealType.values
                    .map(
                      (type) => tr(
                        '{mealType}: {timing}',
                        values: {
                          'mealType': type == MealType.snack
                              ? tr('Snacks')
                              : type.label,
                          'timing': overview.timingLabel(type),
                        },
                      ),
                    )
                    .join('\n'),
              ),
            ],
          ),
        ),
      ],
    ),
    pdf.SizedBox(height: 12),
    _smallSectionTitle(tr('Journal cues')),
    pdf.SizedBox(height: 5),
    pdf.Container(
      width: double.infinity,
      padding: const pdf.EdgeInsets.all(9),
      decoration: pdf.BoxDecoration(
        color: _paper,
        borderRadius: pdf.BorderRadius.circular(8),
      ),
      child: pdf.Column(
        crossAxisAlignment: pdf.CrossAxisAlignment.start,
        children: [
          for (final cue in overview.reviewCues) ...[
            pdf.Row(
              crossAxisAlignment: pdf.CrossAxisAlignment.start,
              children: [
                pdf.Text('- ', style: const pdf.TextStyle(fontSize: 8.4)),
                pdf.Expanded(
                  child: pdf.Text(
                    _pdfSafe(cue),
                    style: const pdf.TextStyle(fontSize: 8.4),
                  ),
                ),
              ],
            ),
            pdf.SizedBox(height: 3),
          ],
        ],
      ),
    ),
    pdf.SizedBox(height: 7),
    pdf.Text(
      tr(
        'Data completion: feelings on {feelingCount}/{total} entries; reflections on {noteCount}/{total}; location on {locationCount}/{total}. Ratings show observed mean, range, and response count; unanswered fields are not treated as zero.',
        values: {
          'feelingCount': overview.feelingEntryCount,
          'noteCount': overview.noteCount,
          'locationCount': overview.locationCount,
          'total': summary.totalEntries,
        },
      ),
      style: const pdf.TextStyle(fontSize: 7.5, color: _sage),
    ),
  ];

  List<pdf.Widget> _patternWidgets({
    required List<MealEntry> entries,
    required JournalExportRange range,
  }) {
    final byDay = <DateTime, List<MealEntry>>{};
    for (final entry in entries) {
      final day = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      byDay.putIfAbsent(day, () => []).add(entry);
    }
    final dates = <DateTime>[];
    for (
      var day = range.start;
      !day.isAfter(range.end);
      day = day.add(const Duration(days: 1))
    ) {
      dates.add(day);
    }

    final widgets = <pdf.Widget>[
      _sectionHeading(
        tr('Weekly pattern view'),
        tr(
          'Each cell lists every recorded entry of that type. Multiple snacks - and repeated meals - appear on separate lines. H, C, and F mean hunger before, craving before, and fullness after.',
        ),
      ),
      pdf.SizedBox(height: 10),
    ];
    for (var offset = 0; offset < dates.length; offset += 7) {
      final week = dates.skip(offset).take(7).toList();
      widgets.add(
        pdf.Text(
          _pdfSafe(
            tr(
              '{start} - {end}',
              values: {
                'start': DateFormat.MMMd(
                  RitualI18n.localeName,
                ).format(week.first),
                'end': DateFormat.yMMMd(
                  RitualI18n.localeName,
                ).format(week.last),
              },
            ),
          ),
          style: pdf.TextStyle(
            color: _ink,
            fontSize: 10,
            fontWeight: pdf.FontWeight.bold,
          ),
        ),
      );
      widgets.add(pdf.SizedBox(height: 4));
      widgets.add(_patternTable(week, byDay));
      widgets.add(pdf.SizedBox(height: 12));
    }
    return widgets;
  }

  pdf.Widget _patternTable(
    List<DateTime> dates,
    Map<DateTime, List<MealEntry>> byDay,
  ) {
    final rows = <pdf.TableRow>[
      pdf.TableRow(
        decoration: const pdf.BoxDecoration(color: _ink),
        children: [
          _tableHeader(tr('Date')),
          _tableHeader(tr('Breakfast')),
          _tableHeader(tr('Lunch')),
          _tableHeader(tr('Dinner')),
          _tableHeader(tr('Snacks')),
        ],
      ),
      for (final day in dates)
        pdf.TableRow(
          children: [
            _tableCell(
              '${DateFormat.E(RitualI18n.localeName).format(day)}\n${DateFormat.MMMd(RitualI18n.localeName).format(day)}',
              bold: true,
            ),
            _patternCell(byDay[day] ?? const [], MealType.breakfast),
            _patternCell(byDay[day] ?? const [], MealType.lunch),
            _patternCell(byDay[day] ?? const [], MealType.dinner),
            _patternCell(byDay[day] ?? const [], MealType.snack),
          ],
        ),
    ];
    return pdf.Table(
      border: pdf.TableBorder.all(color: _line, width: 0.6),
      columnWidths: const {
        0: pdf.FixedColumnWidth(52),
        1: pdf.FlexColumnWidth(),
        2: pdf.FlexColumnWidth(),
        3: pdf.FlexColumnWidth(),
        4: pdf.FlexColumnWidth(1.25),
      },
      children: rows,
    );
  }

  pdf.Widget _patternCell(List<MealEntry> entries, MealType type) {
    final matches = entries.where((entry) => entry.mealType == type).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (matches.isEmpty) return _tableCell('-');
    return _tableCell(matches.map(_patternEntryLabel).join('\n'));
  }

  String _patternEntryLabel(MealEntry entry) {
    final ratings = <String>[
      if (entry.hungerLevel != null) 'H${entry.hungerLevel}',
      if (entry.cravingLevel != null) 'C${entry.cravingLevel}',
      if (entry.fullnessLevel != null) 'F${entry.fullnessLevel}',
    ];
    final suffix = ratings.isEmpty ? '' : ' ${ratings.join('/')}';
    return '${DateFormat.jm().format(entry.createdAt)}$suffix';
  }

  pdf.Widget _tableHeader(String label) => pdf.Padding(
    padding: const pdf.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    child: pdf.Text(
      label,
      style: pdf.TextStyle(
        color: PdfColors.white,
        fontSize: 7.2,
        fontWeight: pdf.FontWeight.bold,
      ),
    ),
  );

  pdf.Widget _tableCell(String value, {bool bold = false}) => pdf.Padding(
    padding: const pdf.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    child: pdf.Text(
      _pdfSafe(value),
      style: pdf.TextStyle(
        color: _ink,
        fontSize: 7.1,
        lineSpacing: 1.5,
        fontWeight: bold ? pdf.FontWeight.bold : pdf.FontWeight.normal,
      ),
    ),
  );

  pdf.Widget _sectionHeading(String title, String subtitle) => pdf.Column(
    crossAxisAlignment: pdf.CrossAxisAlignment.start,
    children: [
      pdf.Text(
        title,
        style: pdf.TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: pdf.FontWeight.bold,
        ),
      ),
      pdf.SizedBox(height: 3),
      pdf.Text(
        subtitle,
        style: const pdf.TextStyle(color: _sage, fontSize: 8.5),
      ),
    ],
  );

  pdf.Widget _smallSectionTitle(String value) => pdf.Text(
    value,
    style: pdf.TextStyle(
      color: _ink,
      fontSize: 9,
      fontWeight: pdf.FontWeight.bold,
    ),
  );

  pdf.Widget _compactMetric(String value, String label) => pdf.Expanded(
    child: pdf.Container(
      margin: const pdf.EdgeInsets.only(right: 6),
      padding: const pdf.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: pdf.BoxDecoration(
        border: pdf.Border.all(color: _line),
        borderRadius: pdf.BorderRadius.circular(7),
      ),
      child: pdf.Row(
        children: [
          pdf.Text(
            value,
            style: pdf.TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: pdf.FontWeight.bold,
            ),
          ),
          pdf.SizedBox(width: 6),
          pdf.Text(label, style: const pdf.TextStyle(fontSize: 8)),
        ],
      ),
    ),
  );

  pdf.Widget _ratingMetric(
    String label,
    _RatingSummary summary,
  ) => pdf.Expanded(
    child: pdf.Container(
      padding: const pdf.EdgeInsets.all(8),
      decoration: pdf.BoxDecoration(
        border: pdf.Border.all(color: _line),
        borderRadius: pdf.BorderRadius.circular(7),
      ),
      child: pdf.Column(
        crossAxisAlignment: pdf.CrossAxisAlignment.start,
        children: [
          pdf.Text(
            label,
            style: pdf.TextStyle(
              fontSize: 8.2,
              fontWeight: pdf.FontWeight.bold,
            ),
          ),
          pdf.SizedBox(height: 4),
          pdf.Text(
            summary.count == 0
                ? tr('No responses')
                : tr(
                    'Mean {mean}/5  |  Range {minimum}-{maximum}  |  n={count}',
                    values: {
                      'mean': summary.mean.toStringAsFixed(1),
                      'minimum': summary.minimum,
                      'maximum': summary.maximum,
                      'count': summary.count,
                    },
                  ),
            style: const pdf.TextStyle(fontSize: 7.5, color: _sage),
          ),
        ],
      ),
    ),
  );

  pdf.Widget _overviewPanel(String value) => pdf.Container(
    width: double.infinity,
    padding: const pdf.EdgeInsets.all(8),
    decoration: pdf.BoxDecoration(
      border: pdf.Border.all(color: _line),
      borderRadius: pdf.BorderRadius.circular(7),
    ),
    child: pdf.Text(
      _pdfSafe(value),
      style: const pdf.TextStyle(fontSize: 7.8, lineSpacing: 2),
    ),
  );

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
    padding: const pdf.EdgeInsets.fromLTRB(9, 5, 9, 5),
    decoration: const pdf.BoxDecoration(
      color: _ink,
      borderRadius: pdf.BorderRadius.all(pdf.Radius.circular(7)),
    ),
    child: pdf.Row(
      mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
      children: [
        pdf.Text(
          DateFormat.yMMMMEEEEd(RitualI18n.localeName).format(day),
          style: pdf.TextStyle(
            color: PdfColors.white,
            fontSize: 9.5,
            fontWeight: pdf.FontWeight.bold,
          ),
        ),
        pdf.Text(
          trPlural(count, one: '{count} entry', other: '{count} entries'),
          style: const pdf.TextStyle(color: _paper, fontSize: 7.5),
        ),
      ],
    ),
  );

  List<pdf.Widget> _dayWidgets(DateTime day, List<_PdfMeal> meals) {
    final first = meals.first;
    final widgets = <pdf.Widget>[
      pdf.Inseparable(
        child: pdf.Column(
          crossAxisAlignment: pdf.CrossAxisAlignment.start,
          children: [
            _dayHeading(day, meals.length),
            pdf.SizedBox(height: 5),
            _mealHeaderCard(first),
          ],
        ),
      ),
      ..._reflectionWidgets(first),
      pdf.SizedBox(height: 5),
    ];
    for (final meal in meals.skip(1)) {
      widgets.add(_mealHeaderCard(meal));
      widgets.addAll(_reflectionWidgets(meal));
      widgets.add(pdf.SizedBox(height: 5));
    }
    widgets.add(pdf.SizedBox(height: 5));
    return widgets;
  }

  pdf.Widget _mealHeaderCard(_PdfMeal meal) {
    final entry = meal.entry;
    final details = <pdf.Widget>[
      pdf.Row(
        mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
        children: [
          pdf.Text(
            entry.mealType.label,
            style: pdf.TextStyle(fontSize: 10, fontWeight: pdf.FontWeight.bold),
          ),
          pdf.Text(
            DateFormat.jm(RitualI18n.localeName).format(entry.createdAt),
            style: const pdf.TextStyle(color: _sage, fontSize: 7.7),
          ),
        ],
      ),
    ];
    final ratings = <String>[
      if (entry.hungerLevel != null)
        tr('Hunger before {value}/5', values: {'value': entry.hungerLevel}),
      if (entry.cravingLevel != null)
        tr('Craving before {value}/5', values: {'value': entry.cravingLevel}),
      if (entry.fullnessLevel != null)
        tr('Fullness after {value}/5', values: {'value': entry.fullnessLevel}),
    ];
    if (ratings.isNotEmpty) {
      details.addAll([
        pdf.SizedBox(height: 3),
        pdf.Text(
          ratings.join('  |  '),
          style: pdf.TextStyle(
            color: _sage,
            fontSize: 7.4,
            fontWeight: pdf.FontWeight.bold,
          ),
        ),
      ]);
    }
    if (entry.feelings.isNotEmpty) {
      details.addAll([
        pdf.SizedBox(height: 3),
        _labeledText(tr('Feelings'), entry.feelings.map(tr).join(', ')),
      ]);
    }
    final place =
        entry.locationLabel ??
        (entry.hasLocation
            ? '${entry.latitude!.toStringAsFixed(4)}, ${entry.longitude!.toStringAsFixed(4)}'
            : null);
    if (place != null) {
      details.addAll([
        pdf.SizedBox(height: 3),
        _labeledText(tr('Place'), place),
      ]);
    }

    return pdf.Container(
      padding: const pdf.EdgeInsets.all(6),
      decoration: pdf.BoxDecoration(
        border: pdf.Border.all(color: _line),
        borderRadius: pdf.BorderRadius.circular(8),
      ),
      child: pdf.Row(
        crossAxisAlignment: pdf.CrossAxisAlignment.start,
        children: [
          pdf.Container(
            width: 56,
            height: 42,
            decoration: pdf.BoxDecoration(
              color: _paper,
              borderRadius: pdf.BorderRadius.circular(6),
            ),
            child: meal.photo == null
                ? pdf.Center(
                    child: pdf.Text(
                      tr('Photo\nunavailable'),
                      textAlign: pdf.TextAlign.center,
                      style: const pdf.TextStyle(color: _sage, fontSize: 6.3),
                    ),
                  )
                : pdf.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pdf.Image(meal.photo!, fit: pdf.BoxFit.cover),
                  ),
          ),
          pdf.SizedBox(width: 7),
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

  List<pdf.Widget> _reflectionWidgets(_PdfMeal meal) {
    final note = meal.entry.note.trim();
    if (note.isEmpty) return const [];
    final chunks = _flowingTextChunks(_pdfSafe(note));
    return [
      pdf.SizedBox(height: 3),
      pdf.Inseparable(
        child: pdf.Column(
          crossAxisAlignment: pdf.CrossAxisAlignment.start,
          children: [
            pdf.Text(
              tr('Reflection'),
              style: pdf.TextStyle(
                color: _sage,
                fontSize: 7.4,
                fontWeight: pdf.FontWeight.bold,
              ),
            ),
            pdf.SizedBox(height: 2),
            pdf.RichText(
              text: pdf.TextSpan(
                text: chunks.first,
                style: const pdf.TextStyle(
                  color: _ink,
                  fontSize: 7.7,
                  lineSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
      for (final chunk in chunks.skip(1))
        pdf.RichText(
          text: pdf.TextSpan(
            text: chunk,
            style: const pdf.TextStyle(
              color: _ink,
              fontSize: 7.7,
              lineSpacing: 2,
            ),
          ),
        ),
    ];
  }

  List<String> _flowingTextChunks(String value, {int maximumLength = 1200}) {
    if (value.length <= maximumLength) return [value];
    final chunks = <String>[];
    var remaining = value;
    while (remaining.length > maximumLength) {
      var split = remaining.lastIndexOf('\n', maximumLength);
      if (split < maximumLength ~/ 2) {
        split = remaining.lastIndexOf(' ', maximumLength);
      }
      if (split < 1) split = maximumLength;
      chunks.add(remaining.substring(0, split + 1));
      remaining = remaining.substring(split + 1);
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks;
  }

  pdf.Widget _labeledText(String label, String value) => pdf.RichText(
    text: pdf.TextSpan(
      style: const pdf.TextStyle(fontSize: 7.5, color: _ink),
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
        .replaceAll('…', '...')
        .replaceAll(' ', ' ')
        .replaceAll(' ', ' ');
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

class _RatingSummary {
  const _RatingSummary({
    required this.mean,
    required this.minimum,
    required this.maximum,
    required this.count,
  });

  const _RatingSummary.empty() : mean = 0, minimum = 0, maximum = 0, count = 0;

  final double mean;
  final int minimum;
  final int maximum;
  final int count;

  factory _RatingSummary.fromValues(Iterable<int?> source) {
    final values = source.whereType<int>().toList();
    if (values.isEmpty) return const _RatingSummary.empty();
    values.sort();
    return _RatingSummary(
      mean: values.reduce((left, right) => left + right) / values.length,
      minimum: values.first,
      maximum: values.last,
      count: values.length,
    );
  }
}

class _FeelingCount {
  const _FeelingCount(this.label, this.count);

  final String label;
  final int count;
}

class _JournalOverview {
  const _JournalOverview({
    required this.periodDays,
    required this.coveragePercent,
    required this.mealCounts,
    required this.hunger,
    required this.craving,
    required this.fullness,
    required this.topFeelings,
    required this.feelingEntryCount,
    required this.noteCount,
    required this.locationCount,
    required this.longestUnloggedRun,
    required this.timingMinutes,
    required this.highHungerCount,
    required this.highHungerResponses,
  });

  final int periodDays;
  final double coveragePercent;
  final Map<MealType, int> mealCounts;
  final _RatingSummary hunger;
  final _RatingSummary craving;
  final _RatingSummary fullness;
  final List<_FeelingCount> topFeelings;
  final int feelingEntryCount;
  final int noteCount;
  final int locationCount;
  final int longestUnloggedRun;
  final Map<MealType, List<int>> timingMinutes;
  final int highHungerCount;
  final int highHungerResponses;

  factory _JournalOverview.fromEntries(
    List<MealEntry> entries,
    JournalExportRange range,
  ) {
    final periodDays = range.end.difference(range.start).inDays + 1;
    final loggedDays = entries
        .map(
          (entry) => DateTime(
            entry.createdAt.year,
            entry.createdAt.month,
            entry.createdAt.day,
          ),
        )
        .toSet();
    final mealCounts = {for (final type in MealType.values) type: 0};
    final timingMinutes = {for (final type in MealType.values) type: <int>[]};
    final feelingCounts = <String, int>{};
    var feelingEntryCount = 0;
    var noteCount = 0;
    var locationCount = 0;
    var highHungerCount = 0;
    var highHungerResponses = 0;
    for (final entry in entries) {
      mealCounts.update(entry.mealType, (count) => count + 1);
      timingMinutes[entry.mealType]!.add(
        entry.createdAt.hour * 60 + entry.createdAt.minute,
      );
      final feelings = entry.feelings
          .map((feeling) => feeling.trim())
          .where((feeling) => feeling.isNotEmpty)
          .toSet();
      if (feelings.isNotEmpty) feelingEntryCount++;
      for (final feeling in feelings) {
        feelingCounts.update(feeling, (count) => count + 1, ifAbsent: () => 1);
      }
      if (entry.note.trim().isNotEmpty) noteCount++;
      if ((entry.locationLabel?.trim().isNotEmpty ?? false) ||
          entry.hasLocation) {
        locationCount++;
      }
      if (entry.hungerLevel != null) {
        highHungerResponses++;
        if (entry.hungerLevel! >= 4) highHungerCount++;
      }
    }
    final rankedFeelings = feelingCounts.entries.toList()
      ..sort((left, right) {
        final byCount = right.value.compareTo(left.value);
        return byCount != 0 ? byCount : left.key.compareTo(right.key);
      });

    var currentGap = 0;
    var longestGap = 0;
    for (
      var day = range.start;
      !day.isAfter(range.end);
      day = day.add(const Duration(days: 1))
    ) {
      if (loggedDays.contains(day)) {
        currentGap = 0;
      } else {
        currentGap++;
        if (currentGap > longestGap) longestGap = currentGap;
      }
    }
    for (final values in timingMinutes.values) {
      values.sort();
    }

    return _JournalOverview(
      periodDays: periodDays,
      coveragePercent: periodDays == 0
          ? 0
          : loggedDays.length / periodDays * 100,
      mealCounts: mealCounts,
      hunger: _RatingSummary.fromValues(
        entries.map((entry) => entry.hungerLevel),
      ),
      craving: _RatingSummary.fromValues(
        entries.map((entry) => entry.cravingLevel),
      ),
      fullness: _RatingSummary.fromValues(
        entries.map((entry) => entry.fullnessLevel),
      ),
      topFeelings: rankedFeelings
          .take(3)
          .map((entry) => _FeelingCount(entry.key, entry.value))
          .toList(),
      feelingEntryCount: feelingEntryCount,
      noteCount: noteCount,
      locationCount: locationCount,
      longestUnloggedRun: longestGap,
      timingMinutes: timingMinutes,
      highHungerCount: highHungerCount,
      highHungerResponses: highHungerResponses,
    );
  }

  String timingLabel(MealType type) {
    final values = timingMinutes[type] ?? const [];
    if (values.isEmpty) return tr('No entries');
    return tr(
      '{start} - {end} (n={count})',
      values: {
        'start': _formatMinutes(values.first),
        'end': _formatMinutes(values.last),
        'count': values.length,
      },
    );
  }

  List<String> get reviewCues {
    final cues = <String>[
      longestUnloggedRun == 0
          ? tr(
              'At least one entry was recorded on every day in the selected period.',
            )
          : trPlural(
              longestUnloggedRun,
              one:
                  'The longest stretch without a recorded entry was {count} day.',
              other:
                  'The longest stretch without a recorded entry was {count} days.',
            ),
    ];
    if (highHungerResponses == 0) {
      cues.add(tr('Hunger before eating was not recorded in this period.'));
    } else {
      cues.add(
        tr(
          'Hunger before eating was rated 4-5 on {highCount} of {responseCount} rated entries.',
          values: {
            'highCount': highHungerCount,
            'responseCount': highHungerResponses,
          },
        ),
      );
    }
    if (topFeelings.isEmpty) {
      cues.add(tr('No feelings were recorded in this period.'));
    } else {
      final top = topFeelings.first;
      cues.add(
        tr(
          "The most frequently selected feeling was '{feeling}', appearing on {entries}.",
          values: {
            'feeling': tr(top.label),
            'entries': trPlural(
              top.count,
              one: '{count} entry',
              other: '{count} entries',
            ),
          },
        ),
      );
    }
    return cues;
  }

  static String _formatMinutes(int value) {
    final hour = value ~/ 60;
    final minute = value % 60;
    return DateFormat.jm(
      RitualI18n.localeName,
    ).format(DateTime(2000, 1, 1, hour, minute));
  }
}
