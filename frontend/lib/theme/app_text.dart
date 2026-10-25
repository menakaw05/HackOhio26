import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Nunito (rounded) for headings, Inter for body. Both are variable fonts, so weight is set
/// through the 'wght' axis as well as fontWeight.
abstract final class AppText {
  static const heading = 'Nunito';
  static const body = 'Inter';

  static TextStyle _style(String family, double size, int weight,
          {double? height, Color color = AppColors.ink, double? letterSpacing}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [FontVariation('wght', weight.toDouble())],
        height: height,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// The big word on Word Practice and Diagnostic.
  static final wordHero = _style(heading, 56, 900, height: 1.1);
  static final display = _style(heading, 32, 900, height: 1.15);
  static final title = _style(heading, 24, 800, height: 1.2);
  static final section = _style(heading, 19, 800, height: 1.25);
  static final bodyText = _style(body, 16, 400, height: 1.45);
  static final bodyStrong = _style(body, 16, 600, height: 1.45);
  static final caption = _style(body, 13, 500, height: 1.35, color: AppColors.inkSoft);
  static final button = _style(heading, 17, 800, letterSpacing: 0.2);

  /// Read Aloud passages: large with generous line spacing.
  static final reading = _style(heading, 26, 700, height: 1.7);
}
