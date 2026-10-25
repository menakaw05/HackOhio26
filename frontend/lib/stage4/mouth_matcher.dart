import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'golden_store.dart';

const goldenAsset = 'assets/golden/golden_data.json';

/// Phoneme → takes → frames → features, from the golden JSON.
Map<String, List<List<List<double>>>> parseGoldenFeatures(String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  return {
    for (final e in (data['phonemes'] as Map<String, dynamic>).entries)
      e.key: [
        for (final take in e.value as List)
          [
            for (final f in (take as Map<String, dynamic>)['frames'] as List)
              [for (final v in (f as Map<String, dynamic>)['f'] as List) (v as num).toDouble()]
          ]
      ],
  };
}

MouthMatcher _buildFromJson(String json) => MouthMatcher.fromTakes(parseGoldenFeatures(json));

/// Stage 4 mouth-movement matching: is the learner's recent mouth movement similar to the
/// golden recordings of a sound?
///
/// Pipeline (all well-known time-series techniques):
/// 1. Smooth each feature with a short moving average (ML Kit points jitter frame to frame).
/// 2. Z-normalize every feature with statistics from all golden frames, so each counts equally.
/// 3. Append each frame's direction of movement (a derivative-DTW variant, after Keogh &
///    Pazzani 2001, using direction rather than raw velocity so slow movement still matches),
///    so the *movement* is compared and not just the mouth shape.
/// 4. Trim the still frames at the start and end of each golden take (templates).
/// 5. Subsequence DTW (Müller 2007): find the best-matching stretch of the live window for each
///    template, with the match length kept between half and triple the template length.
/// 6. Symmetric step weights normalized by both lengths, with a slope constraint (Sakoe & Chiba
///    1978), so slow attempts aren't penalized; use the closest template (1-nearest-neighbour).
/// 7. Similarity = exp(-ln2 · (d/σ)²), where σ for each sound comes from leave-one-out distances
///    among your own takes. A score of 0.5 means "as close as your own takes usually are".
/// 8. Motion gate: a window whose mouth path is much shorter than the sound's can't pass.
/// Tunable settings; defaults were picked with the held-out evaluation in
/// test/stage4_eval_test.dart.
class MatcherConfig {
  const MatcherConfig({
    this.smoothWindow = 5,
    this.velocityWeight = 1.0,
    this.trimFraction = 0.15,
    this.sigmaPercentile = 0.9,
    this.minMotionRatio = 0.3,
  });

  /// Moving-average width in frames.
  final int smoothWindow;

  /// How much movement (velocity) counts relative to mouth shape.
  final double velocityWeight;

  /// Golden frames under this share of the take's peak movement count as still and are trimmed.
  final double trimFraction;

  /// σ is the distance at this percentile of your own leave-one-out takes, so a score of 0.5
  /// means "as close as that share of your own takes".
  final double sigmaPercentile;

  /// A window with less than this share of the sound's usual movement scores 0.
  final double minMotionRatio;
}

class MouthMatcher {
  MouthMatcher._(this.config, this._mean, this._std, this._velStd, this._templates, this._sigma);

  static const _trimPad = 2;
  static const _restFrames = 3;

  final MatcherConfig config;

  final List<double> _mean;
  final List<double> _std;
  final List<double> _velStd;
  final Map<String, List<_Template>> _templates;
  final Map<String, double> _sigma;

  Iterable<String> get phonemes => _templates.keys;
  bool hasPhoneme(String ipa) => _templates.containsKey(ipa);
  double? sigmaFor(String ipa) => _sigma[ipa];

  /// Builds templates and per-sound σ from golden takes (phoneme → takes, each frames × features).
  factory MouthMatcher.fromTakes(Map<String, List<List<List<double>>>> takes,
      {MatcherConfig config = const MatcherConfig()}) {
    final all = [for (final t in takes.values) for (final take in t) ...take];
    if (all.isEmpty) throw ArgumentError('No golden frames');
    final dims = all.first.length;

    final mean = List.generate(dims, (d) => all.map((f) => f[d]).reduce((a, b) => a + b) / all.length);
    final std = List.generate(dims, (d) {
      final v = all.map((f) => math.pow(f[d] - mean[d], 2)).reduce((a, b) => a + b) / all.length;
      return math.max(math.sqrt(v), 1e-6);
    });

    // velocity scale, from smoothed + normalized golden takes
    final vels = <List<double>>[];
    for (final t in takes.values) {
      for (final take in t) {
        final z = _normalize(_smooth(take, config.smoothWindow), mean, std);
        vels.addAll(_velocity(z));
      }
    }
    final velStd = List.generate(dims, (d) {
      final v = vels.map((f) => f[d] * f[d]).reduce((a, b) => a + b) / math.max(vels.length, 1);
      return math.max(math.sqrt(v), 1e-6);
    });

    final matcher = MouthMatcher._(config, mean, std, velStd, {}, {});
    for (final e in takes.entries) {
      matcher._templates[e.key] = [
        for (final take in e.value) matcher._template(take),
      ];
    }
    for (final ipa in takes.keys) {
      matcher._sigma[ipa] = matcher._calibrate(ipa, takes[ipa]!);
    }
    return matcher;
  }

