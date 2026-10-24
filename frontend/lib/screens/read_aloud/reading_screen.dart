import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key, required this.passageId});

  final String passageId;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Reading',
      children: [
        const ComingSoon(label: 'Reading view'),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'See results', expand: true, onPressed: () => context.push(Routes.readingResults(passageId))),
      ],
    );
  }
}
