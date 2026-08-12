import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../theme/ritual_theme.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/streak_celebration_overlay.dart';
import 'browse_screen.dart';
import 'journal_screen.dart';
import 'meal_editor_screen.dart';
import 'settings_screen.dart';

class RitualShell extends StatefulWidget {
  const RitualShell({super.key, required this.controller, this.settings});

  final JournalController controller;
  final SettingsController? settings;

  @override
  State<RitualShell> createState() => _RitualShellState();
}

class _RitualShellState extends State<RitualShell> {
  final ImagePicker _imagePicker = ImagePicker();
  int _selectedIndex = 0;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _recoverInterruptedCapture(),
    );
  }

  Future<void> _recoverInterruptedCapture() async {
    final response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) return;
    final files = response.files;
    if (files != null && files.isNotEmpty && mounted) {
      await _preparePhoto(files.first);
    }
  }

  Future<void> _captureMeal() async {
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
      if (photo != null && mounted) await _preparePhoto(photo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The camera could not be opened.')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _preparePhoto(XFile temporaryPhoto) async {
    String? privatePath;
    try {
      privatePath = await widget.controller.keepCapturedPhoto(temporaryPhoto);
      if (!mounted) {
        await widget.controller.discardPhoto(privatePath);
        return;
      }
      final outcome = await Navigator.of(context).push<Object?>(
        MaterialPageRoute<Object?>(
          builder: (_) => MealEditorScreen(
            controller: widget.controller,
            imagePath: privatePath!,
            settings: widget.settings,
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
      } else {
        await widget.controller.discardPhoto(privatePath);
      }
    } catch (_) {
      if (privatePath != null) {
        await widget.controller.discardPhoto(privatePath);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That photo could not be prepared.')),
        );
      }
    }
  }

  Future<void> _showStreakMoment() {
    final streak = widget.controller.currentStreak;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Streak updated',
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
        tooltip: 'Photograph a meal',
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
                  label: 'Journal',
                  selected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
              ),
              const SizedBox(width: 82),
              Expanded(
                child: _NavItem(
                  icon: Icons.collections_bookmark_outlined,
                  selectedIcon: Icons.collections_bookmark_rounded,
                  label: 'Browse',
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
