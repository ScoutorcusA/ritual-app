import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/meal_entry.dart';

class RitualArchiveException implements Exception {
  const RitualArchiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ArchiveExportResult {
  const ArchiveExportResult({
    required this.bytes,
    required this.fileName,
    required this.entryCount,
  });

  final Uint8List bytes;
  final String fileName;
  final int entryCount;
}

class JournalArchiveService {
  static const schemaVersion = 1;
  static const _manifestName = 'ritual-export.json';
  static const _maxEntries = 10000;
  static const _maxPhotoBytes = 100 * 1024 * 1024;
  static const _maxArchiveBytes = 512 * 1024 * 1024;
  static const _maxManifestBytes = 10 * 1024 * 1024;

  Future<ArchiveExportResult> createArchive(
    List<MealEntry> entries, {
    DateTime? exportedAt,
  }) async {
    if (entries.length > _maxEntries) {
      throw const RitualArchiveException(
        'This journal is too large to export.',
      );
    }
    final archive = Archive();
    final manifestEntries = <Map<String, Object?>>[];
    var totalPhotoBytes = 0;

    for (final entry in entries) {
      final photo = File(entry.imagePath);
      if (!await photo.exists()) {
        throw RitualArchiveException(
          'The photo for entry ${entry.id} is missing. Nothing was exported.',
        );
      }
      final photoBytes = await photo.readAsBytes();
      if (photoBytes.length > _maxPhotoBytes) {
        throw RitualArchiveException(
          'The photo for entry ${entry.id} is unexpectedly large.',
        );
      }
      totalPhotoBytes += photoBytes.length;
      if (totalPhotoBytes > _maxArchiveBytes) {
        throw const RitualArchiveException(
          'This journal is too large to export as one archive.',
        );
      }
      final photoHash = sha256.convert(photoBytes).toString();
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
      archive.add(ArchiveFile.bytes(photoPath, photoBytes));
    }

    final timestamp = (exportedAt ?? DateTime.now()).toUtc();
    final manifest = <String, Object?>{
      'schemaVersion': schemaVersion,
      'app': 'Ritual',
      'exportedAt': timestamp.toIso8601String(),
      'entryCount': manifestEntries.length,
      'entries': manifestEntries,
    };
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    archive.add(ArchiveFile.bytes(_manifestName, manifestBytes));
    final bytes = ZipEncoder().encodeBytes(archive);
    final date = timestamp.toIso8601String().substring(0, 10);
    return ArchiveExportResult(
      bytes: bytes,
      fileName: 'ritual-export-$date.zip',
      entryCount: entries.length,
    );
  }

  List<MealImport> readArchive(Uint8List zipBytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    } catch (_) {
      throw const RitualArchiveException('This is not a readable ZIP archive.');
    }

    final names = <String>{};
    var totalUncompressedBytes = 0;
    for (final file in archive) {
      if (!names.add(file.name)) {
        throw const RitualArchiveException('The ZIP contains duplicate files.');
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
    for (final raw in rawEntries) {
      if (raw is! Map<String, dynamic>) {
        throw const RitualArchiveException('An exported entry is invalid.');
      }
      imports.add(_readEntry(raw, archive));
    }
    return imports;
  }

  MealImport _readEntry(Map<String, dynamic> raw, Archive archive) {
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
      throw RitualArchiveException('The exported photo $photoPath is missing.');
    }
    final photoBytes = photo.content;
    if (sha256.convert(photoBytes).toString() != expectedHash) {
      throw RitualArchiveException(
        'The exported photo $photoPath failed verification.',
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
      photoBytes: photoBytes,
      photoExtension: _safePhotoExtension(p.extension(photoPath)),
      fingerprint: expectedFingerprint,
    );
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
      throw RitualArchiveException('An exported $name rating is invalid.');
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