  /// Builds the matcher from the bundled golden data, off the UI thread.
  static Future<MouthMatcher> loadBundled() async =>
      compute(_buildFromJson, await rootBundle.loadString(goldenAsset));

  factory MouthMatcher.fromStore(Map<String, List<GoldenTake>> takes) => MouthMatcher.fromTakes({
        for (final e in takes.entries)
          e.key: [
            for (final t in e.value) [for (final f in t.frames) f.features]
          ],
      });

  /// Normalized DTW distance from [window] (recent frames × features) to the closest template
  /// of [ipa]. [exclude] skips one template (leave-one-out).
  double distance(String ipa, List<List<double>> window, {int? exclude}) {
    final templates = _templates[ipa];
    if (templates == null || window.length < 2) return double.infinity;
    final seq = _sequence(window);
    var best = double.infinity;
    for (var i = 0; i < templates.length; i++) {
      if (i == exclude) continue;
      best = math.min(best, _subsequenceDtw(templates[i].seq, seq));
    }
    return best;
  }

  /// 0–1 similarity of [window] to [ipa]; 0 when the window barely moves.
  double score(String ipa, List<List<double>> window, {int? exclude}) {
    final sigma = _sigma[ipa];
    final templates = _templates[ipa];
    if (sigma == null || templates == null) return 0;
    final motion = _motion(_sequence(window));
    final templateMotion = templates.map((t) => t.motion).reduce((a, b) => a + b) / templates.length;
    if (motion < config.minMotionRatio * templateMotion) return 0;
    final d = distance(ipa, window, exclude: exclude);
    return math.exp(-math.ln2 * math.pow(d / sigma, 2));
  }

  // --- preprocessing ---

  static List<List<double>> _smooth(List<List<double>> frames, int window) {
    final half = window ~/ 2;
    return [
      for (var i = 0; i < frames.length; i++)
        List.generate(frames[i].length, (d) {
          final lo = math.max(0, i - half);
          final hi = math.min(frames.length - 1, i + half);
          var sum = 0.0;
          for (var j = lo; j <= hi; j++) {
            sum += frames[j][d];
          }
          return sum / (hi - lo + 1);
        }),
    ];
  }

  static List<List<double>> _normalize(List<List<double>> frames, List<double> mean, List<double> std) =>
      [for (final f in frames) List.generate(f.length, (d) => (f[d] - mean[d]) / std[d])];

  /// Centered differences; ends use one-sided differences.
  static List<List<double>> _velocity(List<List<double>> z) => [
        for (var i = 0; i < z.length; i++)
          List.generate(z[i].length, (d) {
            final a = z[math.max(0, i - 1)][d];
            final b = z[math.min(z.length - 1, i + 1)][d];
            return (b - a) / ((math.min(z.length - 1, i + 1) - math.max(0, i - 1)).clamp(1, 2));
          }),
      ];

  /// Velocity smaller than this (in normalized units) is mostly jitter, so its direction is
  /// damped instead of blown up to full length.
  static const _stillSpeed = 1.0;

  /// Per frame: normalized features, then the *direction* of movement. Direction (velocity over
  /// its own length) is the same whether the mouth moves fast or slowly, so a learner following
  /// along slowly still matches.
  List<List<double>> _sequence(List<List<double>> frames) {
    final z = _normalize(_smooth(frames, config.smoothWindow), _mean, _std);
    final v = _velocity(z);
    final w = config.velocityWeight;
    return [
      for (var i = 0; i < z.length; i++) [...z[i], ..._direction(v[i], w)],
    ];
  }

  List<double> _direction(List<double> v, double weight) {
    final scaled = [for (var d = 0; d < v.length; d++) v[d] / _velStd[d]];
    final speed = math.sqrt(scaled.fold(0.0, (s, x) => s + x * x));
    final scale = weight / math.max(speed, _stillSpeed);
    return [for (final x in scaled) x * scale];
  }

