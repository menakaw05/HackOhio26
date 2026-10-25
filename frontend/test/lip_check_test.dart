import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/phoneme_classifier.dart';

List<String> _frames(List<(String, int)> runs) => [
      for (final (label, n) in runs) ...List.filled(n, label),
    ];

bool _passes(List<String> labels) =>
    PhonemeQualityModel.correctLabels.contains(PhonemeQualityModel.majorityVote(labels));

final _t0 = DateTime(2026, 10, 25, 3, 5);

/// One frame every 100 ms, about what the phone gets.
List<DateTime?> _times(int n) => [for (var i = 0; i < n; i++) _t0.add(Duration(milliseconds: 100 * i))];

/// Labels of the frames from [fromFrame] to [toFrame], picked by time.
List<String> _during(List<String> labels, int fromFrame, int toFrame) =>
    PhonemeQualityModel.framesDuring(labels, _times(labels.length),
        _t0.add(Duration(milliseconds: 100 * fromFrame)), _t0.add(Duration(milliseconds: 100 * toFrame)));

// Per-frame labels the A model gave on the phone for the word "cat". The resting mouth before
// and after the sound comes out as APPLE.
void main() {
  test('"cut" fails', () {
    final cut = _frames([('APPLE', 13), ('UH', 3), ('APPLE', 1), ('UH', 13), ('APPLE', 1), ('UH', 14)]);
    expect(_passes(cut), isFalse);
  });

  test('"cat" passes', () {
    final cat = _frames([('APPLE', 47), ('UH', 5), ('EH', 7)]);
    expect(_passes(cat), isTrue);
    expect(_passes(_during(cat, 20, 40)), isTrue);
  });

  test('"uh" fails once only the frames while speaking count', () {
    final uh = _frames([('APPLE', 13), ('UH', 7), ('APPLE', 4), ('UH', 10), ('APPLE', 2)]);
    expect(_passes(uh), isTrue, reason: 'the resting mouth outvotes the sound');
    expect(PhonemeQualityModel.majorityVote(_during(uh, 12, 35)), 'UH');
  });

  test('"aw" fails once only the frames while speaking count', () {
    final aw = _frames([('APPLE', 12), ('UH', 1), ('EH', 1), ('APPLE', 4), ('AW', 21), ('APPLE', 7), ('UH', 1)]);
    expect(_passes(aw), isTrue, reason: 'the resting mouth outvotes the sound');
    expect(PhonemeQualityModel.majorityVote(_during(aw, 16, 40)), 'AW');
  });

  test('too few frames while speaking: the whole attempt counts', () {
    final labels = _frames([('APPLE', 10), ('UH', 10)]);
    expect(_during(labels, 30, 40), labels);
  });
}
