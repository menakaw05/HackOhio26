import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../avatar_coach.dart';
import '../../avatar_view.dart';
import '../../data/app_state.dart';
import '../../data/mock/demo_seed.dart';
import '../../data/models.dart';
import '../../data/practice_queue.dart';
import '../../phoneme_classifier.dart';
import '../../phoneme_feedback.dart';
import '../../practice_services.dart';
import '../../router.dart';
import '../../speech_models.dart';
import '../../stage4/follow_along.dart';
import '../../stage4/golden_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// The practice flow for one word (CLAUDE.md, "Practice flow").
enum _Stage { word, sound, coach, build, check }

const _stageLabels = ['Word', 'Sound', 'Coach', 'Sounds', 'Again'];
const _passScore = 80.0; // Azure word accuracy; 60-80 is "almost"

/// The hero screen: one word, and the stages that help with it if it's missed.
///
/// 1. Word: picture + word, no coach. Azure scores it. Right: done. Wrong: the stages
///    appear and Azure's phoneme scores pick the trouble sound.
/// 2. Sound: "Can you say oo in boot?", the sound's letters highlighted in the word. No
///    coach; the camera and lip model check it.
/// 3. Coach: only after a miss in 2. The coach says the lip model's tip and shows the
///    sound, as many times as it takes.
/// 4. Sounds: the word one sound at a time ("buh", "oo", "tuh"), the coach first, then
///    the child. Only the first time a word is practiced; after that it's the word, then
///    just the trouble sound.
/// 5. Again: the whole word, no coach. Azure's score next to stage 1's; a miss keeps the
///    word for next time.
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
  _Stage _stage = _Stage.word;
  final List<FeedbackKind> _stars = []; // one per stage, once the stages are showing
  bool _listening = false;
  bool _scoring = false;
  bool _cameraOn = false;
  bool _cameraFailed = false;
  int _celebrations = 0;

  // stages 1 and 5, scored by Azure
  PAResult? _firstScore;
  PAResult? _finalScore;

  // stages 2-4: the trouble sound, said with the word's own vowel ("pah")
  PhonemeAssessment? _target;
  int _targetIndex = 0;
  SoundPrompt? _prompt;
  bool _lipModel = false; // the camera can check it
  LipCheck? _lastCheck;
  String? _note; // e.g. no face seen
  bool _soundDone = false;

  // stage 4 (Menaka's follow-along): the coach says the word, stopping on each sound, and the
  // camera matches the child's mouth movement against golden recordings of that sound
  FollowAlongSession? _follow;
  String? _followError;
  Timer? _greenTimer; // the green moment after a sound passes
  int _followIndex = -1;
  FollowPhase? _followPhase;
  bool _built = false;

  @override
  void initState() {
    super.initState();
    final queue = context.read<PracticeQueue>();
    final text = widget.word ?? queue.peek()?.text ?? 'boot';
    _word =
        queue.items.where((w) => w.text == text).firstOrNull ??
        DemoSeed.word(text, widget.source, DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  @override
  void dispose() {
    _greenTimer?.cancel();
    _follow?.dispose();
    _services.dispose();
    super.dispose();
  }

  /// Once stage 1 is missed, the stages show and the child works through them.
  bool get _practicing => _stage != _Stage.word;

  List<PhonemeAssessment> get _scored => [
        for (final w in _firstScore?.words ?? const <WordAssessment>[]) ...w.phonemes,
      ];

  /// Azure's sounds once the word has been said, otherwise the word's own.
  List<String> get _phonemes {
    final heard = [for (final p in _scored) p.phoneme];
    return heard.isEmpty ? _word.phonemes : heard;
  }

  Future<void> _startCamera() async {
    if (_cameraOn || !mounted) return;
    setState(() => _cameraOn = true);
    final ok = await _services.startCamera();
    if (mounted) setState(() => _cameraFailed = !ok);
  }

  static FeedbackKind _kindFor(double accuracy) => accuracy >= _passScore
      ? FeedbackKind.success
      : (accuracy >= 60 ? FeedbackKind.almost : FeedbackKind.focus);

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
      case 'paused':
        _follow?.coachPaused(m['index'] as int);
      case 'finished':
        // the stepwise word, not a demonstration of the sound
        if (_stage == _Stage.build && m['text'] == _word.text) _follow?.coachFinished();
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
    final prompt = _prompt;
    if (!_coachReady || coach == null || prompt == null) return;
    coach.prepare(prompt.text, tts: {'ipa': prompt.ipa});
  }

  /// What the coach shows: the trouble sound.
  (String, Map<String, dynamic>) get _demo {
    final prompt = _prompt!;
    return (prompt.text, _soundOpts(prompt.ipa, hold: true));
  }

  void _demonstrate() {
    final (text, opts) = _demo;
    _withCoach((c) => c.say(text, opts: opts));
  }

  /// [tip] in the app's voice (it's on screen too), then the coach shows the sound. The
  /// coach only ever says the sound itself: whole sentences on its face looked eerie.
  Future<void> _tipThenDemo(String tip) async {
    await _services.speak(tip);
    if (mounted && !_listening) _demonstrate();
  }

  /// The coach shows the trouble sound's mouth shape first ([hold]), then says it,
  /// exaggerating the movement less as the child gets closer.
  Map<String, dynamic> _soundOpts(String ipa, {required bool hold}) {
    final sound = _target!.phoneme;
    final viseme = visemeFor(sound);
    final check = _lastCheck;
    final accuracy = check != null ? check.score * 100 : _target!.accuracyScore;
    final gains = boostFor(sound, boostGain(accuracy));
    return {
      'tts': {'ipa': ipa},
      if (hold && viseme != null) 'holdViseme': viseme,
      'holdMs': 500,
      if (hold && gains.isNotEmpty) 'boost': {'gains': gains, 'start': 0, 'end': 30},
    };
  }

  // -------------------------
  // Stages 1 and 5: the whole word, scored by Azure
  // -------------------------

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
      if (!mounted) return;
      _stage == _Stage.word ? _scoredFirst(score) : _scoredAgain(score);
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

  void _scoredFirst(PAResult azure) {
    final score = withWordSounds(azure, _word.phonemes);
    final passed = score.accuracyScore >= _passScore;
    setState(() {
      _firstScore = score;
      if (passed) _celebrations++;
    });
    if (passed) {
      AppHaptics.success();
      _services.speak('You said ${_word.text}!');
      return;
    }
    final worst = findTroublePhoneme(score, passScore: _passScore);
    if (worst == null) {
      _services.speak("I couldn't hear that. Let's try again.");
      return;
    }
    _startSound(worst);
  }

  void _retryFirst() => setState(() => _firstScore = null);

  // -------------------------
  // Stages 2 and 3: the trouble sound, checked by the camera and lip model
  // -------------------------

  Future<void> _startSound(PhonemeAssessment target) async {
    final around = neighbors(_firstScore!, target);
    final prompt = soundPromptFor(target.phoneme, before: around.before, after: around.after);
    setState(() {
      _stage = _Stage.sound;
      _stars
        ..clear()
        ..add(_kindFor(_firstScore!.accuracyScore));
      _target = target;
      _targetIndex = _scored.indexOf(target).clamp(0, _phonemes.length - 1);
      _prompt = prompt;
      _lipModel = PhonemeQualityModel.hasModelFor(target.phoneme);
      _lastCheck = null;
      _note = null;
      _soundDone = false;
    });
    _services.speak("Let's practice this a bit more! Can you say /${prompt.ipa}/ in ${_word.text}?");
    if (_lipModel) {
      try {
        await _services.loadLipModel(target.phoneme);
      } catch (e) {
        debugPrint('lip model error: $e');
      }
    }
    _prepareCoach();
  }

  /// Whether this try is checked by the camera: the trouble sound has a lip model.
  bool get _checksLips => _lipModel;

  Future<void> _toggleSoundMic() async {
    if (!_listening) {
      await _services.stopSpeaking();
      if (_checksLips) await _services.startLipCapture();
      if (mounted) {
        setState(() {
          _listening = true;
          _note = null;
        });
      }
      return;
    }
    setState(() => _listening = false);
    if (!_checksLips) {
      _tried(passed: true, checked: false);
      return;
    }
    final check = await _services.stopLipCapture();
    if (!mounted) return;
    if (check == null || !check.heard) {
      final note = check == null
          ? "I couldn't see your mouth. Keep your face in the camera and try again."
          : "I couldn't hear you. Say it a little louder.";
      setState(() => _note = note);
      _services.speak(note);
      return;
    }
    setState(() => _lastCheck = check);
    _tried(passed: check.passed, checked: true);
  }

  void _tried({required bool passed, required bool checked}) {
    switch (_stage) {
      case _Stage.sound:
        if (passed && checked) {
          _soundPassed();
        } else {
          // a miss, or a sound the camera can't check: the coach shows it
          setState(() {
            _stage = _Stage.coach;
            _stars.add(FeedbackKind.almost);
          });
          _tipThenDemo(checked
              ? _lastCheck!.tip
              : (isTongueSound(_target!.phoneme)
                  ? 'This sound is made with your tongue. Watch your coach closely.'
                  : 'Watch your coach closely.'));
        }
      case _Stage.coach:
        passed ? _soundPassed() : _tipThenDemo(_lastCheck!.tip);
      case _Stage.word:
      case _Stage.build:
      case _Stage.check:
        break;
    }
  }

  void _soundPassed() {
    setState(() {
      // right in stage 2 straight away: stage 3 isn't needed
      if (_stage == _Stage.sound) _stars.add(FeedbackKind.success);
      _stars.add(FeedbackKind.success);
      _soundDone = true;
      _celebrations++;
    });
    AppHaptics.success();
    _services.speak("You got it! Let's put it all together now.");
  }

  /// Demo: show stage 3 even though stage 2 was right.
  void _coachAnyway() {
    setState(() {
      _stage = _Stage.coach;
      _stars.removeLast();
      _soundDone = false;
    });
    _tipThenDemo('Watch how your coach makes it.');
  }

  // -------------------------
  // Stage 4: one sound at a time
  // -------------------------

  bool get _builtBefore => context.read<AppState>().hasBuiltUp(_word.text);

  Future<void> _startBuild() async {
    setState(() {
      _stage = _Stage.build;
      _built = false;
      _follow = null;
      _followError = null;
      _lastCheck = null;
      _note = null;
    });
    try {
      final matcher = await _services.loadMatcher();
      final steps = await _services.followSteps(_word.text);
      if (matcher == null) throw StateError("the golden data didn't load");
      if (steps.isEmpty) throw StateError('no sounds for "${_word.text}"');
      if (!await _services.startMouthTracking(_onMouthFrame)) throw StateError('no camera');
      if (!mounted) return;
      final coach = _coachReady ? _coachKey.currentState : null;
      final session = FollowAlongSession(matcher: matcher, steps: steps, useAvatar: coach != null)
        ..addListener(_onFollowChanged);
      setState(() => _follow = session);
      session.start();
      coach?.sayStepwise(_word.text, [for (final s in steps) s.pauseAtSeconds]);
    } catch (e) {
      debugPrint('stage 4: $e');
      await _stopFollow();
      if (mounted) setState(() => _followError = "Sound-by-sound practice couldn't start.");
    }
  }

  /// Rebuilds when the sound or phase changes; the meter listens for the score itself.
  void _onFollowChanged() {
    final session = _follow;
    if (session == null || !mounted) return;
    if (session.index != _followIndex || session.phase != _followPhase) {
      _followIndex = session.index;
      _followPhase = session.phase;
      setState(() {});
    }
    if (session.phase == FollowPhase.done && !_built) _finishBuild();
  }

  void _onMouthFrame(MouthFrame? frame) {
    final session = _follow;
    if (session == null || frame == null || !mounted) return;
    if (session.addFrame(frame)) {
      AppHaptics.success();
      _greenTimer = Timer(const Duration(milliseconds: 600), _followNext);
    }
  }

  /// After the green moment: the coach goes on to the next sound (or it starts right away).
  void _followNext() {
    final session = _follow;
    if (session == null || !mounted) return;
    session.advance();
    if (session.useAvatar && session.phase == FollowPhase.coach) _coachKey.currentState?.resumeStep();
  }

  /// Demo: move on without a match.
  void _skipSound() {
    final session = _follow;
    if (session == null || session.phase != FollowPhase.waiting) return;
    session.manualPass();
    _followNext();
  }

  Future<void> _stopFollow() async {
    _greenTimer?.cancel();
    await _services.stopMouthTracking();
  }

  void _finishBuild() {
    _stopFollow();
    context.read<AppState>().markBuiltUp(_word.text);
    setState(() {
      _built = true;
      _stars.add(FeedbackKind.success);
      _celebrations++;
    });
    AppHaptics.success();
    _services.speak("Now let's say the whole word!");
  }

  // -------------------------
  // Stage 5: the whole word again
  // -------------------------

  void _startAgain({bool skippedBuild = false}) {
    setState(() {
      _stage = _Stage.check;
      // seen this word before: no need to break it down again
      if (skippedBuild) _stars.add(FeedbackKind.success);
    });
    _services.speak('Now say ${_word.text}, all by yourself.');
  }

  void _scoredAgain(PAResult score) {
    final passed = score.accuracyScore >= _passScore;
    setState(() {
      _finalScore = score;
      _stars.add(passed ? FeedbackKind.success : FeedbackKind.focus);
      if (passed) _celebrations++;
    });
    if (passed) AppHaptics.success();
    _services.speak(passed
        ? 'You did it! You said ${_word.text}!'
        : "Good work. We'll practice ${_word.text} again next time.");
  }

  void _retryAgain() => setState(() {
        _finalScore = null;
        _stars.removeLast();
      });

  /// On to the next queued word. [later] keeps this one in the queue, at the back.
  void _nextWord({bool later = false}) {
    final queue = context.read<PracticeQueue>();
    if (queue.contains(_word.text)) queue.remove(_word.id);
    if (later) queue.addAll([_word]);
    final next = queue.items.where((w) => w.text != _word.text).firstOrNull;
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
        if (_practicing) AttemptDots(total: _stageLabels.length, results: _stars),
      ],
    );

    // the letters to highlight: the trouble sound, or in stage 4 the sound being said
    final (int, int)? highlight = switch (_stage) {
      _Stage.sound || _Stage.coach => lettersFor(_word.text, _phonemes.length, _targetIndex),
      _Stage.build => _built || _follow?.current == null
          ? null
          : lettersFor(_word.text, _follow!.steps.length, _follow!.index),
      _Stage.word || _Stage.check => null,
    };

    final coach = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // the picture goes with the whole word (stages 1 and 5); while working on the sound
        // the highlighted letters are enough, and the mic stays on screen
        if (_stage == _Stage.word || _stage == _Stage.check) ...[
          Center(child: WordPicture(word: _word.text, size: 120)),
          const SizedBox(height: AppSpace.s),
        ],
        _HighlightedWord(word: _word.text, highlight: highlight),
        if (_firstScore != null) ...[
          const SizedBox(height: AppSpace.s),
          _SoundRow(
            phonemes: _phonemes,
            focus: _practicing ? _targetIndex : null,
            results: [
              for (final p in _scored)
                PhonemeResult(p.phoneme, SoundLevel.fromScore(p.accuracyScore / 100).kind),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.l),
        AnimatedSwitcher(duration: AppMotion.medium, child: _stageCard()),
      ],
    );

    final stage = _AvatarStage(
      coach: _coachView(),
      // the coach only shows in stages 3 and 4; otherwise the porthole has the beluga,
      // with the coach loaded behind it
      coachShown: _stage == _Stage.coach || (_stage == _Stage.build && !_built),
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
      // the stages, along the bottom once the word has been missed
      bottomNavigationBar: _practicing
          ? DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.lakeDeep, width: 2.5)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.s, AppSpace.page, AppSpace.s),
                  // only as tall as the steps (the bar would otherwise stretch to fill)
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [StepperBar(steps: _stageLabels, current: _stage.index)],
                  ),
                ),
              ),
            )
          : null,
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

  Widget _stageCard() => switch (_stage) {
        _Stage.word => _wordCard(),
        _Stage.sound || _Stage.coach => _soundCard(),
        _Stage.build => _buildCard(),
        _Stage.check => _againCard(),
      };

  Widget _mic(VoidCallback onPressed) => Center(
        child: MicButton(listening: _listening, onPressed: _scoring ? null : onPressed),
      );

  String? _listeningText({String? idle}) => _scoring
      ? 'Checking…'
      : (_listening ? 'Listening… tap again when you\'re done.' : idle);

  Widget _wordCard() {
    final score = _firstScore;
    if (score == null) {
      return _StepCard(
        key: const ValueKey('word'),
        instruction: _listeningText(idle: 'Tap the mic and say "${_word.text}".'),
        children: [
          _mic(_toggleWordMic),
          const SizedBox(height: AppSpace.m),
          SecondaryButton(
            label: 'Hear it',
            icon: Icons.volume_up_rounded,
            expand: true,
            onPressed: _listening ? null : () => _services.speak(_word.text),
          ),
        ],
      );
    }
    final passed = score.accuracyScore >= _passScore;
    final weakest = findTroublePhoneme(score, passScore: _passScore);
    return _StepCard(
      key: const ValueKey('word-done'),
      children: [
        FeedbackBanner(
          kind: passed ? FeedbackKind.success : FeedbackKind.focus,
          message: passed ? 'You said "${_word.text}"!' : "I couldn't hear that clearly.",
        ),
        const SizedBox(height: AppSpace.l),
        if (passed) ...[
          PrimaryButton(
            label: 'Next word',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            onPressed: _nextWord,
          ),
          if (weakest != null)
            // demo: walk through the stages even when the word was right
            TextButton(
              onPressed: () => _startSound(weakest),
              child: const Text('Practice it anyway'),
            ),
        ] else
          PrimaryButton(
            label: 'Try again',
            icon: Icons.replay_rounded,
            expand: true,
            onPressed: _retryFirst,
          ),
      ],
    );
  }

  Widget _soundCard() {
    final prompt = _prompt!;
    final check = _lastCheck;
    final note = _note;
    final coachStage = _stage == _Stage.coach;
    if (_soundDone) {
      final builtBefore = _builtBefore;
      return _StepCard(
        key: const ValueKey('sound-done'),
        children: [
          const FeedbackBanner(
            kind: FeedbackKind.success,
            message: "You got it! Let's put it all together now.",
          ),
          const SizedBox(height: AppSpace.l),
          PrimaryButton(
            label: builtBefore ? 'Say the whole word' : 'Put it together',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            onPressed: builtBefore ? () => _startAgain(skippedBuild: true) : _startBuild,
          ),
          if (!coachStage)
            TextButton(onPressed: _coachAnyway, child: const Text('Watch the coach anyway')),
        ],
      );
    }
    return _StepCard(
      key: ValueKey(_stage),
      instruction: _listeningText(
        idle: coachStage ? 'Watch your coach, then say "${prompt.text}".' : null,
      ),
      children: [
        if (note != null)
          FeedbackBanner(kind: FeedbackKind.focus, message: note)
        else if (check != null) ...[
          FeedbackBanner(kind: FeedbackKind.almost, message: check.tip),
          if (check.frames > 0) ...[
            const SizedBox(height: AppSpace.s),
            Text('The camera saw the right lip shape in ${check.correctFrames} of ${check.frames} frames.',
                style: AppText.caption),
          ],
        ] else if (!coachStage)
          FeedbackBanner(
            kind: FeedbackKind.almost,
            message: "Let's practice this a bit more! Can you say \"${prompt.text}\" in ${_word.text}?",
          ),
        if (!_lipModel) ...[
          const SizedBox(height: AppSpace.s),
          Text("This sound is made with your tongue, so the camera can't check it yet.",
              style: AppText.caption),
        ],
        const SizedBox(height: AppSpace.l),
        _mic(_toggleSoundMic),
        if (coachStage) ...[
          const SizedBox(height: AppSpace.l),
          SecondaryButton(
            label: 'Watch again',
            icon: Icons.replay_rounded,
            expand: true,
            onPressed: _listening ? null : _demonstrate,
          ),
        ],
      ],
    );
  }

  Widget _buildCard() {
    if (_built) {
      return _StepCard(
        key: const ValueKey('built'),
        children: [
          const FeedbackBanner(kind: FeedbackKind.success, message: "Now let's say the whole word!"),
          const SizedBox(height: AppSpace.l),
          PrimaryButton(
            label: 'Say the whole word',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            onPressed: _startAgain,
          ),
        ],
      );
    }
    final error = _followError;
    if (error != null) {
      return _StepCard(
        key: const ValueKey('build-error'),
        children: [
          FeedbackBanner(kind: FeedbackKind.focus, message: error),
          const SizedBox(height: AppSpace.l),
          PrimaryButton(
            label: 'Say the whole word',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            onPressed: () => _startAgain(skippedBuild: true),
          ),
        ],
      );
    }
    final session = _follow;
    if (session == null) {
      return const _StepCard(
        key: ValueKey('build-loading'),
        instruction: 'Getting ready…',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final step = session.current;
    final sound = step == null ? '' : soundPromptFor(step.phoneme).text;
    return _StepCard(
      key: const ValueKey('build'),
      instruction: switch (session.phase) {
        FollowPhase.idle || FollowPhase.coach => 'Watch your coach say each sound.',
        FollowPhase.waiting => 'Now you: say "$sound" like your coach.',
        FollowPhase.passed => 'Great!',
        FollowPhase.done => null,
      },
      children: [
        _SoundSteps(
          labels: [for (final s in session.steps) soundPromptFor(s.phoneme).text],
          current: session.index,
        ),
        const SizedBox(height: AppSpace.l),
        // the live meter: how close the child's mouth movement is to the sound's
        ListenableBuilder(
          listenable: session,
          builder: (context, _) => _MatchMeter(
            score: session.score,
            threshold: session.threshold,
            passed: session.phase == FollowPhase.passed,
          ),
        ),
        TextButton(
          onPressed: session.phase == FollowPhase.waiting ? _skipSound : null,
          child: const Text('Skip this sound'),
        ),
      ],
    );
  }

  Widget _againCard() {
    final score = _finalScore;
    if (score == null) {
      return _StepCard(
        key: const ValueKey('again'),
        instruction: _listeningText(idle: 'Now say "${_word.text}", all by yourself.'),
        children: [_mic(_toggleWordMic)],
      );
    }
    final passed = score.accuracyScore >= _passScore;
    return _StepCard(
      key: const ValueKey('again-done'),
      children: [
        FeedbackBanner(
          kind: passed ? FeedbackKind.success : FeedbackKind.focus,
          message: passed
              ? 'You said "${_word.text}"!'
              : 'Good work! We\'ll practice "${_word.text}" again next time.',
        ),
        if (_firstScore case final first?) ...[
          const SizedBox(height: AppSpace.m),
          _ScoreCompare(first: first.accuracyScore, last: score.accuracyScore),
        ],
        const SizedBox(height: AppSpace.l),
        PrimaryButton(
          label: 'Next word',
          icon: Icons.arrow_forward_rounded,
          expand: true,
          onPressed: () => _nextWord(later: !passed),
        ),
        if (!passed) ...[
          const SizedBox(height: AppSpace.s),
          SecondaryButton(label: 'Try again', expand: true, onPressed: _retryAgain),
        ],
      ],
    );
  }
}

/// The word, with the letters of one sound picked out in lotus pink.
class _HighlightedWord extends StatelessWidget {
  const _HighlightedWord({required this.word, this.highlight});

  final String word;
  final (int, int)? highlight;

  @override
  Widget build(BuildContext context) {
    final h = highlight;
    if (h == null) return Text(word, style: AppText.wordHero, textAlign: TextAlign.center);
    final (start, end) = h;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: word.substring(0, start)),
        TextSpan(
          text: word.substring(start, end),
          style: const TextStyle(
            color: AppColors.lotus,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.lotus,
            decorationThickness: 3,
          ),
        ),
        TextSpan(text: word.substring(end)),
      ]),
      style: AppText.wordHero,
      textAlign: TextAlign.center,
    );
  }
}

