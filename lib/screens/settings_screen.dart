import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/journal_export.dart';
import '../models/meal_entry.dart';
import '../services/journal_archive_service.dart';
import '../services/journal_csv_service.dart';
import '../services/journal_pdf_service.dart';
import '../services/meal_reminder_service.dart';
import '../theme/ritual_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.journal,
  });

  final SettingsController settings;
  final JournalController journal;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final JournalArchiveService _archiveService = JournalArchiveService();
  final JournalCsvService _csvService = JournalCsvService();
  final JournalPdfService _pdfService = JournalPdfService();
  bool _working = false;

  Future<void> _chooseLockMode(AppLockMode mode) async {
    if (mode == widget.settings.lockMode) return;
    if (mode == AppLockMode.off) {
      await widget.settings.disableLock();
      return;
    }
    if (mode == AppLockMode.device) {
      final enabled = await widget.settings.enableDeviceLock();
      if (!mounted) return;
      _message(
        enabled
            ? 'Device lock is now protecting Ritual.'
            : 'Device authentication is not set up or was canceled.',
      );
      return;
    }
    final first = await _requestPin('Create a Ritual PIN');
    if (!mounted || first == null) return;
    final second = await _requestPin('Confirm your PIN');
    if (!mounted || second == null) return;
    if (first != second) {
      _message('Those PINs did not match. Nothing changed.');
      return;
    }
    await widget.settings.setPin(first);
    if (mounted) _message('Your Ritual PIN is ready.');
  }

  Future<String?> _requestPin(String title) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PinSetupDialog(title: title),
    );
  }

  Future<void> _exportJournal() async {
    if (_working) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.no_encryption_outlined),
        title: const Text('This ZIP is not encrypted'),
        content: const Text(
          'Anyone who can open the exported file can see its photos, notes, '
          'feelings, dates, and saved places. Store it somewhere private and '
          'share it only with people you trust.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export anyway'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _working = true);
    try {
      final result = await _archiveService.createArchive(
        widget.journal.entries,
      );
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Export Ritual journal',
        fileName: result.fileName,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        bytes: result.bytes,
      );
      if (!mounted || savedPath == null) return;
      _message(
        '${result.entryCount} ${result.entryCount == 1 ? 'entry' : 'entries'} '
        'exported successfully.',
      );
    } on RitualArchiveException catch (error) {
      if (mounted) _message(error.message, error: true);
    } catch (error) {
      if (mounted) _message('Export failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _setReminders(bool enabled) async {
    final result = await widget.settings.setMealRemindersEnabled(enabled);
    if (!mounted) return;
    if (result == ReminderToggleResult.permissionDenied) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.notifications_off_outlined),
          title: const Text('Notifications are turned off'),
          content: const Text(
            'Android did not allow Ritual to send reminders. You can allow '
            'notifications in Ritual’s Android settings, then turn reminders on.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await widget.settings.openNotificationSettings();
      }
    } else if (result == ReminderToggleResult.unavailable) {
      _message(
        'Ritual could not start reminders. Restart the app and try again.',
        error: true,
      );
    }
  }

  Future<void> _pickReminderTime(
    MealReminderKind kind,
    int currentMinutes,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
      helpText: 'Choose reminder time',
    );
    if (picked != null) {
      await widget.settings.setReminderTime(
        kind,
        picked.hour * 60 + picked.minute,
      );
    }
  }

  String _formatMinutes(int minutes) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));

  Future<void> _restartWelcome() async {
    await widget.settings.restartOnboarding();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _exportReport() async {
    if (_working || widget.journal.entries.isEmpty) return;
    final selection = await showDialog<_ReportExportSelection>(
      context: context,
      builder: (context) => _ReportExportDialog(
        entries: widget.journal.entries,
        today: DateTime.now(),
      ),
    );
    if (!mounted || selection == null) return;
    setState(() => _working = true);
    try {
      final isPdf = selection.format == JournalExportFormat.pdf;
      late final Uint8List bytes;
      late final String fileName;
      late final int entryCount;
      if (isPdf) {
        final result = await _pdfService.createReport(
          widget.journal.entries,
          range: selection.range,
        );
        bytes = result.bytes;
        fileName = result.fileName;
        entryCount = result.entryCount;
      } else {
        final result = _csvService.createReport(
          widget.journal.entries,
          range: selection.range,
        );
        bytes = result.bytes;
        fileName = result.fileName;
        entryCount = result.entryCount;
      }
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Export Ritual journal report',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [isPdf ? 'pdf' : 'csv'],
        bytes: bytes,
      );
      if (!mounted || savedPath == null) return;
      _message(
        '$entryCount ${entryCount == 1 ? 'entry' : 'entries'} '
        'exported to ${isPdf ? 'PDF' : 'CSV'}.',
      );
    } catch (error) {
      if (mounted) _message('Report export failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteAllJournalData() async {
    if (_working || widget.journal.entries.isEmpty) return;
    final entryCount = widget.journal.entries.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Delete all journal data?'),
        content: Text(
          'This permanently deletes all $entryCount '
          '${entryCount == 1 ? 'entry' : 'entries'}, app-private photos, '
          'calendar highlights, and streak history from this device. '
          'Your theme, app lock, PIN, and reminder setting will stay.\n\n'
          'This cannot be undone. Export first if you may want a copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my journal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _working = true);
    try {
      await widget.journal.deleteAllJournalData();
      if (mounted) _message('All journal entries and photos were deleted.');
    } catch (error) {
      if (mounted) {
        _message(
          'Ritual could not finish deleting the journal: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importJournal() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Import a Ritual journal',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (picked == null) return;
      if (picked.size > 1024 * 1024 * 1024) {
        throw const RitualArchiveException(
          'This ZIP is too large to import safely.',
        );
      }
      final imports = _archiveService.readArchive(await picked.readAsBytes());
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import this journal?'),
          content: Text(
            'Ritual verified ${imports.length} '
            '${imports.length == 1 ? 'entry' : 'entries'} and their photos. '
            'Existing entries will stay, and exact repeat imports are skipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final imported = await widget.journal.importEntries(imports);
      if (mounted) {
        _message(
          imported == 0
              ? 'Everything in that archive was already in Ritual.'
              : '$imported ${imported == 1 ? 'entry' : 'entries'} imported.',
        );
      }
    } on RitualArchiveException catch (error) {
      if (mounted) _message(error.message, error: true);
    } catch (error) {
      if (mounted) _message('Import failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            const _SectionTitle('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Color theme'),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.settings_brightness_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {widget.settings.themeMode},
                      onSelectionChanged: (value) =>
                          widget.settings.setThemeMode(value.single),
                    ),
                  ],
                ),
              ),
            ),
            const _SectionTitle('Experience'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    value: widget.settings.streaksEnabled,
                    onChanged: widget.settings.setStreaksEnabled,
                    secondary: const Icon(Icons.local_fire_department_outlined),
                    title: const Text('Daily streaks'),
                    subtitle: const Text(
                      'Show streak progress and first-entry celebrations. Turning '
                      'this off does not delete your progress.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: const Text('Welcome setup'),
                    subtitle: const Text('Review your experience choices'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _restartWelcome,
                  ),
                ],
              ),
            ),
            const _SectionTitle('Meal reflection'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    value: widget.settings.hungerScaleEnabled,
                    onChanged: widget.settings.setHungerScaleEnabled,
                    secondary: const Icon(Icons.restaurant_menu_rounded),
                    title: const Text('Hunger before eating'),
                    subtitle: const Text('Optional five-point check-in'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: widget.settings.cravingScaleEnabled,
                    onChanged: widget.settings.setCravingScaleEnabled,
                    secondary: const Icon(Icons.bolt_outlined),
                    title: const Text('Craving before eating'),
                    subtitle: const Text('Optional five-point check-in'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: widget.settings.fullnessScaleEnabled,
                    onChanged: widget.settings.setFullnessScaleEnabled,
                    secondary: const Icon(Icons.spa_outlined),
                    title: const Text('Fullness after eating'),
                    subtitle: const Text('Optional five-point check-in'),
                  ),
                ],
              ),
            ),
            const _SectionTitle('Privacy'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: RadioGroup<AppLockMode>(
                groupValue: widget.settings.lockMode,
                onChanged: (value) {
                  if (value != null) _chooseLockMode(value);
                },
                child: const Column(
                  children: [
                    RadioListTile<AppLockMode>(
                      value: AppLockMode.off,
                      title: Text('No app lock'),
                      secondary: Icon(Icons.lock_open_outlined),
                    ),
                    Divider(height: 1),
                    RadioListTile<AppLockMode>(
                      value: AppLockMode.device,
                      title: Row(
                        children: [
                          Text('Device security'),
                          SizedBox(width: 8),
                          _RecommendedBadge(),
                        ],
                      ),
                      subtitle: Text('Fingerprint, device PIN, or pattern'),
                      secondary: Icon(Icons.fingerprint_rounded),
                    ),
                    Divider(height: 1),
                    RadioListTile<AppLockMode>(
                      value: AppLockMode.pin,
                      title: Text('Ritual PIN'),
                      subtitle: Text('A separate four-digit code'),
                      secondary: Icon(Icons.pin_outlined),
                    ),
                  ],
                ),
              ),
            ),
            const _SectionTitle('Reminders'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    value: widget.settings.mealRemindersEnabled,
                    onChanged: _setReminders,
                    secondary: const Icon(Icons.notifications_none_rounded),
                    title: const Text('Mindful meal reminders'),
                    subtitle: const Text(
                      'Local check-ins that automatically skip meals already logged.',
                    ),
                  ),
                  const Divider(height: 1),
                  _ReminderTimeTile(
                    label: 'Breakfast',
                    time: _formatMinutes(
                      widget.settings.reminderSchedule.breakfastMinutes,
                    ),
                    onTap: () => _pickReminderTime(
                      MealReminderKind.breakfast,
                      widget.settings.reminderSchedule.breakfastMinutes,
                    ),
                  ),
                  _ReminderTimeTile(
                    label: 'Lunch',
                    time: _formatMinutes(
                      widget.settings.reminderSchedule.lunchMinutes,
                    ),
                    onTap: () => _pickReminderTime(
                      MealReminderKind.lunch,
                      widget.settings.reminderSchedule.lunchMinutes,
                    ),
                  ),
                  _ReminderTimeTile(
                    label: 'Dinner',
                    time: _formatMinutes(
                      widget.settings.reminderSchedule.dinnerMinutes,
                    ),
                    onTap: () => _pickReminderTime(
                      MealReminderKind.dinner,
                      widget.settings.reminderSchedule.dinnerMinutes,
                    ),
                  ),
                  _ReminderTimeTile(
                    label: 'Empty-day check-in',
                    time: _formatMinutes(
                      widget.settings.reminderSchedule.emptyDayMinutes,
                    ),
                    onTap: () => _pickReminderTime(
                      MealReminderKind.emptyDay,
                      widget.settings.reminderSchedule.emptyDayMinutes,
                    ),
                  ),
                ],
              ),
            ),
            const _SectionTitle('Your data'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    enabled: !_working,
                    leading: const Icon(Icons.archive_outlined),
                    title: const Text('Export journal'),
                    subtitle: Text(
                      '${widget.journal.entries.length} entries, metadata, and '
                      'photos in one unencrypted ZIP',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exportJournal,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    enabled: !_working && widget.journal.entries.isNotEmpty,
                    leading: const Icon(Icons.medical_information_outlined),
                    title: const Text('Export report'),
                    subtitle: const Text(
                      'Choose PDF or CSV and a date range - unencrypted',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exportReport,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    enabled: !_working,
                    leading: const Icon(Icons.unarchive_outlined),
                    title: const Text('Import Ritual ZIP'),
                    subtitle: const Text(
                      'Verifies every entry and photo before importing',
                    ),
                    trailing: _working
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _importJournal,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    enabled: !_working && widget.journal.entries.isNotEmpty,
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Delete all journal data',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently removes every entry, photo, and streak',
                    ),
                    onTap: _deleteAllJournalData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: RitualColors.sage.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: RitualColors.sage),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Photos and journal data stay inside Ritual unless you '
                      'explicitly export them. Ritual does not use an account or cloud sync.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Ritual 1.5 • ${DateFormat.yMMMM().format(DateTime.now())}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderTimeTile extends StatelessWidget {
  const _ReminderTimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const SizedBox(width: 24),
    title: Text(label),
    trailing: Text(time, style: Theme.of(context).textTheme.titleSmall),
    onTap: onTap,
  );
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: RitualColors.sage.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'RECOMMENDED',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: RitualColors.sage,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: RitualColors.sage,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ReportExportSelection {
  const _ReportExportSelection({required this.format, required this.range});

  final JournalExportFormat format;
  final JournalExportRange range;
}

