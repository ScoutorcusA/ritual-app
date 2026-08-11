import 'package:flutter/material.dart';

import '../insights/insight_engine.dart';
import '../theme/ritual_theme.dart';

class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});

  final JournalInsight insight;

  IconData get _icon => switch (insight.kind) {
    InsightKind.repetition => Icons.repeat_rounded,
    InsightKind.feeling => Icons.sentiment_satisfied_alt_rounded,
    InsightKind.place => Icons.place_outlined,
    InsightKind.consistency => Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RitualColors.terracotta.withValues(alpha: 0.18),
            RitualColors.honey.withValues(alpha: 0.13),
          ],
        ),
        border: Border.all(
          color: RitualColors.terracotta.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.82),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, color: RitualColors.terracotta),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RITUAL INSIGHT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: RitualColors.terracotta,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  insight.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(insight.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
