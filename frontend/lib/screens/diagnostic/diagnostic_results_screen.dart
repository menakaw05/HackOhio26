import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/mock/mock_diagnostic.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class DiagnosticResultsScreen extends StatefulWidget {
  const DiagnosticResultsScreen({super.key});

  @override
  State<DiagnosticResultsScreen> createState() => _DiagnosticResultsScreenState();
}

class _DiagnosticResultsScreenState extends State<DiagnosticResultsScreen> {
  bool _added = false;

  static String _summary(List<SoundScore> profile) {
    final strong = profile.where((s) => s.level == SoundLevel.strong).length;
    final focus = (profile.where((s) => s.level != SoundLevel.strong).toList()
          ..sort((a, b) => a.score.compareTo(b.score)))
        .take(2)
        .map((s) => '/${s.phoneme}/')
        .toList();
    final strongPart = 'You already say $strong sounds really well.';
    if (focus.isEmpty) return '$strongPart Amazing work!';
    return "$strongPart Let's practice ${focus.join(' and ')} next.";
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.soundProfile;
    final groups = {
      for (final level in SoundLevel.values)
        level: profile.where((s) => s.level == level).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Your sound profile'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.s, AppSpace.page, AppSpace.xxl),
          children: [
            AppCard(
              gradient: AppGradients.lake,
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: Text(_summary(profile),
                        style: AppText.bodyStrong.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s),
            const Align(alignment: Alignment.centerLeft, child: TagBadge(label: 'Sample results')),
            for (final level in [SoundLevel.needsPractice, SoundLevel.almost, SoundLevel.strong])
              if (groups[level]!.isNotEmpty) ...[
                SectionHeader(title: level.label),
                AppCard(
                  child: Column(
                    children: [
                      for (final s in groups[level]!) SoundBar(score: s),
                    ],
                  ),
                ),
              ],
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: _added ? 'Added to your practice' : 'Add to my practice',
              icon: _added ? Icons.check_rounded : Icons.playlist_add_rounded,
              expand: true,
              onPressed: _added
                  ? null
                  : () {
                      final words = MockDiagnostic.practiceWordsFor(profile);
                      final count = state.addWords(words, WordSource.diagnostic);
                      setState(() => _added = true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(count == 0
                              ? 'Those words are already in your practice.'
                              : 'Added $count words to your practice.')));
                    },
            ),
            const SizedBox(height: AppSpace.s),
            SecondaryButton(label: 'Done', expand: true, onPressed: () => context.go(Routes.home)),
          ],
        ),
      ),
    );
  }
}
