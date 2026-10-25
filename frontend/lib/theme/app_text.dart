import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Fredoka (bubbly, up to 700) for headings and buttons, Nunito (round) for body text. Both
/// are variable fonts, so weight is set through the 'wght' axis as well as fontWeight.
/// Neither has IPA letters (ɪ, θ, ʃ…), so those fall back to Inter.
abstract final class AppText {
  static const heading = 'Fredoka';
  static const body = 'Nunito';

  static TextStyle _style(String family, double size, int weight,
          {double? height, Color color = AppColors.ink, double? letterSpacing}) =>
      TextStyle(
        fontFamily: family,
        fontFamilyFallback: const ['Inter'],
        fontSize: size,
        fontWeight: FontWeight.values[(weight.clamp(100, 900) ~/ 100) - 1],
        fontVariations: [FontVariation('wght', weight.toDouble())],
        height: height,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// The big word on Word Practice and Diagnostic.
  static final wordHero = _style(heading, 66, 700, height: 1.05);
  static final display = _style(heading, 36, 700, height: 1.1);
  static final title = _style(heading, 25, 600, height: 1.2);
  static final section = _style(heading, 21, 600, height: 1.25);
  static final bodyText = _style(body, 17, 600, height: 1.4);
  static final bodyStrong = _style(body, 17, 800, height: 1.4);
  static final caption = _style(body, 14, 700, height: 1.35, color: AppColors.inkSoft);
  static final button = _style(heading, 19, 600, letterSpacing: 0.3);

  /// Read Aloud passages: large with generous line spacing.
  static final reading = _style(body, 26, 700, height: 1.7);
}
