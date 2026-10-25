import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// "echo" wordmark: sound waves in a lake-blue bubble, with a lotus-pink o.
class EchoLogo extends StatelessWidget {
  const EchoLogo({super.key, this.size = 28, this.onLongPress, this.light = false});

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
          decoration: BoxDecoration(
            gradient: AppGradients.lake,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lakeDeep, width: size * 0.07),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: size * 0.78),
        ),
        SizedBox(width: size * 0.3),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'ech', style: TextStyle(color: light ? Colors.white : AppColors.ink)),
            const TextSpan(text: 'o', style: TextStyle(color: AppColors.lotus)),
          ]),
          style: AppText.display.copyWith(fontSize: size),
        ),
      ],
    );
    return Semantics(
      label: 'echo',
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

/// How the beluga is feeling: [listening] sends its echo waves out faster with an "o"
/// mouth, [happy] wags its tail with a big smile and happy eyes.
enum BuddyMood { idle, listening, happy }

/// The mascot: a beluga, the whale that talks in echoes. It bobs, wags its tail, blows
/// bubbles and sends echo waves out from its round forehead. Pops in when it appears and
/// cheers when tapped. Holds still with Reduce Motion (tests turn that on).
class BelugaBuddy extends StatefulWidget {
  const BelugaBuddy({super.key, this.size = 160, this.mood = BuddyMood.idle, this.bubbles = true});

  final double size;
  final BuddyMood mood;
  final bool bubbles;

  @override
  State<BelugaBuddy> createState() => _BelugaBuddyState();
}

class _BelugaBuddyState extends State<BelugaBuddy> with TickerProviderStateMixin {
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _swim = AnimationController(vsync: this);
  bool _cheering = false; // a short cheer after a tap
  Timer? _cheerTimer;

  BuddyMood get _mood => _cheering ? BuddyMood.happy : widget.mood;

  void _sync() {
    if (reduceMotion(context)) {
      _pop.value = 1;
      _swim.stop();
      return;
    }
    if (_pop.value == 0 && !_pop.isAnimating) _pop.forward();
    _swim.duration = switch (_mood) {
      BuddyMood.idle => const Duration(milliseconds: 2800),
      BuddyMood.listening => const Duration(milliseconds: 1400),
      BuddyMood.happy => const Duration(milliseconds: 900),
    };
    _swim.repeat();
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
  void didUpdateWidget(BelugaBuddy old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _sync();
  }

  @override
  void dispose() {
    _cheerTimer?.cancel();
    _pop.dispose();
    _swim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = _mood;
    return Semantics(
      label: 'echo beluga',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _cheer,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _swim,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _BelugaPainter(t: _swim.value, mood: mood, bubbles: widget.bubbles),
            ),
          ),
        ),
      ),
    );
  }
}

class _BelugaPainter extends CustomPainter {
  _BelugaPainter({required this.t, required this.mood, required this.bubbles});

  final double t; // 0-1, one swim cycle
  final BuddyMood mood;
  final bool bubbles;

  static const _body = Color(0xFFF2F8FA);
  static const _shade = Color(0xFFD6E8EE);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final phase = t * 2 * math.pi;
    final amp = switch (mood) {
      BuddyMood.idle => 1.0,
      BuddyMood.listening => 1.2,
      BuddyMood.happy => 2.0,
    };
    final fill = Paint()..isAntiAlias = true;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.lakeDeep;
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round
      ..color = AppColors.ink;

    // echo waves pulsing out from the melon, the round forehead belugas "click" through
    final melon = Offset(s * 0.83, s * 0.34);
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.022;
    for (var k = 0; k < 3; k++) {
      final p = (t + k / 3) % 1;
      final color = mood == BuddyMood.listening ? AppColors.sky : (k.isEven ? AppColors.lotus : AppColors.sky);
      canvas.drawArc(Rect.fromCircle(center: melon, radius: s * (0.05 + 0.16 * p)), -0.7, 1.4, false,
          wave..color = color.withValues(alpha: (1 - p) * (mood == BuddyMood.idle ? 0.7 : 1)));
    }

    // the whole whale bobs and tilts a little
    canvas.save();
    canvas.translate(0, math.sin(phase) * s * 0.015 * amp);
    canvas.translate(s * 0.47, s * 0.47);
    canvas.rotate(math.sin(phase) * 0.035 * amp);
    canvas.translate(-s * 0.47, -s * 0.47);

