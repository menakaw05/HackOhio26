import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

VoidCallback? _withHaptic(VoidCallback? onPressed) => onPressed == null
    ? null
    : () {
        AppHaptics.tap();
        onPressed();
      };

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final face = color ?? AppColors.lake;
    return ChunkyButton(
      label: label,
      icon: icon,
      expand: expand,
      onPressed: _withHaptic(onPressed),
      face: face,
      edge: AppColors.edgeOf(face),
      foreground: Colors.white,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return ChunkyButton(
      label: label,
      icon: icon,
      expand: expand,
      onPressed: _withHaptic(onPressed),
      face: AppColors.surface,
      edge: AppColors.line,
      border: AppColors.line,
      foreground: AppColors.lakeDeep,
    );
  }
}

/// A pill that sits on a darker edge and presses down into it, like a game button.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.face,
    required this.edge,
    required this.foreground,
    this.icon,
    this.border,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color face;
  final Color edge;
  final Color foreground;
  final IconData? icon;
  final Color? border;
  final bool expand;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  static const _depth = 5.0;
  bool _down = false;

  void _press(bool down) {
    if (widget.onPressed != null && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final face = enabled ? widget.face : AppColors.line;
    final foreground = enabled ? widget.foreground : AppColors.inkFaint;
    final icon = widget.icon;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: foreground, size: 24),
          const SizedBox(width: AppSpace.s),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: AppText.button.copyWith(color: foreground),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
    final button = AnimatedPadding(
      duration: const Duration(milliseconds: 60),
      // the face moves down into the edge while pressed; the total height stays the same
      padding: EdgeInsets.only(
        top: _down ? _depth : 0,
        bottom: _down ? 0 : _depth,
      ),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: AppSize.primaryButton - _depth,
          minWidth: AppSize.minTouch,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.s,
        ),
        decoration: BoxDecoration(
          color: face,
          borderRadius: AppRadius.pillRadius,
          border: widget.border == null
              ? null
              : Border.all(color: widget.border!, width: 2.5),
          boxShadow: _down || !enabled
              ? null
              : [
                  BoxShadow(
                    color: widget.edge,
                    offset: const Offset(0, _depth),
                  ),
                ],
        ),
        child: Center(
          widthFactor: widget.expand ? null : 1,
          heightFactor: 1,
          child: content,
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onPressed,
        child: widget.expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
