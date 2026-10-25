import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../avatar_view.dart';
import '../../stage4/follow_along.dart';
import '../../stage4/golden_store.dart';
import '../../stage4/mouth_matcher.dart';
import '../../stage4/mouth_tracker.dart';
import '../../stage4/trajectory_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// avatar-web dev server, e.g. through a tunnel:
//   flutter run --dart-define=AVATAR_URL=https://<tunnel>.trycloudflare.com
const _avatarUrl = String.fromEnvironment('AVATAR_URL', defaultValue: 'http://localhost:5173');
const _avatarConfigured = bool.hasEnvironment('AVATAR_URL');

/// Stage 4 test screen: the avatar says a word sound by sound and waits; the learner copies
/// each sound until their mouth movement matches the golden data.
class Stage4Screen extends StatefulWidget {
  const Stage4Screen({super.key});

  @override
  State<Stage4Screen> createState() => _Stage4ScreenState();
}

class _Stage4ScreenState extends State<Stage4Screen> {
  static const _greenPause = Duration(milliseconds: 600);

  final _word = TextEditingController(text: 'boot');
  final MouthTracker _tracker = MouthTracker();
  final _avatarKey = GlobalKey<AvatarViewState>();

  bool? _cameraReady;
  bool _useAvatar = _avatarConfigured;
  bool _avatarReady = false;
  double _threshold = 0.5;
  String? _status;
  bool _loadingSteps = false;

  MouthMatcher? _matcher;
  Map<String, List<List<List<double>>>>? _golden;
  FollowAlongSession? _session;
  Timer? _greenTimer;

  @override
  void initState() {
    super.initState();
    _loadGolden();
    _tracker.onFrame = _onFrame;
    _tracker.start().then((ok) {
      if (mounted) setState(() => _cameraReady = ok);
    });
  }

  @override
  void dispose() {
    _greenTimer?.cancel();
    _session?.dispose();
    _tracker.dispose();
    _word.dispose();
    super.dispose();
  }

