import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual/controllers/journal_controller.dart';
import 'package:ritual/data/meal_repository.dart';
import 'package:ritual/models/journal_export.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/screens/browse_screen.dart';
import 'package:ritual/screens/journal_screen.dart';
import 'package:ritual/services/journal_archive_service.dart';
import 'package:ritual/services/journal_csv_service.dart';
import 'package:ritual/services/journal_pdf_service.dart';
import 'package:ritual/theme/ritual_theme.dart';

const _entryCount = 1000;
const _stressDatabase = 'ritual_stress.db';
const _stressPhotos = 'ritual_stress_photos';
const _restoreDatabase = 'ritual_stress_restore.db';
const _restorePhotos = 'ritual_stress_restore_photos';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1,000-entry device stress test', (tester) async {
    final stressIssues = <String>[];
    final repository = SqliteMealRepository(
      databaseName: _stressDatabase,
      photoDirectoryName: _stressPhotos,
    );
    final restoreRepository = SqliteMealRepository(
      databaseName: _restoreDatabase,
      photoDirectoryName: _restorePhotos,
    );
    final controller = JournalController(repository);
    final restoreController = JournalController(restoreRepository);
    addTearDown(() async {
      controller.dispose();
      restoreController.dispose();
      await repository.deleteAllJournalData();
      await restoreRepository.deleteAllJournalData();
      await tester.binding.setSurfaceSize(null);
    });

    await repository.deleteAllJournalData();
    await restoreRepository.deleteAllJournalData();
    final photoBytes = _syntheticPhoto();
    final imports = _syntheticImports(photoBytes);

    final imported = await _timed('sqlite_import_1000', () {
      return repository.importEntries(imports);
    });
    expect(imported, hasLength(_entryCount));

    await _timed('controller_initialize_1000', controller.initialize);
    expect(controller.error, isNull);
    expect(controller.entries, hasLength(_entryCount));
    if (controller.bestStreak != 500 || controller.currentStreak != 500) {
      stressIssues.add(
        'Continuous 500-day journal reported current='
        '${controller.currentStreak}, best=${controller.bestStreak}.',
      );
    }

    final duplicateCount = await _timed('duplicate_import_1000', () {
      return controller.importEntries(imports);
    });
    expect(duplicateCount, 0);
    expect(controller.entries, hasLength(_entryCount));

    final temporaryPhoto = File(
      '${Directory.systemTemp.path}/ritual_stress_new_entry.jpg',
    );
    await temporaryPhoto.writeAsBytes(photoBytes, flush: true);
    final keptPhoto = await controller.keepCapturedPhoto(
      XFile(temporaryPhoto.path),
    );
    final addedAtScale = await _timed('single_add_at_1000', () {
      return controller.addEntry(
        MealDraft(
          imagePath: keptPhoto,
          mealType: MealType.snack,
          feelings: const ['Calm'],
          note: 'Synthetic entry added after the journal reached 1,000.',
          createdAt: DateTime(2026, 8, 14, 21),
          hungerLevel: 3,
          cravingLevel: 2,
          fullnessLevel: 4,
        ),
      );
    });
    expect(controller.entries, hasLength(_entryCount + 1));
    await _timed('single_delete_at_1001', () {
      return controller.deleteEntry(addedAtScale.entry);
    });
    expect(controller.entries, hasLength(_entryCount));

    final middleEntry = controller.entries[_entryCount ~/ 2];
    await _timed('single_update_at_1000', () {
      return controller.updateEntry(
        middleEntry.copyWith(note: 'Updated synthetic stress reflection.'),
      );
    });
    expect(
      controller.entries
          .singleWhere((entry) => entry.id == middleEntry.id)
          .note,
      'Updated synthetic stress reflection.',
    );

    final oldest = controller.entries.last.createdAt;
    final newest = controller.entries.first.createdAt;
    final range = JournalExportRange(start: oldest, end: newest);
    final csv = await _timed('csv_export_1000', () async {
      return JournalCsvService().createReport(controller.entries, range: range);
    });
    expect(csv.entryCount, _entryCount);
    expect(csv.bytes.length, greaterThan(100000));
    debugPrint('RITUAL_STRESS csv_bytes=${csv.bytes.length}');

    final archive = await _timed('zip_export_1000', () {
      return JournalArchiveService().createArchive(
        controller.entries,
        exportedAt: DateTime.utc(2026, 8, 14),
      );
    });
    expect(archive.entryCount, _entryCount);
    expect(archive.bytes, isNotEmpty);
    debugPrint('RITUAL_STRESS zip_bytes=${archive.bytes.length}');

    final restoredImports = await _timed('zip_verify_1000', () async {
      return JournalArchiveService().readArchive(archive.bytes);
    });
    expect(restoredImports, hasLength(_entryCount));
    final restored = await _timed('sqlite_restore_1000', () {
      return restoreRepository.importEntries(restoredImports);
    });
    expect(restored, hasLength(_entryCount));
    await _timed('restored_controller_initialize_1000', () {
      return restoreController.initialize();
    });
    expect(restoreController.entries, hasLength(_entryCount));
    await _timed('delete_all_restored_1000', () {
      return restoreController.deleteAllJournalData();
    });
    expect(await restoreRepository.loadEntries(), isEmpty);

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await _timed('journal_first_frame_1000', () async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ritualTheme(),
          home: Scaffold(
            body: JournalScreen(controller: controller, onSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
    expect(find.text('1000'), findsOneWidget);
    _expectNoFlutterException(tester, 'journal first frame');
    await _stressScroll(
      tester,
      find.byType(CustomScrollView),
      passes: 14,
      metric: 'journal_scroll_14_passes',
    );

    await _timed('gallery_first_frame_1000', () async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ritualTheme(),
          home: Scaffold(body: BrowseScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
    });
    expect(find.text('1000 moments'), findsOneWidget);
    _expectNoFlutterException(tester, 'gallery first frame');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Breakfast'));
    await tester.pumpAndSettle();
    expect(find.text('250 moments'), findsOneWidget);
    _expectNoFlutterException(tester, 'gallery filtering');
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('1000 moments'), findsOneWidget);

    await _stressScroll(
      tester,
      find.byType(CustomScrollView),
      passes: 18,
      metric: 'gallery_scroll_18_passes',
    );
    await _jumpToStart(tester);

    await _timed('calendar_first_frame_1000', () async {
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
    });
    expect(find.text('1000 moments'), findsOneWidget);
    _expectNoFlutterException(tester, 'calendar first frame');
    await _stressScroll(
      tester,
      find.byType(CustomScrollView),
      passes: 12,
      metric: 'calendar_scroll_12_passes',
    );

    try {
      final pdf = await _timed('pdf_export_1000', () {
        return JournalPdfService().createReport(
          controller.entries,
          generatedAt: DateTime(2026, 8, 14, 12),
          range: range,
        );
      });
      expect(pdf.entryCount, _entryCount);
      expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
      debugPrint('RITUAL_STRESS pdf_bytes=${pdf.bytes.length}');
    } catch (error, stackTrace) {
      stressIssues.add('1,000-entry PDF export failed: $error');
      debugPrint('RITUAL_STRESS pdf_failure=$error\n$stackTrace');
    }

    expect(
      stressIssues,
      isEmpty,
      reason: 'Stress test found:\n${stressIssues.join('\n')}',
    );
  });
}

