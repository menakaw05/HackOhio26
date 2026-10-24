import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

enum _Range { week, month }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.history.isEmpty && state.soundProfile.isEmpty) {
      return AppPage(
        title: 'Progress',
        children: [
          AppCard(
            child: EmptyState(
              icon: Icons.insights_rounded,
              title: 'No progress yet',
              message: 'Practice a few words and your progress will show up here.',
              action: SecondaryButton(
                  label: 'Take the Diagnostic', onPressed: () => context.push(Routes.diagnostic)),
            ),
          ),
        ],
      );
    }

    final days = _range == _Range.week ? 7 : 30;
    final since = DateUtils.dateOnly(DateTime.now()).subtract(Duration(days: days - 1));
    final inRange = state.historySince(since);
    final minutes = inRange.fold<int>(0, (s, d) => s + d.minutes);
    final words = inRange.fold<int>(0, (s, d) => s + d.wordsPracticed);
    final sounds = [...state.soundProfile]..sort((a, b) => a.score.compareTo(b.score));

    return AppPage(
      title: 'Progress',
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<_Range>(
                segments: const [
                  ButtonSegment(value: _Range.week, label: Text('Week')),
                  ButtonSegment(value: _Range.month, label: Text('Month')),
                ],
                selected: {_range},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
            ),
            const SizedBox(width: AppSpace.m),
            const TagBadge(label: 'Sample data'),
          ],
        ),
        const SizedBox(height: AppSpace.l),
        Row(
          children: [
            Expanded(
              child: StatTile(
                  icon: Icons.timer_rounded, value: '$minutes', label: 'minutes practiced'),
            ),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: StatTile(
                  icon: Icons.chat_bubble_rounded,
                  color: AppColors.lotus,
                  value: '$words',
                  label: 'words practiced'),
            ),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: StatTile(
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.sky,
                  value: '${inRange.length}',
                  label: 'days practiced'),
            ),
          ],
        ),
        if (state.trends.isNotEmpty) ...[
          const SectionHeader(title: 'Getting better'),
          AppCard(
            child: Column(
              children: [
                for (final t in state.trends) _TrendRow(trend: t),
              ],
            ),
          ),
        ],
        if (sounds.isNotEmpty) ...[
          const SectionHeader(title: 'Every sound'),
          AppCard(child: Column(children: [for (final s in sounds) SoundBar(score: s)])),
        ],
        if (state.mastered.isNotEmpty) ...[
          const SectionHeader(title: 'Sounds mastered'),
          Wrap(
            spacing: AppSpace.m,
            runSpacing: AppSpace.m,
            children: [
              for (final (i, p) in state.mastered.indexed)
                FadeSlideIn(index: i, child: _MasteredBadge(phoneme: p)),
            ],
          ),
        ],
        if (state.activity.isNotEmpty) ...[
          const SectionHeader(title: 'Recent activity'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.s),
            child: Column(
              children: [
                for (var i = 0; i < state.activity.length; i++) ...[
                  if (i > 0) const Divider(),
                  _ActivityRow(entry: state.activity[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});

  final SoundTrend trend;

  @override
  Widget build(BuildContext context) {
    final level = SoundLevel.fromScore(trend.weekly.last);
    return Semantics(
      label: 'Sound ${trend.phoneme} over ${trend.weekly.length} weeks, now ${level.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
        child: Row(
          children: [
            SoundChip(phoneme: trend.phoneme, kind: level.kind),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Text('${trend.weekly.length} weeks · now ${level.label.toLowerCase()}',
                  style: AppText.caption),
            ),
            Sparkline(values: trend.weekly, color: level.kind.color),
          ],
        ),
      ),
    );
  }
}

class _MasteredBadge extends StatelessWidget {
  const _MasteredBadge({required this.phoneme});

  final String phoneme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mastered sound $phoneme',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success, width: 3),
            ),
            alignment: Alignment.center,
            child: Text('/$phoneme/', style: AppText.section.copyWith(color: AppColors.success)),
          ),
          const SizedBox(height: AppSpace.xs),
          const Icon(Icons.star_rounded, color: AppColors.almost, size: 18),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
      child: Row(
        children: [
          Icon(entry.kind.icon, color: entry.kind.color),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.word, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                SourceChip(label: entry.source.label, icon: entry.source.icon),
              ],
            ),
          ),
          Text(relativeDay(entry.when), style: AppText.caption),
        ],
      ),
    );
  }
}
