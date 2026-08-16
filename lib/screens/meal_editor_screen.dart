import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../l10n/ritual_i18n.dart';
import '../models/meal_entry.dart';
import '../models/personal_intention.dart';
import '../services/city_geocoder.dart';
import '../services/debug_log_service.dart';
import '../theme/ritual_theme.dart';
import '../widgets/meal_photo.dart';

class MealEditorScreen extends StatefulWidget {
  const MealEditorScreen({
    super.key,
    required this.controller,
    required this.imagePath,
    this.entry,
    this.settings,
    this.initialMealType,
  });

  final JournalController controller;
  final String imagePath;
  final MealEntry? entry;
  final SettingsController? settings;
  final MealType? initialMealType;

  bool get editing => entry != null;

  @override
  State<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends State<MealEditorScreen> {
  static const _cityGeocoder = CityGeocoder();
  late MealType _mealType;
  late Set<String> _feelings;
  late TextEditingController _noteController;
  double? _latitude;
  double? _longitude;
  String? _locationLabel;
  bool _findingLocation = false;
  bool _saving = false;
  String? _locationMessage;
  int? _hungerLevel;
  int? _fullnessLevel;
  int? _cravingLevel;
  int _locationAttempt = 0;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _mealType =
        entry?.mealType ?? widget.initialMealType ?? _suggestedMealType();
    _feelings = {...?entry?.feelings};
    _noteController = TextEditingController(text: entry?.note ?? '');
    _latitude = entry?.latitude;
    _longitude = entry?.longitude;
    _locationLabel = entry?.locationLabel;
    _hungerLevel = entry?.hungerLevel;
    _fullnessLevel = entry?.fullnessLevel;
    _cravingLevel = entry?.cravingLevel;
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
    if (_findingLocation) return;
    final attempt = ++_locationAttempt;
    final useDirectProvider = attempt > 1;
    setState(() {
      _findingLocation = true;
      _locationMessage = useDirectProvider
          ? tr('Trying Android’s alternate location provider…')
          : tr('Finding your approximate location…');
    });
    unawaited(
      DebugLogService.instance.record(
        'location',
        'attempt $attempt started; provider=${useDirectProvider ? 'direct' : 'fused'}',
      ),
    );
    try {
      final geolocator = GeolocatorPlatform.instance;
      if (!await geolocator.isLocationServiceEnabled()) {
        unawaited(
          DebugLogService.instance.record('location', 'services disabled'),
        );
        throw _LocationIssue(tr('Turn on Location Services, then try again.'));
      }
      var permission = await geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw _LocationIssue(tr('Location permission was not granted.'));
      }
      if (permission == LocationPermission.deniedForever) {
        throw _LocationIssue(
          tr(
            'Location is blocked for Ritual. You can enable it in Android settings.',
          ),
        );
      }
      unawaited(
        DebugLogService.instance.record(
          'location',
          'permission=${permission.name}',
        ),
      );
      final settings = AndroidSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 30),
        forceLocationManager: useDirectProvider,
      );
      final lastKnown = await geolocator.getLastKnownPosition(
        forceLocationManager: useDirectProvider,
      );
      unawaited(
        DebugLogService.instance.record(
          'location',
          'last-known available=${lastKnown != null}',
        ),
      );
      Position position;
      try {
        position = await geolocator.getCurrentPosition(
          locationSettings: settings,
        );
        unawaited(
          DebugLogService.instance.record(
            'location',
            'fresh approximate position received',
          ),
        );
      } on TimeoutException {
        unawaited(
          DebugLogService.instance.record(
            'location',
            'position timed out; fallback=${lastKnown != null}',
          ),
        );
        if (lastKnown == null) {
          throw _LocationIssue(
            tr(
              'Android did not find a location within 30 seconds. Try near a window, or confirm that Location is on in Android settings.',
            ),
          );
        }
        position = lastKnown;
      } on PlatformException {
        if (lastKnown == null) rethrow;
        position = lastKnown;
      }
      try {
        unawaited(
          DebugLogService.instance.record('location', 'city lookup started'),
        );
        final label = await _cityGeocoder
            .cityAndCountry(
              latitude: position.latitude,
              longitude: position.longitude,
            )
            .timeout(const Duration(seconds: 12));
        if (!mounted) return;
        setState(() {
          // Ritual only needs a broad place label. Do not retain raw coordinates.
          _latitude = null;
          _longitude = null;
          _locationLabel = label;
          _locationMessage = null;
        });
        unawaited(
          DebugLogService.instance.record('location', 'city lookup succeeded'),
        );
        return;
      } on CityGeocoderException catch (error) {
        unawaited(
          DebugLogService.instance.record(
            'location',
            'city lookup failed: ${error.message}',
          ),
        );
        throw _LocationIssue(
          tr(
            '{error} Enter your city manually, or try again later.',
            values: {'error': error.message},
          ),
        );
      } on TimeoutException {
        unawaited(
          DebugLogService.instance.record('location', 'city lookup timed out'),
        );
        throw _LocationIssue(
          tr(
            'Android’s place-name service did not respond. Enter your city manually, or try again later.',
          ),
        );
      }
    } on _LocationIssue catch (error) {
      unawaited(
        DebugLogService.instance.record('location', 'failed: ${error.message}'),
      );
      if (mounted) setState(() => _locationMessage = error.message);
    } on LocationServiceDisabledException {
      unawaited(
        DebugLogService.instance.record('location', 'services disabled'),
      );
      if (mounted) {
        setState(
          () => _locationMessage = tr('Android Location Services are off.'),
        );
      }
    } on PermissionDeniedException {
      unawaited(
        DebugLogService.instance.record('location', 'permission denied'),
      );
      if (mounted) {
        setState(
          () => _locationMessage = tr('Android denied location access.'),
        );
      }
    } on PlatformException catch (error) {
      unawaited(
        DebugLogService.instance.record(
          'location',
          'platform failure: ${error.code}',
        ),
      );
      if (mounted) {
        setState(
          () => _locationMessage = tr(
            'Android could not provide a location ({code}).',
            values: {'code': error.code},
          ),
        );
      }
    } catch (error) {
      unawaited(
        DebugLogService.instance.record(
          'location',
          'unexpected failure: ${error.runtimeType}',
        ),
      );
      if (mounted) {
        setState(
          () => _locationMessage = tr(
            'Your location could not be added right now ({errorType}).',
            values: {'errorType': error.runtimeType},
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _findingLocation = false);
    }
  }

  Future<void> _enterPlaceManually() async {
    final controller = TextEditingController(text: _locationLabel ?? '');
    final place = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Enter a place')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: tr('Place name'),
            hintText: tr('Columbus, United States…'),
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
            },
            child: Text(tr('Use place')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || place == null) return;
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationLabel = place;
      _locationMessage = null;
    });
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
          clearCoordinates: _latitude == null || _longitude == null,
          clearLocationLabel: _locationLabel == null,
          hungerLevel: _hungerLevel,
          fullnessLevel: _fullnessLevel,
          cravingLevel: _cravingLevel,
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
            hungerLevel: _hungerLevel,
            fullnessLevel: _fullnessLevel,
            cravingLevel: _cravingLevel,
          ),
        );
        if (mounted) Navigator.of(context).pop(result);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('This moment could not be saved. Please try again.'),
          ),
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
        title: Text(widget.editing ? tr('Edit moment') : tr('New moment')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(tr('Save')),
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
          Text(
            tr('What was this?'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in MealType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: _mealType == type,
                  showCheckmark: false,
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
          if (widget.settings?.hungerScaleEnabled ?? false) ...[
            _ReflectionScale(
              title: tr('How hungry were you before?'),
              lowLabel: tr('Not hungry'),
              highLabel: tr('Very hungry'),
              value: _hungerLevel,
              onChanged: (value) => setState(() => _hungerLevel = value),
            ),
            const SizedBox(height: 24),
          ],
          if (widget.settings?.cravingScaleEnabled ?? false) ...[
            _ReflectionScale(
              title: tr('How strong was the craving?'),
              lowLabel: tr('No craving'),
              highLabel: tr('Very strong'),
              value: _cravingLevel,
              onChanged: (value) => setState(() => _cravingLevel = value),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            tr('How did it feel?'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(tr('Choose any that fit. This is noticing, not scoring.')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final feeling in feelingLabels)
                FilterChip(
                  label: Text(tr(feeling)),
                  selected: _feelings.contains(feeling),
                  showCheckmark: false,
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
          if (widget.settings?.fullnessScaleEnabled ?? false) ...[
            _ReflectionScale(
              title: tr('How full did you feel afterwards?'),
              lowLabel: tr('Still hungry'),
              highLabel: tr('Very full'),
              value: _fullnessLevel,
              onChanged: (value) => setState(() => _fullnessLevel = value),
            ),
            const SizedBox(height: 28),
          ],
          Text(
            tr('A note, if you want'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  widget.settings?.personalIntention.reflectionHint ??
                  tr('What do you want to remember about this meal?'),
            ),
          ),
          const SizedBox(height: 20),
          Text(tr('Place'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (_locationLabel != null ||
              (_latitude != null && _longitude != null))
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
                    tooltip: tr('Remove location'),
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
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _findingLocation ? null : _addLocation,
                icon: _findingLocation
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: Text(
                  _locationLabel == null && _latitude == null
                      ? tr('Use approximate location')
                      : tr('Refresh location'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _findingLocation ? null : _enterPlaceManually,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: Text(
                  _locationLabel == null ? tr('Enter place') : tr('Edit place'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                _locationMessage ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _findingLocation
                      ? colors.onSurfaceVariant
                      : colors.error,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(
              widget.editing ? tr('Save changes') : tr('Keep this moment'),
            ),
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

class _ReflectionScale extends StatelessWidget {
  const _ReflectionScale({
    required this.title,
    required this.lowLabel,
    required this.highLabel,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String lowLabel;
  final String highLabel;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (value != null)
              TextButton(
                onPressed: () => onChanged(null),
                child: Text(tr('Clear')),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var level = 1; level <= 5; level++) ...[
              if (level > 1) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: tr(
                    '{title} {level} of 5',
                    values: {'title': title, 'level': level},
                  ),
                  selected: value == level,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onChanged(level),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: value == level
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '$level',
                        style: TextStyle(
                          color: value == level
                              ? colors.onPrimary
                              : colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: Text(
                lowLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: Text(
                highLabel,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          tr('Optional - choose what feels closest.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
