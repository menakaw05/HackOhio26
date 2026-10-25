import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// "mirrorU" wordmark: a lotus-pink U in a teal mirror.
class MirrorULogo extends StatelessWidget {
  const MirrorULogo({super.key, this.size = 28, this.onLongPress, this.light = false});

  final double size;
  final VoidCallback? onLongPress;

  /// White text, for use on gradients.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final mark = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 1.2,
          height: size * 1.2,
          decoration: const BoxDecoration(gradient: AppGradients.lake, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('U',
              style: AppText.title.copyWith(
                  fontSize: size * 0.75, color: Colors.white, height: 1)),
        ),
        SizedBox(width: size * 0.3),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'mirror', style: TextStyle(color: light ? Colors.white : AppColors.ink)),
            const TextSpan(text: 'U', style: TextStyle(color: AppColors.lotus)),
          ]),
          style: AppText.display.copyWith(fontSize: size),
        ),
      ],
    );
    return Semantics(
      label: 'mirrorU',
      excludeSemantics: true,
      child: GestureDetector(onLongPress: onLongPress, child: mark),
    );
  }
}

/// Circle with the learner's initial. Real avatar images come later.
class LearnerAvatar extends StatelessWidget {
  const LearnerAvatar({super.key, required this.learner, this.size = AppSize.avatar});

  final Learner learner;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarPalette[learner.colorIndex % AppColors.avatarPalette.length];
    return Semantics(
      label: learner.name,
      excludeSemantics: true,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: color,
        child: Text(learner.initial,
            style: AppText.title.copyWith(color: Colors.white, fontSize: size * 0.45)),
      ),
    );
  }
}

/// The mascot: a smiling lotus on a lily pad, floating on the lake. Pops in when it appears.
class LotusBuddy extends StatefulWidget {
  const LotusBuddy({super.key, this.size = 160});

  final double size;

  @override
  State<LotusBuddy> createState() => _LotusBuddyState();
}

class _LotusBuddyState extends State<LotusBuddy> with SingleTickerProviderStateMixin {
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _pop.value = 1;
    } else if (_pop.value == 0) {
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'mirrorU lotus buddy',
      excludeSemantics: true,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
        alignment: Alignment.bottomCenter,
        child: CustomPaint(size: Size.square(widget.size), painter: _LotusBuddyPainter()),
      ),
    );
  }
}

class _LotusBuddyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final fill = Paint()..isAntiAlias = true;

    // ripples on the water
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.5, s * 0.86), width: s * 0.98, height: s * 0.2),
        ripple..color = AppColors.sky.withValues(alpha: 0.45));
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.5, s * 0.88), width: s * 0.76, height: s * 0.13),
        ripple..color = AppColors.lake.withValues(alpha: 0.5));

    // lily pad, with its notch and a darker edge
    final pad = Rect.fromCenter(center: Offset(s * 0.5, s * 0.8), width: s * 0.84, height: s * 0.24);
    Path padPath(Rect r) => Path()
      ..moveTo(r.center.dx, r.center.dy)
      ..arcTo(r, 0.4, 2 * math.pi - 0.4, false)
      ..close();
    canvas.drawPath(padPath(pad.shift(Offset(0, s * 0.025))), fill..color = AppColors.edgeOf(AppColors.lilyPad));
    canvas.drawPath(padPath(pad), fill..color = AppColors.lilyPad);

    // petals fan out from the base: pale ones behind, lotus pink in front
    final base = Offset(s * 0.5, s * 0.76);
    for (final a in [-70.0, -38.0, 0.0, 38.0, 70.0]) {
      canvas.drawPath(_petal(base, a, s * 0.5, s * 0.2), fill..color = const Color(0xFFF59BBE));
    }

    // the face, on the lotus's golden center
    final face = Offset(s * 0.5, s * 0.42);
    final r = s * 0.17;
    canvas.drawCircle(face + Offset(0, s * 0.015), r, fill..color = AppColors.sunDeep);
    canvas.drawCircle(face, r, fill..color = AppColors.sun);
    for (final dx in [-0.42, 0.42]) {
      final eye = face + Offset(r * dx, -r * 0.12);
      canvas.drawOval(Rect.fromCenter(center: eye, width: s * 0.06, height: s * 0.085),
          fill..color = AppColors.ink);
      canvas.drawCircle(eye + Offset(s * 0.01, -s * 0.017), s * 0.012, fill..color = Colors.white);
      canvas.drawOval(
          Rect.fromCenter(center: face + Offset(r * dx * 1.45, r * 0.28), width: s * 0.075, height: s * 0.042),
          fill..color = AppColors.lotus.withValues(alpha: 0.6));
    }
    // an open "aah" mouth: it's a speech coach
    final mouth = Rect.fromCenter(center: face + Offset(0, r * 0.36), width: r * 0.62, height: r * 0.5);
    final mouthPath = Path()
      ..moveTo(mouth.left, mouth.top)
      ..quadraticBezierTo(mouth.center.dx, mouth.top + mouth.height * 0.12, mouth.right, mouth.top)
      ..quadraticBezierTo(mouth.right, mouth.bottom, mouth.center.dx, mouth.bottom)
      ..quadraticBezierTo(mouth.left, mouth.bottom, mouth.left, mouth.top)
      ..close();
    canvas.drawPath(mouthPath, fill..color = AppColors.ink);
    canvas.save();
    canvas.clipPath(mouthPath);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(mouth.center.dx, mouth.bottom), width: mouth.width * 0.7, height: mouth.height * 0.7),
        fill..color = AppColors.lotus);
    canvas.restore();

    // front petals cup the face from below
    for (final a in [-64.0, -32.0, 32.0, 64.0]) {
      canvas.drawPath(_petal(base, a, s * 0.28, s * 0.15), fill..color = AppColors.lotus);
    }
    canvas.drawPath(_petal(base, 0, s * 0.15, s * 0.13), fill..color = AppColors.lotusDeep);

    // sparkles
    _sparkle(canvas, Offset(s * 0.12, s * 0.2), s * 0.065, AppColors.sun);
    _sparkle(canvas, Offset(s * 0.88, s * 0.28), s * 0.05, Colors.white);
    _sparkle(canvas, Offset(s * 0.84, s * 0.08), s * 0.035, AppColors.lotus);
    _sparkle(canvas, Offset(s * 0.2, s * 0.05), s * 0.03, Colors.white);
  }

  /// A pointed petal from [base], tilted [degrees] from straight up.
  Path _petal(Offset base, double degrees, double length, double width) {
    final t = degrees * math.pi / 180;
    final dir = Offset(math.sin(t), -math.cos(t));
    final side = Offset(math.cos(t), math.sin(t)) * width;
    final tip = base + dir * length;
    final mid = base + dir * (length * 0.55);
    return Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo((mid + side).dx, (mid + side).dy, tip.dx, tip.dy)
      ..quadraticBezierTo((mid - side).dx, (mid - side).dy, base.dx, base.dy)
      ..close();
  }

  /// A four-pointed twinkle.
  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LotusBuddyPainter old) => false;
}
