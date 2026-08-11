import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/meal_repository.dart';
import '../models/meal_entry.dart';
import '../utils/streak_calculator.dart';

class SaveResult {
  const SaveResult({required this.entry, required this.firstEntryToday});

  final MealEntry entry;
  final bool firstEntryToday;
}

class JournalController extends ChangeNotifier {
  JournalController(this._repository);

  final MealRepository _repository;
  List<MealEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  int _currentStreak = 0;
  int _bestStreak = 0;

  List<MealEntry> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;
  String? get error => _error;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;

  Future<void> initialize() async {
    try {
      _bestStreak = await _repository.loadBestStreak();
      _entries = await _repository.loadEntries();
      await _recalculateStreak();
    } catch (error) {
      _error = 'Your journal could not be opened. $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String> keepCapturedPhoto(XFile temporaryPhoto) =>
      _repository.keepCapturedPhoto(temporaryPhoto);

  Future<void> discardPhoto(String imagePath) =>
      _repository.discardPhoto(imagePath);

  Future<SaveResult> addEntry(MealDraft draft) async {
    final firstEntryToday = !_entries.any(
      (entry) => _sameDay(entry.createdAt, draft.createdAt),
    );
    final entry = await _repository.addEntry(draft);
    _entries = [entry, ..._entries];
    await _recalculateStreak();
    notifyListeners();
    return SaveResult(entry: entry, firstEntryToday: firstEntryToday);
  }

  Future<void> updateEntry(MealEntry entry) async {
    await _repository.updateEntry(entry);
    _entries = [
      for (final current in _entries)
        if (current.id == entry.id) entry else current,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _recalculateStreak();
    notifyListeners();
  }

  Future<void> deleteEntry(MealEntry entry) async {
    await _repository.deleteEntry(entry);
    _entries = _entries.where((item) => item.id != entry.id).toList();
    await _recalculateStreak();
    notifyListeners();
  }

  Future<int> importEntries(List<MealImport> entries) async {
    final imported = await _repository.importEntries(entries);
    if (imported.isEmpty) return 0;
    _entries = [...imported, ..._entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _recalculateStreak();
    notifyListeners();
    return imported.length;
  }

  Future<void> _recalculateStreak() async {
    final stats = StreakCalculator.calculate(
      _entries.map((entry) => entry.createdAt),
      retainedBest: _bestStreak,
    );
    _currentStreak = stats.current;
    if (stats.longest > _bestStreak) {
      _bestStreak = stats.longest;
      await _repository.saveBestStreak(_bestStreak);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
