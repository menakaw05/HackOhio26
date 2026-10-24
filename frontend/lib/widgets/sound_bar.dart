import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'chips.dart';
import 'stats.dart';

/// A sound chip, its example word, and a bar colored by level.
class SoundBar extends StatelessWidget {
  const SoundBar({super.key, required this.score});

  final SoundScore score;

  @override
  Widget build(BuildContext context) {
    final kind = score.level.kind;
    return Semantics(
      label: 'Sound ${score.phoneme}, as in ${score.exampleWord}: ${score.level.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
        child: Row(
          children: [
            SoundChip(phoneme: score.phoneme, kind: kind),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('as in "${score.exampleWord}"', style: AppText.caption),
                  const SizedBox(height: AppSpace.xs),
                  ProgressBar(value: score.score, color: kind.color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
