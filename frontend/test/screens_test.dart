import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/app_state.dart';
import 'package:frontend/router.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/widgets.dart';

/// Pumps the real app router at [location] as [learner], on an iPhone-sized screen.
Future<GoRouter> pumpAt(WidgetTester tester, String location, {String learner = 'maya'}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final state = AppState()..selectLearner(learner);
  final router = buildRouter(state);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(value: state.queue),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  ));
  router.go(location);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('home shows the demo learner, next word, and lesson path', (tester) async {
    await pumpAt(tester, Routes.home);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Maya!'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('rabbit'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Roaring r'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Roaring r'), findsOneWidget);
  });

  testWidgets('home for a new learner shows empty states', (tester) async {
    await pumpAt(tester, Routes.home, learner: 'sam');
    expect(tester.takeException(), isNull);
    expect(find.text('No words yet'), findsOneWidget);
    expect(find.text('Start the Diagnostic'), findsOneWidget);
  });

  testWidgets('practice hub shows the four doors', (tester) async {
    await pumpAt(tester, Routes.practice);
    expect(tester.takeException(), isNull);
    for (final t in ['Diagnostic', 'Word Practice', 'Read Aloud', 'Look & Say']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Prototype'), findsOneWidget);
  });

  testWidgets('word practice walks hear, watch, try, feedback', (tester) async {
    await pumpAt(tester, Routes.wordPractice('boot'));
    expect(tester.takeException(), isNull);
    expect(find.text('boot'), findsOneWidget);
    expect(find.text('Your avatar coach'), findsOneWidget);

    Future<void> tapText(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    Future<void> sayIt() async {
      final mic = find.byType(MicButton);
      await tester.ensureVisible(mic);
      await tester.pumpAndSettle();
      await tester.tap(mic);
      await tester.pumpAndSettle();
      await tester.tap(mic);
      await tester.pumpAndSettle();
    }

    await tapText('Next: Watch');
    expect(find.text('Tongue position schematic'), findsOneWidget);
    expect(find.text('Guidance'), findsOneWidget);
    await tapText('Next: Try');
    await sayIt();
    expect(find.text('Almost!'), findsOneWidget);
    expect(find.text('Round your lips a little more.'), findsOneWidget);

    await tapText('Try again');
    await sayIt();
    expect(find.text('Great!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the avatar on home switches learner', (tester) async {
    await pumpAt(tester, Routes.home);
    await tester.tap(find.byTooltip('Switch learner'));
    await tester.pumpAndSettle();
    expect(find.text('Switch learner?'), findsOneWidget);
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();
    expect(find.text("Who's practicing today?"), findsOneWidget);
    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sam!'), findsOneWidget);
  });
}
