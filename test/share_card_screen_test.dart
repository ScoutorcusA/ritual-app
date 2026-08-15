import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:ritual/models/meal_entry.dart';
import 'package:ritual/screens/share_card_screen.dart';
import 'package:ritual/theme/ritual_theme.dart';

void main() {
  testWidgets('share card selects recent photos without private metadata', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final directory = Directory(
      '${Directory.current.path}/tmp/share-card-test-'
      '${DateTime.now().microsecondsSinceEpoch}',
    );
    directory.createSync(recursive: true);
    addTearDown(() => directory.deleteSync(recursive: true));
    final entries = <MealEntry>[];
    for (var index = 0; index < 5; index++) {
      final photo = File('${directory.path}/photo-$index.png');
      final canvas = image.Image(width: 80, height: 80);
      image.fill(canvas, color: image.ColorRgb8(80 + index * 20, 120, 90));
      photo.writeAsBytesSync(image.encodePng(canvas));
      entries.add(
        MealEntry(
          id: index + 1,
          imagePath: photo.path,
          mealType: MealType.values[index % MealType.values.length],
          feelings: const ['Private feeling'],
          note: 'Private note',
          createdAt: DateTime(2026, 8, 15 - index),
          locationLabel: 'Private place',
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ritualTheme(),
        home: ShareCardScreen(
          entries: entries,
          currentStreak: 7,
          streaksEnabled: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Share a reflection'), findsOneWidget);
    expect(find.text('Include current streak'), findsOneWidget);
    expect(find.text('7 days of noticing'), findsOneWidget);
    expect(find.text('MADE WITH RITUAL'), findsOneWidget);
    expect(
      find.textContaining('Notes, feelings, dates, and places'),
      findsOneWidget,
    );
    expect(find.text('Private note'), findsNothing);
    expect(find.text('Private feeling'), findsNothing);
    expect(find.text('Private place'), findsNothing);

    await tester.tap(find.text('Include current streak'));
    await tester.pump();
    expect(find.text('A few things I noticed'), findsOneWidget);
  });
}
