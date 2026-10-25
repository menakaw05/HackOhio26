import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'identity.dart';

/// The three ways an attempt can go. There is deliberately no "wrong".
enum FeedbackKind {
  success('Great!', Icons.star_rounded, AppColors.success, AppColors.successSoft),
  almost('Almost!', Icons.auto_awesome_rounded, AppColors.almost, AppColors.almostSoft),
  focus("Let's try again", Icons.replay_rounded, AppColors.focus, AppColors.focusSoft);

  const FeedbackKind(this.title, this.icon, this.color, this.softColor);

  final String title;
  final IconData icon;
  final Color color;
  final Color softColor;
}

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({super.key, required this.kind, this.message});

  final FeedbackKind kind;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: kind.softColor,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: kind.color, width: 2.5),
          boxShadow: [BoxShadow(color: kind.color, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            // the octopus cheers a great try and smiles at the rest
            OctopusBuddy(
              size: 70,
              mood: kind == FeedbackKind.success ? BuddyMood.happy : BuddyMood.idle,
              bubbles: false,
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.title,
                      style: AppText.title.copyWith(color: AppColors.edgeOf(kind.color), fontSize: 26)),
                  if (message != null) Text(message!, style: AppText.bodyStrong),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