  _Template _template(List<List<double>> take) {
    final seq = _sequence(take);
    // movement relative to the relaxed start of the take
    final rest = List.generate(seq.first.length ~/ 2, (d) {
      final n = math.min(_restFrames, seq.length);
      return [for (var i = 0; i < n; i++) seq[i][d]].reduce((a, b) => a + b) / n;
    });
    final dev = [
      for (final f in seq)
        math.sqrt([for (var d = 0; d < rest.length; d++) math.pow(f[d] - rest[d], 2)].reduce((a, b) => a + b))
    ];
    final peak = dev.reduce(math.max);
    var start = dev.indexWhere((x) => x > config.trimFraction * peak);
    var end = dev.lastIndexWhere((x) => x > config.trimFraction * peak);
    if (start < 0 || peak == 0) {
      start = 0;
      end = seq.length - 1;
    }
    start = math.max(0, start - _trimPad);
    end = math.min(seq.length - 1, end + _trimPad);
    final trimmed = seq.sublist(start, end + 1);
    return _Template(trimmed, _motion(trimmed));
  }

  /// Path length of the mouth shape through feature space: how far the mouth moves in total.
  /// Doesn't depend on speed, so slow movements aren't mistaken for a still face.
  static double _motion(List<List<double>> seq) {
    final half = seq.isEmpty ? 0 : seq.first.length ~/ 2;
    var sum = 0.0;
    for (var i = 1; i < seq.length; i++) {
      var s = 0.0;
      for (var d = 0; d < half; d++) {
        final x = seq[i][d] - seq[i - 1][d];
        s += x * x;
      }
      sum += math.sqrt(s);
    }
    return sum;
  }

  /// σ for one sound: the [MatcherConfig.sigmaPercentile] of leave-one-out distances, each untrimmed take
  /// (as if it were live) against the other takes' templates.
  double _calibrate(String ipa, List<List<List<double>>> takes) {
    if (takes.length < 2) return 1;
    final d = [for (var i = 0; i < takes.length; i++) distance(ipa, takes[i], exclude: i)]..sort();
    final idx = ((d.length - 1) * config.sigmaPercentile).round();
    return math.max(d[idx], 1e-6);
  }

  /// Longest matched stretch, as a multiple of the template length (slow learners).
  static const _maxStretch = 3;

  /// Slope constraint: at most this many horizontal (or vertical) steps in a row, so one frame
  /// can't soak up a long run of near-identical frames and dilute the cost.
  static const _maxRun = 2;

  /// Subsequence DTW of [query] (template) inside [stream], with free start and end in the
  /// stream and the matched stretch between half and [_maxStretch]× the query length.
  /// Symmetric step weights (diagonal ×2) normalized by both lengths, with a slope constraint,
  /// so a slower match isn't penalized for being longer (Sakoe & Chiba 1978).
  static double _subsequenceDtw(List<List<double>> query, List<List<double>> stream) {
    final n = query.length;
    final m = stream.length;
    const inf = double.infinity;
    var prevCost = List<double>.filled(m, inf);
    var prevStart = List<int>.filled(m, 0);
    var prevVRun = List<int>.filled(m, 0);

    double local(int i, int j) {
      var s = 0.0;
      final a = query[i];
      final b = stream[j];
      for (var d = 0; d < a.length; d++) {
        final x = a[d] - b[d];
        s += x * x;
      }
      return math.sqrt(s);
    }

    for (var i = 0; i < n; i++) {
      final cost = List<double>.filled(m, inf);
      final start = List<int>.filled(m, 0);
      final hRun = List<int>.filled(m, 0);
      final vRun = List<int>.filled(m, 0);
      for (var j = 0; j < m; j++) {
        final c = local(i, j);
        if (i == 0) {
          // free start anywhere in the stream
          cost[j] = 2 * c;
          start[j] = j;
          continue;
        }
        var best = inf;
        var bestStart = 0;
        var h = 0, v = 0;
        if (j > 0 && prevCost[j - 1] < inf) {
          best = prevCost[j - 1] + 2 * c; // diagonal
          bestStart = prevStart[j - 1];
        }
        if (prevVRun[j] < _maxRun && prevCost[j] + c < best) {
          best = prevCost[j] + c; // vertical: template moves on, stream waits
          bestStart = prevStart[j];
          v = prevVRun[j] + 1;
        }
        if (j > 0 && hRun[j - 1] < _maxRun && cost[j - 1] + c < best) {
          best = cost[j - 1] + c; // horizontal: stream moves on, template waits
          bestStart = start[j - 1];
          h = hRun[j - 1] + 1;
          v = 0;
        }
        cost[j] = best;
        start[j] = bestStart;
        hRun[j] = h;
        vRun[j] = v;
      }
      prevCost = cost;
      prevStart = start;
      prevVRun = vRun;
    }

    var best = inf;
    for (var j = 0; j < m; j++) {
      if (prevCost[j] == inf) continue;
      final length = j - prevStart[j] + 1;
      if (length * 2 < n || length > n * _maxStretch) continue;
      best = math.min(best, prevCost[j] / (n + length));
    }
    return best;
  }
}

class _Template {
  const _Template(this.seq, this.motion);

  final List<List<double>> seq;
  final double motion;
}
