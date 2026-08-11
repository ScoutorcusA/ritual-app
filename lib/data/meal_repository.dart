import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/meal_entry.dart';

abstract class MealRepository {
  Future<List<MealEntry>> loadEntries();
  Future<MealEntry> addEntry(MealDraft draft);
  Future<void> updateEntry(MealEntry entry);
  Future<void> deleteEntry(MealEntry entry);
  Future<String> keepCapturedPhoto(XFile temporaryPhoto);
  Future<void> discardPhoto(String imagePath);
  Future<int> loadBestStreak();
  Future<void> saveBestStreak(int value);
}

class SqliteMealRepository implements MealRepository {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final databasePath = p.join(await getDatabasesPath(), 'ritual.db');
    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE meals(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            meal_type TEXT NOT NULL,
            feelings TEXT NOT NULL,
            note TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            latitude REAL,
            longitude REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE preferences(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  @override
  Future<List<MealEntry>> loadEntries() async {
    final rows = await (await _db).query('meals', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<MealEntry> addEntry(MealDraft draft) async {
    final values = _draftToRow(draft);
    final id = await (await _db).insert('meals', values);
    return MealEntry(
      id: id,
      imagePath: draft.imagePath,
      mealType: draft.mealType,
      feelings: List.unmodifiable(draft.feelings),
      note: draft.note,
      createdAt: draft.createdAt,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
  }

  @override
  Future<void> updateEntry(MealEntry entry) async {
    await (await _db).update(
      'meals',
      _entryToRow(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  @override
  Future<void> deleteEntry(MealEntry entry) async {
    await (await _db).delete('meals', where: 'id = ?', whereArgs: [entry.id]);
    await discardPhoto(entry.imagePath);
  }

  @override
  Future<String> keepCapturedPhoto(XFile temporaryPhoto) async {
    final documents = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(documents.path, 'ritual_photos'));
    await photos.create(recursive: true);

    final sourceExtension = p.extension(temporaryPhoto.path).toLowerCase();
    const supported = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};
    final extension = supported.contains(sourceExtension)
        ? sourceExtension
        : '.jpg';
    final destination = p.join(
      photos.path,
      'meal_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(temporaryPhoto.path).copy(destination);
    try {
      await File(temporaryPhoto.path).delete();
    } on FileSystemException {
      // Some camera providers own and clean up their temporary file.
    }
    return destination;
  }

  @override
  Future<void> discardPhoto(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<int> loadBestStreak() async {
    final rows = await (await _db).query(
      'preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['best_streak'],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value'] as String) ?? 0;
  }

  @override
  Future<void> saveBestStreak(int value) async {
    await (await _db).insert('preferences', {
      'key': 'best_streak',
      'value': '$value',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  MealEntry _fromRow(Map<String, Object?> row) {
    final feelings = (jsonDecode(row['feelings'] as String) as List<dynamic>)
        .cast<String>();
    return MealEntry(
      id: row['id'] as int,
      imagePath: row['image_path'] as String,
      mealType: MealType.values.byName(row['meal_type'] as String),
      feelings: List.unmodifiable(feelings),
      note: row['note'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      latitude: row['latitude'] as double?,
      longitude: row['longitude'] as double?,
    );
  }

  Map<String, Object?> _draftToRow(MealDraft draft) => {
    'image_path': draft.imagePath,
    'meal_type': draft.mealType.name,
    'feelings': jsonEncode(draft.feelings),
    'note': draft.note,
    'created_at': draft.createdAt.millisecondsSinceEpoch,
    'latitude': draft.latitude,
    'longitude': draft.longitude,
  };

  Map<String, Object?> _entryToRow(MealEntry entry) => {
    'image_path': entry.imagePath,
    'meal_type': entry.mealType.name,
    'feelings': jsonEncode(entry.feelings),
    'note': entry.note,
    'created_at': entry.createdAt.millisecondsSinceEpoch,
    'latitude': entry.latitude,
    'longitude': entry.longitude,
  };
}
