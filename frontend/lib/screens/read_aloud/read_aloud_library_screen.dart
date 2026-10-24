import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class ReadAloudLibraryScreen extends StatelessWidget {
  const ReadAloudLibraryScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Read Aloud',
      children: [
        const ComingSoon(label: 'Passage library'),
        const SizedBox(height: AppSpace.m),
        SecondaryButton(label: 'The Lotus Pond', expand: true, onPressed: () => context.push(Routes.reading('lotus-pond'))),
      ],
    );
  }
}
