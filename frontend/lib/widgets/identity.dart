import 'dart:async';
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

/// How the octopus is feeling: [listening] wiggles faster with an "o" mouth, [happy] waves
/// its arms with a big smile.
enum BuddyMood { idle, listening, happy }

/// The mascot: a pink octopus that wiggles its arms and blows bubbles. Pops in when it
/// appears and cheers when tapped. Holds still with Reduce Motion (tests turn that on).
class OctopusBuddy extends StatefulWidget {
  const OctopusBuddy({super.key, this.size = 160, this.mood = BuddyMood.idle, this.bubbles = true});

  final double size;
  final BuddyMood mood;
  final bool bubbles;

  @override
  State<OctopusBuddy> createState() => _OctopusBuddyState();
}

class _OctopusBuddyState extends State<OctopusBuddy> with TickerProviderStateMixin {
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _wiggle = AnimationController(vsync: this);
  bool _cheering = false; // a short cheer after a tap
  Timer? _cheerTimer;

  BuddyMood get _mood => _cheering ? BuddyMood.happy : widget.mood;

  void _sync() {
    if (reduceMotion(context)) {
      _pop.value = 1;
      _wiggle.stop();
      return;
    }
    if (_pop.value == 0 && !_pop.isAnimating) _pop.forward();
    _wiggle.duration = switch (_mood) {
      BuddyMood.idle => const Duration(milliseconds: 2600),
      BuddyMood.listening => const Duration(milliseconds: 1300),
      BuddyMood.happy => const Duration(milliseconds: 800),
    };
    _wiggle.repeat();
  }

