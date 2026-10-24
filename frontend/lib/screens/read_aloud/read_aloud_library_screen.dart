import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ReadAloudLibraryScreen extends StatelessWidget {
  const ReadAloudLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final passages = context.watch<AppState>().passages;
    return AppPage(
      title: 'Read Aloud',
      children: [
        Text('Pick a story to read out loud.',
            style: AppText.bodyText.copyWith(color: AppColors.inkSoft)),
        const SizedBox(height: AppSpace.l),
        if (passages.isEmpty)
          const EmptyState(icon: Icons.menu_book_rounded, title: 'No stories yet')
        else
          for (final p in passages) ...[
            _PassageCard(passage: p),
            const SizedBox(height: AppSpace.m),
          ],
      ],
    );
  }
}

class _PassageCard extends StatelessWidget {
  const _PassageCard({required this.passage});

  final Passage passage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(Routes.reading(passage.id)),
      semanticLabel: '${passage.title}, ${passage.level}, about ${passage.minutes} minutes',
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              gradient: AppGradients.lotus,
              borderRadius: AppRadius.chipRadius,
            ),
            child: Icon(passage.icon, color: Colors.white, size: 36),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(passage.title, style: AppText.section),
                const SizedBox(height: AppSpace.xs),
                Wrap(
                  spacing: AppSpace.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TagBadge(label: passage.level),
                    Text('${passage.minutes} min', style: AppText.caption),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}
