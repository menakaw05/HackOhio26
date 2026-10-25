import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Underwater scenery behind a screen: water getting deeper toward the bottom, bubbles,
/// seaweed in the corners and a wave along the bottom edge.
class OceanBackdrop extends StatelessWidget {
  const OceanBackdrop({super.key, required this.child, this.gradient = _lagoon});

  final Widget child;
  final Gradient gradient;

  static const _lagoon = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.background, AppColors.lakeMist, Color(0xFFBFE9E4)],
    stops: [0, 0.55, 1],
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: CustomPaint(painter: _OceanPainter(), child: child),
    );
  }
}

class _OceanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // a soft wave along the bottom
    final wave = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w; x += 8) {
      wave.lineTo(x, h - 46 - math.sin(x / w * math.pi * 3) * 10);
    }
    wave
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(wave, Paint()..color = AppColors.lake.withValues(alpha: 0.12));

    // seaweed swaying up from the corners
    final weed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12
      ..color = AppColors.lilyPad.withValues(alpha: 0.28);
    for (final (x, tall) in [(18.0, 150.0), (40.0, 100.0), (w - 22, 130.0), (w - 46, 80.0)]) {
      final path = Path()..moveTo(x, h);
      for (var y = 0.0; y <= tall; y += 10) {
        path.lineTo(x + math.sin(y / 22) * 9, h - y);
      }
      canvas.drawPath(path, weed);
    }

    // bubbles, always in the same places
    final rng = math.Random(7);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 14; i++) {
      final pos = Offset(rng.nextDouble() * w, rng.nextDouble() * h);
      final r = 4 + rng.nextDouble() * 10;
      canvas.drawCircle(pos, r, ring..color = AppColors.sky.withValues(alpha: 0.22));
      canvas.drawCircle(pos + Offset(-r * 0.35, -r * 0.35), r * 0.22,
          Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
  }

  @override
  bool shouldRepaint(_OceanPainter old) => false;
}

/// A round brass porthole, e.g. for the coach to look out of.
class Porthole extends StatelessWidget {
  const Porthole({super.key, required this.child});

  final Widget child;

  static const _rim = 10.0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        foregroundPainter: _BoltsPainter(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.lakeMist,
            border: Border.fromBorderSide(BorderSide(color: AppColors.sun, width: _rim)),
            boxShadow: [BoxShadow(color: AppColors.sunDeep, offset: Offset(0, 5))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(_rim),
            child: ClipOval(child: child),
          ),
        ),
      ),
    );
  }
}

class _BoltsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - Porthole._rim / 2;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      final bolt = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(bolt, 2.6, Paint()..color = AppColors.sunDeep);
      canvas.drawCircle(bolt + const Offset(-0.8, -0.8), 1, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_BoltsPainter old) => false;
}

/// A starfish, e.g. one per try. [color] null draws an empty outline.
class Starfish extends StatelessWidget {
  const Starfish({super.key, this.color, this.size = 30});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _StarfishPainter(color));
}

class _StarfishPainter extends CustomPainter {
  _StarfishPainter(this.color);

  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = size.center(Offset.zero);
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? s * 0.4 : s * 0.19;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    final color = this.color;
    final round = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    if (color == null) {
      canvas.drawPath(star, round
        ..color = AppColors.inkFaint
        ..strokeWidth = s * 0.07);
      return;
    }
    // a thick round stroke in the same color makes the arms plump
    canvas.drawPath(star, Paint()..color = color);
    canvas.drawPath(star, round
      ..color = color
      ..strokeWidth = s * 0.14);
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(c, s * 0.045, dot);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * s * 0.2, s * 0.03, dot);
    }
  }

  @override
  bool shouldRepaint(_StarfishPainter old) => old.color != color;
}
