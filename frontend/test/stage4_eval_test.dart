// Leave-one-out evaluation of the stage 4 matcher on the recorded golden data. Each take is
// treated as a live attempt (untrimmed, with its still frames) and scored against the other
// takes. Prints a report; the assertions are sanity floors, not targets.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/stage4/mouth_matcher.dart';

/// Azure viseme groups: sounds that look the same on the lips. Report only.
const _visemeOf = {
  'æ': 1, 'ə': 1, 'ʌ': 1, 'ɑ': 2, 'ɔ': 3, 'ɛ': 4, 'ʊ': 4, 'eɪ': 4, 'ɝ': 5, 'ɚ': 5,
  'j': 6, 'i': 6, 'ɪ': 6, 'w': 7, 'u': 7, 'oʊ': 8, 'aʊ': 9, 'ɔɪ': 10, 'aɪ': 11,
  'h': 12, 'ɹ': 13, 'l': 14, 's': 15, 'z': 15, 'ʃ': 16, 'tʃ': 16, 'dʒ': 16, 'ʒ': 16,
  'ð': 17, 'f': 18, 'v': 18, 'd': 19, 't': 19, 'n': 19, 'θ': 19, 'k': 20, 'g': 20,
  'ŋ': 20, 'p': 21, 'b': 21, 'm': 21,
  'ɑɹ': 2, 'ɛɹ': 4, 'ɪɹ': 6, 'ɔɹ': 3, 'aɪɹ': 11, 'aʊɹ': 9,
};

Map<String, List<List<List<double>>>> loadGolden() =>
    parseGoldenFeatures(File(goldenAsset).readAsStringSync());

/// [take] stretched to [factor]× as many frames, as if said more slowly.
List<List<double>> slowed(List<List<double>> take, double factor) {
  final n = (take.length * factor).round();
  return [
    for (var i = 0; i < n; i++)
      () {
        final x = i * (take.length - 1) / (n - 1);
        final lo = x.floor(), hi = math.min(lo + 1, take.length - 1), t = x - lo;
        return [for (var d = 0; d < take[lo].length; d++) take[lo][d] * (1 - t) + take[hi][d] * t];
      }(),
  ];
}

double _dev(List<double> a, List<double> b) =>
    math.sqrt([for (var d = 0; d < a.length; d++) math.pow(a[d] - b[d], 2)].reduce((x, y) => x + y));

int _peak(List<List<double>> t) {
  var best = 0;
  for (var i = 1; i < t.length; i++) {
    if (_dev(t[i], t.first) > _dev(t[best], t.first)) best = i;
  }
  return best;
}

/// A sound as it happens inside a word: coming from another sound's mouth shape, into this
/// sound up to its peak, without relaxing in between (unlike the isolated golden takes).
List<List<double>> inWord(List<List<double>> prev, List<List<double>> target) {
  final pp = _peak(prev), tp = _peak(target);
  final from = target.indexWhere((f) => _dev(f, target.first) > 0.3 * _dev(target[tp], target.first));
  return [
    ...prev.sublist(math.max(0, pp - 3), math.min(prev.length, pp + 3)),
    ...target.sublist(math.max(0, from), math.min(target.length, tp + 3)),
    for (var i = 0; i < 8; i++) target[math.min(target.length - 1, tp + 2)],
  ];
}

