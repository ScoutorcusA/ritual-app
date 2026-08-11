import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/journal_controller.dart';
import '../models/meal_entry.dart';
import '../theme/ritual_theme.dart';
import '../widgets/meal_photo.dart';

class MealEditorScreen extends StatefulWidget {
  const MealEditorScreen({
    super.key,
    required this.controller,
    required this.imagePath,
    this.entry,
  });

  final JournalController controller;
  final String imagePath;
  final MealEntry? entry;

  bool get editing => entry != null;

  @override
  State<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends State<MealEditorScreen> {
  late MealType _mealType;
  late Set<String> _feelings;
  late TextEditingController _noteController;
  double? _latitude;
  double? _longitude;
  bool _findingLocation = false;
  bool _saving = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _mealType = entry?.mealType ?? _suggestedMealType();
    _feelings = {...?entry?.feelings};
    _noteController = TextEditingController(text: entry?.note ?? '');
    _latitude = entry?.latitude;
    _longitude = entry?.longitude;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  MealType _suggestedMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return MealType.breakfast;
    if (hour < 16) return MealType.lunch;
    if (hour < 22) return MealType.dinner;
    return MealType.snack;
  }

  Future<void> _addLocation() async {
    setState(() {
      _findingLocation = true;
      _locationMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationIssue(
          'Turn on Location Services, then try again.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationIssue('Location permission was not granted.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationIssue(
          'Location is blocked for Ritual. You can enable it in Android settings.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } on _LocationIssue catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _locationMessage = 'Your location could not be added right now.',
        );
      }
    } finally {
      if (mounted) setState(() => _findingLocation = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (widget.editing) {
        final updated = widget.entry!.copyWith(
          mealType: _mealType,
          feelings: _feelings.toList(),
          note: _noteController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          clearLocation: _latitude == null || _longitude == null,
        );
        await widget.controller.updateEntry(updated);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final result = await widget.controller.addEntry(
          MealDraft(
            imagePath: widget.imagePath,
            mealType: _mealType,
            feelings: _feelings.toList(),
            note: _noteController.text.trim(),
            createdAt: DateTime.now(),
            latitude: _latitude,
            longitude: _longitude,
          ),
        );
        if (mounted) Navigator.of(context).pop(result);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This moment could not be saved. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Edit moment' : 'New moment'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: MealPhoto(path: widget.imagePath),
          ),
          const SizedBox(height: 28),
          Text('What was this?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in MealType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: _mealType == type,
                  selectedColor: RitualColors.ink,
                  labelStyle: TextStyle(
                    color: _mealType == type
                        ? RitualColors.paper
                        : RitualColors.ink,
                  ),
                  onSelected: (_) => setState(() => _mealType = type),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'How did it feel?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text('Choose any that fit. This is noticing, not scoring.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final feeling in feelingLabels)
                FilterChip(
                  label: Text(feeling),
                  selected: _feelings.contains(feeling),
                  selectedColor: RitualColors.sage.withValues(alpha: 0.25),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _feelings.add(feeling);
                    } else {
                      _feelings.remove(feeling);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'A note, if you want',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 6,
            maxLength: 280,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What do you want to remember about this meal?',
            ),
          ),
          const SizedBox(height: 20),
          Text('Place', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (_latitude != null && _longitude != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RitualColors.paper,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: RitualColors.sage,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove location',
                    onPressed: () => setState(() {
                      _latitude = null;
                      _longitude = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _findingLocation ? null : _addLocation,
              icon: _findingLocation
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add current location'),
            ),
          if (_locationMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _locationMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.editing ? 'Save changes' : 'Keep this moment'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationIssue implements Exception {
  const _LocationIssue(this.message);
  final String message;
}
