import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/services/journal_pdf_service.dart';

void main() {
  test('creates a clinician PDF with every journal field', () async {
    final directory = await Directory.systemTemp.createTemp('ritual-pdf-test-');
    addTearDown(() => directory.delete(recursive: true));
    final photo = File('${directory.path}/meal.jpg');
    await photo.writeAsBytes(
      image.encodeJpg(image.Image(width: 320, height: 240)),
    );
    final service = JournalPdfService();

    final result = await service.createReport([
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
    ], generatedAt: DateTime(2026, 8, 13, 10));

    expect(result.entryCount, 1);
    expect(result.fileName, 'ritual-clinician-report-2026-08-13.pdf');
    expect(String.fromCharCodes(result.bytes.take(5)), '%PDF-');
    expect(result.bytes.length, greaterThan(1000));
  });
}
