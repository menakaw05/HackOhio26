import 'dart:convert';
import 'dart:math' as math;

class RawFrameFeatures {
  final double lipGapNorm;
  final double mouthHeightNorm;
  final double roundRatio;

  /// When the camera frame was processed, if the payload has it.
  final DateTime? time;

  RawFrameFeatures({
    required this.lipGapNorm,
    required this.mouthHeightNorm,
    required this.roundRatio,
    this.time,
  });
}


// ------------------------
// helper geometry functions
// ------------------------

Map<String, double>? centroid(List<dynamic>? points) {
  if (points == null || points.isEmpty) return null;
  double sx = 0.0;
  double sy = 0.0;
  int n = 0;
  for (final p in points) {
    if (p is Map && p["x"] != null && p["y"] != null) {
      sx += (p["x"] as num).toDouble();
      sy += (p["y"] as num).toDouble();
      n++;
    }
  }
  if (n == 0) return null;
  return {"x": sx / n, "y": sy / n};
}

double? euclideanDistance(Map<String, double>? a, Map<String, double>? b) {
  if (a == null || b == null) return null;
  final dx = a["x"]! - b["x"]!;
  final dy = a["y"]! - b["y"]!;
  return math.sqrt(dx * dx + dy * dy);
}

double? verticalDistance(Map<String, double>? a, Map<String, double>? b) {
  if (a == null || b == null) return null;
  return (a["y"]! - b["y"]!).abs();
}

List<Map<String, double>?> mouthCorners(List<dynamic>? pts) {
  if (pts == null || pts.isEmpty) return [null, null];
  Map<String, double>? left;
  Map<String, double>? right;

  for (final p in pts) {
    if (p is Map && p["x"] != null && p["y"] != null) {
      final px = (p["x"] as num).toDouble();
      final py = (p["y"] as num).toDouble();
      if (left == null || px < left["x"]!) left = {"x": px, "y": py};
      if (right == null || px > right["x"]!) right = {"x": px, "y": py};
    }
  }
  return [left, right];
}

// ------------------------
// main feature extraction
// ------------------------

RawFrameFeatures? extractRawFrameFeaturesSingle(
  Map<String, dynamic> frameMap,
) {
  final mc = frameMap["mouthContours"] as Map<String, dynamic>;

  final upperLipTop = mc["upperLipTop"] as List<dynamic>?;
  final upperLipBottom = mc["upperLipBottom"] as List<dynamic>?;
  final lowerLipTop = mc["lowerLipTop"] as List<dynamic>?;
  final lowerLipBottom = mc["lowerLipBottom"] as List<dynamic>?;

  final upBotCenter = centroid(upperLipBottom);
  final lowTopCenter = centroid(lowerLipTop);
  final upTopCenter = centroid(upperLipTop);
  final lowBotCenter = centroid(lowerLipBottom);

  final lipGap = verticalDistance(upBotCenter, lowTopCenter);
  final mouthHeight = verticalDistance(upTopCenter, lowBotCenter);

  final refForCorners =
      (lowerLipTop != null && lowerLipTop.isNotEmpty) ? lowerLipTop : upperLipBottom;
  final corners = mouthCorners(refForCorners);
  final mouthWidth = euclideanDistance(corners[0], corners[1]);

  if (mouthWidth == null ||
      mouthWidth == 0.0 ||
      lipGap == null ||
      mouthHeight == null) {
    return null;
  }

  final lipGapNorm = lipGap / mouthWidth;
  final mouthHeightNorm = mouthHeight / mouthWidth;
  final roundRatio = mouthHeight > 0 ? (mouthWidth / mouthHeight) : double.infinity;

  return RawFrameFeatures(
    lipGapNorm: lipGapNorm,
    mouthHeightNorm: mouthHeightNorm,
    roundRatio: roundRatio,
    time: DateTime.tryParse(frameMap["timestamp"]?.toString() ?? ""),
  );
}


