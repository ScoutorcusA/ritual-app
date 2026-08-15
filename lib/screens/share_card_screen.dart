import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/meal_entry.dart';
import '../theme/ritual_theme.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/meal_photo.dart';

class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({
    super.key,
    required this.entries,
    required this.currentStreak,
    required this.streaksEnabled,
  });

  final List<MealEntry> entries;
  final int currentStreak;
  final bool streaksEnabled;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  late final List<MealEntry> _recentEntries;
  late final Set<int> _selectedIds;
  late bool _includeStreak;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _recentEntries = widget.entries.take(12).toList(growable: false);
    _selectedIds = _recentEntries.take(4).map((entry) => entry.id).toSet();
    _includeStreak = widget.streaksEnabled && widget.currentStreak > 0;
  }

  List<MealEntry> get _selectedEntries => _recentEntries
      .where((entry) => _selectedIds.contains(entry.id))
      .take(4)
      .toList(growable: false);

  void _toggleEntry(MealEntry entry) {
    setState(() {
      if (_selectedIds.remove(entry.id)) return;
      if (_selectedIds.length < 4) _selectedIds.add(entry.id);
    });
  }

  Future<void> _share() async {
    if (_sharing || _selectedEntries.isEmpty) return;
    setState(() => _sharing = true);
    File? temporaryCard;
    try {
      for (final entry in _selectedEntries) {
        await precacheImage(FileImage(File(entry.imagePath)), context);
      }
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Share card was not ready.');
      final pixelRatio = (1080 / boundary.size.width).clamp(1.0, 4.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Share card could not be rendered.');
      final directory = await getTemporaryDirectory();
      temporaryCard = File(
        p.join(
          directory.path,
          'ritual-share-${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await temporaryCard.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      await AppLockGate.runTrustedInterruption(
        context,
        () => SharePlus.instance.share(
          ShareParams(
            files: [XFile(temporaryCard!.path, mimeType: 'image/png')],
            text: 'A mindful moment from Ritual',
            subject: 'My Ritual reflection',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The share card could not be created.')),
        );
      }
    } finally {
      if (temporaryCard != null) {
        try {
          if (await temporaryCard.exists()) await temporaryCard.delete();
        } on FileSystemException {
          // Android will eventually clear this cache file.
        }
      }
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedEntries;
    return Scaffold(
      appBar: AppBar(title: const Text('Share a reflection')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Choose up to four recent moments',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Only the selected photos and optional streak appear. Notes, feelings, dates, and places stay private.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentEntries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = _recentEntries[index];
                final selected = _selectedIds.contains(entry.id);
                return Semantics(
                  label: '${entry.mealType.label} photo',
                  selected: selected,
                  child: InkWell(
                    onTap: () => _toggleEntry(entry),
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        Container(
                          width: 82,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? RitualColors.terracotta
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: MealPhoto(path: entry.imagePath),
                          ),
                        ),
                        if (selected)
                          const Positioned(
                            right: 5,
                            top: 5,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: RitualColors.terracotta,
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.streaksEnabled && widget.currentStreak > 0) ...[
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeStreak,
              onChanged: (value) => setState(() => _includeStreak = value),
              title: const Text('Include current streak'),
              subtitle: Text('${widget.currentStreak} days'),
            ),
          ],
          const SizedBox(height: 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _ShareCardArtwork(
                    entries: selected,
                    streak: _includeStreak ? widget.currentStreak : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: selected.isEmpty || _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(_sharing ? 'Preparing card…' : 'Share card'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareCardArtwork extends StatelessWidget {
  const _ShareCardArtwork({required this.entries, required this.streak});

  final List<MealEntry> entries;
  final int? streak;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: RitualColors.paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 25, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              streak == null ? 'RECENT MOMENTS' : 'A GENTLE STREAK',
              style: const TextStyle(
                color: RitualColors.sage,
                fontSize: 11,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              streak == null
                  ? 'A few things I noticed'
                  : '$streak days of noticing',
              style: const TextStyle(
                color: RitualColors.ink,
                fontSize: 26,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 17),
            Expanded(child: _PhotoCollage(entries: entries)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.yMMMM().format(DateTime.now()),
                  style: const TextStyle(
                    color: RitualColors.sage,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'MADE WITH RITUAL',
                  style: TextStyle(
                    color: RitualColors.terracotta,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCollage extends StatelessWidget {
  const _PhotoCollage({required this.entries});

  final List<MealEntry> entries;

  Widget _photo(MealEntry entry) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: MealPhoto(path: entry.imagePath),
  );

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: RitualColors.sage.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
      );
    }
    if (entries.length == 1) return _photo(entries.first);
    if (entries.length == 2) {
      return Row(
        children: [
          Expanded(child: _photo(entries[0])),
          const SizedBox(width: 7),
          Expanded(child: _photo(entries[1])),
        ],
      );
    }
    if (entries.length == 3) {
      return Column(
        children: [
          Expanded(flex: 6, child: _photo(entries[0])),
          const SizedBox(height: 7),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(child: _photo(entries[1])),
                const SizedBox(width: 7),
                Expanded(child: _photo(entries[2])),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _photo(entries[0])),
              const SizedBox(width: 7),
              Expanded(child: _photo(entries[1])),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _photo(entries[2])),
              const SizedBox(width: 7),
              Expanded(child: _photo(entries[3])),
            ],
          ),
        ),
      ],
    );
  }
}
