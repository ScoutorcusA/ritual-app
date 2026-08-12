import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/controllers/journal_controller.dart';
import 'package:ritual/controllers/settings_controller.dart';
import 'package:ritual/screens/meal_editor_screen.dart';
import 'package:ritual/theme/ritual_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_meal_repository.dart';

void main() {
  testWidgets('only enabled reflection scales appear in the meal editor', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final settings = SettingsController();
    await settings.initialize();
    await settings.setHungerScaleEnabled(true);
    await settings.setFullnessScaleEnabled(true);
    final journal = JournalController(MemoryMealRepository());
    await journal.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: ritualTheme(),
        home: MealEditorScreen(
          controller: journal,
          imagePath: '/private/meal.jpg',
          settings: settings,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('How hungry were you before?'),
      300,
    );
    expect(find.text('How hungry were you before?'), findsOneWidget);
    expect(find.text('How strong was the craving?'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('How full did you feel afterwards?'),
      300,
    );
    expect(find.text('How full did you feel afterwards?'), findsOneWidget);
  });
}
