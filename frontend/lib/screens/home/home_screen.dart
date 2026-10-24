import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Home',
      children: [
        const ComingSoon(label: 'Home'),
      ],
    );
  }
}
