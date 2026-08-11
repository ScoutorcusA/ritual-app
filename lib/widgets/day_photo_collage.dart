import 'package:flutter/material.dart';

import '../models/meal_entry.dart';
import 'meal_photo.dart';

class DayPhotoCollage extends StatelessWidget {
  const DayPhotoCollage({
    super.key,
    required this.entries,
    this.borderRadius = 24,
  });

  final List<MealEntry> entries;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final visible = entries.take(4).toList(growable: false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: _layout(visible),
    );
  }

  Widget _layout(List<MealEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    const gap = 3.0;
    if (entries.length == 1) return _photo(entries.first);
    if (entries.length == 2) {
      return Row(
        children: [
          Expanded(child: _photo(entries[0])),
          const SizedBox(width: gap),
          Expanded(child: _photo(entries[1])),
        ],
      );
    }
    if (entries.length == 3) {
      return Row(
        children: [
          Expanded(child: _photo(entries[0])),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _photo(entries[1])),
                const SizedBox(height: gap),
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
              const SizedBox(width: gap),
              Expanded(child: _photo(entries[1])),
            ],
          ),
        ),
        const SizedBox(height: gap),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _photo(entries[2])),
              const SizedBox(width: gap),
              Expanded(child: _photo(entries[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _photo(MealEntry entry) =>
      MealPhoto(path: entry.imagePath, borderRadius: 0);
}
