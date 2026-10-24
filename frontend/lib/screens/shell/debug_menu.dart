import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';

class _Jump {
  const _Jump(this.label, this.location, {this.push = false});

  final String label;
  final String location;

  /// Full-screen routes are pushed so there's something to go back to.
  final bool push;
}

final _jumps = [
  const _Jump('Welcome', Routes.welcome),
  const _Jump('Home', Routes.home),
  const _Jump('Practice Hub', Routes.practice),
  _Jump('Word Practice (boot)', Routes.wordPractice('boot'), push: true),
  const _Jump('Diagnostic', Routes.diagnostic, push: true),
  const _Jump('Sound profile', Routes.diagnosticResults, push: true),
  const _Jump('Read Aloud library', Routes.readAloud),
  _Jump('Reading: The Lotus Pond', Routes.reading('lotus-pond'), push: true),
  _Jump('Reading results', Routes.readingResults('lotus-pond'), push: true),
  _Jump('Word Practice from Reading (frog)',
      Routes.wordPractice('frog', source: WordSource.reading), push: true),
  const _Jump('Look & Say', Routes.lookAndSay, push: true),
  const _Jump('Progress', Routes.progress),
  const _Jump('SLP / parent', Routes.grownups),
  const _Jump('Settings', Routes.settings),
  const _Jump('Testing', Routes.testing),
];

/// Hidden menu (long-press the logo): reset sample data and jump to any screen.
Future<void> showDebugMenu(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final state = context.read<AppState>();
      void jump(_Jump j) {
        Navigator.pop(sheetContext);
        // screens past Welcome need a learner; use the demo learner
        if (j.location != Routes.welcome && !state.hasLearner) state.selectLearner('maya');
        if (j.push) {
          context.push(j.location);
        } else {
          context.go(j.location);
        }
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.xxl),
          children: [
            Text('Debug menu', style: AppText.title),
            const SizedBox(height: AppSpace.m),
            FilledButton.icon(
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset sample data'),
              onPressed: () {
                state.resetDemo();
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sample data reset.')));
              },
            ),
            const SizedBox(height: AppSpace.l),
            Text('Jump to', style: AppText.section),
            for (final j in _jumps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(j.label, style: AppText.bodyText),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => jump(j),
              ),
          ],
        ),
      );
    },
  );
}