/// Stage 4's sounds in order: done ones checked, the current one highlighted.
class _SoundSteps extends StatelessWidget {
  const _SoundSteps({required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      children: [
        for (var i = 0; i < labels.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: AppSpace.s),
            decoration: BoxDecoration(
              color: i < current
                  ? AppColors.successSoft
                  : (i == current ? AppColors.lotusBlush : AppColors.surface),
              borderRadius: AppRadius.pillRadius,
              border: Border.all(
                color: i == current ? AppColors.lotus : AppColors.line,
                width: 2.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i < current) ...[
                  const Icon(Icons.check_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: AppSpace.xs),
                ],
                Text(labels[i],
                    style: AppText.section.copyWith(
                        color: i == current ? AppColors.lotusDeep : AppColors.ink)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Stage 4's live meter: how closely the child's mouth movement matches the sound, with a
/// mark where it passes.
class _MatchMeter extends StatelessWidget {
  const _MatchMeter({required this.score, required this.threshold, required this.passed});

  final double score;
  final double threshold;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final value = passed ? 1.0 : score.clamp(0.0, 1.0);
    final color = passed || score >= threshold ? AppColors.success : AppColors.lake;
    return Semantics(
      label: passed ? 'Matched' : 'Match ${(value * 100).round()} percent',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.lakeMist,
                borderRadius: AppRadius.pillRadius,
                border: Border.all(color: AppColors.lakeDeep, width: 2),
              ),
            ),
            AnimatedContainer(
              duration: AppMotion.fast,
              height: 24,
              width: box.maxWidth * value,
              decoration: BoxDecoration(color: color, borderRadius: AppRadius.pillRadius),
            ),
            // where it passes
            Positioned(
              left: box.maxWidth * threshold - 2,
              top: -4,
              bottom: -4,
              child: Container(width: 4, color: AppColors.lotusDeep),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stage 1's Azure score next to stage 5's.
class _ScoreCompare extends StatelessWidget {
  const _ScoreCompare({required this.first, required this.last});

  final double first;
  final double last;

  @override
  Widget build(BuildContext context) {
    Widget score(String label, double value, Color color) => Column(
          children: [
            Text(value.toStringAsFixed(0), style: AppText.display.copyWith(color: color)),
            Text(label, style: AppText.caption),
          ],
        );
    return Semantics(
      container: true,
      label: 'First try ${first.round()}, now ${last.round()}',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          score('First try', first, AppColors.inkSoft),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.l),
            child: Icon(Icons.arrow_forward_rounded, color: AppColors.lake, size: 32),
          ),
          score('Now', last, last >= first ? AppColors.success : AppColors.almost),
        ],
      ),
    );
  }
}

/// The coach, with the child's camera beside it.
class _AvatarStage extends StatelessWidget {
  const _AvatarStage({
    required this.coach,
    required this.coachShown,
    this.camera,
    this.vertical = false,
  });

  final Widget coach;

  /// Otherwise the porthole shows the beluga, with the coach loaded behind it.
  final bool coachShown;
  final Widget? camera;

  /// Stack the camera under the coach (the tall stage on wide screens).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final camera = this.camera;
    final window = Stack(
      children: [
        Positioned.fill(child: coach),
        if (!coachShown)
          const Positioned.fill(
            child: ColoredBox(
              color: AppColors.lakeMist,
              child: FittedBox(child: BelugaBuddy(size: 160)),
            ),
          ),
      ],
    );
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
          ? Center(child: Porthole(child: window))
          : Flex(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              children: [
                Expanded(child: Center(child: Porthole(child: window))),
                const SizedBox(width: AppSpace.s, height: AppSpace.s),
                Expanded(child: camera),
              ],
            ),
    );
  }
}

/// The word's sounds as bubbles, colored by stage 1's scores, the trouble one picked out.
class _SoundRow extends StatelessWidget {
  const _SoundRow({required this.phonemes, required this.focus, required this.results});

  final List<String> phonemes;
  final int? focus;
  final List<PhonemeResult> results;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      children: [
        for (var i = 0; i < phonemes.length; i++)
          SoundChip(
            phoneme: phonemes[i],
            kind: i < results.length ? results[i].kind : null,
            selected: focus == i,
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
