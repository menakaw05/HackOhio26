import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/mock/demo_seed.dart';
import '../../data/mock/mock_pronunciation.dart';
import '../../data/models.dart';
import '../../data/practice_queue.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

enum _Step { hear, watch, tryIt, feedback }

const _stepLabels = ['Hear', 'Watch', 'Try', 'Feedback'];
const _maxAttempts = 3;

/// The hero screen: Hear → Watch → Try → Feedback for one word. Services are mocked for now.
class WordPracticeScreen extends StatefulWidget {
  const WordPracticeScreen({super.key, this.word, required this.source});

  final String? word;
  final WordSource source;

  @override
  State<WordPracticeScreen> createState() => _WordPracticeScreenState();
}

class _WordPracticeScreenState extends State<WordPracticeScreen> {
  late WordItem _word;
  _Step _step = _Step.hear;
  final List<AttemptResult> _attempts = [];
  bool _listening = false;
  bool _slowMotion = false;
  String? _focusPhoneme;
  int _celebrations = 0;

  @override
  void initState() {
    super.initState();
    final queue = context.read<PracticeQueue>();
    final text = widget.word ?? queue.peek()?.text ?? 'boot';
    _word =
        queue.items.where((w) => w.text == text).firstOrNull ??
        DemoSeed.word(text, widget.source, DateTime.now());
  }

  void _comingSoon(String what) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$what is coming soon.')));

  void _toggleMic() {
    if (!_listening) {
      setState(() => _listening = true);
      return;
    }
    // MOCK: real scoring comes from the pronunciation service later
    final result = MockPronunciation.assess(_word, _attempts.length);
    setState(() {
      _listening = false;
      _attempts.add(result);
      _step = _Step.feedback;
      if (result.kind == FeedbackKind.success) _celebrations++;
    });
    if (result.kind == FeedbackKind.success) AppHaptics.success();
  }

  void _tryAgain() => setState(() => _step = _Step.tryIt);

