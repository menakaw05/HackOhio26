import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/app_theme.dart';

/// A winding trail of lesson nodes: done, current, locked.
class LessonPath extends StatelessWidget {
  const LessonPath({super.key, required this.lessons, required this.onOpen});

  final List<LessonNode> lessons;
  final ValueChanged<LessonNode> onOpen;

  static const double _rowHeight = 112;
  // left-to-right sway of the trail, as a fraction of the width
  static const _sway = [0.5, 0.25, 0.5, 0.75];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final centers = [
        for (var i = 0; i < lessons.length; i++)
          Offset(width * _sway[i % _sway.length], _rowHeight * i + 36),
      ];
      return SizedBox(
        height: _rowHeight * lessons.length,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _TrailPainter(centers))),
            for (var i = 0; i < lessons.length; i++)
              Positioned(
                left: (centers[i].dx - 60).clamp(0, width - 120),
                top: centers[i].dy - 36,
                width: 120,
                child: _LessonNodeView(
                  lesson: lessons[i],
                  onTap: () {
                    if (lessons[i].status == LessonStatus.locked) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Finish the lesson before this one to unlock it.')));
                    } else {
                      onOpen(lessons[i]);
                    }
                  },
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _LessonNodeView extends StatelessWidget {
  const _LessonNodeView({required this.lesson, required this.onTap});

  final LessonNode lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon, size) = switch (lesson.status) {
      LessonStatus.done => (AppColors.lilyPad, Icons.check_rounded, 60.0),
      LessonStatus.current => (AppColors.lotus, Icons.play_arrow_rounded, 72.0),
      LessonStatus.locked => (AppColors.line, Icons.lock_rounded, 60.0),
    };
    return Semantics(
      button: true,
      label: '${lesson.title}, ${lesson.status.name}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: 72,
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 4),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Icon(icon,
                      color: lesson.status == LessonStatus.locked
                          ? AppColors.inkFaint
                          : Colors.white,
                      size: 30),
                ),
              ),
            ),
            Text(lesson.title,
                style: AppText.caption.copyWith(
                    color: lesson.status == LessonStatus.locked
                        ? AppColors.inkFaint
                        : AppColors.ink),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.centers);

  final List<Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final a = centers[i - 1];
      final b = centers[i];
      final midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    final paint = Paint()
      ..color = AppColors.lakeMist
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.centers != centers;
}