class _ReportExportDialog extends StatefulWidget {
  const _ReportExportDialog({required this.entries, required this.today});

  final List<MealEntry> entries;
  final DateTime today;

  @override
  State<_ReportExportDialog> createState() => _ReportExportDialogState();
}

class _ReportExportDialogState extends State<_ReportExportDialog> {
  JournalExportFormat _format = JournalExportFormat.pdf;
  JournalExportRangePreset _preset = JournalExportRangePreset.last7Days;
  JournalExportRange? _customRange;

  late final JournalExportRange _last7Days = JournalExportRange.lastDays(
    today: widget.today,
    days: 7,
  );
  late final JournalExportRange _last30Days = JournalExportRange.lastDays(
    today: widget.today,
    days: 30,
  );

  JournalExportRange? get _selectedRange => switch (_preset) {
    JournalExportRangePreset.last7Days => _last7Days,
    JournalExportRangePreset.last30Days => _last30Days,
    JournalExportRangePreset.custom => _customRange,
  };

  Future<void> _selectPreset(JournalExportRangePreset preset) async {
    if (preset != JournalExportRangePreset.custom) {
      setState(() => _preset = preset);
      return;
    }
    final earliestEntry = widget.entries.fold<DateTime>(
      widget.today,
      (earliest, entry) =>
          entry.createdAt.isBefore(earliest) ? entry.createdAt : earliest,
    );
    final latestEntry = widget.entries.fold<DateTime>(
      widget.today,
      (latest, entry) =>
          entry.createdAt.isAfter(latest) ? entry.createdAt : latest,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(earliestEntry.year - 1),
      lastDate: DateTime(latestEntry.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: _customRange?.start ?? _last30Days.start,
        end: _customRange?.end ?? _last30Days.end,
      ),
      helpText: 'Choose journal dates',
      saveText: 'Use dates',
    );
    if (!mounted || picked == null) return;
    setState(() {
      _customRange = JournalExportRange(start: picked.start, end: picked.end);
      _preset = JournalExportRangePreset.custom;
    });
  }

