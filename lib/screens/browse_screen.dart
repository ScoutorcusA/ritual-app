import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/journal_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/meal_entry.dart';
import '../theme/ritual_theme.dart';
import '../utils/journal_days.dart';
import '../widgets/meal_photo.dart';
import 'entry_detail_screen.dart';

enum BrowseView { gallery, calendar }

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key, required this.controller, this.settings});

  final JournalController controller;
  final SettingsController? settings;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  BrowseView _view = BrowseView.gallery;
  MealType? _mealFilter;
  String? _feelingFilter;
  DateTime? _expandedDay;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final filteredEntries = widget.controller.entries
            .where((entry) {
              final mealMatches =
                  _mealFilter == null || entry.mealType == _mealFilter;
              final feelingMatches =
                  _feelingFilter == null ||
                  entry.feelings.contains(_feelingFilter);
              return mealMatches && feelingMatches;
            })
            .toList(growable: false);

        return CustomScrollView(
          key: PageStorageKey('browse-${_view.name}-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: _BrowseHeader(
                view: _view,
                count: _view == BrowseView.gallery
                    ? filteredEntries.length
                    : widget.controller.entries.length,
                onViewChanged: (view) => setState(() => _view = view),
                filter: _mealFilter,
                feelingFilter: _feelingFilter,
                showFilters: _view == BrowseView.gallery,
                hasFeelings: widget.controller.entries.any(
                  (entry) => entry.feelings.isNotEmpty,
                ),
                onMealFilterChanged: (filter) =>
                    setState(() => _mealFilter = filter),
                onFeelingFilterChanged: (filter) =>
                    setState(() => _feelingFilter = filter),
              ),
            ),
            if (_view == BrowseView.gallery)
              ..._gallerySlivers(filteredEntries)
            else
              ..._calendarSlivers(widget.controller.entries),
          ],
        );
      },
    );
  }

  List<Widget> _gallerySlivers(List<MealEntry> entries) {
    if (entries.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('No moments match these filters.')),
        ),
      ];
    }
    return [
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
            return _GalleryTile(entry: entry, onTap: () => _openEntry(entry));
          },
        ),
      ),
    ];
  }

  List<Widget> _calendarSlivers(List<MealEntry> entries) {
    final months = _monthsFor(entries);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        sliver: SliverList.separated(
          itemCount: months.length,
          separatorBuilder: (_, _) => const SizedBox(height: 32),
          itemBuilder: (context, index) => _MonthCalendar(
            month: months[index],
            entries: entries,
            expandedDay: _expandedDay,
            highlightForDay: widget.controller.highlightForDay,
            onDayTap: (day, hasEntries) {
              if (!hasEntries) return;
              setState(() {
                _expandedDay = isSameDay(_expandedDay ?? DateTime(0), day)
                    ? null
                    : day;
              });
            },
            onEntryTap: _openEntry,
          ),
        ),
      ),
    ];
  }

  List<DateTime> _monthsFor(List<MealEntry> entries) {
    final now = DateTime.now();
    if (entries.isEmpty) return [DateTime(now.year, now.month)];
    var earliest = DateTime(now.year, now.month);
    var latest = earliest;
    for (final entry in entries) {
      final month = DateTime(entry.createdAt.year, entry.createdAt.month);
      if (month.isBefore(earliest)) earliest = month;
      if (month.isAfter(latest)) latest = month;
    }
    final months = <DateTime>[];
    var cursor = latest;
    while (!cursor.isBefore(earliest)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return months;
  }

  void _openEntry(MealEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntryDetailScreen(
          controller: widget.controller,
          entryId: entry.id,
          settings: widget.settings,
        ),
      ),
    );
  }
}

class _BrowseHeader extends StatelessWidget {
  const _BrowseHeader({
    required this.view,
    required this.count,
    required this.onViewChanged,
    required this.filter,
    required this.feelingFilter,
    required this.showFilters,
    required this.hasFeelings,
    required this.onMealFilterChanged,
    required this.onFeelingFilterChanged,
  });

