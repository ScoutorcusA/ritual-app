import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../l10n/ritual_i18n.dart';
import '../models/meal_entry.dart';

class RitualArchiveException implements Exception {
  const RitualArchiveException(this.source, {this.values = const {}});

  final String source;
  final Map<String, Object?> values;

  String get message => tr(source, values: values);

  @override
  String toString() => tr(message);
}

class ArchiveExportResult {
  const ArchiveExportResult({
    required this.filePath,
    required this.fileName,
    required this.entryCount,
    required this.encrypted,
  });

  final String filePath;
  final String fileName;
  final int entryCount;
  final bool encrypted;
}

class JournalImportPreview {
  JournalImportPreview({required this.entries, required this.stagingPath});

  final List<MealImport> entries;
  final String stagingPath;

  Future<void> dispose() async {
    try {
      final stagingDirectory = Directory(stagingPath);
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    } on FileSystemException {
      // Android will eventually clear the temporary directory.
    }
  }
}

class JournalArchiveService {
  static const schemaVersion = 1;
  static const _manifestName = 'ritual-export.json';
  static const _maxEntries = 10000;
  static const _maxPhotoBytes = 32 * 1024 * 1024;
  static const _maxArchiveBytes = 512 * 1024 * 1024;
  static const _maxManifestBytes = 10 * 1024 * 1024;
  static const minimumPasswordLength = 12;

  Future<ArchiveExportResult> createArchiveFile(
    List<MealEntry> entries, {
    required String outputPath,
    String? password,
    DateTime? exportedAt,
  }) => Isolate.run(
    () => _createArchiveFile(
      entries,
      outputPath: outputPath,
      password: password,
      exportedAt: exportedAt,
    ),
  );

