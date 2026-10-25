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
    final color = kind?.color ?? AppColors.lakeDeep;
    final background = selected ? color : (kind?.softColor ?? AppColors.lakeMist);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: 'Sound $phoneme',
      child: Material(
        color: background,
        borderRadius: AppRadius.chipRadius,
        child: InkWell(
          borderRadius: AppRadius.chipRadius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                minWidth: AppSize.minTouch, minHeight: AppSize.minTouch),
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
          style: AppText.caption.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }
}
