import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/practice_queue.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../shell/debug_menu.dart';
import '../shell/switch_learner.dart';
import 'lesson_path.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static String greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final queue = context.watch<PracticeQueue>();
    final learner = state.learner;
    // briefly null while switching learner, before the redirect to Welcome
    if (learner == null) return const Scaffold();

    final weekAgo = DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 6));
    final wordsThisWeek =
        state.historySince(weekAgo).fold<int>(0, (sum, d) => sum + d.wordsPracticed);
    final improving = state.trends.where((t) => t.weekly.last > t.weekly.first).length;

    return Scaffold(
      body: OceanBackdrop(child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.s, AppSpace.page, AppSpace.xxl),
          children: [
            Row(
              children: [
                MirrorULogo(size: 22, onLongPress: () => showDebugMenu(context)),
                const Spacer(),
                Tooltip(
                  message: 'Switch learner',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => confirmSwitchLearner(context),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.xs),
                      child: LearnerAvatar(learner: learner, size: 40),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            Text('${greeting(DateTime.now())}, ${learner.name}!', style: AppText.display),
            Text('Ready to practice?', style: AppText.bodyText.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: AppSpace.l),
            _ContinueCard(next: queue.peek()),
            SectionHeader(
              title: "Today's practice",
              actionLabel: queue.isEmpty ? null : '${queue.length} words',
            ),
            if (queue.isEmpty)
              EmptyState(
                icon: Icons.playlist_add_rounded,
                title: 'No words yet',
                message: 'Words from the Diagnostic, Read Aloud and Look & Say show up here.',
                action: SecondaryButton(
                    label: 'Find words', onPressed: () => context.go(Routes.practice)),
              )
            else
              SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: queue.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpace.m),
                  itemBuilder: (context, i) =>
                      FadeSlideIn(index: i, child: _QueueWordCard(word: queue.items[i])),
                ),
              ),
            const SectionHeader(title: 'This week'),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.waves_rounded,
                    color: AppColors.sky,
                    value: '${learner.streak}',
                    label: 'day streak',
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: StatTile(
                    icon: Icons.chat_bubble_rounded,
                    value: '$wordsThisWeek',
                    label: 'words practiced',
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: StatTile(
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                    value: '$improving',
                    label: 'sounds improving',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s),
            const Align(alignment: Alignment.centerLeft, child: TagBadge(label: 'Sample data')),
            const SectionHeader(title: 'Your lesson path'),
            if (state.lessons.isEmpty)
              _DiagnosticPrompt(message: 'Take the Diagnostic to build your lesson path.')
            else
              LessonPath(
                lessons: state.lessons,
                onOpen: (lesson) => context.push(
                    Routes.wordPractice(lesson.words.first, source: WordSource.assigned)),
              ),
            const SectionHeader(title: 'Sounds to work on'),
            if (state.soundsToWorkOn.isEmpty)
              _DiagnosticPrompt(message: 'Take the Diagnostic to find sounds to work on.')
            else
              Wrap(
                spacing: AppSpace.s,
                runSpacing: AppSpace.s,
                children: [
                  for (final s in state.soundsToWorkOn)
                    SoundChip(
                      phoneme: s.phoneme,
                      kind: s.level.kind,
                      onTap: () => context.push(
                          Routes.wordPractice(s.exampleWord, source: WordSource.diagnostic)),
                    ),
                ],
              ),
          ],
        ),
      )),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.next});

  final WordItem? next;

  @override
  Widget build(BuildContext context) {
    final word = next;
    return AppCard(
      gradient: AppGradients.lake,
      padding: const EdgeInsets.all(AppSpace.xl),
      semanticLabel: word == null ? 'Start the diagnostic' : 'Continue with ${word.text}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word == null ? "Let's get started" : 'Up next',
                        style: AppText.bodyStrong.copyWith(color: Colors.white70)),
                    const SizedBox(height: AppSpace.xs),
                    Text(word?.text ?? 'Find your sounds',
                        style: AppText.wordHero.copyWith(color: Colors.white, fontSize: 44)),
                  ],
                ),
              ),
              const OctopusBuddy(size: 96),
            ],
          ),
          if (word != null) ...[
            const SizedBox(height: AppSpace.s),
            SourceChip(
                label: word.source.label, icon: word.source.icon, when: relativeDay(word.addedAt)),
          ],
          const SizedBox(height: AppSpace.l),
          PrimaryButton(
            label: word == null ? 'Start the Diagnostic' : 'Start practice',
            icon: Icons.play_arrow_rounded,
            color: AppColors.lotus,
            onPressed: () => context.push(word == null
                ? Routes.diagnostic
                : Routes.wordPractice(word.text, source: word.source)),
          ),
        ],
      ),
    );
  }
}

class _QueueWordCard extends StatelessWidget {
  const _QueueWordCard({required this.word});

  final WordItem word;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: AppCard(
        semanticLabel: 'Practice ${word.text}',
        onTap: () => context.push(Routes.wordPractice(word.text, source: word.source)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(word.text, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(word.phonemes.map((p) => '/$p/').join(' '),
                style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            SourceChip(label: word.source.label, icon: word.source.icon),
            const SizedBox(height: AppSpace.s),
            Row(
              children: [
                Text('Start', style: AppText.button.copyWith(color: AppColors.lakeDeep)),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.lakeDeep),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticPrompt extends StatelessWidget {
  const _DiagnosticPrompt({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: EmptyState(
        icon: Icons.fact_check_rounded,
        title: 'Nothing here yet',
        message: message,
        action: SecondaryButton(
            label: 'Take the Diagnostic', onPressed: () => context.push(Routes.diagnostic)),
      ),
    );
  }
}
