import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../router.dart';

/// Asks before going back to the profile picker.
Future<void> confirmSwitchLearner(BuildContext context) async {
  final state = context.read<AppState>();
  final name = state.learner?.name ?? 'this learner';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Switch learner?'),
      content: Text('$name will be signed out and you can pick who\'s practicing.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Switch')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  state.signOut();
  context.go(Routes.welcome);
}
