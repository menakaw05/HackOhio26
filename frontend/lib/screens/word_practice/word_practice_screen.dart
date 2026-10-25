import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../avatar_coach.dart';
import '../../avatar_view.dart';
import '../../data/mock/demo_seed.dart';
import '../../data/models.dart';
import '../../data/practice_queue.dart';
import '../../phoneme_classifier.dart';
import '../../phoneme_feedback.dart';
import '../../practice_services.dart';
import '../../router.dart';
import '../../speech_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

enum _Step { hear, watch, tryIt, feedback }

const _stepLabels = ['Hear', 'Watch', 'Try', 'Feedback'];
const _maxAttempts = 3;
const _passScore = 80.0; // Azure word accuracy; 60-80 is "almost"

// The coach says words at a normal pace (slower in slow motion) and tips a
// little slower; sounds are demonstrated slower still (the page's default).
const Map<String, dynamic> _wordTts = {'rate': '0%'};
const Map<String, dynamic> _slowTts = {'rate': '-30%'};
const Map<String, dynamic> _tipTts = {'rate': '-10%'};

/// The hero screen: Hear → Watch → Try → Feedback for one word.
///
/// The first try is unaided: Watch (the coach) opens only after a miss.
/// Try scores the word with Azure. If the weakest sound has a lip model
/// (/p/, /æ/, /u/), the child can practice it on its own in a syllable
/// ("pah"), checked by the camera and the lip model. After a miss the coach
/// says the model's tip and demonstrates, as many times as it takes; then
/// it's back to the whole word.
class WordPracticeScreen extends StatefulWidget {
  const WordPracticeScreen({super.key, this.word, required this.source});

  final String? word;
  final WordSource source;

  @override
  State<WordPracticeScreen> createState() => _WordPracticeScreenState();
}

class _WordPracticeScreenState extends State<WordPracticeScreen> {
  final PracticeServices _services = createPracticeServices();
  final GlobalKey<AvatarViewState> _coachKey = GlobalKey();
  bool _coachReady = false;
  VoidCallback? _coachPending; // runs once the coach has loaded

  late WordItem _word;
  _Step _step = _Step.hear;
  final List<AttemptResult> _attempts = [];
  PAResult? _lastScore;
  bool _listening = false;
  bool _scoring = false;
  bool _slowMotion = false;
  bool _cameraOn = false;
  bool _cameraFailed = false;
  String? _focusPhoneme;
  int _celebrations = 0;

  String? _weakest; // the weakest sound in the last missed word

  // Sound practice: the weakest sound, said with the word's own vowel ("pah").
  PhonemeAssessment? _practice; // offered after a missed word
  PhonemeAssessment? _target; // being practiced now
  SoundPrompt? _prompt;
  List<String> _tips = const [];
  bool _demo = false; // the coach has started demonstrating
  LipCheck? _lastCheck;
  String? _soundNote; // e.g. no face seen
  String? _soundWon; // the sound just passed, until the next word try

  @override
  void initState() {
    super.initState();
    final queue = context.read<PracticeQueue>();
    final text = widget.word ?? queue.peek()?.text ?? 'boot';
    _word =
        queue.items.where((w) => w.text == text).firstOrNull ??
        DemoSeed.word(text, widget.source, DateTime.now());
  }

  @override
  void dispose() {
    _services.dispose();
    super.dispose();
  }

  bool get _outOfTries => _attempts.length >= _maxAttempts;

  /// The coach only demonstrates once the child has tried on their own and missed.
  bool get _missed => _attempts.any((a) => a.kind != FeedbackKind.success);

  /// Azure's sounds once the word has been tried, otherwise the word's own.
  List<String> get _phonemes {
    final heard = [
      for (final p in _attempts.lastOrNull?.phonemeResults ?? const <PhonemeResult>[])
        p.phoneme,
    ];
    return heard.isEmpty ? _word.phonemes : heard;
  }

