import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../l10n/ritual_i18n.dart';
import '../utils/journal_days.dart';
import '../widgets/day_photo_collage.dart';
import '../widgets/meal_card.dart';
import 'entry_detail_screen.dart';

class DailyJournalScreen extends StatelessWidget {
  const DailyJournalScreen({
    super.key,
    required this.controller,
    required this.day,
    this.settings,
  });

  final JournalController controller;
  final DateTime day;
  final SettingsController? settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final entries = controller.entries
            .where((entry) => isSameDay(entry.createdAt, day))
            .toList(growable: false);
        return Scaffold(
          appBar: AppBar(
            title: Text(DateFormat.MMMMd(RitualI18n.localeName).format(day)),
          ),
          body: entries.isEmpty
              ? Center(child: Text(tr('This day has no moments now.')))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  itemCount: entries.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: DayPhotoCollage(entries: entries),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            DateFormat.MMMMEEEEd(
                              RitualI18n.localeName,
                            ).format(day),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            feelingsSummary(entries),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      );
                    }
                    final entry = entries[index - 1];
                    return MealCard(
                      entry: entry,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EntryDetailScreen(
                            controller: controller,
                            entryId: entry.id,
                            settings: settings,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
