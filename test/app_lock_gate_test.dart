import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/controllers/settings_controller.dart';
import 'package:ritual/widgets/app_lock_gate.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('covers immediately and locks after five seconds away', (
    tester,
  ) async {
    final settings = _FakeSettingsController();
    var now = DateTime(2026, 8, 21, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          settings: settings,
          now: () => now,
          child: const Scaffold(body: Text('Private journal entry')),
        ),
      ),
    );

    expect(find.text('Private journal entry'), findsOneWidget);

    settings.enableDeviceLockForTest();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.text('Private journal entry'), findsNothing);
    expect(find.text('Your journal is private'), findsOneWidget);
    expect(find.text('Unlock Ritual'), findsNothing);

    now = now.add(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.text('Private journal entry'), findsNothing);
    expect(find.text('Ritual is still locked.'), findsOneWidget);
  });

  testWidgets('does not lock for a brief notification-shade check', (
    tester,
  ) async {
    final settings = _FakeSettingsController();
    var now = DateTime(2026, 8, 21, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          settings: settings,
          now: () => now,
          child: const Scaffold(body: Text('Private journal entry')),
        ),
      ),
    );
    settings.enableDeviceLockForTest();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.text('Private journal entry'), findsNothing);
    expect(find.text('Your journal is private'), findsOneWidget);

    now = now.add(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Private journal entry'), findsOneWidget);
    expect(find.text('Your journal is private'), findsNothing);
  });

  testWidgets('fails closed if the device clock moves backward while away', (
    tester,
  ) async {
    final settings = _FakeSettingsController();
    var now = DateTime(2026, 8, 21, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          settings: settings,
          now: () => now,
          child: const Scaffold(body: Text('Private journal entry')),
        ),
      ),
    );
    settings.enableDeviceLockForTest();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    now = now.subtract(const Duration(minutes: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.text('Private journal entry'), findsNothing);
    expect(find.text('Ritual is still locked.'), findsOneWidget);
  });

  testWidgets('does not lock while the trusted camera flow is active', (
    tester,
  ) async {
    final settings = _FakeSettingsController();
    late BuildContext childContext;
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          settings: settings,
          child: Builder(
            builder: (context) {
              childContext = context;
              return const Scaffold(body: Text('Private journal entry'));
            },
          ),
        ),
      ),
    );
    settings.enableDeviceLockForTest();
    await tester.pump();

    final cameraCompleter = Completer<void>();
    final camera = AppLockGate.runTrustedInterruption(
      childContext,
      () => cameraCompleter.future,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('Private journal entry'), findsOneWidget);
    expect(find.text('Your journal is private'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    cameraCompleter.complete();
    await camera;
    await tester.pump();

    expect(find.text('Private journal entry'), findsOneWidget);
    expect(find.text('Your journal is private'), findsNothing);
  });

  testWidgets('covers routes pushed above the home page when locked', (
    tester,
  ) async {
    final settings = _FakeSettingsController();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppLockGate(
          settings: settings,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('Private settings content')),
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Private settings content'), findsOneWidget);

    settings.enableDeviceLockForTest();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.text('Private settings content'), findsNothing);
    expect(find.text('Your journal is private'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  testWidgets('drops private field focus and hides the keyboard immediately', (
    tester,
  ) async {
    final settings = _FakeSettingsController();
    final fieldFocus = FocusNode();
    addTearDown(fieldFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          settings: settings,
          child: Scaffold(body: TextField(focusNode: fieldFocus)),
        ),
      ),
    );
    settings.enableDeviceLockForTest();
    await tester.pump();
    await tester.showKeyboard(find.byType(TextField));

    expect(fieldFocus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(fieldFocus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byType(TextField), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });
}

class _FakeSettingsController extends SettingsController {
  AppLockMode _mode = AppLockMode.off;

  @override
  AppLockMode get lockMode => _mode;

  @override
  bool get lockEnabled => _mode != AppLockMode.off;

  @override
  Future<bool> authenticateDevice() async => false;

  void enableDeviceLockForTest() {
    _mode = AppLockMode.device;
    notifyListeners();
  }
}