void main() {
  final golden = loadGolden();
  final matcher = MouthMatcher.fromTakes(golden);
  final phonemes = golden.keys.toList();

  test('held-out evaluation on golden data', () {
    var total = 0, top1 = 0, top3 = 0, visemeTop1 = 0, genuinePass = 0;
    var impostorPass = 0, impostorTotal = 0, stillPass = 0, slow15Pass = 0, slow2Pass = 0;
    var inWordPass = 0, inWordOther = 0, inWordOtherTotal = 0;
    final rng = math.Random(1);
    final confusions = <String, int>{};
    final genuineScores = <double>[];

    for (final p in phonemes) {
      for (var i = 0; i < golden[p]!.length; i++) {
        final take = golden[p]![i];
        // the held-out take isn't used for templates, σ, or normalization
        final m = MouthMatcher.fromTakes({
          for (final e in golden.entries)
            e.key: [
              for (var k = 0; k < e.value.length; k++)
                if (!(e.key == p && k == i)) e.value[k]
            ],
        });
        total++;
        final dists = {for (final q in phonemes) q: m.distance(q, take)};
        final ranked = phonemes.toList()..sort((a, b) => dists[a]!.compareTo(dists[b]!));
        if (ranked.first == p) top1++;
        if (ranked.take(3).contains(p)) top3++;
        if (_visemeOf[ranked.first] == _visemeOf[p]) visemeTop1++;
        if (ranked.first != p) {
          final key = '$p→${ranked.first}';
          confusions[key] = (confusions[key] ?? 0) + 1;
        }

        // the live flow scores the last 0.75 s (18 frames at 24 fps)
        List<List<double>> recent(List<List<double>> f) => f.sublist(math.max(0, f.length - 18));
        final prev = phonemes[rng.nextInt(phonemes.length)];
        final word = inWord(golden[prev]!.first, take);
        var best = 0.0;
        for (var end = 2; end <= word.length; end++) {
          best = math.max(best, m.score(p, recent(word.sublist(0, end))));
        }
        if (best >= 0.5) inWordPass++;
        for (var r = 0; r < 3; r++) {
          final q = phonemes[rng.nextInt(phonemes.length)];
          if (q == p) continue;
          inWordOtherTotal++;
          var bestQ = 0.0;
          for (var end = 2; end <= word.length; end++) {
            bestQ = math.max(bestQ, m.score(q, recent(word.sublist(0, end))));
          }
          if (bestQ >= 0.5) inWordOther++;
        }
        if (m.score(p, slowed(take, 1.5)) >= 0.5) slow15Pass++;
        if (m.score(p, slowed(take, 2)) >= 0.5) slow2Pass++;
        final own = m.score(p, take);
        genuineScores.add(own);
        if (own >= 0.5) genuinePass++;
        for (final q in phonemes) {
          if (q == p) continue;
          impostorTotal++;
          if (m.score(q, take) >= 0.5) impostorPass++;
        }

        // a still face: the take's relaxed first frame held for a second
        final still = List.generate(24, (_) => take.first);
        if (m.score(p, still) >= 0.5) stillPass++;
      }
    }

    String pct(int a, int b) => '${(100 * a / b).toStringAsFixed(1)}%';
    final topConfusions = confusions.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    genuineScores.sort();
    // ignore: avoid_print
    print('''
--- stage 4 matcher, held out one take at a time, on ${golden.length} sounds / $total takes ---
1-NN sound accuracy:    ${pct(top1, total)}   (chance ${pct(1, phonemes.length)})
top-3 sound accuracy:   ${pct(top3, total)}
1-NN viseme accuracy:   ${pct(visemeTop1, total)}   (same mouth shape group)
own sound passes (≥0.5): ${pct(genuinePass, total)}
  …said 1.5× slower:    ${pct(slow15Pass, total)}
  …said 2× slower:      ${pct(slow2Pass, total)}
other sounds pass:      ${pct(impostorPass, impostorTotal)}
in a word (0.75 s window, coming from another sound):
  own sound passes:     ${pct(inWordPass, total)}
  other sounds pass:    ${pct(inWordOther, inWordOtherTotal)}
still face passes:      ${pct(stillPass, total)}
own score quartiles:    ${[0.25, 0.5, 0.75].map((q) => genuineScores[((genuineScores.length - 1) * q).round()].toStringAsFixed(2)).join(' / ')}
top confusions:         ${topConfusions.take(12).map((e) => '${e.key}×${e.value}').join(', ')}
''');

    // core-of-the-sound templates trade some sound-picking accuracy for matching inside words
    expect(top1 / total, greaterThan(0.35), reason: 'chance is about 2%');
    expect(genuinePass / total, greaterThan(0.75));
    expect(impostorPass / impostorTotal, lessThan(0.32));
    expect(inWordPass / total, greaterThan(0.45));
    expect(stillPass, 0);
    expect(slow2Pass / total, greaterThan(0.6), reason: 'learners follow along slowly');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('every sound has a finite σ and scores stay between 0 and 1', () {
    for (final p in phonemes) {
      expect(matcher.sigmaFor(p)!.isFinite, isTrue, reason: p);
    }
    for (final p in ['k', 'ŋ', 'b', 't']) {
      for (final q in phonemes) {
        final s = matcher.score(q, golden[p]!.first);
        expect(s.isNaN, isFalse, reason: '$p vs $q');
        expect(s, inInclusiveRange(0, 1));
      }
    }
  });

  test('chart helpers: normalized keeps shape, closest template of a golden take is itself', () {
    final take = golden['u']![2];
    final z = matcher.normalized(take);
    expect(z.length, take.length);
    expect(z.first.length, 5);
    expect(matcher.closestTemplate('u', take), 2);
    expect(matcher.closestTemplate('zzz', take), isNull);
  });

  test('scores are 0-1 and a sound scores higher than an unrelated one on average', () {
    final s = matcher.score('u', golden['u']!.first, exclude: 0);
    expect(s, inInclusiveRange(0, 1));
    double mean(String q) =>
        [for (final t in golden['u']!) matcher.score(q, t)].reduce((a, b) => a + b) / golden['u']!.length;
    expect(mean('u'), greaterThan(mean('i')));
    expect(math.max(0, matcher.sigmaFor('u')!), greaterThan(0));
  });
}
