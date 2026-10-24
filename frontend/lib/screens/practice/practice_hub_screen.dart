import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Practice',
      children: [
        const ComingSoon(label: 'Practice Hub'),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'Diagnostic', expand: true, onPressed: () => context.push(Routes.diagnostic)),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'Word Practice', expand: true, onPressed: () => context.push(Routes.wordPractice('boot'))),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'Read Aloud', expand: true, onPressed: () => context.go(Routes.readAloud)),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'Look & Say', expand: true, onPressed: () => context.push(Routes.lookAndSay)),
      ],
    );
  }
}