List<RawFrameFeatures> extractAllRawFrameFeaturesFromPayload(String jsonStr) {
  final decoded = json.decode(jsonStr) as Map<String, dynamic>;
  final frames = decoded["frame"] as List<dynamic>;

  final out = <RawFrameFeatures>[];

  for (final f in frames) {
    final frameMap = f as Map<String, dynamic>;
    final feats = extractRawFrameFeaturesSingle(frameMap);
    if (feats != null) {
      out.add(feats);
    }
  }

  return out;
}

double _mean(List<double> xs) {
  if (xs.isEmpty) return 0.0;
  double s = 0.0;
  for (final v in xs) {
    s += v;
  }
  return s / xs.length;
}

double _std(List<double> xs) {
  if (xs.length < 2) return 0.0;
  final m = _mean(xs);
  double accum = 0.0;
  for (final v in xs) {
    final d = v - m;
    accum += d * d;
  }
  // sample std (n - 1) to match pandas rolling().std() used in training
  final variance = accum / (xs.length - 1);
  return math.sqrt(variance);
}

List<List<double>> buildFeatureVectorsForAttempt(List<RawFrameFeatures> rawFrames) {
  final vectors = <List<double>>[];

  double prevLip = 0.0;
  double prevMouth = 0.0;
  double prevRound = 0.0;

  for (int i = 0; i < rawFrames.length; i++) {
    final f = rawFrames[i];

    // deltas vs previous frame
    final lipDelta    = (i == 0) ? 0.0 : (f.lipGapNorm        - prevLip);
    final mouthDelta  = (i == 0) ? 0.0 : (f.mouthHeightNorm   - prevMouth);
    final roundDelta  = (i == 0) ? 0.0 : (f.roundRatio        - prevRound);

    // rolling window of up to 5 frames: indices [i-4 .. i]
    final start = (i - 4 < 0) ? 0 : i - 4;
    final window = rawFrames.sublist(start, i + 1);

    final lipVals   = window.map((w) => w.lipGapNorm).toList();
    final mouthVals = window.map((w) => w.mouthHeightNorm).toList();
    final roundVals = window.map((w) => w.roundRatio).toList();

    final lipRollMean    = _mean(lipVals);
    final lipRollStd     = _std(lipVals);
    final mouthRollMean  = _mean(mouthVals);
    final mouthRollStd   = _std(mouthVals);
    final roundRollMean  = _mean(roundVals);
    final roundRollStd   = _std(roundVals);

    // lip_gap_prev_norm for frame0 = current (to match your Python branch)
    final lipPrevNorm   = (i == 0) ? f.lipGapNorm      : prevLip;
    // mouth_height_prev_norm existed in your old FrameFeatures but it is NOT
    // in the 15-column list. Good: we don't include it in ONNX input.
    // Same for mouthHeightPrevNorm.

    // Construct the 15 features in the same order as Python feature_cols
    final featVec = <double>[
      f.lipGapNorm,            // 1 lip_gap_norm
      f.mouthHeightNorm,       // 2 mouth_height_norm
      f.roundRatio,            // 3 round_ratio
      lipPrevNorm,             // 4 lip_gap_prev_norm
      lipDelta,                // 5 lip_gap_delta_norm  (aka lip_gap_norm_delta in spirit)
      mouthDelta,              // 6 mouth_height_delta_norm
      lipRollMean,             // 7 lip_gap_norm_rollmean5
      lipRollStd,              // 8 lip_gap_norm_rollstd5
      lipDelta,                // 9 lip_gap_norm_delta (same numeric as lipDelta)
      mouthRollMean,           //10 mouth_height_norm_rollmean5
      mouthRollStd,            //11 mouth_height_norm_rollstd5
      mouthDelta,              //12 mouth_height_norm_delta
      roundRollMean,           //13 round_ratio_rollmean5
      roundRollStd,            //14 round_ratio_rollstd5
      roundDelta,              //15 round_ratio_delta
    ];

    vectors.add(featVec);

    // update prevs
    prevLip = f.lipGapNorm;
    prevMouth = f.mouthHeightNorm;
    prevRound = f.roundRatio;
  }

  return vectors;
}


