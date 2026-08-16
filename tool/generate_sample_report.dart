import 'dart:io';

import 'package:image/image.dart' as image;
import 'package:ritual/models/journal_export.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/services/journal_csv_service.dart';
import 'package:ritual/services/journal_pdf_service.dart';

Future<void> main() async {
  final temporary = await Directory.systemTemp.createTemp('ritual-report-qa-');
  try {
    final entries = <MealEntry>[];
    final moments = [
      (MealType.breakfast, DateTime(2026, 8, 10, 8, 15), 0xffd6a56f),
      (MealType.lunch, DateTime(2026, 8, 10, 13, 5), 0xff77917b),
      (MealType.dinner, DateTime(2026, 8, 10, 19, 20), 0xffb86652),
      (MealType.breakfast, DateTime(2026, 8, 11, 8, 40), 0xffe0bd65),
      (MealType.snack, DateTime(2026, 8, 11, 15, 10), 0xff8c789c),
      (MealType.snack, DateTime(2026, 8, 11, 17, 45), 0xff6f8da8),
      (MealType.dinner, DateTime(2026, 8, 12, 20, 5), 0xff9d7554),
    ];
    for (final (index, moment) in moments.indexed) {
      final photo = File('${temporary.path}/meal-$index.jpg');
      final canvas = image.Image(width: 640, height: 480);
      image.fill(
        canvas,
        color: image.ColorRgb8(
          (moment.$3 >> 16) & 0xff,
          (moment.$3 >> 8) & 0xff,
          moment.$3 & 0xff,
        ),
      );
      await photo.writeAsBytes(image.encodeJpg(canvas, quality: 86));
      entries.add(
        MealEntry(
          id: index + 1,
          imagePath: photo.path,
          mealType: moment.$1,
          feelings: index.isEven
              ? const ['Calm', 'Satisfied']
              : const ['Happy', 'Social'],
          note: index == 1
              ? 'A relaxed meal with enough time to notice the flavors.'
              : index == 4
              ? 'Quick snack, eaten outside.\nI felt more settled afterward.'
              : index == 6
              ? List.generate(
                  12,
                  (line) =>
                      'Reflection ${line + 1}: I noticed a different part of the meal and recorded enough context to discuss it later.',
                ).join('\n')
              : '',
          createdAt: moment.$2,
          locationLabel: index < 3 ? 'Home' : 'Neighborhood cafe, downtown',
          hungerLevel: 3 + index % 2,
          cravingLevel: 2 + index % 3,
          fullnessLevel: 3 + index % 2,
        ),
      );
    }

    final range = JournalExportRange(
      start: DateTime(2026, 8, 6),
      end: DateTime(2026, 8, 12),
    );
    final report = await JournalPdfService().createReport(
      entries,
      generatedAt: DateTime(2026, 8, 12, 10, 30),
      range: range,
    );
    final output = Directory('output/pdf');
    await output.create(recursive: true);
    await File(
      '${output.path}/ritual-sample-journal-report.pdf',
    ).writeAsBytes(report.bytes, flush: true);

    final csv = JournalCsvService().createReport(entries, range: range);
    final csvOutput = Directory('output/csv');
    await csvOutput.create(recursive: true);
    await File(
      '${csvOutput.path}/ritual-sample-journal.csv',
    ).writeAsBytes(csv.bytes, flush: true);
  } finally {
    await temporary.delete(recursive: true);
  }
}