  String _countLabel(JournalExportRange range) {
    final count = range.count(widget.entries);
    return '$count ${count == 1 ? 'entry' : 'entries'}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedRange = _selectedRange;
    final selectedCount = selectedRange?.count(widget.entries) ?? 0;
    final isPdf = _format == JournalExportFormat.pdf;
    return AlertDialog(
      icon: const Icon(Icons.health_and_safety_outlined),
      title: const Text('Export journal report'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Format', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<JournalExportFormat>(
                segments: const [
                  ButtonSegment(
                    value: JournalExportFormat.pdf,
                    label: Text('PDF'),
                    icon: Icon(Icons.picture_as_pdf_outlined),
                  ),
                  ButtonSegment(
                    value: JournalExportFormat.csv,
                    label: Text('CSV'),
                    icon: Icon(Icons.table_chart_outlined),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: (selection) =>
                    setState(() => _format = selection.single),
              ),
              const SizedBox(height: 8),
              Text(
                isPdf
                    ? 'Includes photos and all journal details.'
                    : 'Includes journal details in one row per entry. Photos are not included.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Text('Date range', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              RadioGroup<JournalExportRangePreset>(
                groupValue: _preset,
                onChanged: (preset) {
                  if (preset != null) _selectPreset(preset);
                },
                child: Column(
                  children: [
                    RadioListTile<JournalExportRangePreset>(
                      value: JournalExportRangePreset.last7Days,
                      title: const Text('Last 7 days'),
                      subtitle: Text(_countLabel(_last7Days)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<JournalExportRangePreset>(
                      value: JournalExportRangePreset.last30Days,
                      title: const Text('Last 30 days'),
                      subtitle: Text(_countLabel(_last30Days)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<JournalExportRangePreset>(
                      value: JournalExportRangePreset.custom,
                      title: const Text('Custom dates'),
                      subtitle: Text(
                        _customRange == null
                            ? 'Choose dates to see the entry count'
                            : '${_customRange!.displayLabel} • ${_countLabel(_customRange!)}',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  selectedRange == null
                      ? 'Choose a custom date range to continue.'
                      : '$selectedCount ${selectedCount == 1 ? 'entry' : 'entries'} will be exported.',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.no_encryption_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This export is not encrypted. Save it privately and share it only with people you trust.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: selectedRange == null || selectedCount == 0
              ? null
              : () => Navigator.pop(
                  context,
                  _ReportExportSelection(format: _format, range: selectedRange),
                ),
          child: Text(isPdf ? 'Create PDF' : 'Create CSV'),
        ),
      ],
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog({required this.title});

  final String title;

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        labelText: '4-digit PIN',
        counterText: '',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_controller.text.length == 4) {
            Navigator.pop(context, _controller.text);
          }
        },
        child: const Text('Continue'),
      ),
    ],
  );
}
