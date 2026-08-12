import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/meal_entry.dart';
import '../utils/journal_days.dart';
import 'day_photo_collage.dart';

class DailyJournalCard extends StatelessWidget {
  const DailyJournalCard({
    super.key,
    required this.day,
    required this.entries,
    required this.onTap,
  });

  final DateTime day;
  final List<MealEntry> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = entries.length;
    return Semantics(
      button: true,
      label:
          '${DateFormat.yMMMMd().format(day)}, $count ${count == 1 ? 'moment' : 'moments'}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, MMMM d').format(day),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 15,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$count ${count == 1 ? 'moment' : 'moments'}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 10,
                child: DayPhotoCollage(entries: entries, borderRadius: 0),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
                child: Row(
                  children: [
                    Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feelingsSummary(entries),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
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
