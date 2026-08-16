import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../l10n/ritual_i18n.dart';
import '../models/meal_entry.dart';
import '../models/personal_intention.dart';
import '../services/adaptive_reminder_advisor.dart';
import '../services/meal_reminder_service.dart';
import '../theme/ritual_theme.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/streak_celebration_overlay.dart';
import 'browse_screen.dart';
import 'journal_screen.dart';
import 'meal_editor_screen.dart';
import 'settings_screen.dart';

class RitualShell extends StatefulWidget {
  const RitualShell({
    super.key,
    required this.controller,
    this.settings,
    this.reminders,
  });

  final JournalController controller;
  final SettingsController? settings;
  final MealReminderScheduler? reminders;

  @override
  State<RitualShell> createState() => _RitualShellState();
}

class _RitualShellState extends State<RitualShell> {
  final ImagePicker _imagePicker = ImagePicker();
  int _selectedIndex = 0;
  bool _capturing = false;
  bool _showingAdaptivePrompt = false;
  bool _checkedExistingPatterns = false;
  StreamSubscription<MealReminderResponse>? _reminderSubscription;
  static const _adaptiveAdvisor = AdaptiveReminderAdvisor();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_journalChanged);
    _reminderSubscription = widget.reminders?.responses.listen(
      _handleReminderResponse,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _recoverInterruptedCapture();
      final initial = await widget.reminders?.takeInitialResponse();
      if (initial != null) await _handleReminderResponse(initial);
      _journalChanged();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_journalChanged);
    _reminderSubscription?.cancel();
    super.dispose();
  }

  void _journalChanged() {
    if (_checkedExistingPatterns || widget.controller.loading) return;
    _checkedExistingPatterns = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerAdaptiveTime());
  }

  Future<void> _recoverInterruptedCapture() async {
    final response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) return;
    final files = response.files;
    if (files != null && files.isNotEmpty && mounted) {
      await _preparePhoto(files.first);
    }
  }

  Future<void> _captureMeal([MealType? initialMealType]) async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final photo = await AppLockGate.runTrustedInterruption(
        context,
        () => _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 92,
          maxWidth: 2400,
          requestFullMetadata: false,
        ),
      );
      if (photo != null && mounted) {
        await _preparePhoto(photo, initialMealType: initialMealType);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('The camera could not be opened.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _preparePhoto(
    XFile temporaryPhoto, {
    MealType? initialMealType,
  }) async {
    String? privatePath;
    try {
      privatePath = await widget.controller.keepCapturedPhoto(temporaryPhoto);
      if (!mounted) {
        await widget.controller.discardPhoto(privatePath);
        return;
      }
      await _openNewEntry(privatePath, initialMealType: initialMealType);
    } catch (_) {
      if (privatePath != null) {
        await widget.controller.discardPhoto(privatePath);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('That photo could not be prepared.'))),
        );
      }
    }
  }

  Future<void> _openNewEntry(
    String privatePath, {
    MealType? initialMealType,
  }) async {
    try {
      final outcome = await Navigator.of(context).push<Object?>(
        MaterialPageRoute<Object?>(
          builder: (_) => MealEditorScreen(
            controller: widget.controller,
            imagePath: privatePath,
            settings: widget.settings,
            initialMealType: initialMealType,
          ),
        ),
      );
      if (outcome is SaveResult) {
        setState(() => _selectedIndex = 0);
        if (outcome.firstEntryToday &&
            (widget.settings?.streaksEnabled ?? true) &&
            mounted) {
          await _showStreakMoment();
        }
        final savedKind = _kindFor(outcome.entry.mealType);
        if (savedKind != null) await _offerAdaptiveTime(kind: savedKind);
      } else {
        await widget.controller.discardPhoto(privatePath);
      }
    } catch (_) {
      await widget.controller.discardPhoto(privatePath);
      rethrow;
    }
  }

  Future<void> _handleReminderResponse(MealReminderResponse response) async {
    while (mounted && !AppLockGate.interactionAllowed(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final type = _mealTypeFor(response.kind);
    switch (response.action) {
      case ReminderAction.takePhoto:
        await _captureMeal(type);
        return;
      case ReminderAction.snooze:
        await widget.reminders?.snooze(
          response.kind,
          intention:
              widget.settings?.personalIntention ??
              PersonalIntention.mindfulPause,
        );
        if (mounted) _message(tr('We’ll remind you again in 30 minutes.'));
        return;
      case ReminderAction.skipToday:
        await widget.settings?.skipRemindersToday();
        if (mounted) _message(tr('Meal reminders are paused for today.'));
        return;
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _offerAdaptiveTime({MealReminderKind? kind}) async {
    final settings = widget.settings;
    if (!mounted ||
        _showingAdaptivePrompt ||
        settings == null ||
        !settings.mealRemindersEnabled) {
      return;
    }
    final kinds = kind == null
        ? const [
            MealReminderKind.breakfast,
            MealReminderKind.lunch,
            MealReminderKind.dinner,
          ]
        : [kind];
    AdaptiveReminderSuggestion? suggestion;
    for (final candidate in kinds) {
      suggestion = _adaptiveAdvisor.suggestionFor(
        entries: widget.controller.entries,
        kind: candidate,
        currentMinutes: _minutesFor(settings.reminderSchedule, candidate),
        dismissedSuggestedMinutes: settings.dismissedAdaptiveTime(candidate),
      );
      if (suggestion != null) break;
    }
    if (suggestion == null || !mounted) return;
    final prompt = suggestion;
    _showingAdaptivePrompt = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.schedule_outlined),
        title: Text(
          tr(
            'A better time for {mealType}?',
            values: {'mealType': _kindLabel(prompt.kind)},
          ),
        ),
        content: Text(
          tr(
            'Your recent {mealType} entries have usually been logged around {typicalTime}. Move the reminder to {suggestedTime}?',
            values: {
              'mealType': _kindLabel(prompt.kind),
              'typicalTime': _formatMinutes(context, prompt.typicalMinutes),
              'suggestedTime': _formatMinutes(context, prompt.suggestedMinutes),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              tr(
                'Keep {time}',
                values: {
                  'time': _formatMinutes(context, prompt.currentMinutes),
                },
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr(
                'Move to {time}',
                values: {
                  'time': _formatMinutes(context, prompt.suggestedMinutes),
                },
              ),
            ),
          ),
        ],
      ),
    );
    _showingAdaptivePrompt = false;
    if (accepted == true) {
      await settings.setReminderTime(prompt.kind, prompt.suggestedMinutes);
    } else {
      await settings.dismissAdaptiveReminderSuggestion(
        prompt.kind,
        prompt.suggestedMinutes,
      );
    }
  }

  MealType? _mealTypeFor(MealReminderKind kind) => switch (kind) {
    MealReminderKind.breakfast => MealType.breakfast,
    MealReminderKind.lunch => MealType.lunch,
    MealReminderKind.dinner => MealType.dinner,
    MealReminderKind.emptyDay => null,
  };

  MealReminderKind? _kindFor(MealType type) => switch (type) {
    MealType.breakfast => MealReminderKind.breakfast,
    MealType.lunch => MealReminderKind.lunch,
    MealType.dinner => MealReminderKind.dinner,
    MealType.snack => null,
  };

  int _minutesFor(ReminderSchedule schedule, MealReminderKind kind) =>
      switch (kind) {
        MealReminderKind.breakfast => schedule.breakfastMinutes,
        MealReminderKind.lunch => schedule.lunchMinutes,
        MealReminderKind.dinner => schedule.dinnerMinutes,
        MealReminderKind.emptyDay => schedule.emptyDayMinutes,
      };

  String _kindLabel(MealReminderKind kind) => switch (kind) {
    MealReminderKind.breakfast => tr('breakfast'),
    MealReminderKind.lunch => tr('lunch'),
    MealReminderKind.dinner => tr('dinner'),
    MealReminderKind.emptyDay => tr('evening check-in'),
  };

  String _formatMinutes(BuildContext context, int minutes) =>
      MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));

  Future<void> _showStreakMoment() {
    final streak = widget.controller.currentStreak;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: tr('Streak updated'),
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => StreakCelebrationOverlay(streak: streak),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          JournalScreen(
            controller: widget.controller,
            settings: widget.settings,
            onCapture: _captureMeal,
            onSettings: () {
              final settings = widget.settings;
              if (settings != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(
                      settings: settings,
                      journal: widget.controller,
                    ),
                  ),
                );
              }
            },
          ),
          BrowseScreen(
            controller: widget.controller,
            settings: widget.settings,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.large(
        onPressed: _capturing ? null : _captureMeal,
        tooltip: tr('Photograph a meal'),
        backgroundColor: RitualColors.terracotta,
        foregroundColor: Colors.white,
        child: _capturing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add_a_photo_outlined, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        elevation: 10,
        shadowColor: Colors.black26,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        height: 74,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.auto_stories_outlined,
                  selectedIcon: Icons.auto_stories,
                  label: tr('Journal'),
                  selected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
              ),
              const SizedBox(width: 82),
              Expanded(
                child: _NavItem(
                  icon: Icons.collections_bookmark_outlined,
                  selectedIcon: Icons.collections_bookmark_rounded,
                  label: tr('Browse'),
                  selected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? selectedIcon : icon,
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.48),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.48),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
