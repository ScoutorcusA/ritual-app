import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../insights/insight_engine.dart';
import '../models/meal_entry.dart';
import '../theme/ritual_theme.dart';
import '../utils/journal_days.dart';
import '../utils/journal_summary.dart';
import '../widgets/daily_journal_card.dart';
import '../widgets/insight_card.dart';
import 'daily_journal_screen.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({
    super.key,
    required this.controller,
    required this.onSettings,
    this.settings,
  });

  final JournalController controller;
  final VoidCallback onSettings;
  final SettingsController? settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null) {
          return _JournalError(message: controller.error!);
        }

        final grouped = groupEntriesByDay(controller.entries);
        final insights = InsightEngine.build(controller.entries);
        return CustomScrollView(
          key: const PageStorageKey('journal-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: _JournalHeader(
                controller: controller,
                onSettings: onSettings,
                showStreaks: settings?.streaksEnabled ?? true,
              ),
            ),
            if (controller.entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyJournal(),
              )
            else
              for (final (groupIndex, group) in grouped.indexed) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: DailyJournalCard(
                      day: group.day,
                      entries: group.entries,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DailyJournalScreen(
                            controller: controller,
                            day: group.day,
                            settings: settings,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (groupIndex < insights.length)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    sliver: SliverToBoxAdapter(
                      child: InsightCard(insight: insights[groupIndex]),
                    ),
                  ),
              ],
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }
}

class _JournalHeader extends StatelessWidget {
  const _JournalHeader({
    required this.controller,
    required this.onSettings,
    required this.showStreaks,
  });

  final JournalController controller;
  final VoidCallback onSettings;
  final bool showStreaks;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat(
                      'EEEE, MMMM d',
                    ).format(DateTime.now()).toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: RitualColors.sage,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your daily ritual',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            if (showStreaks) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: RitualColors.ink,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: RitualColors.honey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.currentStreak == 0
                            ? 'Begin with one mindful meal'
                            : '${controller.currentStreak} day streak',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: RitualColors.paper,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      'Best ${controller.bestStreak}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RitualColors.paper.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (controller.entries.isNotEmpty) ...[
              SizedBox(height: showStreaks ? 14 : 20),
              _JournalSummaryCard(entries: controller.entries),
            ],
          ],
        ),
      ),
    );
  }
}

class _JournalSummaryCard extends StatelessWidget {
  const _JournalSummaryCard({required this.entries});

  final List<MealEntry> entries;

  @override
  Widget build(BuildContext context) {
    final summary = JournalSummary.fromEntries(entries);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            _SummaryMetric(
              value: '${summary.totalEntries}',
              label: 'Total moments',
            ),
            _SummaryMetric(
              value: summary.mealsPerLoggedDay.toStringAsFixed(1),
              label: 'Per logged day',
            ),
            _SummaryMetric(
              value: summary.typicalGapLabel,
              label: 'Typical gap',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 20, 36, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: RitualColors.paper,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 34,
              color: RitualColors.sage,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Notice what nourishes you',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Photograph a meal, name how it felt, and let the days gather here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _JournalError extends StatelessWidget {
  const _JournalError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