  void _nextWord() {
    final queue = context.read<PracticeQueue>();
    if (queue.contains(_word.text)) queue.remove(_word.id);
    final next = queue.peek();
    if (next == null) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("That's everything in your practice list!"),
        ),
      );
    } else {
      context.pushReplacement(
        Routes.wordPractice(next.text, source: next.source),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppSize.sidebarBreakpoint;

    final header = Row(
      children: [
        Flexible(
          child: SourceChip(
            label: _word.source.label,
            icon: _word.source.icon,
            when: relativeDay(_word.addedAt),
          ),
        ),
        const Spacer(),
        AttemptDots(
          total: _maxAttempts,
          results: [for (final a in _attempts) a.kind],
        ),
      ],
    );

    final coach = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_word.text, style: AppText.wordHero, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s),
        _SoundRow(
          phonemes: _word.phonemes,
          focus: _focusPhoneme,
          results: _step == _Step.feedback && _attempts.isNotEmpty
              ? _attempts.last.phonemeResults
              : null,
          onTap: (p) =>
              setState(() => _focusPhoneme = _focusPhoneme == p ? null : p),
        ),
        const SizedBox(height: AppSpace.l),
        StepperBar(
          steps: _stepLabels,
          current: _step.index,
          onStepTap: (i) {
            // feedback only makes sense once there's an attempt
            if (i == _Step.feedback.index && _attempts.isEmpty) return;
            setState(() => _step = _Step.values[i]);
          },
        ),
        const SizedBox(height: AppSpace.l),
        AnimatedSwitcher(duration: AppMotion.medium, child: _stepBody()),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Word Practice'),
      ),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(
                        flex: 55,
                        child: Padding(
                          padding: EdgeInsets.all(AppSpace.xl),
                          child: _AvatarStage(),
                        ),
                      ),
                      Expanded(
                        flex: 45,
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpace.xl),
                          children: [
                            header,
                            const SizedBox(height: AppSpace.l),
                            coach,
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      AppSpace.s,
                      AppSpace.page,
                      AppSpace.xxl,
                    ),
                    children: [
                      header,
                      const SizedBox(height: AppSpace.m),
                      const SizedBox(height: 220, child: _AvatarStage()),
                      const SizedBox(height: AppSpace.l),
                      coach,
                    ],
                  ),
          ),
          Positioned.fill(child: CelebrationOverlay(playCount: _celebrations)),
        ],
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case _Step.hear:
        return _StepCard(
          key: const ValueKey(_Step.hear),
          instruction: 'Listen to how "${_word.text}" sounds.',
          children: [
            PrimaryButton(
              label: 'Play the word',
              icon: Icons.volume_up_rounded,
              expand: true,
              onPressed: () => _comingSoon('Hearing the word'),
            ),
            const SizedBox(height: AppSpace.s),
            SecondaryButton(
              label: 'Next: Watch',
              expand: true,
              onPressed: () => setState(() => _step = _Step.watch),
            ),
          ],
        );
      case _Step.watch:
        return _StepCard(
          key: const ValueKey(_Step.watch),
          instruction: _focusPhoneme == null
              ? "Watch your coach's mouth. Tap a sound above to focus on it."
              : 'Watch how your coach makes /$_focusPhoneme/.',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Slow motion', style: AppText.bodyStrong),
              value: _slowMotion,
              onChanged: (v) => setState(() => _slowMotion = v),
            ),
            const SizedBox(height: AppSpace.s),
            Row(
              children: [
                Flexible(
                  child: Text('Tongue guidance', style: AppText.bodyStrong),
                ),
                const SizedBox(width: AppSpace.s),
                const TagBadge(label: 'Guidance'),
              ],
            ),
            const SizedBox(height: AppSpace.s),
            const ComingSoon(
              label: 'Tongue position schematic',
              icon: Icons.schema_rounded,
              height: 140,
              detail: 'A drawing to guide you, not a measurement.',
            ),
            const SizedBox(height: AppSpace.m),
            SecondaryButton(
              label: 'Next: Try',
              expand: true,
              onPressed: () => setState(() => _step = _Step.tryIt),
            ),
          ],
        );
      case _Step.tryIt:
        return _StepCard(
          key: const ValueKey(_Step.tryIt),
          instruction: _listening
              ? 'Listening… tap again when you\'re done.'
              : 'Tap the mic and say "${_word.text}".',
          children: [
            const ComingSoon(
              label: 'Camera with mouth guide',
              icon: Icons.videocam_rounded,
              height: 150,
            ),
            const SizedBox(height: AppSpace.l),
            Center(
              child: MicButton(listening: _listening, onPressed: _toggleMic),
            ),
          ],
        );
      case _Step.feedback:
        final last = _attempts.last;
        final outOfTries = _attempts.length >= _maxAttempts;
        return _StepCard(
          key: ValueKey('feedback-${_attempts.length}'),
          children: [
            FeedbackBanner(kind: last.kind, message: last.coaching),
            const SizedBox(height: AppSpace.s),
            const Align(
              alignment: Alignment.centerLeft,
              child: TagBadge(label: 'Sample feedback'),
            ),
            const SizedBox(height: AppSpace.l),
            if (last.kind != FeedbackKind.success && !outOfTries) ...[
              PrimaryButton(
                label: 'Try again',
                icon: Icons.replay_rounded,
                expand: true,
                onPressed: _tryAgain,
              ),
              const SizedBox(height: AppSpace.s),
              SecondaryButton(
                label: 'Next word',
                expand: true,
                onPressed: _nextWord,
              ),
            ] else
              PrimaryButton(
                label: 'Next word',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                onPressed: _nextWord,
              ),
          ],
        );
    }
  }
}

class _AvatarStage extends StatelessWidget {
  const _AvatarStage();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.stage,
        borderRadius: AppRadius.cardRadius,
      ),
      padding: const EdgeInsets.all(AppSpace.m),
      child: const ComingSoon(
        label: 'Your avatar coach',
        icon: Icons.face_retouching_natural_rounded,
        height: null,
        detail: 'Says the word and shows the mouth shape.',
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.phonemes,
    required this.focus,
    required this.results,
    required this.onTap,
  });

  final List<String> phonemes;
  final String? focus;
  final List<PhonemeResult>? results;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (phonemes.isEmpty) {
      return Text(
        'Sounds for this word are coming soon.',
        style: AppText.caption,
        textAlign: TextAlign.center,
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      children: [
        for (var i = 0; i < phonemes.length; i++)
          SoundChip(
            phoneme: phonemes[i],
            kind: results != null && i < results!.length
                ? results![i].kind
                : null,
            selected: focus == phonemes[i],
            onTap: () => onTap(phonemes[i]),
          ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({super.key, this.instruction, required this.children});

  final String? instruction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (instruction != null) ...[
            Text(instruction!, style: AppText.bodyStrong),
            const SizedBox(height: AppSpace.m),
          ],
          ...children,
        ],
      ),
    );
  }
}
