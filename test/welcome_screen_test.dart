import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/controllers/settings_controller.dart';
import 'package:ritual/screens/welcome_screen.dart';
import 'package:ritual/theme/ritual_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('welcome setup covers experience choices and completes', (
    tester,
  ) async {
    final settings = SettingsController();
    await settings.initialize();
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          theme: ritualTheme(),
          darkTheme: ritualDarkTheme(),
          themeMode: settings.themeMode,
          home: WelcomeScreen(settings: settings),
        ),
      ),
    );

    expect(find.text('Notice, without judgment'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Make it feel like yours'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Choose what you reflect on'), findsOneWidget);

    await tester.tap(find.text('Hunger before eating'));
    await tester.pump();
    expect(settings.hungerScaleEnabled, isTrue);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Set your rhythm'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Empty-day check-in'), findsOneWidget);

    await tester.tap(find.text('Start journaling'));
    await tester.pump();
    expect(settings.onboardingComplete, isTrue);
  });
}
