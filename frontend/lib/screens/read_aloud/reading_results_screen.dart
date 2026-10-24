import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class ReadingResultsScreen extends StatelessWidget {
  const ReadingResultsScreen({super.key, required this.passageId});

  final String passageId;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Results',
      children: [
        const ComingSoon(label: 'Reading results'),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'Practice "frog"', expand: true, onPressed: () => context.push(Routes.wordPractice('frog', source: WordSource.reading))),
      ],
    );
  }
}
