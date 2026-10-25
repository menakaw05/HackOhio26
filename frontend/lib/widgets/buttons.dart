import 'package:flutter/material.dart';
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
    final style = color == null ? null : FilledButton.styleFrom(backgroundColor: color);
    final tap = _withHaptic(onPressed);
    final button = icon == null
        ? FilledButton(style: style, onPressed: tap, child: Text(label))
        : FilledButton.icon(style: style, onPressed: tap, icon: Icon(icon), label: Text(label));
    return PressScale(
      enabled: onPressed != null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
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
    final tap = _withHaptic(onPressed);
    final button = icon == null
        ? OutlinedButton(onPressed: tap, child: Text(label))
        : OutlinedButton.icon(onPressed: tap, icon: Icon(icon), label: Text(label));
    return PressScale(
      enabled: onPressed != null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
