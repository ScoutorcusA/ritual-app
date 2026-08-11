import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

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
  String? _locationLabel;
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
    _locationLabel = entry?.locationLabel;
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
      final geolocator = GeolocatorPlatform.instance;
      if (!await geolocator.isLocationServiceEnabled()) {
        throw const _LocationIssue(
          'Turn on Location Services, then try again.',
        );
      }
      var permission = await geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationIssue('Location permission was not granted.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationIssue(
          'Location is blocked for Ritual. You can enable it in Android settings.',
        );
      }
      final lastKnown = await geolocator.getLastKnownPosition();
      Position position;
      var usedLastKnown = false;
      try {
        position = await geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 30),
          ),
        );
      } on TimeoutException {
        if (lastKnown == null) {
          throw const _LocationIssue(
            'Android did not find a location within 30 seconds. Try near a '
            'window, or confirm that Location is on in Android settings.',
          );
        }
        position = lastKnown;
        usedLastKnown = true;
      } on PlatformException {
        if (lastKnown == null) rethrow;
        position = lastKnown;
        usedLastKnown = true;
      }
      String? label;
      try {
        final geocoder = Geocoding();
        if (await geocoder.isPresent()) {
          final places = await geocoder
              .placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(const Duration(seconds: 8));
          if (places.isNotEmpty) {
            final place = places.first;
            label = _firstNonEmpty([
              place.administrativeArea,
              place.locality,
              place.subAdministrativeArea,
              place.country,
            ]);
          }
        }
      } catch (_) {
        // Coordinates remain useful even if Android's geocoder is unavailable.
      }
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationLabel = label;
        if (usedLastKnown) {
          _locationMessage =
              'Using Android’s last known location because a '
              'fresh fix was not available.';
        } else if (label == null) {
          _locationMessage =
              'Location added. Android could not name this place, '
              'so Ritual saved the coordinates.';
        }
      });
    } on _LocationIssue catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } on LocationServiceDisabledException {
      if (mounted) {
        setState(() => _locationMessage = 'Android Location Services are off.');
      }
    } on PermissionDeniedException {
      if (mounted) {
        setState(() => _locationMessage = 'Android denied location access.');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _locationMessage =
              'Android could not provide a location (${error.code}).',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _locationMessage =
              'Your location could not be added right now (${error.runtimeType}).',
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
          locationLabel: _locationLabel,
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
            locationLabel: _locationLabel,
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
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                  selectedColor: dark
                      ? const Color(0xFF3B3A34)
                      : RitualColors.ink,
                  backgroundColor: colors.surface,
                  checkmarkColor: RitualColors.paper,
                  side: BorderSide(color: colors.outline),
                  labelStyle: TextStyle(
                    color: _mealType == type
                        ? RitualColors.paper
                        : colors.onSurface,
                    fontWeight: _mealType == type
                        ? FontWeight.w700
                        : FontWeight.w500,
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
                  backgroundColor: colors.surface,
                  checkmarkColor: colors.onSurface,
                  side: BorderSide(color: colors.outline),
                  labelStyle: TextStyle(color: colors.onSurface),
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
                color: colors.surface,
                border: Border.all(color: colors.outlineVariant),
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
                      _locationLabel ??
                          '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove location',
                    onPressed: () => setState(() {
                      _latitude = null;
                      _longitude = null;
                      _locationLabel = null;
                      _locationMessage = null;
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

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

class _LocationIssue implements Exception {
  const _LocationIssue(this.message);
  final String message;
}
