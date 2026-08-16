import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ritual/controllers/journal_controller.dart';
import 'package:ritual/data/meal_repository.dart';
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/screens/ritual_shell.dart';
import 'package:ritual/theme/ritual_theme.dart';

void main() {
  testWidgets('opens to a calm empty journal', (tester) async {
    final controller = JournalController(_MemoryRepository());
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: ritualTheme(),
        home: RitualShell(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your daily ritual'), findsOneWidget);
    expect(find.text('One moment for today'), findsOneWidget);
    expect(find.text('Save today’s first moment'), findsOneWidget);
    expect(find.text('Begin with one mindful meal'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('streak-day-'),
      ),
      findsNWidgets(7),
    );
    expect(find.text('Notice what nourishes you'), findsOneWidget);
    expect(find.byTooltip('Photograph a meal'), findsOneWidget);
  });
}

class _MemoryRepository implements MealRepository {
  @override
  Future<MealEntry> addEntry(MealDraft draft) => throw UnimplementedError();

  @override
  Future<void> deleteEntry(MealEntry entry) async {}

  @override
  Future<void> deleteAllJournalData() async {}

  @override
  Future<void> discardPhoto(String imagePath) async {}

  @override
  Future<String> keepCapturedPhoto(XFile temporaryPhoto) =>
      Future.value(temporaryPhoto.path);

  @override
  Future<int> loadBestStreak() => Future.value(0);

  @override
  Future<List<MealEntry>> loadEntries() => Future.value(const []);

  @override
  Future<void> saveBestStreak(int value) async {}

  @override
  Future<void> updateEntry(MealEntry entry) async {}

  @override
  Future<List<MealEntry>> importEntries(List<MealImport> entries) async =>
      const [];

  @override
  Future<Map<String, int>> loadDailyHighlights() => Future.value(const {});

  @override
  Future<void> saveDailyHighlight(String dayKey, int entryId) async {}

  @override
  Future<void> deleteDailyHighlight(String dayKey) async {}
}