    // tail fluke, wagging, tucked behind the end of the body
    final wag = math.sin(phase * 2) * 0.22 * amp;
    for (final (dy, a) in [(-0.075, -0.65), (0.075, 0.65)]) {
      canvas.save();
      canvas.translate(s * 0.09, s * (0.53 + dy));
      canvas.rotate(a + wag);
      final lobe = Rect.fromCenter(center: Offset.zero, width: s * 0.16, height: s * 0.07);
      canvas.drawOval(lobe.shift(Offset(0, s * 0.012)), fill..color = AppColors.lakeDeep);
      canvas.drawOval(lobe, fill..color = _shade);
      canvas.drawOval(lobe, outline);
      canvas.restore();
    }

    // body: a tail stalk on the left, the round melon and short beak on the right
    final body = Path()
      ..moveTo(s * 0.13, s * 0.5)
      ..cubicTo(s * 0.26, s * 0.42, s * 0.38, s * 0.27, s * 0.54, s * 0.25)
      ..cubicTo(s * 0.66, s * 0.17, s * 0.81, s * 0.23, s * 0.8, s * 0.38)
      ..quadraticBezierTo(s * 0.8, s * 0.45, s * 0.775, s * 0.47)
      ..quadraticBezierTo(s * 0.835, s * 0.48, s * 0.82, s * 0.52)
      ..quadraticBezierTo(s * 0.8, s * 0.58, s * 0.72, s * 0.62)
      ..cubicTo(s * 0.62, s * 0.7, s * 0.4, s * 0.7, s * 0.28, s * 0.62)
      ..cubicTo(s * 0.22, s * 0.58, s * 0.18, s * 0.56, s * 0.13, s * 0.56)
      ..close();
    canvas.drawPath(body.shift(Offset(0, s * 0.02)), fill..color = AppColors.lakeDeep);
    canvas.drawPath(body, fill..color = _body);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(Rect.fromLTWH(s * 0.12, s * 0.1, s * 0.56, s * 0.22), fill..color = _shade.withValues(alpha: 0.55));
    canvas.restore();
    canvas.drawPath(body, outline);
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.68, s * 0.26), width: s * 0.09, height: s * 0.045),
        fill..color = Colors.white);

    // flipper, paddling
    canvas.save();
    canvas.translate(s * 0.48, s * 0.66);
    canvas.rotate(0.55 + math.sin(phase * 2) * 0.15 * amp);
    final fin = Rect.fromCenter(center: Offset(s * 0.02, 0), width: s * 0.14, height: s * 0.06);
    canvas.drawOval(fin, fill..color = _shade);
    canvas.drawOval(fin, outline);
    canvas.restore();

    // face: eye (happy "^" while cheering), rosy cheek, and its mouth
    final eye = Offset(s * 0.65, s * 0.39);
    if (mood == BuddyMood.happy) {
      canvas.drawArc(Rect.fromCenter(center: eye + Offset(0, s * 0.015), width: s * 0.06, height: s * 0.05),
          math.pi * 1.1, math.pi * 0.8, false, ink);
    } else {
      canvas.drawOval(Rect.fromCenter(center: eye, width: s * 0.05, height: s * 0.065), fill..color = AppColors.ink);
      canvas.drawCircle(eye + Offset(s * 0.008, -s * 0.012), s * 0.01, fill..color = Colors.white);
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.65, s * 0.5), width: s * 0.065, height: s * 0.035),
        fill..color = AppColors.lotus.withValues(alpha: 0.5));
    switch (mood) {
      case BuddyMood.listening:
        canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.77, s * 0.53), width: s * 0.035, height: s * 0.045),
            fill..color = AppColors.ink);
      case BuddyMood.idle:
      case BuddyMood.happy:
        // the beluga smile, running back from the beak; wider when happy
        final back = mood == BuddyMood.happy ? 0.67 : 0.69;
        canvas.drawPath(
            Path()
              ..moveTo(s * 0.78, s * 0.475)
              ..quadraticBezierTo(s * 0.74, s * (mood == BuddyMood.happy ? 0.57 : 0.54), s * back, s * 0.52),
            ink);
    }
    canvas.restore();

    // bubbles rising from the blowhole
    if (bubbles) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.01;
      for (var k = 0; k < 3; k++) {
        final p = (t + k / 3) % 1;
        final pos = Offset(s * (0.56 - k * 0.04) + math.sin(p * 6) * s * 0.015, s * (0.2 - p * 0.17));
        final r = s * (0.016 + k * 0.006);
        final a = (1 - p).clamp(0.0, 1.0);
        canvas.drawCircle(pos, r, ring..color = AppColors.sky.withValues(alpha: 0.8 * a));
        canvas.drawCircle(pos + Offset(-r * 0.35, -r * 0.35), r * 0.25,
            fill..color = Colors.white.withValues(alpha: 0.9 * a));
      }
    }
  }

  @override
  bool shouldRepaint(_BelugaPainter old) => old.t != t || old.mood != mood || old.bubbles != bubbles;
}
