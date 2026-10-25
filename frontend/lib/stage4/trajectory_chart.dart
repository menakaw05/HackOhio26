import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'mouth_features.dart';

const featureColors = [
  AppColors.lake,
  AppColors.lotus,
  AppColors.sky,
  AppColors.almost,
  AppColors.lilyPad,
];

/// Each feature over time as its own line. With [min]/[max], every chart shares that fixed
/// scale (so stillness looks flat); without, each line is stretched to its own min-max.
class TrajectoryChart extends StatelessWidget {
  const TrajectoryChart({
    super.key,
    required this.series,
    this.height = 72,
    this.min,
    this.max,
    this.faint = const [],
  });

  /// Frames × features.
  final List<List<double>> series;
  final double height;
  final double? min;
  final double? max;

  /// Extra series drawn lightly behind, e.g. the other golden takes.
  final List<List<List<double>>> faint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mouth movement chart, ${series.length} frames',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _TrajectoryPainter(series, min, max, faint)),
      ),
    );
  }
}

class FeatureLegend extends StatelessWidget {
  const FeatureLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.m,
      runSpacing: AppSpace.xs,
      children: [
        for (var i = 0; i < featureNames.length; i++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, color: featureColors[i]),
            const SizedBox(width: AppSpace.xs),
            Text(featureNames[i], style: AppText.caption),
          ]),
      ],
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  _TrajectoryPainter(this.series, this.min, this.max, this.faint);

  final List<List<double>> series;
  final double? min;
  final double? max;
  final List<List<List<double>>> faint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AppRadius.chip)),
      Paint()..color = AppColors.lakeMist.withValues(alpha: 0.5),
    );
    final lo = min, hi = max;
    if (lo != null && hi != null && lo < 0 && hi > 0) {
      // zero line: the golden average
      final y = _y(0, lo, hi - lo, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = AppColors.line);
    }
    for (final s in faint) {
      _drawSeries(canvas, size, s, alpha: 0.25, width: 1.5);
    }
    _drawSeries(canvas, size, series, alpha: 1, width: 2);
  }

  double _y(double v, double lo, double span, Size size) =>
      size.height - 4 - (size.height - 8) * ((v - lo) / span).clamp(0.0, 1.0);

  void _drawSeries(Canvas canvas, Size size, List<List<double>> s,
      {required double alpha, required double width}) {
    if (s.length < 2) return;
    for (var f = 0; f < s.first.length; f++) {
      final values = [for (final frame in s) frame[f]];
      final lo = min ?? values.reduce(math.min);
      final span = math.max((max ?? values.reduce(math.max)) - lo, 1e-6);
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = size.width * i / (values.length - 1);
        final y = _y(values[i], lo, span, size);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = featureColors[f % featureColors.length].withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }
  }

  @override
  bool shouldRepaint(_TrajectoryPainter old) =>
      old.series != series || old.faint != faint || old.min != min || old.max != max;
}
