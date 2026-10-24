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
          ],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Almost!'), findsOneWidget);
  });
}
