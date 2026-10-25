import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// Rounded white tile on a solid ledge. Pass [gradient] for hero cards.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpace.l),
    this.color = AppColors.surface,
    this.gradient,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Gradient? gradient;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    return Semantics(
      button: tap != null,
      label: semanticLabel,
      child: PressScale(
        enabled: tap != null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: AppRadius.cardRadius,
            border: gradient == null ? Border.all(color: AppColors.line, width: 2) : null,
            boxShadow: gradient == null
                ? AppShadows.soft
                : [BoxShadow(color: AppColors.edgeOf(gradient!.colors.last), offset: const Offset(0, 6))],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: AppRadius.cardRadius,
              onTap: tap == null
                  ? null
                  : () {
                      AppHaptics.tap();
                      tap();
                    },
              onLongPress: onLongPress,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
