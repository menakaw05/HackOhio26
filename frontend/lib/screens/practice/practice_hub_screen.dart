import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/practice_queue.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final next = context.watch<PracticeQueue>().peek();
    final cards = [
      _HubCard(
        title: 'Diagnostic',
        description: 'Find the sounds to work on',
        time: '5 min',
        icon: Icons.fact_check_rounded,
        color: AppColors.sky,
        onTap: () => context.push(Routes.diagnostic),
      ),
      _HubCard(
        title: 'Word Practice',
        description: 'Hear, watch, and try a word',
        time: '2 min a word',
        icon: Icons.record_voice_over_rounded,
        color: AppColors.lake,
        onTap: () => context.push(next == null
            ? Routes.wordPractice('boot')
            : Routes.wordPractice(next.text, source: next.source)),
      ),
      _HubCard(
        title: 'Read Aloud',
        description: 'Read a story out loud',
        time: '3 min',
        icon: Icons.menu_book_rounded,
        color: AppColors.lotus,
        onTap: () => context.go(Routes.readAloud),
      ),
      _HubCard(
        title: 'Look & Say',
        description: 'Point the camera at something and say it',
        time: '2 min',
        icon: Icons.center_focus_strong_rounded,
        color: AppColors.lilyPad,
        prototype: true,
        onTap: () => context.push(Routes.lookAndSay),
      ),
    ];

    return AppPage(
      title: 'Practice',
      children: [
        Text('Pick a way to practice.', style: AppText.bodyText.copyWith(color: AppColors.inkSoft)),
        const SizedBox(height: AppSpace.l),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700 ? 4 : 2;
          final width =
              (constraints.maxWidth - AppSpace.m * (columns - 1)) / columns;
          return Wrap(
            spacing: AppSpace.m,
            runSpacing: AppSpace.m,
            children: [
              for (var i = 0; i < cards.length; i++)
                SizedBox(width: width, child: FadeSlideIn(index: i, child: cards[i])),
            ],
          );
        }),
        if (next != null) ...[
          const SectionHeader(title: 'Up next in your practice'),
          AppCard(
            onTap: () => context.push(Routes.wordPractice(next.text, source: next.source)),
            semanticLabel: 'Practice ${next.text}',
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(next.text, style: AppText.title),
                      const SizedBox(height: AppSpace.xs),
                      SourceChip(
                          label: next.source.label,
                          icon: next.source.icon,
                          when: relativeDay(next.addedAt)),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded, color: AppColors.lake, size: 44),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.color,
    required this.onTap,
    this.prototype = false,
  });

  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool prototype;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: '$title. $description. About $time.',
      child: SizedBox(
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: AppRadius.chipRadius,
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                const Spacer(),
                if (prototype) const Flexible(child: TagBadge(label: 'Prototype')),
              ],
            ),
            const Spacer(),
            Text(title, style: AppText.section, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpace.xs),
            Text(description,
                style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpace.s),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: AppColors.inkFaint),
                const SizedBox(width: AppSpace.xs),
                Flexible(
                    child: Text(time, style: AppText.caption, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
