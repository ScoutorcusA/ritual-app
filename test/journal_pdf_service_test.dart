import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:ritual/models/journal_export.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/services/journal_pdf_service.dart';

void main() {
  test('creates a journal-pattern PDF with every journal field', () async {
    final directory = await Directory.systemTemp.createTemp('ritual-pdf-test-');
    addTearDown(() => directory.delete(recursive: true));
    final photo = File('${directory.path}/meal.jpg');
    await photo.writeAsBytes(
      image.encodeJpg(image.Image(width: 320, height: 240)),
    );
    final service = JournalPdfService();

    final result = await service.createReport(
      [
        MealEntry(
          id: 1,
          imagePath: photo.path,
          mealType: MealType.lunch,
          feelings: const ['Happy', 'Satisfied'],
          note: 'Lunch with a friend',
          createdAt: DateTime(2026, 8, 12, 12, 30),
          locationLabel: 'Home',
          hungerLevel: 4,
          cravingLevel: 2,
          fullnessLevel: 3,
        ),
      ],
      generatedAt: DateTime(2026, 8, 13, 10),
      range: JournalExportRange(
        start: DateTime(2026, 8, 6),
        end: DateTime(2026, 8, 12),
      ),
    );

    expect(result.entryCount, 1);
    expect(result.fileName, 'ritual-journal-2026-08-06-to-2026-08-12.pdf');
    expect(String.fromCharCodes(result.bytes.take(5)), '%PDF-');
    expect(result.bytes.length, greaterThan(1000));
  });

  test('excludes entries outside the selected period', () async {
    final result = await JournalPdfService().createReport(
      [
        MealEntry(
          id: 1,
          imagePath: '/missing.jpg',
          mealType: MealType.breakfast,
          feelings: const [],
          note: '',
          createdAt: DateTime(2026, 8, 5),
        ),
      ],
      generatedAt: DateTime(2026, 8, 13),
      range: JournalExportRange(
        start: DateTime(2026, 8, 6),
        end: DateTime(2026, 8, 12),
      ),
    );

    expect(result.entryCount, 0);
  });

  test(
    'supports repeated snacks and long reflections without truncation',
    () async {
      final longReflection = List.generate(
        80,
        (index) =>
            'Reflection line ${index + 1}: context, appetite, feelings, and what changed after eating.',
      ).join('\n');
      final entries = <MealEntry>[
        for (var index = 0; index < 4; index++)
          MealEntry(
            id: index + 1,
            imagePath: '/missing-$index.jpg',
            mealType: MealType.snack,
            feelings: const ['Calm'],
            note: index == 2 ? longReflection : 'Snack ${index + 1}',
            createdAt: DateTime(2026, 8, 12, 9 + index * 2, 15),
            hungerLevel: 2 + index % 3,
            cravingLevel: 1 + index % 4,
            fullnessLevel: 3,
          ),
      ];

      final result = await JournalPdfService().createReport(
        entries,
        generatedAt: DateTime(2026, 8, 13, 10),
        range: JournalExportRange(
          start: DateTime(2026, 8, 6),
          end: DateTime(2026, 8, 12),
        ),
      );

      expect(result.entryCount, 4);
      expect(String.fromCharCodes(result.bytes.take(5)), '%PDF-');
      expect(result.bytes.length, greaterThan(3000));
    },
  );
}
