import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/app_state.dart';
import 'package:frontend/data/mock/demo_seed.dart';
import 'package:frontend/practice_services.dart';
import 'package:frontend/router.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/widgets.dart';

import 'fake_practice_services.dart';

/// Pumps the real app router at [location] as [learner], on an iPhone-sized screen.
Future<GoRouter> pumpAt(WidgetTester tester, String location, {String learner = 'maya'}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  // Reduce Motion on, so the repeating mic pulse doesn't keep pumpAndSettle waiting
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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
  // no backend, camera or avatar page in tests
  setUp(() => createPracticeServices = FakePracticeServices.new);
  tearDown(() => createPracticeServices = LivePracticeServices.new);

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
    final services = FakePracticeServices(
      scores: [
        scoreOf('boot', [('b', 95), ('u', 40), ('t', 90)], accuracy: 65),
        scoreOf('boot', [('b', 95), ('u', 92), ('t', 90)], accuracy: 93),
      ],
      lipChecks: [
        const LipCheck(passed: false, score: 0.2, tip: 'Try rounding your lips more.'),
        const LipCheck(passed: true, score: 0.8, tip: 'Great job!'),
      ],
    );
    createPracticeServices = () => services;
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

    // the first try is unaided: Watch stays locked until a miss
    await tapText('Watch');
    expect(find.text('Listen to how "boot" sounds.'), findsOneWidget);
    await tapText('Next: Try');
    await sayIt();
    // Azure: the /u/ was weak, and /u/ has a lip model
    expect(find.text('Almost!'), findsOneWidget);
    expect(find.text("Let's work on the /u/ sound."), findsOneWidget);

    await tapText('Watch');
    expect(find.text('Tongue position schematic'), findsOneWidget);
    expect(find.text('Guidance'), findsOneWidget);
    await tapText('Feedback');
    await tapText('Practice the /u/ sound');
    expect(services.lipModel, 'u');
    expect(find.text('Tap the mic and say "oo".'), findsOneWidget);
    await sayIt();
    // a miss: the lip model's tip, and the coach demonstrates
    expect(find.text('Try rounding your lips more.'), findsOneWidget);
    expect(find.text('Watch your coach, then say "oo".'), findsOneWidget);
    await sayIt();
    expect(find.text('You got the /u/ sound! Now say the whole word.'), findsOneWidget);

    await sayIt();
    expect(find.text('Great!'), findsOneWidget);
    expect(find.text('You said "boot" clearly!'), findsOneWidget);
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

  testWidgets('read aloud: library, reading highlight, results', (tester) async {
    await pumpAt(tester, Routes.readAloud);
    expect(find.text('The Lotus Pond'), findsOneWidget);
    expect(find.text('Moon Boots'), findsOneWidget);

    await tester.tap(find.text('The Lotus Pond'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MicButton));
    // MOCK pace is 450ms a word; let it run through the whole passage
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 450));
    }
    await tester.pumpAndSettle();
    expect(find.text('Nice reading!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a flagged reading word opens word practice for it', (tester) async {
    final router = await pumpAt(tester, Routes.readingResults('lotus-pond'));
    expect(find.text('words to practice'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Practice frog').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/word-practice');
    expect(router.state.uri.queryParameters['word'], 'frog');
    // frog is already in Maya's queue from yesterday's reading, so that entry is used
    expect(find.text('from Reading · yesterday'), findsOneWidget);
  });

  testWidgets('practice these words adds flagged words to the queue', (tester) async {
    await pumpAt(tester, Routes.readingResults('lotus-pond'));
    final state = Provider.of<AppState>(tester.element(find.byType(Scaffold).first), listen: false);
    final before = state.queue.length;
    await tester.ensureVisible(find.text('Practice these words'));
    await tester.tap(find.text('Practice these words'));
    await tester.pumpAndSettle();
    // frog is already queued for Maya; leaf and fish are new
    expect(state.queue.length, before + 2);
    expect(find.text('Added to your practice'), findsOneWidget);
  });

  testWidgets('diagnostic: 12 words, sound profile, add to practice', (tester) async {
    // Azure scores every word; /r/ (spelled ɹ by Azure) is weak
    createPracticeServices = () => FakePracticeServices(scores: [
          for (final w in diagnosticWords)
            scoreOf(w, [for (final p in phonemesFor(w)) p == 'r' ? ('ɹ', 40.0) : (p, 92.0)], accuracy: 85),
        ]);
    final router = await pumpAt(tester, Routes.diagnostic, learner: 'sam');
    expect(find.text('Word 1 of 12'), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byType(MicButton));
      await tester.pump();
      await tester.tap(find.byType(MicButton));
      await tester.pump();
      expect(find.text('Got it!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
    }
    expect(find.text('Your sound profile'), findsOneWidget);
    expect(find.text('Needs practice'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final state = Provider.of<AppState>(tester.element(find.byType(Scaffold).first), listen: false);
    expect(state.queue.isEmpty, isTrue);
    await tester.scrollUntilVisible(find.text('Add to my practice'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle(); // let the final scroll lay out before tapping
    await tester.tap(find.text('Add to my practice'));
    await tester.pumpAndSettle();
    expect(state.queue.isEmpty, isFalse);
    expect(state.queue.items.first.source.name, 'diagnostic');

    router.go(Routes.home);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sounds to work on'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('No words yet'), findsNothing);
  });

  testWidgets('leaving the diagnostic asks first', (tester) async {
    await pumpAt(tester, Routes.diagnostic);
    await tester.tap(find.byTooltip('Exit'));
    await tester.pumpAndSettle();
    expect(find.text('Stop the Diagnostic?'), findsOneWidget);
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.text('Word 1 of 12'), findsOneWidget);
  });

  testWidgets('look and say: pick a sample object, then say it', (tester) async {
    final router = await pumpAt(tester, Routes.lookAndSay);
    expect(find.text('Prototype'), findsOneWidget);
    expect(find.text('Camera view'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'cat'));
    await tester.pumpAndSettle();
    expect(find.text('cat'), findsNWidgets(2)); // chip + detection label
    await tester.scrollUntilVisible(find.text('Say "cat"'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Say "cat"'));
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['word'], 'cat');
    expect(find.text('from Look & Say · today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress: stats change with range, sections for the demo learner', (tester) async {
    await pumpAt(tester, Routes.progress);
    expect(tester.takeException(), isNull);
    expect(find.text('Getting better'), findsOneWidget);
    String daysValue() => (tester
            .widget<StatTile>(find.widgetWithText(StatTile, 'days practiced')))
        .value;
    final weekDays = daysValue();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(int.parse(daysValue()), greaterThan(int.parse(weekDays)));
    await tester.scrollUntilVisible(find.text('Recent activity'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress for a new learner is an empty state', (tester) async {
    await pumpAt(tester, Routes.progress, learner: 'sam');
    expect(find.text('No progress yet'), findsOneWidget);
  });

  testWidgets('SLP/parent can assign words to the queue', (tester) async {
    await pumpAt(tester, Routes.grownups);
    expect(tester.takeException(), isNull);
    final state = Provider.of<AppState>(tester.element(find.byType(Scaffold).first), listen: false);
    final before = state.queue.length;
    await tester.scrollUntilVisible(find.byType(TextField), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), 'rain, giraffe, rain');
    await tester.tap(find.text('Add to practice'));
    await tester.pumpAndSettle();
    // rain is already queued for Maya; only giraffe is new
    expect(state.queue.length, before + 1);
    expect(state.queue.items.last.text, 'giraffe');
    expect(state.queue.items.last.source.name, 'assigned');
    expect(find.text('rain, giraffe, rain'), findsNothing);
  });

  testWidgets('settings sections render', (tester) async {
    await pumpAt(tester, Routes.settings);
    expect(tester.takeException(), isNull);
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Preview'), findsWidgets);
    await tester.scrollUntilVisible(find.text('About & credits'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Testing'), findsOneWidget);
  });

  testWidgets('long-pressing the logo opens the debug menu, which can reset and jump',
      (tester) async {
    final router = await pumpAt(tester, Routes.home);
    final state = Provider.of<AppState>(tester.element(find.byType(Scaffold).first), listen: false);
    state.queue.next();
    final shortened = state.queue.length;

    await tester.longPress(find.byType(EchoLogo));
    await tester.pumpAndSettle();
    expect(find.text('Debug menu'), findsOneWidget);
    await tester.tap(find.text('Reset sample data'));
    await tester.pumpAndSettle();
    expect(state.queue.length, shortened + 1);

    await tester.longPress(find.byType(EchoLogo));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Look & Say'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Look & Say'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.lookAndSay);
  });

  testWidgets('unknown story and unknown route show a friendly error', (tester) async {
    final router = await pumpAt(tester, Routes.reading('nope'));
    expect(find.text("We couldn't find that story"), findsOneWidget);
    router.go('/not-a-page');
    await tester.pumpAndSettle();
    expect(find.text("We couldn't find that page"), findsOneWidget);
    await tester.tap(find.text('Go home'));
    await tester.pumpAndSettle();
    expect(find.text('Up next'), findsOneWidget);
  });
}
