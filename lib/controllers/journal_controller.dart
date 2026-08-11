import 'dart:math';

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
  Map<String, int> _dailyHighlights = const {};

  List<MealEntry> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;
  String? get error => _error;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;

  Future<void> initialize() async {
    try {
      _bestStreak = await _repository.loadBestStreak();
      _dailyHighlights = await _repository.loadDailyHighlights();
      _entries = await _repository.loadEntries();
      await _syncDailyHighlights();
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
    await _syncDailyHighlights();
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
    await _syncDailyHighlights();
    await _recalculateStreak();
    notifyListeners();
  }

  Future<int> importEntries(List<MealImport> entries) async {
    final imported = await _repository.importEntries(entries);
    if (imported.isEmpty) return 0;
    _entries = [...imported, ..._entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _syncDailyHighlights();
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

  MealEntry? highlightForDay(DateTime day) {
    final entries = _entries
        .where((entry) => _sameDay(entry.createdAt, day))
        .toList(growable: false);
    if (entries.isEmpty) return null;
    final selectedId = _dailyHighlights[_dayKey(day)];
    for (final entry in entries) {
      if (entry.id == selectedId) return entry;
    }
    return entries.first;
  }

  Future<void> _syncDailyHighlights() async {
    final groups = <String, List<MealEntry>>{};
    for (final entry in _entries) {
      groups.putIfAbsent(_dayKey(entry.createdAt), () => []).add(entry);
    }
    final highlights = Map<String, int>.from(_dailyHighlights);

    for (final savedDay in highlights.keys.toList(growable: false)) {
      final entries = groups[savedDay];
      final selected = highlights[savedDay];
      if (entries == null || !entries.any((entry) => entry.id == selected)) {
        highlights.remove(savedDay);
        await _repository.deleteDailyHighlight(savedDay);
      }
    }

    for (final group in groups.entries) {
      if (group.value.length < 2 || highlights.containsKey(group.key)) {
        continue;
      }
      final selected = group.value[Random().nextInt(group.value.length)].id;
      highlights[group.key] = selected;
      await _repository.saveDailyHighlight(group.key, selected);
    }
    _dailyHighlights = highlights;
  }

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
