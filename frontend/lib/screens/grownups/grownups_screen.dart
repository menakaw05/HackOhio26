import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// For the learner's SLP or parent: weekly summary, assigning words, export.
class GrownupsScreen extends StatefulWidget {
  const GrownupsScreen({super.key});

  @override
  State<GrownupsScreen> createState() => _GrownupsScreenState();
}

class _GrownupsScreenState extends State<GrownupsScreen> {
  final _words = TextEditingController();

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  void _assign(AppState state) {
    final words = _words.text
        .split(RegExp(r'[\s,;]+'))
        .map((w) => w.trim().toLowerCase())
        .where((w) => w.isNotEmpty)
        .toSet();
    if (words.isEmpty) return;
    final added = state.addWords(words, WordSource.assigned);
    _words.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added == 0
            ? 'Those words are already in the practice list.'
            : 'Added $added words to ${state.learner?.name}\'s practice.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.learner?.name ?? 'your learner';
    final weekAgo = DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 6));
    final week = state.historySince(weekAgo);
    final minutes = week.fold<int>(0, (s, d) => s + d.minutes);
    final words = week.fold<int>(0, (s, d) => s + d.wordsPracticed);
    final improving =
        state.trends.where((t) => t.weekly.last > t.weekly.first).map((t) => t.phoneme).toList();
    final support = state.soundsToWorkOn;

    return AppPage(
      title: 'For your SLP / parent',
      children: [
        Text("A look at $name's week, and a place to add words to practice.",
            style: AppText.bodyText.copyWith(color: AppColors.inkSoft)),
        SectionHeader(title: 'This week', actionLabel: null),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Weekly summary', style: AppText.section)),
                  const TagBadge(label: 'Sample data'),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              Row(
                children: [
                  Expanded(child: _SummaryFigure(value: '$minutes', label: 'minutes')),
                  Expanded(child: _SummaryFigure(value: '$words', label: 'words')),
                  Expanded(child: _SummaryFigure(value: '${week.length}', label: 'days')),
                ],
              ),
              const Divider(height: AppSpace.xl),
              Text('Sounds improving', style: AppText.bodyStrong),
              const SizedBox(height: AppSpace.s),
              _SoundList(phonemes: improving, kind: FeedbackKind.success, empty: 'None yet'),
              const SizedBox(height: AppSpace.l),
              Text('Sounds needing support', style: AppText.bodyStrong),
              const SizedBox(height: AppSpace.s),
              _SoundList(
                phonemes: [for (final s in support) s.phoneme],
                kind: FeedbackKind.focus,
                empty: 'Run the Diagnostic to find out',
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Assign a word list'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Type or paste words to add to $name's practice.", style: AppText.caption),
              const SizedBox(height: AppSpace.m),
              TextField(
                controller: _words,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'e.g. rain, rabbit, three'),
                onSubmitted: (_) => _assign(state),
              ),
              const SizedBox(height: AppSpace.m),
              PrimaryButton(
                label: 'Add to practice',
                icon: Icons.playlist_add_rounded,
                onPressed: () => _assign(state),
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Share'),
        SecondaryButton(
          label: 'Export summary',
          icon: Icons.ios_share_rounded,
          expand: true,
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exporting a summary is coming soon.'))),
        ),
        const SizedBox(height: AppSpace.xl),
        Text(
          'echo-me is a practice aid that works alongside a speech-language pathologist. '
          'It does not diagnose or treat speech conditions.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SummaryFigure extends StatelessWidget {
  const _SummaryFigure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppText.title.copyWith(color: AppColors.lakeDeep)),
        Text(label, style: AppText.caption),
      ],
    );
  }
}

class _SoundList extends StatelessWidget {
  const _SoundList({required this.phonemes, required this.kind, required this.empty});

  final List<String> phonemes;
  final FeedbackKind kind;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (phonemes.isEmpty) return Text(empty, style: AppText.caption);
    return Wrap(
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      children: [for (final p in phonemes) SoundChip(phoneme: p, kind: kind)],
    );
  }
}
