import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Nunito everywhere: round and chunky, easy for kids to read. It's a variable font, so
/// weight is set through the 'wght' axis as well as fontWeight. Nunito has no IPA letters
/// (ɪ, θ, ʃ…), so those fall back to Inter.
abstract final class AppText {
  static const heading = 'Nunito';
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
  static final wordHero = _style(heading, 64, 1000, height: 1.05, letterSpacing: -1);
  static final display = _style(heading, 34, 1000, height: 1.1, letterSpacing: -0.5);
  static final title = _style(heading, 24, 900, height: 1.2);
  static final section = _style(heading, 20, 900, height: 1.25);
  static final bodyText = _style(body, 17, 600, height: 1.4);
  static final bodyStrong = _style(body, 17, 800, height: 1.4);
  static final caption = _style(body, 14, 700, height: 1.35, color: AppColors.inkSoft);
  static final button = _style(heading, 18, 900, letterSpacing: 0.3);

  /// Read Aloud passages: large with generous line spacing.
  static final reading = _style(heading, 26, 700, height: 1.7);
}
