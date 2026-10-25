import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// A burst of stars and bubbles, with two fish swimming across. Plays each time [playCount]
/// goes up.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.playCount});

  final int playCount;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  static const _particleCount = 32;
  static const _colors = [
    AppColors.lotus,
    AppColors.lake,
    AppColors.almost,
    AppColors.sky,
    AppColors.lilyPad,
  ];

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..addListener(() => setState(() {}));
  List<_Particle> _particles = const [];

  @override
  void didUpdateWidget(CelebrationOverlay old) {
    super.didUpdateWidget(old);
    if (widget.playCount > old.playCount && !reduceMotion(context)) _play();
  }

  void _play() {
    final rng = math.Random(widget.playCount);
    _particles = [
      for (var i = 0; i < _particleCount; i++)
        _Particle(
          angle: -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 1.4,
          speed: 0.35 + rng.nextDouble() * 0.45,
          size: 8 + rng.nextDouble() * 10,
          spin: (rng.nextDouble() - 0.5) * 8,
          star: i.isEven,
          color: _colors[i % _colors.length],
        ),
    ];
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CelebrationPainter(_particles, _controller.value),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.star,
    required this.color,
  });

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final bool star;
  final Color color;
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.4);
    final reach = size.shortestSide;
    for (final p in particles) {
      final travel = p.speed * reach * Curves.easeOut.transform(t);
      final gravity = 0.5 * reach * t * t;
      final pos = origin + Offset(math.cos(p.angle) * travel, math.sin(p.angle) * travel + gravity);
      final paint = Paint()..color = p.color.withValues(alpha: (1 - t).clamp(0, 1));

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      if (p.star) {
        canvas.drawPath(_star(p.size), paint);
      } else {
        // a bubble with a shine
        canvas.drawCircle(Offset.zero, p.size * 0.6,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
        canvas.drawCircle(Offset(-p.size * 0.2, -p.size * 0.2), p.size * 0.14,
            Paint()..color = Colors.white.withValues(alpha: (1 - t).clamp(0, 1)));
      }
      canvas.restore();
    }

    // two fish swim across, one each way
    _fish(canvas, Offset(-60 + (size.width + 120) * t, size.height * 0.28 + math.sin(t * 12) * 8),
        AppColors.sky, 1);
    _fish(canvas, Offset(size.width + 60 - (size.width + 120) * t, size.height * 0.62 + math.sin(t * 10) * 8),
        AppColors.lotus, -1);
  }

  /// A little fish facing [dir] (1 = right).
  void _fish(Canvas canvas, Offset at, Color color, double dir) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(dir, 1);
    final body = Paint()..color = color;
    canvas.drawPath(
        Path()
          ..moveTo(-16, 0)
          ..lineTo(-30, -11)
          ..lineTo(-30, 11)
          ..close(),
        body);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 40, height: 26), body);
    canvas.drawCircle(const Offset(10, -3), 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(11, -3), 2.3, Paint()..color = AppColors.ink);
    canvas.restore();
  }

  Path _star(double size) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? size / 2 : size / 4.5;
      final a = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => old.t != t;
}
