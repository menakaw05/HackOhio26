import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Progress',
      children: [
        const ComingSoon(label: 'Progress'),
      ],
    );
  }
}