  void _goTo(_Step step) {
    setState(() => _step = step);
    if (step == _Step.watch) _coachShow();
    if (step == _Step.tryIt) _startCamera();
  }

  Future<void> _startCamera() async {
    if (_cameraOn) return;
    setState(() => _cameraOn = true);
    final ok = await _services.startCamera();
    if (mounted) setState(() => _cameraFailed = !ok);
  }

  // -------------------------
  // Coach
  // -------------------------

  void _onCoachMessage(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    switch (m['event']) {
      case 'ready':
        _coachReady = true;
        _prepareCoach();
        final pending = _coachPending;
        _coachPending = null;
        pending?.call();
      case 'error':
        debugPrint('coach: ${m['message']}');
    }
  }

  /// Runs [action] on the coach now, or once it has loaded.
  void _withCoach(void Function(AvatarViewState coach) action) {
    final coach = _coachKey.currentState;
    if (_coachReady && coach != null) {
      action(coach);
    } else if (_services.coachUrl != null) {
      _coachPending = () => _withCoach(action);
    }
  }

  /// Has the coach synthesize what it may say next, so it starts right away.
  void _prepareCoach() {
    final coach = _coachKey.currentState;
    if (!_coachReady || coach == null) return;
    coach.prepare(_word.text, tts: _slowMotion ? _slowTts : _wordTts);
    final prompt = _prompt;
    if (prompt != null) {
      coach.prepare(prompt.text, tts: {'ipa': prompt.ipa});
      for (final tip in _tips) {
        coach.prepare(tip, tts: _tipTts);
      }
    }
  }

  /// The coach says the word, or the sound being practiced or tapped.
  void _coachShow() {
    final sound = _target?.phoneme ?? _focusPhoneme;
    if (sound == null) {
      _withCoach((c) => c.say(_word.text, opts: {'tts': _slowMotion ? _slowTts : _wordTts}));
      return;
    }
    final prompt = _promptFor(sound);
    _withCoach((c) => c.say(prompt.text, opts: _soundOpts(sound, prompt)));
  }

  /// After a missed sound: the coach says the tip, then demonstrates.
  void _coachTip(String tip) {
    final coach = _coachKey.currentState;
    if (!_coachReady || coach == null) {
      _services.speak(tip);
      return;
    }
    final prompt = _prompt!;
    coach.sayAll([
      (tip, {'tts': _tipTts}),
      (prompt.text, _soundOpts(_target!.phoneme, prompt)),
    ]);
  }

  SoundPrompt _promptFor(String sound) {
    final prompt = _prompt;
    if (prompt != null && sound == _target?.phoneme) return prompt;
    final phonemes = _phonemes;
    final i = phonemes.indexOf(sound);
    return soundPromptFor(
      sound,
      before: i > 0 ? phonemes[i - 1] : null,
      after: i >= 0 && i + 1 < phonemes.length ? phonemes[i + 1] : null,
    );
  }

  /// The coach shows the mouth shape first, then says the sound, exaggerating
  /// the movement less as the child gets closer.
  Map<String, dynamic> _soundOpts(String sound, SoundPrompt prompt) {
    final viseme = visemeFor(sound);
    final check = _lastCheck;
    final accuracy = check != null ? check.score * 100 : (_target?.accuracyScore ?? 100);
    final gains = boostFor(sound, boostGain(accuracy));
    return {
      'tts': {'ipa': prompt.ipa},
      if (viseme != null) 'holdViseme': viseme,
      'holdMs': 500,
      if (gains.isNotEmpty) 'boost': {'gains': gains, 'start': 0, 'end': 30},
    };
  }

  // -------------------------
  // The word: scored by Azure
  // -------------------------

  Future<void> _toggleMic() => _target == null ? _toggleWordMic() : _toggleSoundMic();