  final BrowseView view;
  final int count;
  final ValueChanged<BrowseView> onViewChanged;
  final MealType? filter;
  final String? feelingFilter;
  final bool showFilters;
  final bool hasFeelings;
  final ValueChanged<MealType?> onMealFilterChanged;
  final ValueChanged<String?> onFeelingFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Browse', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 6),
            Text(
              '$count ${count == 1 ? 'moment' : 'moments'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<BrowseView>(
                segments: const [
                  ButtonSegment(
                    value: BrowseView.gallery,
                    icon: Icon(Icons.grid_view_rounded),
                    label: Text('Gallery'),
                  ),
                  ButtonSegment(
                    value: BrowseView.calendar,
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text('Calendar'),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (selection) =>
                    onViewChanged(selection.single),
              ),
            ),
            if (showFilters) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: filter == null,
                      onSelected: () => onMealFilterChanged(null),
                    ),
                    for (final type in MealType.values)
                      _FilterChip(
                        label: type.label,
                        selected: filter == type,
                        onSelected: () => onMealFilterChanged(type),
                      ),
                  ],
                ),
              ),
              if (hasFeelings) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: feelingFilter,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.mood_outlined),
                    labelText: 'Feeling',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any feeling'),
                    ),
                    for (final feeling in feelingLabels)
                      DropdownMenuItem(value: feeling, child: Text(feeling)),
                  ],
                  onChanged: onFeelingFilterChanged,
                ),
              ],
            ],
          ],
        ),
      ),
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: dark ? const Color(0xFF3B3A34) : RitualColors.ink,
        backgroundColor: colors.surface,
        labelStyle: TextStyle(
          color: selected ? RitualColors.paper : colors.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(color: colors.outline),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.entry, required this.onTap});

  final MealEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
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

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.entries,
    required this.expandedDay,
    required this.highlightForDay,
    required this.onDayTap,
    required this.onEntryTap,
  });

  final DateTime month;
  final List<MealEntry> entries;
  final DateTime? expandedDay;
  final MealEntry? Function(DateTime day) highlightForDay;
  final void Function(DateTime day, bool hasEntries) onDayTap;
  final ValueChanged<MealEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    final weeks = _weeksInMonth(month);
    final selected =
        expandedDay != null &&
            expandedDay!.year == month.year &&
            expandedDay!.month == month.month
        ? expandedDay
        : null;
    final selectedEntries = selected == null
        ? const <MealEntry>[]
        : entries
              .where((entry) => isSameDay(entry.createdAt, selected))
              .toList(growable: false);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: RitualColors.honey.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                DateFormat.yMMMM().format(month),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                for (final weekday in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Expanded(
                    child: Text(
                      weekday,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final week in weeks)
              SizedBox(
                height: 78,
                child: _WeekCard(
                  days: week,
                  entries: entries,
                  expandedDay: expandedDay,
                  highlightForDay: highlightForDay,
                  onDayTap: onDayTap,
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: selectedEntries.isEmpty
                  ? const SizedBox.shrink()
                  : _ExpandedCalendarDay(
                      day: selected!,
                      entries: selectedEntries,
                      onEntryTap: onEntryTap,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<List<DateTime>> _weeksInMonth(DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0);
    final weeks = <List<DateTime>>[];
    var cursor = DateTime(month.year, month.month);
    while (!cursor.isAfter(last)) {
      final week = <DateTime>[];
      final end = cursor.add(Duration(days: 7 - (cursor.weekday % 7) - 1));
      while (!cursor.isAfter(end) && !cursor.isAfter(last)) {
        week.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
      weeks.add(week);
    }
    return weeks;
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.days,
    required this.entries,
    required this.expandedDay,
    required this.highlightForDay,
    required this.onDayTap,
  });

  final List<DateTime> days;
  final List<MealEntry> entries;
  final DateTime? expandedDay;
  final MealEntry? Function(DateTime day) highlightForDay;
  final void Function(DateTime day, bool hasEntries) onDayTap;

  @override
  Widget build(BuildContext context) {
    final leading = days.first.day == 1 ? days.first.weekday % 7 : 0;
    final trailing = 7 - leading - days.length;
    return Row(
      children: [
        for (var index = 0; index < leading; index++)
          const Expanded(child: SizedBox.shrink()),
        for (final day in days)
          Expanded(
            child: _CalendarDay(
              day: day,
              entries: entries
                  .where((entry) => isSameDay(entry.createdAt, day))
                  .toList(growable: false),
              highlight: highlightForDay(day),
              expanded: expandedDay != null && isSameDay(expandedDay!, day),
              onTap: onDayTap,
            ),
          ),
        for (var index = 0; index < trailing; index++)
          const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.entries,
    required this.highlight,
    required this.expanded,
    required this.onTap,
  });

  final DateTime day;
  final List<MealEntry> entries;
  final MealEntry? highlight;
  final bool expanded;
  final void Function(DateTime day, bool hasEntries) onTap;

  @override
  Widget build(BuildContext context) {
    final hasEntries = entries.isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: hasEntries,
      label:
          '${DateFormat.yMMMMd().format(day)}, ${entries.length} ${entries.length == 1 ? 'moment' : 'moments'}',
      child: Material(
        color: expanded
            ? RitualColors.honey.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          key: ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'),
          onTap: hasEntries ? () => onTap(day, true) : null,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            decoration: BoxDecoration(
              border: expanded
                  ? Border.all(color: RitualColors.honey, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(17),
            ),
            padding: const EdgeInsets.fromLTRB(3, 3, 3, 5),
            child: Column(
              children: [
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.64),
                    fontWeight: expanded ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: highlight == null
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.onSurface.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            MealPhoto(
                              path: highlight!.imagePath,
                              borderRadius: 15,
                            ),
                            if (entries.length > 1)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RitualColors.ink,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '+${entries.length - 1}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: RitualColors.paper,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedCalendarDay extends StatelessWidget {
  const _ExpandedCalendarDay({
    required this.day,
    required this.entries,
    required this.onEntryTap,
  });

  final DateTime day;
  final List<MealEntry> entries;
  final ValueChanged<MealEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  DateFormat('EEEE, MMMM d').format(day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  feelingsSummary(entries),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 6),
              for (final entry in entries)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: SizedBox.square(
                    dimension: 52,
                    child: MealPhoto(path: entry.imagePath, borderRadius: 12),
                  ),
                  title: Text(entry.mealType.label),
                  subtitle: Text(
                    [
                      DateFormat.jm().format(entry.createdAt),
                      if (entry.feelings.isNotEmpty)
                        entry.feelings.take(2).join(' · '),
                    ].join('  •  '),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onEntryTap(entry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
