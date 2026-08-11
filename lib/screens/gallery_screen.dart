import 'package:flutter/material.dart';

import '../controllers/journal_controller.dart';
import '../models/meal_entry.dart';
import '../theme/ritual_theme.dart';
import '../widgets/meal_photo.dart';
import 'entry_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.controller});

  final JournalController controller;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  MealType? _mealFilter;
  String? _feelingFilter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final entries = widget.controller.entries.where((entry) {
          final mealMatches =
              _mealFilter == null || entry.mealType == _mealFilter;
          final feelingMatches =
              _feelingFilter == null || entry.feelings.contains(_feelingFilter);
          return mealMatches && feelingMatches;
        }).toList();

        return CustomScrollView(
          key: const PageStorageKey('gallery-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gallery',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${entries.length} ${entries.length == 1 ? 'moment' : 'moments'}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _mealFilter == null,
                              onSelected: () =>
                                  setState(() => _mealFilter = null),
                            ),
                            for (final type in MealType.values)
                              _FilterChip(
                                label: type.label,
                                selected: _mealFilter == type,
                                onSelected: () =>
                                    setState(() => _mealFilter = type),
                              ),
                          ],
                        ),
                      ),
                      if (widget.controller.entries.any(
                        (entry) => entry.feelings.isNotEmpty,
                      )) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          initialValue: _feelingFilter,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.mood_outlined),
                            labelText: 'Feeling',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Any feeling'),
                            ),
                            for (final feeling in feelingLabels)
                              DropdownMenuItem(
                                value: feeling,
                                child: Text(feeling),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _feelingFilter = value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No moments match these filters.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverGrid.builder(
                  itemCount: entries.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _GalleryTile(
                      entry: entry,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EntryDetailScreen(
                            controller: widget.controller,
                            entryId: entry.id,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: RitualColors.ink,
      labelStyle: TextStyle(
        color: selected ? RitualColors.paper : RitualColors.ink,
      ),
      onSelected: (_) => onSelected(),
    ),
  );
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.entry, required this.onTap});
  final MealEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RitualColors.paper,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MealPhoto(path: entry.imagePath, borderRadius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB3000000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                entry.mealType.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
