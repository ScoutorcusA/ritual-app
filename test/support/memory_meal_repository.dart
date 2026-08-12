import 'package:image_picker/image_picker.dart';
import 'package:ritual/data/meal_repository.dart';
import 'package:ritual/models/meal_entry.dart';

class MemoryMealRepository implements MealRepository {
  MemoryMealRepository({List<MealEntry> entries = const []})
    : entries = List.of(entries);

  final List<MealEntry> entries;
  final Map<String, int> highlights = {};
  int bestStreak = 0;

  @override
  Future<MealEntry> addEntry(MealDraft draft) async {
    final nextId =
        entries.fold<int>(0, (value, entry) {
          return entry.id > value ? entry.id : value;
        }) +
        1;
    final entry = MealEntry(
      id: nextId,
      imagePath: draft.imagePath,
      mealType: draft.mealType,
      feelings: List.unmodifiable(draft.feelings),
      note: draft.note,
      createdAt: draft.createdAt,
      latitude: draft.latitude,
      longitude: draft.longitude,
      locationLabel: draft.locationLabel,
      hungerLevel: draft.hungerLevel,
      fullnessLevel: draft.fullnessLevel,
      cravingLevel: draft.cravingLevel,
    );
    entries.add(entry);
    return entry;
  }

  @override
  Future<void> deleteEntry(MealEntry entry) async {
    entries.removeWhere((candidate) => candidate.id == entry.id);
  }

  @override
  Future<void> deleteAllJournalData() async {
    entries.clear();
    highlights.clear();
    bestStreak = 0;
  }

  @override
  Future<void> deleteDailyHighlight(String dayKey) async {
    highlights.remove(dayKey);
  }

  @override
  Future<void> discardPhoto(String imagePath) async {}

  @override
  Future<List<MealEntry>> importEntries(List<MealImport> entries) async =>
      const [];

  @override
  Future<String> keepCapturedPhoto(XFile temporaryPhoto) async =>
      temporaryPhoto.path;

  @override
  Future<int> loadBestStreak() async => bestStreak;

  @override
  Future<Map<String, int>> loadDailyHighlights() async => Map.of(highlights);

  @override
  Future<List<MealEntry>> loadEntries() async {
    final result = List.of(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<void> saveBestStreak(int value) async {
    bestStreak = value;
  }

  @override
  Future<void> saveDailyHighlight(String dayKey, int entryId) async {
    highlights[dayKey] = entryId;
  }

  @override
  Future<void> updateEntry(MealEntry entry) async {
    final index = entries.indexWhere((candidate) => candidate.id == entry.id);
    if (index >= 0) entries[index] = entry;
  }
}