Future<void> _jumpToStart(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.byType(Scrollable),
  );
  final state = tester.state<ScrollableState>(scrollable);
  state.position.jumpTo(0);
  await tester.pumpAndSettle();
}

Uint8List _syntheticPhoto() {
  final photo = image.Image(width: 640, height: 480);
  return Uint8List.fromList(image.encodeJpg(photo, quality: 78));
}

List<MealImport> _syntheticImports(Uint8List photoBytes) {
  final anchor = DateTime(2026, 8, 14);
  return List.generate(_entryCount, (index) {
    final day = DateTime(anchor.year, anchor.month, anchor.day - (index ~/ 2));
    final createdAt = DateTime(
      day.year,
      day.month,
      day.day,
      index.isEven ? 8 : 18,
      index % 60,
    );
    final type = MealType.values[index % MealType.values.length];
    final formulaProbe = index % 100 == 0 ? '=SUM(1,1) ' : '';
    return MealImport(
      draft: MealDraft(
        imagePath: '',
        mealType: type,
        feelings: [
          feelingLabels[index % feelingLabels.length],
          feelingLabels[(index + 3) % feelingLabels.length],
        ],
        note:
            '${formulaProbe}Synthetic entry $index with commas, "quotes", '
            'and a second line.\nNo real journal data is used.',
        createdAt: createdAt,
        latitude: index % 3 == 0 ? 39.9612 : null,
        longitude: index % 3 == 0 ? -82.9988 : null,
        locationLabel: index % 3 == 0 ? 'Synthetic kitchen' : null,
        hungerLevel: (index % 5) + 1,
        cravingLevel: ((index + 1) % 5) + 1,
        fullnessLevel: ((index + 2) % 5) + 1,
      ),
      photoBytes: photoBytes,
      photoExtension: '.jpg',
      fingerprint: 'ritual-stress-${index.toString().padLeft(4, '0')}',
    );
  }, growable: false);
}

Future<T> _timed<T>(String name, Future<T> Function() operation) async {
  final stopwatch = Stopwatch()..start();
  final before = ProcessInfo.currentRss;
  try {
    return await operation();
  } finally {
    stopwatch.stop();
    final after = ProcessInfo.currentRss;
    debugPrint(
      'RITUAL_STRESS $name '
      'milliseconds=${stopwatch.elapsedMilliseconds} '
      'rss_before_mb=${(before / 1048576).toStringAsFixed(1)} '
      'rss_after_mb=${(after / 1048576).toStringAsFixed(1)}',
    );
  }
}

Future<void> _stressScroll(
  WidgetTester tester,
  Finder scrollable, {
  required int passes,
  required String metric,
}) async {
  await _timed(metric, () async {
    for (var index = 0; index < passes; index++) {
      await tester.fling(scrollable, const Offset(0, -700), 5000);
      await tester.pumpAndSettle();
      _expectNoFlutterException(tester, '$metric pass $index');
    }
  });
}

void _expectNoFlutterException(WidgetTester tester, String phase) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: 'Flutter exception during $phase');
}