  void _cheer() {
    AppHaptics.tap();
    _cheerTimer?.cancel();
    setState(() => _cheering = true);
    _sync();
    _cheerTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _cheering = false);
      _sync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OctopusBuddy old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _sync();
  }

  @override
  void dispose() {
    _cheerTimer?.cancel();
    _pop.dispose();
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = _mood;
    return Semantics(
      label: 'mirrorU octopus',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _cheer,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _wiggle,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _OctopusPainter(
                t: _wiggle.value,
                mood: mood,
                bubbles: widget.bubbles,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OctopusPainter extends CustomPainter {
  _OctopusPainter({required this.t, required this.mood, required this.bubbles});

  final double t; // 0-1, one wiggle
  final BuddyMood mood;
  final bool bubbles;

  static const _body = AppColors.lotus;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final phase = t * 2 * math.pi;
    final amp = switch (mood) {
      BuddyMood.idle => 1.0,
      BuddyMood.listening => 1.3,
      BuddyMood.happy => 2.2,
    };
    final edge = AppColors.edgeOf(_body);
    final fill = Paint()..isAntiAlias = true;

    // six arms behind the head, each swaying a little out of step with the next
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.085;
    for (var i = 0; i < 6; i++) {
      final u = (i - 2.5) / 2.5; // -1 (left) to 1 (right)
      final dir = u < 0 ? -1.0 : 1.0;
      final lift = mood == BuddyMood.happy ? s * 0.14 * u.abs() : 0.0; // arms up to cheer
      final w = math.sin(phase + i * 1.3) * amp * s * 0.045;
      final base = Offset(s * (0.5 + u * 0.2), s * 0.56);
      final end = Offset(s * (0.5 + u * 0.34) + w * 0.4, s * (0.87 - u.abs() * 0.08) - lift);
      final c1 = base + Offset(u * s * 0.06 + w * 0.6, s * 0.14);
      final c2 = end + Offset(-u * s * 0.04 - w, -s * 0.12);
      final curl = end + Offset(dir * s * 0.06 + w * 0.3, -s * 0.05);
      final path = Path()
        ..moveTo(base.dx, base.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy)
        ..quadraticBezierTo(end.dx + dir * s * 0.05, end.dy + s * 0.05, curl.dx, curl.dy);
      canvas.drawPath(path.shift(Offset(0, s * 0.015)), arm..color = edge);
      canvas.drawPath(path, arm..color = _body);
      // suckers along the lower half
      final metric = path.computeMetrics().first;
      for (final at in [0.55, 0.7, 0.85]) {
        final pos = metric.getTangentForOffset(metric.length * at)?.position;
        if (pos != null) canvas.drawCircle(pos, s * 0.013, fill..color = AppColors.lotusBlush);
      }
    }

    // head, bobbing with the arms
    final bob = math.sin(phase) * s * 0.012 * amp;
    final head = Rect.fromCenter(center: Offset(s * 0.5, s * 0.4 + bob), width: s * 0.62, height: s * 0.56);
    final c = head.center;
    canvas.drawOval(head.shift(Offset(0, s * 0.02)), fill..color = edge);
    canvas.drawOval(head, fill..color = _body);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(-s * 0.14, -s * 0.16), width: s * 0.12, height: s * 0.06),
        fill..color = Colors.white.withValues(alpha: 0.45));
    for (final (dx, dy, r) in [(0.17, -0.13, 0.03), (0.23, -0.03, 0.02), (-0.21, 0.0, 0.018)]) {
      canvas.drawCircle(c + Offset(s * dx, s * dy), s * r, fill..color = AppColors.lotusBlush);
    }

    // eyes: round and shiny, or happy "^ ^" while cheering
    final ink = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;
    for (final dx in [-0.11, 0.11]) {
      final eye = c + Offset(s * dx, s * 0.01);
      if (mood == BuddyMood.happy) {
        canvas.drawArc(Rect.fromCenter(center: eye + Offset(0, s * 0.02), width: s * 0.08, height: s * 0.07),
            math.pi * 1.1, math.pi * 0.8, false, ink);
      } else {
        canvas.drawOval(Rect.fromCenter(center: eye, width: s * 0.11, height: s * 0.13), fill..color = Colors.white);
        canvas.drawCircle(eye + Offset(0, s * 0.012), s * 0.034, fill..color = AppColors.ink);
        canvas.drawCircle(eye + Offset(s * 0.01, -s * 0.004), s * 0.012, fill..color = Colors.white);
      }
      canvas.drawOval(Rect.fromCenter(center: c + Offset(s * dx * 1.75, s * 0.1), width: s * 0.08, height: s * 0.045),
          fill..color = AppColors.lotusDeep.withValues(alpha: 0.45));
    }

    // mouth: a smile, an "o" while listening, wide open while cheering
    final m = c + Offset(0, s * 0.12);
    switch (mood) {
      case BuddyMood.idle:
        canvas.drawPath(
            Path()
              ..moveTo(m.dx - s * 0.05, m.dy - s * 0.012)
              ..quadraticBezierTo(m.dx, m.dy + s * 0.04, m.dx + s * 0.05, m.dy - s * 0.012),
            ink);
      case BuddyMood.listening:
        canvas.drawOval(Rect.fromCenter(center: m, width: s * 0.06, height: s * 0.07), fill..color = AppColors.ink);
      case BuddyMood.happy:
        final r = Rect.fromCenter(center: m + Offset(0, s * 0.01), width: s * 0.13, height: s * 0.09);
        final mouth = Path()
          ..moveTo(r.left, r.top)
          ..quadraticBezierTo(r.center.dx, r.top + r.height * 0.15, r.right, r.top)
          ..quadraticBezierTo(r.right, r.bottom, r.center.dx, r.bottom)
          ..quadraticBezierTo(r.left, r.bottom, r.left, r.top)
          ..close();
        canvas.drawPath(mouth, fill..color = AppColors.ink);
        canvas.save();
        canvas.clipPath(mouth);
        canvas.drawOval(Rect.fromCenter(center: Offset(r.center.dx, r.bottom), width: r.width * 0.7, height: r.height),
            fill..color = AppColors.lotusBlush);
        canvas.restore();
    }

    // bubbles drifting up past its head
    if (bubbles) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.01;
      for (var k = 0; k < 3; k++) {
        final p = (t + k / 3) % 1;
        final pos = Offset(s * (0.86 - k * 0.05) + math.sin(p * 6) * s * 0.015, s * (0.4 - p * 0.36));
        final r = s * (0.022 + k * 0.008);
        final a = (1 - p).clamp(0.0, 1.0);
        canvas.drawCircle(pos, r, ring..color = AppColors.sky.withValues(alpha: 0.8 * a));
        canvas.drawCircle(pos + Offset(-r * 0.35, -r * 0.35), r * 0.25,
            fill..color = Colors.white.withValues(alpha: 0.9 * a));
      }
    }
  }

  @override
  bool shouldRepaint(_OctopusPainter old) => old.t != t || old.mood != mood || old.bubbles != bubbles;
}
