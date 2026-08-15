import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// A small, persistent diagnostics log that deliberately excludes journal
/// content, photos, place names, and coordinates.
class DebugLogService {
  DebugLogService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static final DebugLogService instance = DebugLogService();

  static const _storageKey = 'ritual_debug_log';
  static const _maximumEntries = 120;

  final SharedPreferencesAsync _preferences;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> record(String area, String event) {
    _writeQueue = _writeQueue
        .catchError((_) {})
        .then((_) => _recordNow(area, event));
    return _writeQueue;
  }

  Future<void> _recordNow(String area, String event) async {
    final entries = await _preferences.getStringList(_storageKey) ?? <String>[];
    entries.add('${DateTime.now().toUtc().toIso8601String()} | $area | $event');
    final retained = entries.length > _maximumEntries
        ? entries.sublist(entries.length - _maximumEntries)
        : entries;
    await _preferences.setStringList(_storageKey, retained);
  }

  Future<String> copyableText() async {
    await _writeQueue.catchError((_) {});
    final entries =
        await _preferences.getStringList(_storageKey) ?? const <String>[];
    return <String>[
      'Ritual debug log',
      'Times are UTC. Photos, notes, feelings, place names, and coordinates are not logged.',
      if (entries.isEmpty)
        'No diagnostic events have been recorded yet.'
      else
        ...entries,
    ].join('\n');
  }

  Future<void> clear() async {
    await _writeQueue.catchError((_) {});
    await _preferences.remove(_storageKey);
  }
}
