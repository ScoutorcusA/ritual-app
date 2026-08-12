import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/meal_entry.dart';
import '../theme/ritual_theme.dart';
import '../widgets/meal_photo.dart';
import 'meal_editor_screen.dart';

class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({
    super.key,
    required this.controller,
    required this.entryId,
    this.settings,
  });

  final JournalController controller;
  final int entryId;
  final SettingsController? settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        MealEntry? entry;
        for (final candidate in controller.entries) {
          if (candidate.id == entryId) entry = candidate;
        }
        if (entry == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final currentEntry = entry;
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Edit moment',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<Object?>(
                    builder: (_) => MealEditorScreen(
                      controller: controller,
                      imagePath: currentEntry.imagePath,
                      entry: currentEntry,
                      settings: settings,
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete moment',
                onPressed: () => _confirmDelete(context, currentEntry),
                icon: const Icon(Icons.delete_outline),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: MealPhoto(path: currentEntry.imagePath),
              ),
              const SizedBox(height: 26),
              Text(
                currentEntry.mealType.label,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat(
                  'EEEE, MMMM d · h:mm a',
                ).format(currentEntry.createdAt),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (currentEntry.feelings.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final feeling in currentEntry.feelings)
                      Chip(
                        avatar: const Icon(
                          Icons.circle,
                          size: 8,
                          color: RitualColors.terracotta,
                        ),
                        label: Text(feeling),
                      ),
                  ],
                ),
              ],
              if (currentEntry.hungerLevel != null ||
                  currentEntry.cravingLevel != null ||
                  currentEntry.fullnessLevel != null) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (currentEntry.hungerLevel != null)
                      _ScaleChip(
                        label: 'Hunger before',
                        value: currentEntry.hungerLevel!,
                      ),
                    if (currentEntry.cravingLevel != null)
                      _ScaleChip(
                        label: 'Craving before',
                        value: currentEntry.cravingLevel!,
                      ),
                    if (currentEntry.fullnessLevel != null)
                      _ScaleChip(
                        label: 'Fullness after',
                        value: currentEntry.fullnessLevel!,
                      ),
                  ],
                ),
              ],
              if (currentEntry.note.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text(
                  'Reflection',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  currentEntry.note,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (currentEntry.hasLocation ||
                  currentEntry.locationLabel != null) ...[
                const SizedBox(height: 26),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: RitualColors.sage,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentEntry.locationLabel ??
                          '${currentEntry.latitude!.toStringAsFixed(4)}, '
                              '${currentEntry.longitude!.toStringAsFixed(4)}',
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, MealEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this moment?'),
        content: const Text(
          'Its photo and reflection will be removed from Ritual permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) return;
    await controller.deleteEntry(entry);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _ScaleChip extends StatelessWidget {
  const _ScaleChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.tune_rounded, size: 17),
    label: Text('$label $value/5'),
  );
}
