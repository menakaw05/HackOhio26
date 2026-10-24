import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Settings',
      children: [
        const ComingSoon(label: 'Settings'),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'Testing', expand: true, onPressed: () => context.go(Routes.testing)),
      ],
    );
  }
}
