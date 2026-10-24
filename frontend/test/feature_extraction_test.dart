import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/model/feature_extraction.dart';

void main() {
  test('rolling std is sample std, matching pandas rolling().std() used in training', () {
    final frames = [
      RawFrameFeatures(lipGapNorm: 0.1, mouthHeightNorm: 0.3, roundRatio: 3.0),
      RawFrameFeatures(lipGapNorm: 0.3, mouthHeightNorm: 0.3, roundRatio: 3.0),
    ];
    final vecs = buildFeatureVectorsForAttempt(frames);

    expect(vecs, hasLength(2));
    expect(vecs.every((v) => v.length == 15), isTrue);
    // lip_gap_norm_rollstd5 for [0.1, 0.3] with n - 1 = sqrt(0.02)
    expect(vecs[1][7], closeTo(math.sqrt(0.02), 1e-12));
    // a single-frame window has no spread
    expect(vecs[0][7], 0.0);
  });
}
