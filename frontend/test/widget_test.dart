import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app.dart';
import 'package:frontend/practice_page.dart';

void main() {
  testWidgets('app opens on the profile picker and enters the shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MirrorUApp());
    await tester.pumpAndSettle();

    expect(find.text("Who's practicing today?"), findsOneWidget);
    await tester.tap(find.text('Maya'));
    await tester.pumpAndSettle();

    // bottom navigation with all five sections
    for (final label in ['Home', 'Practice', 'Progress', 'SLP/Parent', 'Settings']) {
      expect(find.text(label), findsWidgets, reason: label);
    }

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Testing'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Testing'));
    await tester.pumpAndSettle();
    expect(find.text('Word drill'), findsOneWidget);
    expect(find.text('Avatar test'), findsOneWidget);
  });

  testWidgets('original word drill page still renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PracticePage()));

    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Text to say'), findsOneWidget);
  });
}
