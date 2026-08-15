import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/services/journal_archive_service.dart';

void main() {
  late Directory temporaryDirectory;
  late JournalArchiveService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'ritual-archive-test-',
    );
    service = JournalArchiveService();
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'disk-backed archive round trips every field and exact photos',
    () async {
      final firstBytes = Uint8List.fromList([0, 1, 2, 3, 254, 255]);
      final secondBytes = Uint8List.fromList(
        List.generate(512, (index) => index % 251),
      );
      final firstPhoto = await _photo(
        temporaryDirectory,
        'first.jpg',
        firstBytes,
      );
      final secondPhoto = await _photo(
        temporaryDirectory,
        'second.png',
        secondBytes,
      );
      final entries = [
        MealEntry(
          id: 7,
          imagePath: firstPhoto.path,
          mealType: MealType.breakfast,
          feelings: const ['Happy', 'Calm'],
          note: 'Quiet morning',
          createdAt: DateTime(2026, 8, 11, 8, 45),
          latitude: 39.9612,
          longitude: -82.9988,
          locationLabel: 'Ohio',
          hungerLevel: 4,
          fullnessLevel: 3,
          cravingLevel: 2,
        ),
        MealEntry(
          id: 8,
          imagePath: secondPhoto.path,
          mealType: MealType.snack,
          feelings: const [],
          note: '',
          createdAt: DateTime(2026, 8, 10, 16, 30),
        ),
      ];

      final exported = await service.createArchiveFile(
        entries,
        outputPath: '${temporaryDirectory.path}/standard.zip',
        exportedAt: DateTime.utc(2026, 8, 11),
      );
      final preview = await service.readArchiveFile(exported.filePath);
      addTearDown(preview.dispose);
      final imported = preview.entries;

      expect(exported.fileName, 'ritual-export-2026-08-11.zip');
      expect(exported.entryCount, 2);
      expect(exported.encrypted, isFalse);
      expect(imported, hasLength(2));
      expect(imported[0].draft.mealType, MealType.breakfast);
      expect(imported[0].draft.feelings, ['Happy', 'Calm']);
      expect(imported[0].draft.note, 'Quiet morning');
      expect(imported[0].draft.createdAt, DateTime(2026, 8, 11, 8, 45));
      expect(imported[0].draft.latitude, 39.9612);
      expect(imported[0].draft.longitude, -82.9988);
      expect(imported[0].draft.locationLabel, 'Ohio');
      expect(imported[0].draft.hungerLevel, 4);
      expect(imported[0].draft.fullnessLevel, 3);
      expect(imported[0].draft.cravingLevel, 2);
      expect(await File(imported[0].photoPath).readAsBytes(), firstBytes);
      expect(imported[0].photoExtension, '.jpg');
      expect(imported[1].draft.mealType, MealType.snack);
      expect(imported[1].draft.latitude, isNull);
      expect(imported[1].draft.locationLabel, isNull);
      expect(await File(imported[1].photoPath).readAsBytes(), secondBytes);
      expect(imported[1].fingerprint, isNotEmpty);
    },
  );

  test('AES-256 ZIP requires the exact export password', () async {
    final photo = await _photo(
      temporaryDirectory,
      'private.jpg',
      Uint8List.fromList([1, 2, 3, 4]),
    );
    final exported = await service.createArchiveFile(
      [_entry(photo.path)],
      outputPath: '${temporaryDirectory.path}/encrypted.zip',
      password: 'correct horse battery staple',
      exportedAt: DateTime.utc(2026, 8, 11),
    );

    expect(exported.encrypted, isTrue);
    expect(exported.fileName, contains('-encrypted.zip'));
    expect(await service.isEncryptedArchiveFile(exported.filePath), isTrue);
    await expectLater(
      service.readArchiveFile(exported.filePath),
      throwsA(
        isA<RitualArchiveException>().having(
          (error) => error.message,
          'message',
          contains('requires'),
        ),
      ),
    );
    await expectLater(
      service.readArchiveFile(exported.filePath, password: 'wrong password!'),
      throwsA(isA<RitualArchiveException>()),
    );

    final preview = await service.readArchiveFile(
      exported.filePath,
      password: 'correct horse battery staple',
    );
    expect(preview.entries, hasLength(1));
    await preview.dispose();
  });

  test('refuses short archive passwords', () async {
    final photo = await _photo(
      temporaryDirectory,
      'valid.jpg',
      Uint8List.fromList([1]),
    );
    await expectLater(
      service.createArchiveFile(
        [_entry(photo.path)],
        outputPath: '${temporaryDirectory.path}/short.zip',
        password: 'too-short',
      ),
      throwsA(isA<RitualArchiveException>()),
    );
  });

  test('refuses to export if any referenced photo is missing', () async {
    final entry = _entry('${temporaryDirectory.path}/missing.jpg');
    await expectLater(
      service.createArchiveFile([
        entry,
      ], outputPath: '${temporaryDirectory.path}/missing.zip'),
      throwsA(isA<RitualArchiveException>()),
    );
  });

  test('rejects an unsupported schema before importing', () async {
    final file = await _validArchiveFile(temporaryDirectory, service);
    await _rewriteArchive(file, (manifest) => manifest['schemaVersion'] = 999);
    await expectLater(
      service.readArchiveFile(file.path),
      throwsA(
        isA<RitualArchiveException>().having(
          (error) => error.message,
          'message',
          contains('unsupported'),
        ),
      ),
    );
  });

  test('rejects missing and corrupted photos', () async {
    final missingFile = await _validArchiveFile(temporaryDirectory, service);
    await _rebuildArchive(missingFile, (file, rebuilt) {
      if (!file.name.startsWith('photos/')) {
        rebuilt.add(ArchiveFile.bytes(file.name, file.content));
      }
    });
    await expectLater(
      service.readArchiveFile(missingFile.path),
      throwsA(isA<RitualArchiveException>()),
    );

    final corruptFile = await _validArchiveFile(
      temporaryDirectory,
      service,
      name: 'corrupt.zip',
    );
    await _rebuildArchive(corruptFile, (file, rebuilt) {
      final content = Uint8List.fromList(file.content);
      if (file.name.startsWith('photos/')) content[0] ^= 0xff;
      rebuilt.add(ArchiveFile.bytes(file.name, content));
    });
    await expectLater(
      service.readArchiveFile(corruptFile.path),
      throwsA(
        isA<RitualArchiveException>().having(
          (error) => error.message,
          'message',
          contains('failed verification'),
        ),
      ),
    );
  });

  test('rejects path traversal and invalid manifests', () async {
    final unsafeFile = await _validArchiveFile(temporaryDirectory, service);
    await _rebuildArchive(
      unsafeFile,
      (file, rebuilt) {
        rebuilt.add(ArchiveFile.bytes(file.name, file.content));
      },
      after: (rebuilt) {
        rebuilt.add(ArchiveFile.bytes('../outside.jpg', [1, 2, 3]));
      },
    );
    await expectLater(
      service.readArchiveFile(unsafeFile.path),
      throwsA(
        isA<RitualArchiveException>().having(
          (error) => error.message,
          'message',
          contains('unsafe'),
        ),
      ),
    );

    final invalid = File('${temporaryDirectory.path}/invalid.zip');
    final archive = Archive()
      ..add(ArchiveFile.string('ritual-export.json', '{not json'));
    await invalid.writeAsBytes(ZipEncoder().encodeBytes(archive));
    await expectLater(
      service.readArchiveFile(invalid.path),
      throwsA(isA<RitualArchiveException>()),
    );
  });
}

