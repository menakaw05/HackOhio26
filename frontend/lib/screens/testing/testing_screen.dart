import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Dev screens that already work end to end, kept exactly as they were.
class TestingScreen extends StatelessWidget {
  const TestingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Testing',
      children: [
        Text('Working prototypes. These talk to the real backend.', style: AppText.caption),
        const SizedBox(height: AppSpace.l),
        _TestingTile(
          icon: Icons.record_voice_over_rounded,
          title: 'Word drill',
          detail: 'Azure scoring, worst-sound drill, /u/ face model and TTS. '
              'Needs the backend running.',
          onTap: () => context.push(Routes.wordDrill),
        ),
        const SizedBox(height: AppSpace.m),
        _TestingTile(
          icon: Icons.face_retouching_natural_rounded,
          title: 'Avatar test',
          detail: 'Avatar with Azure lip sync over the front camera. '
              'Needs the avatar-web dev server.',
          onTap: () => context.push(Routes.avatarTest),
        ),
      ],
    );
  }
}

class _TestingTile extends StatelessWidget {
  const _TestingTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: title,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.lakeMist,
            child: Icon(icon, color: AppColors.lakeDeep),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.section),
                Text(detail, style: AppText.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}
