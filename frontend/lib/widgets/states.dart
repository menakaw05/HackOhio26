import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.s),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: AppText.section))),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.lakeMist,
            child: Icon(icon, size: 32, color: AppColors.lake),
          ),
          const SizedBox(height: AppSpace.m),
          Text(title, style: AppText.section, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(message!, style: AppText.caption, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: AppSpace.l), action!],
        ],
      ),
    );
  }
}

/// Dashed placeholder for features whose backend or setup isn't ready yet.
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.label,
    this.icon = Icons.hourglass_empty_rounded,
    this.height = 160,
    this.detail,
  });

  final String label;
  final IconData icon;

  /// Minimum height; null fills the parent.
  final double? height;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, coming soon',
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: double.infinity,
            minHeight: height ?? 0,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              mainAxisSize: height == null ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.inkFaint, size: 32),
                const SizedBox(height: AppSpace.s),
                Text(label, style: AppText.bodyStrong.copyWith(color: AppColors.inkSoft),
                    textAlign: TextAlign.center),
                Text('Coming soon', style: AppText.caption),
                if (detail != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(detail!, style: AppText.caption, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1), const Radius.circular(AppRadius.card));
    canvas.drawRRect(rrect, Paint()..color = AppColors.lakeMist.withValues(alpha: 0.5));

    final paint = Paint()
      ..color = AppColors.inkFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dash = 8.0;
    const gap = 6.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

/// Friendly error card. Uses the calm focus blue, never red.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = "Let's try that again.",
    this.actionLabel = 'Try again',
    this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.focusSoft,
            child: Icon(Icons.cloud_off_rounded, size: 32, color: AppColors.focus),
          ),
          const SizedBox(height: AppSpace.m),
          Text(title, style: AppText.section, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.xs),
          Text(message, style: AppText.caption, textAlign: TextAlign.center),
          if (onAction != null) ...[
            const SizedBox(height: AppSpace.l),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder shown while something loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = AppRadius.chip});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final x = _controller.value * 3 - 1;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(x - 1, 0),
                end: Alignment(x + 1, 0),
                colors: const [AppColors.lakeMist, AppColors.surface, AppColors.lakeMist],
              ),
            ),
          );
        },
      ),
    );
  }
}
