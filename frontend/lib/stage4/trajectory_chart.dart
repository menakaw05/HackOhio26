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

/// Each feature over time as its own line, scaled to its own min-max so shapes are visible.
class TrajectoryChart extends StatelessWidget {
  const TrajectoryChart({super.key, required this.series, this.height = 72});

  /// Frames × features.
  final List<List<double>> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mouth movement chart, ${series.length} frames',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _TrajectoryPainter(series)),
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
  _TrajectoryPainter(this.series);

  final List<List<double>> series;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AppRadius.chip)),
      Paint()..color = AppColors.lakeMist.withValues(alpha: 0.5),
    );
    if (series.length < 2) return;
    final features = series.first.length;
    for (var f = 0; f < features; f++) {
      final values = [for (final frame in series) frame[f]];
      final lo = values.reduce(math.min);
      final span = math.max(values.reduce(math.max) - lo, 1e-6);
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = size.width * i / (values.length - 1);
        final y = size.height - 4 - (size.height - 8) * (values[i] - lo) / span;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = featureColors[f % featureColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_TrajectoryPainter old) => old.series != series;
}
