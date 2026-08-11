import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../theme/ritual_theme.dart';
import 'gallery_screen.dart';
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
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
        maxWidth: 2400,
        requestFullMetadata: false,
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
          ),
        ),
      );
      if (outcome is SaveResult) {
        setState(() => _selectedIndex = 0);
        if (outcome.firstEntryToday && mounted) {
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
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 34, 28, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: RitualColors.honey.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 42,
                  color: RitualColors.honey,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                streak == 1
                    ? 'A ritual begins'
                    : '$streak days, gently gathered',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'One meal is enough for today. Come back to notice, not to be perfect.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep going gently'),
              ),
            ],
          ),
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
          GalleryScreen(controller: widget.controller),
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
                  icon: Icons.grid_view_outlined,
                  selectedIcon: Icons.grid_view_rounded,
                  label: 'Gallery',
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
