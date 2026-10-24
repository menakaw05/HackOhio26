import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

String _clean(String word) => word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

class ReadingResultsScreen extends StatefulWidget {
  const ReadingResultsScreen({super.key, required this.passageId});

  final String passageId;

  @override
  State<ReadingResultsScreen> createState() => _ReadingResultsScreenState();
}

class _ReadingResultsScreenState extends State<ReadingResultsScreen> {
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final passage = state.passages.where((p) => p.id == widget.passageId).firstOrNull;
    if (passage == null) return const MissingPage(what: 'story');
    final words = passage.words;
    // SAMPLE DATA: results come from the seeded passage, not a real reading
    final flagged = passage.mockResults.keys.toList();
    final clearCount = words.where((w) => !passage.mockResults.containsKey(_clean(w))).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Nice reading!'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.s, AppSpace.page, AppSpace.xxl),
          children: [
            Row(
              children: [
                Expanded(child: Text(passage.title, style: AppText.section)),
                const TagBadge(label: 'Sample data'),
              ],
            ),
            const SizedBox(height: AppSpace.m),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                    value: '$clearCount',
                    label: 'words read clearly',
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: StatTile(
                    icon: Icons.flag_rounded,
                    color: AppColors.almost,
                    value: '${flagged.length}',
                    label: 'words to practice',
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                const Expanded(
                  child: StatTile(
                    icon: Icons.speed_rounded,
                    color: AppColors.sky,
                    value: '—',
                    label: 'pace (coming soon)',
                  ),
                ),
              ],
            ),
            const SectionHeader(title: 'How it went'),
            const _Legend(),
            const SizedBox(height: AppSpace.m),
            AppCard(
              child: Wrap(
                runSpacing: AppSpace.xs,
                children: [
                  for (final w in words) _ResultWord(word: w, kind: passage.mockResults[_clean(w)]),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s),
            Text('Tap a highlighted word to practice it.', style: AppText.caption),
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: _added ? 'Added to your practice' : 'Practice these words',
              icon: _added ? Icons.check_rounded : Icons.playlist_add_rounded,
              expand: true,
              onPressed: _added
                  ? null
                  : () {
                      final count = state.addWords(flagged, WordSource.reading);
                      setState(() => _added = true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(count == 0
                              ? 'Those words are already in your practice.'
                              : 'Added $count words to your practice.')));
                    },
            ),
            const SizedBox(height: AppSpace.s),
            SecondaryButton(
              label: 'Read again',
              expand: true,
              onPressed: () => context.pushReplacement(Routes.reading(passage.id)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultWord extends StatelessWidget {
  const _ResultWord({required this.word, required this.kind});

  final String word;
  final FeedbackKind? kind;

  @override
  Widget build(BuildContext context) {
    final text = Text(word,
        style: AppText.reading.copyWith(fontSize: 22, color: kind?.color ?? AppColors.ink));
    if (kind == null) {
      return Padding(padding: const EdgeInsets.only(right: 6), child: text);
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        label: 'Practice $word',
        excludeSemantics: true,
        child: Material(
          color: kind!.softColor,
          borderRadius: AppRadius.chipRadius,
          child: InkWell(
            borderRadius: AppRadius.chipRadius,
            onTap: () =>
                context.push(Routes.wordPractice(_clean(word), source: WordSource.reading)),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: text),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpace.xs),
            Text(label, style: AppText.caption),
          ],
        );
    return Wrap(
      spacing: AppSpace.l,
      runSpacing: AppSpace.xs,
      children: [
        item(AppColors.ink, 'Clear'),
        item(FeedbackKind.almost.color, 'Almost'),
        item(FeedbackKind.focus.color, 'Needs practice'),
      ],
    );
  }
}
