import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../l10n/ritual_i18n.dart';
import '../models/journal_export.dart';
import '../models/meal_entry.dart';
import '../models/personal_intention.dart';
import '../services/journal_archive_service.dart';
import '../services/journal_csv_service.dart';
import '../services/journal_pdf_service.dart';
import '../services/local_file_saver.dart';
import '../services/meal_reminder_service.dart';
import '../services/debug_log_service.dart';
import '../theme/ritual_theme.dart';
import '../widgets/app_lock_gate.dart';
import 'privacy_policy_screen.dart';
import 'support_ritual_screen.dart';

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
  final LocalFileSaver _fileSaver = const LocalFileSaver();
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
            ? tr('Device lock is now protecting Ritual.')
            : tr('Device authentication is not set up or was canceled.'),
      );
    }
  }

  Future<void> _exportJournal() async {
    if (_working) return;
    final protection = await showDialog<_ArchiveProtection>(
      context: context,
      builder: (context) => const _ArchiveExportDialog(),
    );
    if (!mounted || protection == null) return;
    setState(() => _working = true);
    File? temporaryArchive;
    try {
      final directory = await getTemporaryDirectory();
      final outputPath = p.join(
        directory.path,
        'ritual-export-${DateTime.now().microsecondsSinceEpoch}.zip',
      );
      final result = await _archiveService.createArchiveFile(
        widget.journal.entries,
        outputPath: outputPath,
        password: protection.password,
      );
      temporaryArchive = File(result.filePath);
      if (!mounted) return;
      final saved = await AppLockGate.runTrustedInterruption(
        context,
        () => _fileSaver.save(
          sourcePath: result.filePath,
          fileName: result.fileName,
          mimeType: 'application/zip',
        ),
      );
      if (!mounted || !saved) return;
      _message(
        tr(
          result.encrypted
              ? '{entries} exported with password protection.'
              : '{entries} exported.',
          values: {
            'entries': trPlural(
              result.entryCount,
              one: '{count} entry',
              other: '{count} entries',
            ),
          },
        ),
      );
    } on RitualArchiveException catch (error) {
      if (mounted) _message(error.message, error: true);
    } on LocalFileSaverException catch (error) {
      if (mounted) _message(error.message, error: true);
    } catch (error) {
      if (mounted) {
        _message(
          tr('Export failed: {error}', values: {'error': error}),
          error: true,
        );
      }
    } finally {
      if (temporaryArchive != null) {
        try {
          if (await temporaryArchive.exists()) await temporaryArchive.delete();
        } on FileSystemException {
          // Android will eventually clear the cached export.
        }
      }
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
          title: Text(tr('Notifications are turned off')),
          content: Text(
            tr(
              'Android did not allow Ritual to send reminders. You can allow notifications in Ritual’s Android settings, then turn reminders on.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Not now')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('Open settings')),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await widget.settings.openNotificationSettings();
      }
    } else if (result == ReminderToggleResult.unavailable) {
      _message(
        tr('Ritual could not start reminders. Restart the app and try again.'),
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
      helpText: tr('Choose reminder time'),
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

  Future<void> _choosePersonalIntention() async {
    final selected = await showDialog<PersonalIntention>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('Personal intention')),
        children: [
          RadioGroup<PersonalIntention>(
            groupValue: widget.settings.personalIntention,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              children: [
                for (final intention in PersonalIntention.values)
                  RadioListTile<PersonalIntention>(
                    value: intention,
                    title: Text(intention.label),
                    subtitle: Text(intention.description),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected != null) {
      await widget.settings.setPersonalIntention(selected);
    }
  }

  Future<void> _copyDebugLog() async {
    try {
      final log = await DebugLogService.instance.copyableText();
      await Clipboard.setData(ClipboardData(text: log));
      if (mounted) {
        _message(tr('Debug log copied. You can paste it into a message.'));
      }
    } catch (_) {
      if (mounted) {
        _message(tr('The debug log could not be copied.'), error: true);
      }
    }
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
        dialogTitle: tr('Export Ritual journal report'),
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [isPdf ? 'pdf' : 'csv'],
        bytes: bytes,
      );
      if (!mounted || savedPath == null) return;
      _message(
        tr(
          '{entries} exported to {format}.',
          values: {
            'entries': trPlural(
              entryCount,
              one: '{count} entry',
              other: '{count} entries',
            ),
            'format': isPdf ? 'PDF' : 'CSV',
          },
        ),
      );
    } catch (error) {
      if (mounted) {
        _message(
          tr('Report export failed: {error}', values: {'error': error}),
          error: true,
        );
      }
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
        title: Text(tr('Delete all journal data?')),
        content: Text(
          tr(
            'This permanently deletes all {entries}, app-private photos, calendar highlights, and streak history from this device. Your theme, app lock, and reminder setting will stay.\n\nThis cannot be undone. Export first if you may want a copy.',
            values: {
              'entries': trPlural(
                entryCount,
                one: '{count} entry',
                other: '{count} entries',
              ),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Keep my journal')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete everything')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _working = true);
    try {
      await widget.journal.deleteAllJournalData();
      if (mounted) {
        _message(tr('All journal entries and photos were deleted.'));
      }
    } catch (error) {
      if (mounted) {
        _message(
          tr(
            'Ritual could not finish deleting the journal: {error}',
            values: {'error': error},
          ),
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
      final picked = await AppLockGate.runTrustedInterruption(
        context,
        () => FilePicker.pickFile(
          dialogTitle: tr('Import a Ritual journal'),
          type: FileType.custom,
          allowedExtensions: const ['zip'],
        ),
      );
      if (picked == null) return;
      if (picked.size > 1024 * 1024 * 1024 || picked.path == null) {
        throw RitualArchiveException(
          tr('This ZIP is unavailable or too large to import safely.'),
        );
      }
      String? password;
      if (await _archiveService.isEncryptedArchiveFile(picked.path!)) {
        if (!mounted) return;
        password = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const _ArchivePasswordDialog(),
        );
        if (password == null) return;
      }
      final preview = await _archiveService.readArchiveFile(
        picked.path!,
        password: password,
      );
      try {
        final imports = preview.entries;
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('Import this journal?')),
            content: Text(
              tr(
                'Ritual verified {entries} and their photos. Existing entries will stay, and exact repeat imports are skipped.',
                values: {
                  'entries': trPlural(
                    imports.length,
                    one: '{count} entry',
                    other: '{count} entries',
                  ),
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('Import')),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        final imported = await widget.journal.importEntries(imports);
        if (mounted) {
          _message(
            imported == 0
                ? tr('Everything in that archive was already in Ritual.')
                : trPlural(
                    imported,
                    one: '{count} entry imported.',
                    other: '{count} entries imported.',
                  ),
          );
        }
      } finally {
        await preview.dispose();
      }
    } on RitualArchiveException catch (error) {
      if (mounted) _message(error.message, error: true);
    } catch (error) {
      if (mounted) {
        _message(
          tr('Import failed: {error}', values: {'error': error}),
          error: true,
        );
      }
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
        appBar: AppBar(title: Text(tr('Settings'))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _SectionTitle(tr('Appearance')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Color theme')),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(tr('System')),
                          icon: const Icon(Icons.settings_brightness_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(tr('Light')),
                          icon: const Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(tr('Dark')),
                          icon: const Icon(Icons.dark_mode_outlined),
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
            _SectionTitle(tr('Experience')),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(tr('Personal intention')),
                    subtitle: Text(widget.settings.personalIntention.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _choosePersonalIntention,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: widget.settings.streaksEnabled,
                    onChanged: widget.settings.setStreaksEnabled,
                    secondary: const Icon(Icons.local_fire_department_outlined),
                    title: Text(tr('Daily streaks')),
                    subtitle: Text(
                      tr(
                        'Show streak progress and first-entry celebrations. Turning this off does not delete your progress.',
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(tr('Welcome setup')),
                    subtitle: Text(tr('Review your experience choices')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _restartWelcome,
                  ),
                ],
              ),
            ),
            _SectionTitle(tr('Meal reflection')),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    value: widget.settings.hungerScaleEnabled,
                    onChanged: widget.settings.setHungerScaleEnabled,
                    secondary: const Icon(Icons.restaurant_menu_rounded),
                    title: Text(tr('Hunger before eating')),
                    subtitle: Text(tr('Optional five-point check-in')),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: widget.settings.cravingScaleEnabled,
                    onChanged: widget.settings.setCravingScaleEnabled,
                    secondary: const Icon(Icons.bolt_outlined),
                    title: Text(tr('Craving before eating')),
                    subtitle: Text(tr('Optional five-point check-in')),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: widget.settings.fullnessScaleEnabled,
                    onChanged: widget.settings.setFullnessScaleEnabled,
                    secondary: const Icon(Icons.spa_outlined),
                    title: Text(tr('Fullness after eating')),
                    subtitle: Text(tr('Optional five-point check-in')),
                  ),
                ],
              ),
            ),
            _SectionTitle(tr('Privacy')),
            Card(
              clipBehavior: Clip.antiAlias,
              child: RadioGroup<AppLockMode>(
                groupValue: widget.settings.lockMode,
                onChanged: (value) {
                  if (value != null) _chooseLockMode(value);
                },
                child: Column(
                  children: [
                    RadioListTile<AppLockMode>(
                      value: AppLockMode.off,
                      title: Text(tr('No app lock')),
                      secondary: Icon(Icons.lock_open_outlined),
                    ),
                    Divider(height: 1),
                    RadioListTile<AppLockMode>(
                      value: AppLockMode.device,
                      title: Row(
                        children: [
                          Text(tr('Device security')),
                          SizedBox(width: 8),
                          _RecommendedBadge(),
                        ],
                      ),
                      subtitle: Text(tr('Fingerprint, device PIN, or pattern')),
                      secondary: Icon(Icons.fingerprint_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: Text(tr('Privacy policy & health disclaimer')),
                subtitle: Text(tr('How Ritual handles your journal data')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
            ),
            _SectionTitle(tr('Reminders')),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    value: widget.settings.mealRemindersEnabled,
                    onChanged: _setReminders,
                    secondary: const Icon(Icons.notifications_none_rounded),
                    title: Text(tr('Mindful meal reminders')),
                    subtitle: Text(
                      tr(
                        'Local check-ins that automatically skip meals already logged.',
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _ReminderTimeTile(
                    label: tr('Breakfast'),
                    time: _formatMinutes(
                      widget.settings.reminderSchedule.breakfastMinutes,
                    ),
                    onTap: () => _pickReminderTime(
                      MealReminderKind.breakfast,
                      widget.settings.reminderSchedule.breakfastMinutes,
                    ),
                  ),
                  _ReminderTimeTile(
                    label: tr('Lunch'),
                    time: _formatMinutes(
                      widget.settings.reminderSchedule.lunchMinutes,
                    ),
                    onTap: () => _pickReminderTime(
                      MealReminderKind.lunch,
                      widget.settings.reminderSchedule.lunchMinutes,
                    ),
                  ),
                  _ReminderTimeTile(
                    label: tr('Dinner'),
                    time: _formatMinutes(
                      widget.settings.reminderSchedule.dinnerMinutes,
                    ),
                    onTap: () => _pickReminderTime(
                      MealReminderKind.dinner,
                      widget.settings.reminderSchedule.dinnerMinutes,
                    ),
                  ),
                  _ReminderTimeTile(
                    label: tr('Empty-day check-in'),
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
            _SectionTitle(tr('Your data')),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    enabled: !_working,
                    leading: const Icon(Icons.archive_outlined),
                    title: Text(tr('Export journal')),
                    subtitle: Text(
                      tr(
                        '{count} entries, metadata, and photos in a password-protected or standard ZIP',
                        values: {'count': widget.journal.entries.length},
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exportJournal,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    enabled: !_working && widget.journal.entries.isNotEmpty,
                    leading: const Icon(Icons.medical_information_outlined),
                    title: Text(tr('Export report')),
                    subtitle: Text(
                      tr('Choose PDF or CSV and a date range - unencrypted'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exportReport,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    enabled: !_working,
                    leading: const Icon(Icons.unarchive_outlined),
                    title: Text(tr('Import Ritual ZIP')),
                    subtitle: Text(
                      tr('Verifies every entry and photo before importing'),
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
                      tr('Delete all journal data'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      tr('Permanently removes every entry, photo, and streak'),
                    ),
                    onTap: _deleteAllJournalData,
                  ),
                ],
              ),
            ),
            _SectionTitle(tr('About Ritual')),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.favorite_border_rounded,
                      color: RitualColors.terracotta,
                    ),
                    title: Text(tr('Support Ritual')),
                    subtitle: Text(
                      tr('Optional support — Ritual is free forever'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SupportRitualScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: Text(tr('Copy debug log')),
                    subtitle: Text(
                      tr(
                        'Recent technical events only — no photos, notes, places, or coordinates',
                      ),
                    ),
                    trailing: const Icon(Icons.copy_outlined),
                    onTap: _copyDebugLog,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: RitualColors.sage),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr(
                        'Photos and journal data stay inside Ritual unless you explicitly export them. Ritual does not use an account or cloud sync.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              tr(
                'Ritual 1.6 • {month}',
                values: {
                  'month': DateFormat.yMMMM(
                    RitualI18n.localeName,
                  ).format(DateTime.now()),
                },
              ),
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
      tr('RECOMMENDED'),
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
      helpText: tr('Choose journal dates'),
      saveText: tr('Use dates'),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _customRange = JournalExportRange(start: picked.start, end: picked.end);
      _preset = JournalExportRangePreset.custom;
    });
  }

  String _countLabel(JournalExportRange range) {
    final count = range.count(widget.entries);
    return trPlural(count, one: '{count} entry', other: '{count} entries');
  }

  @override
  Widget build(BuildContext context) {
    final selectedRange = _selectedRange;
    final selectedCount = selectedRange?.count(widget.entries) ?? 0;
    final isPdf = _format == JournalExportFormat.pdf;
    return AlertDialog(
      icon: const Icon(Icons.health_and_safety_outlined),
      title: Text(tr('Export journal report')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Format'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<JournalExportFormat>(
                segments: [
                  ButtonSegment(
                    value: JournalExportFormat.pdf,
                    label: Text(tr('PDF')),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                  ButtonSegment(
                    value: JournalExportFormat.csv,
                    label: Text(tr('CSV')),
                    icon: const Icon(Icons.table_chart_outlined),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: (selection) =>
                    setState(() => _format = selection.single),
              ),
              const SizedBox(height: 8),
              Text(
                isPdf
                    ? tr('Includes photos and all journal details.')
                    : tr(
                        'Includes journal details in one row per entry. Photos are not included.',
                      ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Text(
                tr('Date range'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
                      title: Text(tr('Last 7 days')),
                      subtitle: Text(_countLabel(_last7Days)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<JournalExportRangePreset>(
                      value: JournalExportRangePreset.last30Days,
                      title: Text(tr('Last 30 days')),
                      subtitle: Text(_countLabel(_last30Days)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<JournalExportRangePreset>(
                      value: JournalExportRangePreset.custom,
                      title: Text(tr('Custom dates')),
                      subtitle: Text(
                        _customRange == null
                            ? tr('Choose dates to see the entry count')
                            : tr(
                                '{dateRange} • {entries}',
                                values: {
                                  'dateRange': _customRange!.displayLabel,
                                  'entries': _countLabel(_customRange!),
                                },
                              ),
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
                      ? tr('Choose a custom date range to continue.')
                      : tr(
                          '{entries} will be exported.',
                          values: {
                            'entries': trPlural(
                              selectedCount,
                              one: '{count} entry',
                              other: '{count} entries',
                            ),
                          },
                        ),
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
                      tr(
                        'This export is not encrypted. Save it privately and share it only with people you trust.',
                      ),
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
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          onPressed: selectedRange == null || selectedCount == 0
              ? null
              : () => Navigator.pop(
                  context,
                  _ReportExportSelection(format: _format, range: selectedRange),
                ),
          child: Text(isPdf ? tr('Create PDF') : tr('Create CSV')),
        ),
      ],
    );
  }
}

enum _ArchiveProtectionMode { encrypted, standard }

class _ArchiveProtection {
  const _ArchiveProtection({this.password});

  final String? password;
}

class _ArchiveExportDialog extends StatefulWidget {
  const _ArchiveExportDialog();

  @override
  State<_ArchiveExportDialog> createState() => _ArchiveExportDialogState();
}

class _ArchiveExportDialogState extends State<_ArchiveExportDialog> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  _ArchiveProtectionMode _mode = _ArchiveProtectionMode.encrypted;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_mode == _ArchiveProtectionMode.standard) {
      Navigator.pop(context, const _ArchiveProtection());
      return;
    }
    final password = _passwordController.text;
    if (password.length < JournalArchiveService.minimumPasswordLength) {
      setState(
        () => _error = tr(
          'Use at least {count} characters.',
          values: {'count': JournalArchiveService.minimumPasswordLength},
        ),
      );
      return;
    }
    if (password != _confirmationController.text) {
      setState(() => _error = tr('The passwords do not match.'));
      return;
    }
    Navigator.pop(context, _ArchiveProtection(password: password));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: Icon(
      _mode == _ArchiveProtectionMode.encrypted
          ? Icons.enhanced_encryption_outlined
          : Icons.no_encryption_outlined,
    ),
    title: Text(tr('Protect this backup')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<_ArchiveProtectionMode>(
            groupValue: _mode,
            onChanged: (value) {
              if (value != null) setState(() => _mode = value);
            },
            child: Column(
              children: [
                RadioListTile<_ArchiveProtectionMode>(
                  contentPadding: EdgeInsets.zero,
                  value: _ArchiveProtectionMode.encrypted,
                  title: Text(tr('Password-protected ZIP')),
                  subtitle: Text(tr('Recommended - AES-256 encryption')),
                ),
                RadioListTile<_ArchiveProtectionMode>(
                  contentPadding: EdgeInsets.zero,
                  value: _ArchiveProtectionMode.standard,
                  title: Text(tr('Standard ZIP')),
                  subtitle: Text(tr('Compatible but readable by anyone')),
                ),
              ],
            ),
          ),
          if (_mode == _ArchiveProtectionMode.encrypted) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: tr('Export password'),
                helperText: tr('At least 12 characters'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmationController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _continue(),
              decoration: InputDecoration(labelText: tr('Confirm password')),
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                'Ritual cannot recover this password. You will need it to import the ZIP.',
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              tr(
                'Anyone who opens this ZIP can see its photos, notes, feelings, dates, and saved places.',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Cancel')),
      ),
      FilledButton(onPressed: _continue, child: Text(tr('Create ZIP'))),
    ],
  );
}

class _ArchivePasswordDialog extends StatefulWidget {
  const _ArchivePasswordDialog();

  @override
  State<_ArchivePasswordDialog> createState() => _ArchivePasswordDialogState();
}

class _ArchivePasswordDialogState extends State<_ArchivePasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    if (_controller.text.isNotEmpty) Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.lock_outline_rounded),
    title: Text(tr('Encrypted Ritual ZIP')),
    content: TextField(
      controller: _controller,
      autofocus: true,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (_) => _continue(),
      decoration: InputDecoration(
        labelText: tr('Export password'),
        helperText: tr('Use the password chosen when this ZIP was exported.'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Cancel')),
      ),
      FilledButton(onPressed: _continue, child: Text(tr('Unlock'))),
    ],
  );
}
