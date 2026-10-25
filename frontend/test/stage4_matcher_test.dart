import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/stage4/mouth_matcher.dart';

/// A synthetic take: still, then a smooth open-close of [features] over [len] frames, then still.
List<List<double>> take(List<double> peak, {int len = 12, double noise = 0, int seed = 0}) {
  final rng = math.Random(seed);
  const rest = [0.1, 0.4, 0.6, 1.2, 0.6];
  List<double> at(double t) => [
        for (var d = 0; d < 5; d++)
          rest[d] + (peak[d] - rest[d]) * math.sin(math.pi * t) + noise * (rng.nextDouble() - 0.5)
      ];
  return [
    for (var i = 0; i < 4; i++) rest.toList(),
    for (var i = 0; i < len; i++) at(i / (len - 1)),
    for (var i = 0; i < 4; i++) rest.toList(),
  ];
}

const open = [0.5, 0.9, 0.6, 1.6, 1.5]; // jaw drops, lips part
const pucker = [0.15, 0.55, 0.35, 1.3, 1.6]; // lips round and narrow

// like real golden takes: a few each, at slightly different speeds, with some jitter
MouthMatcher matcher() => MouthMatcher.fromTakes({
      'ɑ': [for (var s = 0; s < 5; s++) take(open, len: 10 + s, noise: 0.08, seed: s)],
      'u': [for (var s = 0; s < 5; s++) take(pucker, len: 10 + s, noise: 0.08, seed: 10 + s)],
    });

void main() {
  test('a new attempt of the same movement scores high, a different one low', () {
    final m = matcher();
    final attempt = take(open, noise: 0.08, seed: 99);
    expect(m.score('ɑ', attempt), greaterThan(0.5));
    expect(m.score('u', attempt), lessThan(m.score('ɑ', attempt)));
  });

  test('the same movement done slower still matches (time warping)', () {
    final m = matcher();
    // about twice as slow as the golden takes
    final slow = take(open, len: 24, noise: 0.08, seed: 98);
    expect(m.score('ɑ', slow), greaterThan(0.5));
  });

  test('the match is found inside a longer window (subsequence)', () {
    final m = matcher();
    final window = [
      ...List.generate(10, (_) => [0.1, 0.4, 0.6, 1.2, 0.6]),
      ...take(pucker, noise: 0.08, seed: 97),
    ];
    expect(m.score('u', window), greaterThan(0.5));
  });

  test('a still face scores 0, and unknown sounds score 0', () {
    final m = matcher();
    final still = List.generate(24, (_) => [0.1, 0.4, 0.6, 1.2, 0.6]);
    expect(m.score('ɑ', still), 0);
    expect(m.score('zzz', take(open)), 0);
    expect(m.hasPhoneme('u'), isTrue);
  });

  testWidgets('bundled golden data loads into a matcher for every sound', (tester) async {
    final m = (await tester.runAsync(MouthMatcher.loadBundled))!;
    expect(m.phonemes.length, 47);
    expect(m.hasPhoneme('ɑɹ'), isTrue);
  });
}
