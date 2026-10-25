import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'feedback_banner.dart';

/// A phoneme, shown as /u/. Colored by [kind] when there's a result for it.
class SoundChip extends StatelessWidget {
  const SoundChip({
    super.key,
    required this.phoneme,
    this.kind,
    this.selected = false,
    this.onTap,
  });

  final String phoneme;
  final FeedbackKind? kind;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = kind?.color ?? AppColors.lake;
    final background = selected ? color : (kind?.softColor ?? AppColors.lakeMist);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: 'Sound $phoneme',
      // a bubble: round, rimmed, with a shine
      child: Material(
        color: background,
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: selected ? 1 : 0.55), width: 2.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 58, minHeight: 58),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '/$phoneme/',
                      style: AppText.section.copyWith(color: selected ? Colors.white : color),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 11,
                top: 9,
                child: Transform.rotate(
                  angle: -0.6,
                  child: Container(
                    width: 13,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: AppRadius.pillRadius,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a queued word came from, e.g. "from Reading · yesterday".
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.label, required this.icon, this.when});

  final String label;
  final IconData icon;
  final String? when;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s, vertical: AppSpace.xs),
      decoration: const BoxDecoration(
        color: AppColors.lotusBlush,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.lotusDeep),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              when == null ? 'from $label' : 'from $label · $when',
              style: AppText.caption.copyWith(color: AppColors.lotusDeep),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill label, e.g. "Prototype" or "Sample data".
class TagBadge extends StatelessWidget {
  const TagBadge({
    super.key,
    required this.label,
    this.color = AppColors.sky,
    this.background = AppColors.skySoft,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.pillRadius),
      child: Text(label,
          style: AppText.caption.copyWith(color: color, fontSize: 12.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }
}
