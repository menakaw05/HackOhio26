import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

/// "mirrorU" wordmark: a lotus-pink U in a teal mirror.
class MirrorULogo extends StatelessWidget {
  const MirrorULogo({super.key, this.size = 28, this.onLongPress, this.light = false});

  final double size;
  final VoidCallback? onLongPress;

  /// White text, for use on gradients.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final mark = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 1.2,
          height: size * 1.2,
          decoration: const BoxDecoration(gradient: AppGradients.lake, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('U',
              style: AppText.title.copyWith(
                  fontSize: size * 0.75, color: Colors.white, height: 1)),
        ),
        SizedBox(width: size * 0.3),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'mirror', style: TextStyle(color: light ? Colors.white : AppColors.ink)),
            const TextSpan(text: 'U', style: TextStyle(color: AppColors.lotus)),
          ]),
          style: AppText.display.copyWith(fontSize: size),
        ),
      ],
    );
    return Semantics(
      label: 'mirrorU',
      excludeSemantics: true,
      child: GestureDetector(onLongPress: onLongPress, child: mark),
    );
  }
}

/// Circle with the learner's initial. Real avatar images come later.
class LearnerAvatar extends StatelessWidget {
  const LearnerAvatar({super.key, required this.learner, this.size = AppSize.avatar});

  final Learner learner;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarPalette[learner.colorIndex % AppColors.avatarPalette.length];
    return Semantics(
      label: learner.name,
      excludeSemantics: true,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: color,
        child: Text(learner.initial,
            style: AppText.title.copyWith(color: Colors.white, fontSize: size * 0.45)),
      ),
    );
  }
}
