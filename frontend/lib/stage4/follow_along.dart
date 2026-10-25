import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../speech_services.dart';
import 'golden_store.dart';
import 'mouth_matcher.dart';

/// One sound of the word, and when the avatar says it.
class FollowStep {
  const FollowStep(this.phoneme, this.offsetMs, this.durationMs);

  final String phoneme;
  final double offsetMs;
  final double durationMs;

  /// Where the avatar stops for this sound: most of the way through it, so the mouth shape
  /// is showing.
  double get pauseAtSeconds => (offsetMs + 0.7 * durationMs) / 1000;
}

/// Test-only: the word's sounds with the avatar's timing, from the backend.
Future<List<FollowStep>> fetchFollowSteps(String word) async {
  final uri = Uri.parse('${SpeechServices.baseUrl}/api/stage4/phonemes')
      .replace(queryParameters: {'word': word});
  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw Exception('Could not get sounds for "$word": ${response.statusCode} ${response.body}');
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return [
    for (final p in json['phonemes'] as List)
      FollowStep(
        (p as Map<String, dynamic>)['phoneme'] as String,
        (p['offsetMs'] as num).toDouble(),
        (p['durationMs'] as num).toDouble(),
      ),
  ];
}

enum FollowPhase { idle, coach, waiting, passed, done }

/// Stage 4 state: the avatar says each sound and waits; the learner's mouth movement is scored
/// against that sound's golden data until it stays above the threshold.
class FollowAlongSession extends ChangeNotifier {
  FollowAlongSession({
    required this.matcher,
    required this.steps,
    required this.useAvatar,
    this.threshold = 0.5,
    this.window = const Duration(milliseconds: 750),
    this.hold = const Duration(milliseconds: 300),
    this.autoPass = true,
  });

  /// False for debug recording: scores are still computed, but only [manualPass] moves on.
  final bool autoPass;

  final MouthMatcher matcher;
  final List<FollowStep> steps;

  /// With the avatar, each sound starts when the avatar pauses on it; without, right away.
  final bool useAvatar;
  double threshold;

  /// How much recent movement is scored.
  Duration window;

  /// How long the score must stay above the threshold to pass.
  final Duration hold;

  FollowPhase phase = FollowPhase.idle;
  int index = 0;
  double score = 0;
  final List<MouthFrame> _frames = [];
  int? _aboveSince;
  int? _waitStartedAt;

  /// The current sound barely shows on the lips, so it passes after its usual duration
  /// instead of being matched; [score] shows progress toward that.
  bool get autoPassing => current != null && matcher.barelyVisible(current!.phoneme);

  FollowStep? get current => index < steps.length ? steps[index] : null;

  /// Frames in the scoring window for the current sound.
  List<List<double>> get windowFeatures => [for (final f in _frames) f.features];

  void start() {
    index = 0;
    if (useAvatar) {
      phase = FollowPhase.coach;
    } else {
      _wait(0);
    }
    notifyListeners();
  }

  /// The avatar stopped on sound [i].
  void coachPaused(int i) {
    if (i >= steps.length) return;
    _wait(i);
    notifyListeners();
  }

  /// The avatar finished the word.
  void coachFinished() {
    phase = FollowPhase.done;
    notifyListeners();
  }

  /// Feed every camera frame. Returns true when this frame completed the current sound.
  bool addFrame(MouthFrame frame) {
    if (phase != FollowPhase.waiting) return false;
    final step = current!;
    _frames
      ..add(frame)
      ..removeWhere((f) => frame.t - f.t > window.inMilliseconds);
    _waitStartedAt ??= frame.t;

    if (autoPassing) {
      final wait = matcher.typicalDuration(step.phoneme)!.inMilliseconds;
      final elapsed = frame.t - _waitStartedAt!;
      score = wait == 0 ? 1 : (elapsed / wait).clamp(0, 1);
      if (autoPass && elapsed >= wait) {
        phase = FollowPhase.passed;
        notifyListeners();
        return true;
      }
      notifyListeners();
      return false;
    }

    // a sound with no golden data can't be checked, so it passes
    score = matcher.hasPhoneme(step.phoneme) ? matcher.score(step.phoneme, windowFeatures) : 1;
    if (!autoPass) {
      notifyListeners();
      return false;
    }
    if (score >= threshold) {
      _aboveSince ??= frame.t;
      if (frame.t - _aboveSince! >= hold.inMilliseconds) {
        phase = FollowPhase.passed;
        notifyListeners();
        return true;
      }
    } else {
      _aboveSince = null;
    }
    notifyListeners();
    return false;
  }

  /// Debug recording: the learner says they made the sound; treat it as passed.
  void manualPass() {
    if (phase != FollowPhase.waiting) return;
    phase = FollowPhase.passed;
    notifyListeners();
  }

  /// After the green moment: on to the next sound (the avatar continues, or the next sound
  /// starts straight away), or done.
  void advance() {
    if (phase != FollowPhase.passed) return;
    final last = index == steps.length - 1;
    if (useAvatar) {
      // the avatar says the word up to its next pause (or to the end, then reports finished)
      phase = FollowPhase.coach;
      index++;
    } else if (last) {
      index = steps.length;
      phase = FollowPhase.done;
    } else {
      _wait(index + 1);
    }
    notifyListeners();
  }

  void _wait(int i) {
    index = i;
    phase = FollowPhase.waiting;
    score = 0;
    _frames.clear();
    _aboveSince = null;
    _waitStartedAt = null;
  }
}

/// For compute(): builds the matcher off the UI thread.
MouthMatcher buildMatcher(Map<String, List<List<List<double>>>> golden) =>
    MouthMatcher.fromTakes(golden);
