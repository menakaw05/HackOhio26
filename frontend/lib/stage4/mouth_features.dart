import 'dart:math' as math;

/// Contours kept per frame, by short key. Raw points are saved with each golden frame so
/// features can be recomputed later without re-recording.
const contourKeys = [
  'upperLipTop',
  'upperLipBottom',
  'lowerLipTop',
  'lowerLipBottom',
  'noseBottom',
  'face',
  'leftEye',
  'rightEye',
];

/// The per-frame features, all divided by the distance between the eyes so they don't depend
/// on how far the face is from the camera (mouth width itself changes with smile/pucker, so
/// it isn't used as the scale).
const featureNames = [
  'lipGap', // inner lips apart
  'mouthHeight', // outer lips top to bottom
  'mouthWidth', // corner to corner: spread vs pucker
  'jawOpen', // bottom of nose to chin
  'roundness', // mouthHeight / mouthWidth
];

typedef Pt = ({double x, double y});

Pt? _centroid(List<Pt>? pts) {
  if (pts == null || pts.isEmpty) return null;
  var sx = 0.0, sy = 0.0;
  for (final p in pts) {
    sx += p.x;
    sy += p.y;
  }
  return (x: sx / pts.length, y: sy / pts.length);
}

double _dist(Pt a, Pt b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

/// Features for one frame from raw contours (pixel coordinates), or null if a needed contour
/// is missing. Uses only distances, so head tilt in the image plane doesn't matter.
List<double>? mouthFeatures(Map<String, List<Pt>> contours) {
  final leftEye = _centroid(contours['leftEye']);
  final rightEye = _centroid(contours['rightEye']);
  final upTop = _centroid(contours['upperLipTop']);
  final upBottom = _centroid(contours['upperLipBottom']);
  final lowTop = _centroid(contours['lowerLipTop']);
  final lowBottom = _centroid(contours['lowerLipBottom']);
  final nose = _centroid(contours['noseBottom']);
  final face = contours['face'];
  final outerLips = [...?contours['upperLipTop'], ...?contours['lowerLipBottom']];
  if (leftEye == null ||
      rightEye == null ||
      upTop == null ||
      upBottom == null ||
      lowTop == null ||
      lowBottom == null ||
      nose == null ||
      face == null ||
      face.isEmpty ||
      outerLips.length < 2) {
    return null;
  }

  final eyeDistance = _dist(leftEye, rightEye);
  if (eyeDistance == 0) return null;

  // mouth corners: the two outer-lip points farthest apart
  var width = 0.0;
  for (var i = 0; i < outerLips.length; i++) {
    for (var j = i + 1; j < outerLips.length; j++) {
      width = math.max(width, _dist(outerLips[i], outerLips[j]));
    }
  }

  // chin: the face-outline point farthest from between the eyes
  final eyesMid = (x: (leftEye.x + rightEye.x) / 2, y: (leftEye.y + rightEye.y) / 2);
  final chin = face.reduce((a, b) => _dist(a, eyesMid) >= _dist(b, eyesMid) ? a : b);

  final height = _dist(upTop, lowBottom);
  return [
    _dist(upBottom, lowTop) / eyeDistance,
    height / eyeDistance,
    width / eyeDistance,
    _dist(nose, chin) / eyeDistance,
    width == 0 ? 0 : height / width,
  ];
}
