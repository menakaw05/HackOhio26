import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class LookAndSayScreen extends StatelessWidget {
  const LookAndSayScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Look & Say',
      children: [
        const ComingSoon(label: 'Look & Say'),
      ],
    );
  }
}
