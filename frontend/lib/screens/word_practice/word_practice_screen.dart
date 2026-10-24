import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../widgets/widgets.dart';

// Wireframe stub; built out in a later commit.
class WordPracticeScreen extends StatelessWidget {
  const WordPracticeScreen({super.key, this.word, required this.source});

  final String? word;
  final WordSource source;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: word ?? 'Word Practice',
      children: [
        const ComingSoon(label: 'Word Practice'),
      ],
    );
  }
}
