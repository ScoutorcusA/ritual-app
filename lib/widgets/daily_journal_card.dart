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
      label: '${DateFormat.yMMMMd().format(day)}, $count moments',
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMMM d').format(day),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'moment' : 'moments'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded),
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
