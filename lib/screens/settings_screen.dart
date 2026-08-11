import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../services/journal_archive_service.dart';
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
                      title: Text('Device security'),
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
                      '${widget.journal.entries.length} entries, metadata, and photos in one ZIP',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exportJournal,
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
              'Ritual 1.0 • ${DateFormat.yMMMM().format(DateTime.now())}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
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
