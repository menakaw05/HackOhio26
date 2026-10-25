import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/widgets.dart';

void main() {
  testWidgets('base widgets render without layout errors', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppCard(child: Text('card')),
            PrimaryButton(label: 'Start', icon: Icons.play_arrow, onPressed: () {}),
            SecondaryButton(label: 'Later', onPressed: () {}, expand: true),
            const Wrap(children: [
              SoundChip(phoneme: 'u'),
              SoundChip(phoneme: 't', kind: FeedbackKind.almost, selected: true),
            ]),
            const SourceChip(label: 'Reading', icon: Icons.menu_book, when: 'yesterday'),
            const TagBadge(label: 'Prototype'),
            const Row(children: [
              Expanded(child: StatTile(icon: Icons.local_fire_department, value: '5', label: 'day streak')),
              ProgressRing(value: 0.6, child: Text('60%')),
            ]),
            const ProgressBar(value: 0.4),
            const SectionHeader(title: 'Section', actionLabel: 'See all'),
            const EmptyState(icon: Icons.inbox, title: 'Nothing here', message: 'Yet'),
            const ComingSoon(label: 'Avatar'),
            for (final k in FeedbackKind.values) FeedbackBanner(kind: k, message: 'msg'),
            MicButton(listening: false, onPressed: () {}),
            const StepperBar(steps: ['Hear', 'Watch', 'Try', 'Feedback'], current: 1),
            const AttemptDots(total: 3, results: [FeedbackKind.almost]),
            const SkeletonBox(width: 120),
            const ErrorState(),
          ],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Almost!'), findsOneWidget);
  });

  testWidgets('mic pulses while listening and stops when done', (tester) async {
    var listening = true;
    late StateSetter setOuter;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          setOuter = setState;
          return MicButton(listening: listening, onPressed: () {});
        }),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);
    setOuter(() => listening = false);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('celebration plays once and clears', (tester) async {
    var plays = 0;
    late StateSetter setOuter;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        setOuter = setState;
        return CelebrationOverlay(playCount: plays);
      }),
    ));
    setOuter(() => plays++);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with Reduce Motion the mic does not pulse', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MicButton(listening: true, onPressed: () {})),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