  Future<ArchiveExportResult> _createArchiveFile(
    List<MealEntry> entries, {
    required String outputPath,
    String? password,
    DateTime? exportedAt,
  }) async {
    if (entries.length > _maxEntries) {
      throw const RitualArchiveException(
        'This journal is too large to export.',
      );
    }
    final normalizedPassword = password;
    if (normalizedPassword != null &&
        normalizedPassword.length < minimumPasswordLength) {
      throw const RitualArchiveException(
        'Use an export password with at least 12 characters.',
      );
    }

    final output = File(outputPath);
    await output.parent.create(recursive: true);
    if (await output.exists()) await output.delete();
    final encoder = ZipFileEncoder(password: normalizedPassword);
    var encoderOpen = false;
    try {
      final manifestEntries = <Map<String, Object?>>[];
      var totalPhotoBytes = 0;
      final prepared = <({MealEntry entry, File photo, String path})>[];

      for (final entry in entries) {
        final photo = File(entry.imagePath);
        if (!await photo.exists()) {
          throw RitualArchiveException(
            'The photo for entry {entryId} is missing. Nothing was exported.',
            values: {'entryId': entry.id},
          );
        }
        final size = await photo.length();
        if (size > _maxPhotoBytes) {
          throw RitualArchiveException(
            'The photo for entry {entryId} is unexpectedly large.',
            values: {'entryId': entry.id},
          );
        }
        totalPhotoBytes += size;
        if (totalPhotoBytes > _maxArchiveBytes) {
          throw const RitualArchiveException(
            'This journal is too large to export as one archive.',
          );
        }
        final photoHash = (await sha256.bind(photo.openRead()).first)
            .toString();
        final extension = _safePhotoExtension(p.extension(entry.imagePath));
        final photoPath =
            'photos/${entry.id}_${photoHash.substring(0, 12)}$extension';
        final values = <String, Object?>{
          'mealType': entry.mealType.name,
          'feelings': entry.feelings,
          'note': entry.note,
          'createdAt': entry.createdAt.toUtc().toIso8601String(),
          'latitude': entry.latitude,
          'longitude': entry.longitude,
          'locationLabel': entry.locationLabel,
          'hungerLevel': entry.hungerLevel,
          'fullnessLevel': entry.fullnessLevel,
          'cravingLevel': entry.cravingLevel,
          'photo': photoPath,
          'photoSha256': photoHash,
        };
        values['fingerprint'] = _fingerprint(values);
        manifestEntries.add(values);
        prepared.add((entry: entry, photo: photo, path: photoPath));
      }

      final timestamp = (exportedAt ?? DateTime.now()).toUtc();
      final manifest = <String, Object?>{
        'schemaVersion': schemaVersion,
        'app': 'Ritual',
        'exportedAt': timestamp.toIso8601String(),
        'entryCount': manifestEntries.length,
        'encrypted': normalizedPassword != null,
        'entries': manifestEntries,
      };
      final manifestBytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );

      encoder.create(outputPath, level: ZipFileEncoder.store);
      encoderOpen = true;
      for (final item in prepared) {
        // Meal photos are already compressed. STORE avoids buffering a second
        // deflated copy and the archive package releases each file before the
        // next one is processed.
        await encoder.addFile(item.photo, item.path, ZipFileEncoder.store);
      }
      encoder.addArchiveFile(
        ArchiveFile.noCompress(
          _manifestName,
          manifestBytes.length,
          manifestBytes,
        ),
      );
      await encoder.close();
      encoderOpen = false;

      final date = timestamp.toIso8601String().substring(0, 10);
      return ArchiveExportResult(
        filePath: output.path,
        fileName:
            'ritual-export-$date${normalizedPassword == null ? '' : '-encrypted'}.zip',
        entryCount: entries.length,
        encrypted: normalizedPassword != null,
      );
    } on RitualArchiveException {
      rethrow;
    } catch (_) {
      throw const RitualArchiveException(
        'Ritual could not create the journal archive.',
      );
    } finally {
      if (encoderOpen) {
        try {
          await encoder.close();
        } catch (_) {
          // Preserve the original failure.
        }
      }
      if (encoderOpen && await output.exists()) {
        try {
          await output.delete();
        } on FileSystemException {
          // The incomplete cache file is not user-visible.
        }
      }
    }
  }

  Future<bool> isEncryptedArchiveFile(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() < 8) return false;
    final bytes = await file
        .openRead(0, 8)
        .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
    if (bytes.length < 8 ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4b ||
        bytes[2] != 0x03 ||
        bytes[3] != 0x04) {
      return false;
    }
    final flags = bytes[6] | (bytes[7] << 8);
    return flags & 0x1 != 0;
  }

  Future<JournalImportPreview> readArchiveFile(
    String zipPath, {
    String? password,
  }) => Isolate.run(() => _readArchiveFile(zipPath, password: password));

  Future<JournalImportPreview> _readArchiveFile(
    String zipPath, {
    String? password,
  }) async {
    final source = File(zipPath);
    if (!await source.exists()) {
      throw const RitualArchiveException('The selected ZIP is unavailable.');
    }
    if (await source.length() > 1024 * 1024 * 1024) {
      throw const RitualArchiveException(
        'This ZIP is too large to import safely.',
      );
    }
    final encrypted = await isEncryptedArchiveFile(zipPath);
    if (encrypted && (password == null || password.isEmpty)) {
      throw const RitualArchiveException(
        'This Ritual ZIP requires its export password.',
      );
    }

    final staging = await Directory.systemTemp.createTemp('ritual-import-');
    InputFileStream? input;
    Archive? archive;
    try {
      input = InputFileStream(zipPath);
      archive = ZipDecoder().decodeStream(input, password: password);
      final names = <String>{};
      var totalUncompressedBytes = 0;
      for (final file in archive) {
        if (!names.add(file.name)) {
          throw const RitualArchiveException(
            'The ZIP contains duplicate files.',
          );
        }
        if (_isUnsafePath(file.name) || file.isSymbolicLink) {
          throw const RitualArchiveException(
            'The ZIP contains an unsafe file path.',
          );
        }
        totalUncompressedBytes += file.size;
        if (totalUncompressedBytes > _maxArchiveBytes) {
          throw const RitualArchiveException(
            'The ZIP expands beyond Ritual’s safe import limit.',
          );
        }
      }
      final manifestFile = archive.find(_manifestName);
      if (manifestFile == null || !manifestFile.isFile) {
        throw const RitualArchiveException(
          'The Ritual export manifest is missing.',
        );
      }
      if (manifestFile.size > _maxManifestBytes) {
        throw const RitualArchiveException(
          'The Ritual export manifest is too large.',
        );
      }

      final Map<String, dynamic> manifest;
      try {
        final decoded = jsonDecode(utf8.decode(manifestFile.content));
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        manifest = decoded;
      } catch (_) {
        if (encrypted) {
          throw const RitualArchiveException(
            'The export password is incorrect, or the ZIP is damaged.',
          );
        }
        throw const RitualArchiveException(
          'The Ritual export manifest is damaged.',
        );
      }
      if (manifest['schemaVersion'] != schemaVersion) {
        throw const RitualArchiveException(
          'This export was created by an unsupported version of Ritual.',
        );
      }
      final rawEntries = manifest['entries'];
      if (rawEntries is! List || rawEntries.length > _maxEntries) {
        throw const RitualArchiveException('The export entry list is invalid.');
      }
      if (manifest['entryCount'] != rawEntries.length) {
        throw const RitualArchiveException(
          'The export entry count does not match.',
        );
      }

      final imports = <MealImport>[];
      for (var index = 0; index < rawEntries.length; index++) {
        final raw = rawEntries[index];
        if (raw is! Map<String, dynamic>) {
          throw const RitualArchiveException('An exported entry is invalid.');
        }
        imports.add(await _stageEntry(raw, archive, staging, index, encrypted));
      }
      return JournalImportPreview(entries: imports, stagingPath: staging.path);
    } on RitualArchiveException {
      await _deleteStaging(staging);
      rethrow;
    } catch (_) {
      await _deleteStaging(staging);
      throw RitualArchiveException(
        encrypted
            ? 'The export password is incorrect, or the ZIP is damaged.'
            : 'This is not a readable Ritual ZIP archive.',
      );
    } finally {
      try {
        if (archive != null) {
          for (final file in archive) {
            await file.close();
          }
        }
        await input?.close();
      } catch (_) {
        // The staging result no longer depends on the source ZIP handle.
      }
    }
  }

  Future<MealImport> _stageEntry(
    Map<String, dynamic> raw,
    Archive archive,
    Directory staging,
    int index,
    bool encrypted,
  ) async {
    final photoPath = raw['photo'];
    final expectedHash = raw['photoSha256'];
    final expectedFingerprint = raw['fingerprint'];
    if (photoPath is! String ||
        expectedHash is! String ||
        expectedFingerprint is! String ||
        _isUnsafePhotoPath(photoPath)) {
      throw const RitualArchiveException(
        'An exported photo reference is invalid.',
      );
    }
    final photo = archive.find(photoPath);
    if (photo == null || !photo.isFile || photo.size > _maxPhotoBytes) {
      throw RitualArchiveException(
        'The exported photo {photoPath} is missing.',
        values: {'photoPath': photoPath},
      );
    }
    final extension = _safePhotoExtension(p.extension(photoPath));
    final stagedPhoto = File(p.join(staging.path, 'photo_$index$extension'));
    try {
      final output = OutputFileStream(stagedPhoto.path, bufferSize: 64 * 1024);
      photo.writeContent(output);
      await output.close();
    } catch (_) {
      throw encrypted
          ? const RitualArchiveException(
              'The export password is incorrect, or an encrypted photo is damaged.',
            )
          : RitualArchiveException(
              'The exported photo {photoPath} could not be read.',
              values: {'photoPath': photoPath},
            );
    }
    final actualHash = (await sha256.bind(stagedPhoto.openRead()).first)
        .toString();
    if (actualHash != expectedHash) {
      throw RitualArchiveException(
        'The exported photo {photoPath} failed verification.',
        values: {'photoPath': photoPath},
      );
    }
    final fingerprintValues = Map<String, dynamic>.from(raw)
      ..remove('fingerprint');
    if (_fingerprint(fingerprintValues) != expectedFingerprint) {
      throw const RitualArchiveException(
        'An exported entry failed verification.',
      );
    }

    final mealTypeName = raw['mealType'];
    final createdAtText = raw['createdAt'];
    final feelingsValue = raw['feelings'];
    if (mealTypeName is! String ||
        createdAtText is! String ||
        feelingsValue is! List ||
        raw['note'] is! String) {
      throw const RitualArchiveException('An exported entry is incomplete.');
    }
    final mealType = MealType.values.where((type) => type.name == mealTypeName);
    final createdAt = DateTime.tryParse(createdAtText);
    final feelings = feelingsValue.whereType<String>().toList(growable: false);
    if (mealType.length != 1 ||
        createdAt == null ||
        feelings.length != feelingsValue.length) {
      throw const RitualArchiveException(
        'An exported entry contains invalid values.',
      );
    }
    if (feelings.length > 50 ||
        feelings.any((feeling) => feeling.length > 200) ||
        (raw['note'] as String).length > 10000) {
      throw const RitualArchiveException('An exported entry is too large.');
    }
    final latitude = _nullableDouble(raw['latitude']);
    final longitude = _nullableDouble(raw['longitude']);
    if ((latitude == null) != (longitude == null) ||
        (latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180))) {
      throw const RitualArchiveException('An exported location is invalid.');
    }
    final locationLabel = raw['locationLabel'];
    if (locationLabel != null && locationLabel is! String) {
      throw const RitualArchiveException('An exported place name is invalid.');
    }
    if (locationLabel is String && locationLabel.length > 500) {
      throw const RitualArchiveException('An exported place name is too long.');
    }
    final hungerLevel = _nullableScale(raw['hungerLevel'], 'hunger');
    final fullnessLevel = _nullableScale(raw['fullnessLevel'], 'fullness');
    final cravingLevel = _nullableScale(raw['cravingLevel'], 'craving');

    return MealImport(
      draft: MealDraft(
        imagePath: '',
        mealType: mealType.single,
        feelings: feelings,
        note: raw['note'] as String,
        createdAt: createdAt.toLocal(),
        latitude: latitude,
        longitude: longitude,
        locationLabel: locationLabel as String?,
        hungerLevel: hungerLevel,
        fullnessLevel: fullnessLevel,
        cravingLevel: cravingLevel,
      ),
      photoPath: stagedPhoto.path,
      photoExtension: extension,
      fingerprint: expectedFingerprint,
    );
  }

  Future<void> _deleteStaging(Directory staging) async {
    try {
      if (await staging.exists()) await staging.delete(recursive: true);
    } on FileSystemException {
      // Android will eventually clear the temporary directory.
    }
  }

  double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is! num) {
      throw const RitualArchiveException('An exported coordinate is invalid.');
    }
    return value.toDouble();
  }

  int? _nullableScale(Object? value, String name) {
    if (value == null) return null;
    if (value is! int || value < 1 || value > 5) {
      throw RitualArchiveException(
        'An exported {ratingName} rating is invalid.',
        values: {'ratingName': name},
      );
    }
    return value;
  }

  String _fingerprint(Map<String, Object?> values) {
    final sorted = <String, Object?>{};
    for (final key in values.keys.toList()..sort()) {
      sorted[key] = values[key];
    }
    return sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
  }

  bool _isUnsafePhotoPath(String value) {
    if (!value.startsWith('photos/') || _isUnsafePath(value)) return true;
    return value.substring('photos/'.length).contains('/');
  }

  bool _isUnsafePath(String value) =>
      value.isEmpty ||
      value.startsWith('/') ||
      value.contains('\\') ||
      value.split('/').any((part) => part == '..' || part == '.');

  String _safePhotoExtension(String value) {
    const supported = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};
    final lower = value.toLowerCase();
    return supported.contains(lower) ? lower : '.jpg';
  }
}