Future<File> _photo(Directory directory, String name, Uint8List bytes) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(bytes);
  return file;
}

MealEntry _entry(String imagePath) => MealEntry(
  id: 1,
  imagePath: imagePath,
  mealType: MealType.lunch,
  feelings: const ['Satisfied'],
  note: 'A note',
  createdAt: DateTime(2026, 8, 11, 12),
);

Future<File> _validArchiveFile(
  Directory directory,
  JournalArchiveService service, {
  String name = 'valid.zip',
}) async {
  final photo = await _photo(
    directory,
    '$name.jpg',
    Uint8List.fromList([1, 2, 3, 4]),
  );
  return File(
    (await service.createArchiveFile([
      _entry(photo.path),
    ], outputPath: '${directory.path}/$name')).filePath,
  );
}

Future<void> _rewriteArchive(
  File target,
  void Function(Map<String, dynamic>) change,
) => _rebuildArchive(target, (file, rebuilt) {
  if (file.name == 'ritual-export.json') {
    final manifest =
        jsonDecode(utf8.decode(file.content)) as Map<String, dynamic>;
    change(manifest);
    rebuilt.add(ArchiveFile.string(file.name, jsonEncode(manifest)));
  } else {
    rebuilt.add(ArchiveFile.bytes(file.name, file.content));
  }
});

Future<void> _rebuildArchive(
  File target,
  void Function(ArchiveFile file, Archive rebuilt) copy, {
  void Function(Archive rebuilt)? after,
}) async {
  final decoded = ZipDecoder().decodeBytes(await target.readAsBytes());
  final rebuilt = Archive();
  for (final file in decoded) {
    copy(file, rebuilt);
  }
  after?.call(rebuilt);
  await target.writeAsBytes(ZipEncoder().encodeBytes(rebuilt), flush: true);
}