  Future<void> _toggleWordMic() async {
    if (!_listening) {
      await _services.stopSpeaking();
      if (!mounted) return;
      final started = await _services.startRecording(context);
      if (mounted) setState(() => _listening = started);
      return;
    }
    setState(() {
      _listening = false;
      _scoring = true;
    });
    try {
      final score = await _services.stopAndScore(_word.text);
      if (mounted) _scoreWord(score);
    } catch (e) {
      debugPrint('assess error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't check that one. Let's try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _scoring = false);
    }
  }

  void _scoreWord(PAResult score) {
    final passed = score.accuracyScore >= _passScore;
    final worst = passed ? null : findWorstPhoneme(score);
    // only sounds with a lip model can be checked on their own with the camera
    final practice =
        worst != null && PhonemeQualityModel.hasModelFor(worst.phoneme) ? worst : null;
    final String coaching;
    if (passed) {
      coaching = 'You said "${_word.text}" clearly!';
    } else if (practice != null) {
      coaching = "Let's work on the /${practice.phoneme}/ sound.";
    } else if (worst != null) {
      coaching = azureFeedbackFor(worst);
    } else {
      coaching = "I couldn't hear that clearly. Let's try again.";
    }

    final result = AttemptResult(
      wordId: _word.id,
      kind: passed
          ? FeedbackKind.success
          : (score.accuracyScore >= 60 ? FeedbackKind.almost : FeedbackKind.focus),
      phonemeResults: [
        for (final w in score.words)
          for (final p in w.phonemes)
            PhonemeResult(p.phoneme, SoundLevel.fromScore(p.accuracyScore / 100).kind),
      ],
      coaching: coaching,
      timestamp: DateTime.now(),
    );
    setState(() {
      _attempts.add(result);
      _lastScore = score;
      _weakest = worst?.phoneme;
      _practice = practice;
      _soundWon = null;
      _step = _Step.feedback;
      if (passed) _celebrations++;
    });
    if (passed) AppHaptics.success();
    _services.speak(coaching);
  }

  void _tryAgain() {
    setState(() => _soundWon = null);
    _goTo(_Step.tryIt);
  }

  /// After a miss with no lip check for the sound: the coach shows it.
  void _watchWeakest() {
    setState(() => _focusPhoneme = _weakest);
    _goTo(_Step.watch);
  }

  // -------------------------
  // One sound: checked by the camera and the lip model
  // -------------------------

  Future<void> _startSoundPractice() async {
    final target = _practice!;
    final around = neighbors(_lastScore!, target);
    final prompt = soundPromptFor(target.phoneme, before: around.before, after: around.after);
    setState(() {
      _target = target;
      _prompt = prompt;
      _tips = const [];
      _demo = false;
      _lastCheck = null;
      _soundNote = null;
      _focusPhoneme = target.phoneme;
    });
    _goTo(_Step.tryIt);
    _services.speak("Let's practice the /${target.phoneme}/ sound. Say /${prompt.ipa}/.");
    try {
      _tips = await _services.loadLipModel(target.phoneme);
      _prepareCoach();
    } catch (e) {
      debugPrint('lip model error: $e');
    }
  }

  Future<void> _toggleSoundMic() async {
    if (!_listening) {
      await _services.stopSpeaking();
      await _services.startLipCapture();
      if (mounted) {
        setState(() {
          _listening = true;
          _soundNote = null;
        });
      }
      return;
    }
    setState(() => _listening = false);
    final check = await _services.stopLipCapture();
    if (!mounted) return;
    if (check == null) {
      const note = "I couldn't see your mouth. Keep your face in the camera and try again.";
      setState(() => _soundNote = note);
      _services.speak(note);
      return;
    }
    setState(() => _lastCheck = check);
    if (check.passed) {
      _soundPassed();
      return;
    }
    setState(() => _demo = true);
    _coachTip(check.tip);
  }

  void _soundPassed() {
    final sound = _target!.phoneme;
    setState(() {
      _target = null;
      _prompt = null;
      _practice = null;
      _demo = false;
      _lastCheck = null;
      _focusPhoneme = null;
      _soundWon = sound;
      _celebrations++;
    });
    AppHaptics.success();
    _services.speak(_outOfTries
        ? 'You got the /$sound/ sound!'
        : 'You got the /$sound/ sound! Now say the whole word, ${_word.text}.');
  }

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
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SourceChip(
              label: _word.source.label,
              icon: _word.source.icon,
              when: relativeDay(_word.addedAt),
            ),
          ),
        ),
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
          phonemes: _phonemes,
          focus: _focusPhoneme,
          results: _step == _Step.feedback && _attempts.isNotEmpty
              ? _attempts.last.phonemeResults
              : null,
          onTap: (p) {
            setState(() => _focusPhoneme = _focusPhoneme == p ? null : p);
            if (_step == _Step.watch) _coachShow();
          },
        ),
        const SizedBox(height: AppSpace.l),
        StepperBar(
          steps: _stepLabels,
          current: _step.index,
          locked: {if (!_missed) _Step.watch.index},
          onStepTap: (i) {
            // feedback only makes sense once there's an attempt
            if (i == _Step.feedback.index && _attempts.isEmpty) return;
            _goTo(_Step.values[i]);
          },
        ),
        const SizedBox(height: AppSpace.l),
        AnimatedSwitcher(duration: AppMotion.medium, child: _stepBody()),
      ],
    );

    final stage = _AvatarStage(
      coach: _coachView(),
      camera: _cameraOn ? _cameraView() : null,
      vertical: wide,
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
                      Expanded(
                        flex: 55,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.xl),
                          child: stage,
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
                      SizedBox(height: _cameraOn ? 260 : 220, child: stage),
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

  /// The avatar page. The key keeps it loaded when the camera joins it.
  /// Touches go to the app, not the page.
  Widget _coachView() {
    final url = _services.coachUrl;
    if (url == null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.face_retouching_natural_rounded, color: AppColors.lakeDeep, size: 40),
            Text('Your avatar coach', style: AppText.caption.copyWith(color: AppColors.lakeDeep)),
          ]),
        ),
      );
    }
    return IgnorePointer(
      child: AvatarView(key: _coachKey, url: url, onMessage: _onCoachMessage),
    );
  }

  Widget _cameraView() {
    final camera = _services.camera;
    if (camera == null) {
      return Center(
        child: _cameraFailed
            ? Text('No camera on this device.',
                style: AppText.caption.copyWith(color: Colors.white70), textAlign: TextAlign.center)
            : const CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: ClipRRect(borderRadius: AppRadius.cardRadius, child: CameraPreview(camera)),
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
              onPressed: () => _services.speak(_word.text),
            ),
            const SizedBox(height: AppSpace.s),
            SecondaryButton(
              label: 'Next: Try',
              expand: true,
              onPressed: () => _goTo(_Step.tryIt),
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
              onChanged: (v) {
                setState(() => _slowMotion = v);
                _coachShow();
              },
            ),
            const SizedBox(height: AppSpace.s),
            SecondaryButton(
              label: 'Watch again',
              icon: Icons.replay_rounded,
              expand: true,
              onPressed: _coachShow,
            ),
            const SizedBox(height: AppSpace.m),
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
              onPressed: () => _goTo(_Step.tryIt),
            ),
          ],
        );
      case _Step.tryIt:
        return _target == null ? _tryWord() : _trySound();
      case _Step.feedback:
        final last = _attempts.last;
        final practice = _practice;
        return _StepCard(
          key: ValueKey('feedback-${_attempts.length}'),
          children: [
            FeedbackBanner(kind: last.kind, message: last.coaching),
            const SizedBox(height: AppSpace.l),
            if (last.kind == FeedbackKind.success || (_outOfTries && practice == null))
              PrimaryButton(
                label: 'Next word',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                onPressed: _nextWord,
              )
            else ...[
              if (practice != null)
                PrimaryButton(
                  label: 'Practice the /${practice.phoneme}/ sound',
                  icon: Icons.record_voice_over_rounded,
                  expand: true,
                  onPressed: _startSoundPractice,
                )
              else
                PrimaryButton(
                  label: 'Watch the coach',
                  icon: Icons.face_retouching_natural_rounded,
                  expand: true,
                  onPressed: _watchWeakest,
                ),
              const SizedBox(height: AppSpace.s),
              if (!_outOfTries) ...[
                SecondaryButton(
                  label: 'Try the word again',
                  expand: true,
                  onPressed: _tryAgain,
                ),
                const SizedBox(height: AppSpace.s),
              ],
              SecondaryButton(
                label: 'Next word',
                expand: true,
                onPressed: _nextWord,
              ),
            ],
          ],
        );
    }
  }

  Widget _tryWord() {
    final won = _soundWon;
    return _StepCard(
      key: const ValueKey('try-word'),
      instruction: _scoring
          ? 'Checking…'
          : _listening
              ? 'Listening… tap again when you\'re done.'
              : (_outOfTries ? null : 'Tap the mic and say "${_word.text}".'),
      children: [
        if (won != null) ...[
          FeedbackBanner(
            kind: FeedbackKind.success,
            message: _outOfTries
                ? 'You got the /$won/ sound!'
                : 'You got the /$won/ sound! Now say the whole word.',
          ),
          const SizedBox(height: AppSpace.l),
        ],
        if (_outOfTries)
          PrimaryButton(
            label: 'Next word',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            onPressed: _nextWord,
          )
        else
          Center(
            child: MicButton(listening: _listening, onPressed: _scoring ? null : _toggleMic),
          ),
      ],
    );
  }

  Widget _trySound() {
    final prompt = _prompt!;
    final check = _lastCheck;
    final note = _soundNote;
    return _StepCard(
      key: const ValueKey('try-sound'),
      instruction: _listening
          ? 'Watching… tap again when you\'re done.'
          : _demo
              ? 'Watch your coach, then say "${prompt.text}".'
              : 'Tap the mic and say "${prompt.text}".',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TagBadge(label: 'Sound practice: /${_target!.phoneme}/'),
        ),
        const SizedBox(height: AppSpace.m),
        if (note != null) ...[
          FeedbackBanner(kind: FeedbackKind.focus, message: note),
          const SizedBox(height: AppSpace.l),
        ] else if (check != null) ...[
          FeedbackBanner(kind: FeedbackKind.almost, message: check.tip),
          const SizedBox(height: AppSpace.l),
        ],
        Center(child: MicButton(listening: _listening, onPressed: _toggleMic)),
        if (_demo) ...[
          const SizedBox(height: AppSpace.l),
          SecondaryButton(
            label: 'Watch again',
            icon: Icons.replay_rounded,
            expand: true,
            onPressed: _listening ? null : _coachShow,
          ),
        ],
      ],
    );
  }
}

/// The coach, with the child's camera beside it while they try.
class _AvatarStage extends StatelessWidget {
  const _AvatarStage({required this.coach, this.camera, this.vertical = false});

  final Widget coach;
  final Widget? camera;

  /// Stack the camera under the coach (the tall stage on wide screens).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final camera = this.camera;
    return Container(
      // a pond, with the coach looking out of a porthole
      decoration: const BoxDecoration(
        gradient: AppGradients.stage,
        borderRadius: AppRadius.cardRadius,
        border: Border.fromBorderSide(BorderSide(color: AppColors.lakeDeep, width: 2.5)),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(AppSpace.m),
      child: camera == null
          ? Center(child: Porthole(child: coach))
          : Flex(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              children: [
                Expanded(child: Center(child: Porthole(child: coach))),
                const SizedBox(width: AppSpace.s, height: AppSpace.s),
                Expanded(child: camera),
              ],
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
