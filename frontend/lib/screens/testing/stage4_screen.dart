import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';

import '../../avatar_view.dart';
import '../../stage4/follow_along.dart';
import '../../stage4/golden_store.dart';
import '../../stage4/mouth_matcher.dart';
import '../../stage4/mouth_tracker.dart';
import '../../stage4/session_log.dart';
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
  double _windowSeconds = 0.75;
  String? _status;
  bool _loadingSteps = false;

  /// Debug recording: no auto-pass; "Next sound" moves on and everything is logged.
  bool _manual = false;
  Stage4SessionLog? _log;

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
    if (session == null || !mounted) return;
    if (frame != null && session.addFrame(frame)) {
      AppHaptics.success();
      setState(() => _status = 'Great!');
      _greenTimer = Timer(_greenPause, _advance);
    }
    // log after scoring, so each frame carries the score it produced
    _log?.frame(_tracker.nowMs, frame, session);
  }

  /// Debug recording: the learner made the sound; move on.
  void _manualNext() {
    final session = _session;
    if (session == null || session.phase != FollowPhase.waiting) return;
    _log?.event(_tracker.nowMs, 'next', index: session.index);
    session.manualPass();
    _advance();
  }

  Future<void> _exportLog(BuildContext buttonContext) async {
    final log = _log;
    if (log == null) return;
    final file = await log.writeFile();
    if (!buttonContext.mounted) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'mirrorU stage 4 session: ${log.word}',
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  void _advance() {
    final session = _session;
    if (session == null) return;
    session.advance();
    _log?.event(_tracker.nowMs, session.phase.name, index: session.index);
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
        window: Duration(milliseconds: (_windowSeconds * 1000).round()),
        autoPass: !_manual,
      )..addListener(() => setState(() {}));
      _session?.dispose();
      setState(() {
        _session = session;
        _log = Stage4SessionLog(
          word: word,
          steps: steps,
          useAvatar: _useAvatar,
          threshold: _threshold,
          windowMs: (_windowSeconds * 1000).round(),
          config: matcher.config,
        );
      });
      session.start();
      _log!.event(_tracker.nowMs, 'start');
      _log!.event(_tracker.nowMs, session.phase.name, index: session.index);
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
        _log?.event(_tracker.nowMs, 'avatarPaused', index: m['index'] as int);
        _session?.coachPaused(m['index'] as int);
        _updateStatus();
      case 'finished':
        _log?.event(_tracker.nowMs, 'avatarFinished');
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
        FollowPhase.waiting => _manual
            ? 'Say /${s.current!.phoneme}/, then tap Next sound.'
            : 'Your turn: say /${s.current!.phoneme}/ like the coach.',
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Manual (record for debugging)', style: AppText.bodyStrong),
          subtitle: Text(
            "Sounds don't auto-pass; tap Next sound after each correct attempt. "
            'Every frame is logged for export.',
            style: AppText.caption,
          ),
          value: _manual,
          onChanged: running ? null : (v) => setState(() => _manual = v),
        ),
        const SizedBox(height: AppSpace.s),
        _stage(step, boxColor),
        const SizedBox(height: AppSpace.m),
        if (_status != null)
          Text(_status!, style: AppText.section, textAlign: TextAlign.center),
        if (_manual && session != null) ...[
          const SizedBox(height: AppSpace.m),
          PrimaryButton(
            label: 'Next sound',
            icon: Icons.skip_next_rounded,
            expand: true,
            onPressed: session.phase == FollowPhase.waiting ? _manualNext : null,
          ),
        ],
        if (_log != null) ...[
          const SizedBox(height: AppSpace.s),
          Builder(
            builder: (buttonContext) => SecondaryButton(
              label: 'Export session (${_log!.frameCount} frames)',
              icon: Icons.ios_share_rounded,
              expand: true,
              onPressed: () => _exportLog(buttonContext),
            ),
          ),
        ],
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
        Text('Window: last ${_windowSeconds.toStringAsFixed(2)} s', style: AppText.caption,
            textAlign: TextAlign.center),
        Slider(
          value: _windowSeconds,
          min: 0.5,
          max: 1.5,
          divisions: 8,
          label: '${_windowSeconds.toStringAsFixed(2)} s',
          onChanged: (v) => setState(() {
            _windowSeconds = v;
            session?.window = Duration(milliseconds: (v * 1000).round());
          }),
        ),
        if (_matcher == null)
          const Center(child: CircularProgressIndicator())
        else if (step != null && session != null)
          ..._charts(_matcher!, step.phoneme, session.windowFeatures),
      ],
    );
  }

  /// Both charts on the matcher's own scale (z-units, ±3), so stillness looks flat and the
  /// two are directly comparable. Golden shows the take that's actually closest.
  List<Widget> _charts(MouthMatcher matcher, String ipa, List<List<double>> window) {
    const lo = -3.0, hi = 3.0;
    final takes = _golden?[ipa] ?? const <List<List<double>>>[];
    final closest = matcher.closestTemplate(ipa, window);
    final shown = closest ?? 0;
    return [
      Text('You (last ${_windowSeconds.toStringAsFixed(2)} s)', style: AppText.caption),
      const SizedBox(height: AppSpace.xs),
      TrajectoryChart(series: matcher.normalized(window), min: lo, max: hi),
      const SizedBox(height: AppSpace.s),
      Text(
        takes.isEmpty
            ? 'No golden data for /$ipa/'
            : 'Golden /$ipa/: ${closest == null ? 'take 1' : 'closest take, ${shown + 1} of ${takes.length}'} '
                '(others faint)',
        style: AppText.caption,
      ),
      const SizedBox(height: AppSpace.xs),
      if (takes.isNotEmpty)
        TrajectoryChart(
          series: matcher.normalized(takes[shown]),
          faint: [
            for (var i = 0; i < takes.length; i++)
              if (i != shown) matcher.normalized(takes[i]),
          ],
          min: lo,
          max: hi,
        ),
      const SizedBox(height: AppSpace.s),
      Text('Scale: standard deviations from your golden average (0 = middle line).',
          style: AppText.caption),
      const SizedBox(height: AppSpace.xs),
      const FeatureLegend(),
    ];
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
