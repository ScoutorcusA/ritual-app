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

  test('round trips every entry field and exact photo bytes', () async {
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

    final exported = await service.createArchive(
      entries,
      exportedAt: DateTime.utc(2026, 8, 11),
    );
    final imported = service.readArchive(exported.bytes);

    expect(exported.fileName, 'ritual-export-2026-08-11.zip');
    expect(exported.entryCount, 2);
    expect(imported, hasLength(2));
    expect(imported[0].draft.mealType, MealType.breakfast);
    expect(imported[0].draft.feelings, ['Happy', 'Calm']);
    expect(imported[0].draft.note, 'Quiet morning');
    expect(imported[0].draft.createdAt, DateTime(2026, 8, 11, 8, 45));
    expect(imported[0].draft.latitude, 39.9612);
    expect(imported[0].draft.longitude, -82.9988);
    expect(imported[0].draft.locationLabel, 'Ohio');
    expect(imported[0].photoBytes, firstBytes);
    expect(imported[0].photoExtension, '.jpg');
    expect(imported[1].draft.mealType, MealType.snack);
    expect(imported[1].draft.latitude, isNull);
    expect(imported[1].draft.locationLabel, isNull);
    expect(imported[1].photoBytes, secondBytes);
    expect(imported[1].fingerprint, isNotEmpty);
  });

  test('refuses to export if any referenced photo is missing', () async {
    final entry = _entry('${temporaryDirectory.path}/missing.jpg');
    await expectLater(
      service.createArchive([entry]),
      throwsA(isA<RitualArchiveException>()),
    );
  });

  test('rejects an unsupported schema before importing', () async {
    final bytes = await _validArchiveBytes(temporaryDirectory, service);
    final changed = _rewriteManifest(bytes, (manifest) {
      manifest['schemaVersion'] = 999;
    });
    expect(
      () => service.readArchive(changed),
      throwsA(
        isA<RitualArchiveException>().having(
          (error) => error.message,
          'message',
          contains('unsupported'),
        ),
      ),
    );
  });

  test('rejects a missing photo without returning partial entries', () async {
    final bytes = await _validArchiveBytes(temporaryDirectory, service);
    final decoded = ZipDecoder().decodeBytes(bytes);
    final rebuilt = Archive();
    for (final file in decoded) {
      if (!file.name.startsWith('photos/')) {
        rebuilt.add(ArchiveFile.bytes(file.name, file.content));
      }
    }
    expect(
      () => service.readArchive(ZipEncoder().encodeBytes(rebuilt)),
      throwsA(isA<RitualArchiveException>()),
    );
  });

  test('rejects photo corruption using SHA-256 verification', () async {
    final bytes = await _validArchiveBytes(temporaryDirectory, service);
    final decoded = ZipDecoder().decodeBytes(bytes);
    final rebuilt = Archive();
    for (final file in decoded) {
      final content = file.content;
      if (file.name.startsWith('photos/')) content[0] ^= 0xff;
      rebuilt.add(ArchiveFile.bytes(file.name, content));
    }
    expect(
      () => service.readArchive(ZipEncoder().encodeBytes(rebuilt)),
      throwsA(
        isA<RitualArchiveException>().having(
          (error) => error.message,
          'message',
          contains('failed verification'),
        ),
      ),
    );
  });

  test(
    'rejects path traversal entries even when they are not referenced',
    () async {
      final bytes = await _validArchiveBytes(temporaryDirectory, service);
      final decoded = ZipDecoder().decodeBytes(bytes);
      final rebuilt = Archive();
      for (final file in decoded) {
        rebuilt.add(ArchiveFile.bytes(file.name, file.content));
      }
      rebuilt.add(ArchiveFile.bytes('../outside.jpg', [1, 2, 3]));
      expect(
        () => service.readArchive(ZipEncoder().encodeBytes(rebuilt)),
        throwsA(
          isA<RitualArchiveException>().having(
            (error) => error.message,
            'message',
            contains('unsafe'),
          ),
        ),
      );
    },
  );

  test('rejects invalid manifest JSON and mismatched entry counts', () async {
    final invalidJson = Archive()
      ..add(ArchiveFile.string('ritual-export.json', '{not json'));
    expect(
      () => service.readArchive(ZipEncoder().encodeBytes(invalidJson)),
      throwsA(isA<RitualArchiveException>()),
    );

    final bytes = await _validArchiveBytes(temporaryDirectory, service);
    final changed = _rewriteManifest(bytes, (manifest) {
      manifest['entryCount'] = 40;
    });
    expect(
      () => service.readArchive(changed),
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

Future<Uint8List> _validArchiveBytes(
  Directory directory,
  JournalArchiveService service,
) async {
  final photo = await _photo(
    directory,
    'valid.jpg',
    Uint8List.fromList([1, 2, 3, 4]),
  );
  return (await service.createArchive([_entry(photo.path)])).bytes;
}

Uint8List _rewriteManifest(
  Uint8List bytes,
  void Function(Map<String, dynamic>) change,
) {
  final decoded = ZipDecoder().decodeBytes(bytes);
  final rebuilt = Archive();
  for (final file in decoded) {
    if (file.name == 'ritual-export.json') {
      final manifest =
          jsonDecode(utf8.decode(file.content)) as Map<String, dynamic>;
      change(manifest);
      rebuilt.add(ArchiveFile.string(file.name, jsonEncode(manifest)));
    } else {
      rebuilt.add(ArchiveFile.bytes(file.name, file.content));
    }
  }
  return ZipEncoder().encodeBytes(rebuilt);
}
