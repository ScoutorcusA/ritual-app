import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/widgets/streak_celebration_overlay.dart';

void main() {
  test('uses special copy for requested streak milestones', () {
    for (final streak in [7, 30, 100, 365]) {
      expect(StreakCelebration.forStreak(streak).milestone, isTrue);
    }
    expect(StreakCelebration.forStreak(6).milestone, isFalse);
    expect(StreakCelebration.forStreak(7).title, contains('Seven'));
    expect(StreakCelebration.forStreak(365).title, contains('year'));
  });

  testWidgets('overlay can be skipped and otherwise dismisses automatically', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showGeneralDialog<void>(
                context: context,
                barrierDismissible: false,
                barrierLabel: 'Streak updated',
                pageBuilder: (_, _, _) =>
                    const StreakCelebrationOverlay(streak: 7),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Seven days of showing up'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Seven days of showing up'), findsNothing);

    await tester.tap(find.text('Show'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Seven days of showing up'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Seven days of showing up'), findsNothing);
  });
}