  Future<void> _loadGolden() async {
    try {
      final json = await rootBundle.loadString(goldenAsset);
      final golden = await compute(parseGoldenFeatures, json);
      final matcher = await compute(buildMatcher, golden);
      if (!mounted) return;
      setState(() {
        _golden = golden;
        _matcher = matcher;
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not load golden data: $e');
    }
  }

  void _onFrame(MouthFrame? frame) {
    final session = _session;
    if (frame == null || session == null || !mounted) return;
    if (session.addFrame(frame)) {
      AppHaptics.success();
      setState(() => _status = 'Great!');
      _greenTimer = Timer(_greenPause, _advance);
    }
  }

  void _advance() {
    final session = _session;
    if (session == null) return;
    session.advance();
    if (session.useAvatar && session.phase == FollowPhase.coach) {
      _avatarKey.currentState?.controller.runJavaScript('window.resumeStep();');
    }
    _updateStatus();
  }

  Future<void> _start() async {
    final matcher = _matcher;
    final word = _word.text.trim().toLowerCase();
    if (matcher == null || word.isEmpty) return;
    FocusScope.of(context).unfocus();
    _greenTimer?.cancel();
    setState(() {
      _loadingSteps = true;
      _status = 'Getting the sounds in "$word"…';
    });
    try {
      final steps = await fetchFollowSteps(word);
      if (steps.isEmpty) throw Exception('No sounds found for "$word"');
      final session = FollowAlongSession(
        matcher: matcher,
        steps: steps,
        useAvatar: _useAvatar,
        threshold: _threshold,
      )..addListener(() => setState(() {}));
      _session?.dispose();
      setState(() => _session = session);
      session.start();
      if (_useAvatar) {
        final pauses = jsonEncode([for (final s in steps) s.pauseAtSeconds]);
        await _avatarKey.currentState?.controller
            .runJavaScript('window.sayStepwise(${jsonEncode(word)}, $pauses);');
      }
      _updateStatus();
    } catch (e) {
      setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _loadingSteps = false);
    }
  }

  void _onAvatarMessage(String message) {
    final m = jsonDecode(message) as Map<String, dynamic>;
    switch (m['event']) {
      case 'ready':
        setState(() => _avatarReady = true);
      case 'paused':
        _session?.coachPaused(m['index'] as int);
        _updateStatus();
      case 'finished':
        _session?.coachFinished();
        _updateStatus();
      case 'error':
        setState(() => _status = 'Avatar: ${m['message']}');
    }
  }

  void _updateStatus() {
    final s = _session;
    if (s == null || !mounted) return;
    setState(() {
      _status = switch (s.phase) {
        FollowPhase.idle => null,
        FollowPhase.coach => 'Watch the coach…',
        FollowPhase.waiting => 'Your turn: say /${s.current!.phoneme}/ like the coach.',
        FollowPhase.passed => 'Great!',
        FollowPhase.done => 'All sounds done!',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final running = session != null &&
        session.phase != FollowPhase.idle &&
        session.phase != FollowPhase.done;
    final step = session?.current;
    final boxColor = switch (session?.phase) {
      FollowPhase.waiting => AppColors.almost,
      FollowPhase.passed => AppColors.success,
      _ => Colors.transparent,
    };

    return AppPage(
      title: 'Stage 4: follow along',
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _word,
                enabled: !running,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _start(),
                decoration: const InputDecoration(labelText: 'Word'),
              ),
            ),
            const SizedBox(width: AppSpace.m),
            PrimaryButton(
              label: running ? 'Restart' : 'Start',
              icon: Icons.play_arrow_rounded,
              onPressed: _matcher == null || _loadingSteps || _cameraReady != true ? null : _start,
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Use avatar', style: AppText.bodyStrong),
          subtitle: Text(
            _useAvatar
                ? (_avatarReady ? 'Avatar ready' : 'Loading avatar from $_avatarUrl')
                : 'Step through the sounds without the avatar',
            style: AppText.caption,
          ),
          value: _useAvatar,
          onChanged: running ? null : (v) => setState(() => _useAvatar = v),
        ),
        const SizedBox(height: AppSpace.s),
        _stage(step, boxColor),
        const SizedBox(height: AppSpace.m),
        if (_status != null)
          Text(_status!, style: AppText.section, textAlign: TextAlign.center),
        if (session != null) ...[
          const SizedBox(height: AppSpace.m),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.s,
            runSpacing: AppSpace.s,
            children: [
              for (var i = 0; i < session.steps.length; i++)
                SoundChip(
                  phoneme: session.steps[i].phoneme,
                  kind: i < session.index ||
                          (i == session.index && session.phase == FollowPhase.passed) ||
                          session.phase == FollowPhase.done
                      ? FeedbackKind.success
                      : (i == session.index ? FeedbackKind.almost : null),
                  selected: i == session.index && session.phase == FollowPhase.waiting,
                ),
            ],
          ),
        ],
        const SectionHeader(title: 'Tuning'),
        _ScoreBar(score: session?.score ?? 0, threshold: _threshold),
        Slider(
          value: _threshold,
          min: 0.1,
          max: 0.95,
          divisions: 17,
          label: _threshold.toStringAsFixed(2),
          onChanged: (v) => setState(() {
            _threshold = v;
            session?.threshold = v;
          }),
        ),
        if (_matcher == null)
          const Center(child: CircularProgressIndicator())
        else if (step != null && session != null) ...[
          Text('You (last 1.5 s)', style: AppText.caption),
          const SizedBox(height: AppSpace.xs),
          TrajectoryChart(series: session.windowFeatures),
          const SizedBox(height: AppSpace.s),
          Text('Golden /${step.phoneme}/ (take 1)', style: AppText.caption),
          const SizedBox(height: AppSpace.xs),
          TrajectoryChart(series: _golden?[step.phoneme]?.first ?? const []),
          const SizedBox(height: AppSpace.s),
          const FeatureLegend(),
        ],
      ],
    );
  }

  Widget _stage(FollowStep? step, Color boxColor) {
    final controller = _tracker.controller;
    return AnimatedContainer(
      duration: AppMotion.fast,
      height: 340,
      decoration: BoxDecoration(
        gradient: AppGradients.stage,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: boxColor, width: 6),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card - 6)),
        child: Stack(
          children: [
            Positioned.fill(
              child: _useAvatar
                  ? AvatarView(
                      key: _avatarKey,
                      url: '$_avatarUrl/?embed=1&frame=0,0,1,1',
                      onMessage: _onAvatarMessage,
                    )
                  : Center(
                      child: Text(step == null ? 'Ready' : '/${step.phoneme}/',
                          style: AppText.wordHero),
                    ),
            ),
            Positioned(
              right: AppSpace.s,
              bottom: AppSpace.s,
              width: 96,
              height: 128,
              child: ClipRRect(
                borderRadius: AppRadius.chipRadius,
                child: switch (_cameraReady) {
                  true when controller != null => CameraPreview(controller),
                  false => const ColoredBox(
                      color: AppColors.lakeMist,
                      child: Center(child: Icon(Icons.videocam_off_rounded)),
                    ),
                  _ => const ColoredBox(color: AppColors.lakeMist),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live score with the threshold marked.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score, required this.threshold});

  final double score;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final passing = score >= threshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: AppRadius.pillRadius,
                child: LinearProgressIndicator(
                  value: score.clamp(0, 1),
                  minHeight: 16,
                  color: passing ? AppColors.success : AppColors.almost,
                  backgroundColor: AppColors.lakeMist,
                ),
              ),
              Positioned(
                left: constraints.maxWidth * threshold - 1,
                top: -4,
                bottom: -4,
                child: Container(width: 2, color: AppColors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          'score ${score.toStringAsFixed(2)} · threshold ${threshold.toStringAsFixed(2)}',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
