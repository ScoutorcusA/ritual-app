import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/meal_entry.dart';
import '../theme/ritual_theme.dart';
import 'meal_photo.dart';

class MealCard extends StatelessWidget {
  const MealCard({super.key, required this.entry, required this.onTap});

  final MealEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${entry.mealType.label} at ${DateFormat.jm().format(entry.createdAt)}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: MealPhoto(path: entry.imagePath, borderRadius: 0),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.mealType.label,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          DateFormat.jm().format(entry.createdAt),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    if (entry.feelings.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        entry.feelings.join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: RitualColors.sage,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (entry.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        entry.note.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
