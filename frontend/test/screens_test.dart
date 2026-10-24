import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/app_state.dart';
import 'package:frontend/router.dart';
import 'package:frontend/theme/app_theme.dart';

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
}
