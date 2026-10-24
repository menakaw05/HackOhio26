import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class DiagnosticScreen extends StatelessWidget {
  const DiagnosticScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Diagnostic',
      children: [
        const ComingSoon(label: 'Diagnostic'),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'See sound profile', expand: true, onPressed: () => context.push(Routes.diagnosticResults)),
      ],
    );
  }
}
