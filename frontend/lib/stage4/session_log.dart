import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'follow_along.dart';
import 'golden_store.dart';
import 'mouth_features.dart';
import 'mouth_matcher.dart';

/// Debug recording of a stage 4 run: every camera frame with what the matcher saw, plus events,
/// on the tracker's clock. Exported as JSON for offline analysis.
class Stage4SessionLog {
  Stage4SessionLog({
    required this.word,
    required this.steps,
    required this.useAvatar,
    required this.threshold,
    required this.windowMs,
    required this.config,
  }) : startedAt = DateTime.now();

  final DateTime startedAt;
  final String word;
  final List<FollowStep> steps;
  final bool useAvatar;
  final double threshold;
  final int windowMs;
  final MatcherConfig config;
  final List<Map<String, dynamic>> _events = [];
  final List<Map<String, dynamic>> _frames = [];

  int get frameCount => _frames.length;

  void event(int t, String type, {int? index}) =>
      _events.add({'t': t, 'type': type, 'index': ?index});

  /// [frame] null when no face was found.
  void frame(int t, MouthFrame? frame, FollowAlongSession session) {
    _frames.add({
      't': frame?.t ?? t,
      'phase': session.phase.name,
      'index': session.index,
      'score': double.parse(session.score.toStringAsFixed(4)),
      if (frame != null) ...frame.toJson()..remove('t'),
    });
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'startedAt': startedAt.toIso8601String(),
        'word': word,
        'steps': [
          for (final s in steps)
            {'phoneme': s.phoneme, 'offsetMs': s.offsetMs, 'durationMs': s.durationMs},
        ],
        'useAvatar': useAvatar,
        'threshold': threshold,
        'windowMs': windowMs,
        'config': {
          'smoothWindow': config.smoothWindow,
          'velocityWeight': config.velocityWeight,
          'trimFraction': config.trimFraction,
          'sigmaPercentile': config.sigmaPercentile,
          'minMotionRatio': config.minMotionRatio,
        },
        'features': featureNames,
        'events': _events,
        'frames': _frames,
      };

  /// Writes the log to a temporary file for the share sheet.
  Future<File> writeFile() async {
    final stamp = startedAt.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File(p.join((await getTemporaryDirectory()).path, 'stage4_${word}_$stamp.json'));
    await file.writeAsString(jsonEncode(toJson()));
    return file;
  }
}
