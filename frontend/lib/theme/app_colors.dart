import 'package:flutter/material.dart';

/// mirrorU palette: a lotus on a lake. Teals and blue-greens for the water, lotus pinks for
/// warmth. Feedback colors never use red for a child's attempt.
abstract final class AppColors {
  // brand
  static const lake = Color(0xFF1A9E9A); // primary teal
  static const lakeDeep = Color(0xFF0E5E66);
  static const lakeMist = Color(0xFFDDF3F1);
  static const lotus = Color(0xFFEE7AA5); // accent pink
  static const lotusDeep = Color(0xFFC94F80);
  static const lotusBlush = Color(0xFFFCE6EF);
  static const lilyPad = Color(0xFF5DBB93); // blue-leaning green
  static const lilyPadSoft = Color(0xFFE0F3EA);
  static const sky = Color(0xFF4A8FD6);
  static const skySoft = Color(0xFFE2EEFB);
  static const sun = Color(0xFFFFC94D); // the lotus's golden center: stars and rewards
  static const sunDeep = Color(0xFFE0A21B);

  // neutrals
  static const ink = Color(0xFF15333B);
  static const inkSoft = Color(0xFF52707A);
  static const inkFaint = Color(0xFF8FA7AE);
  static const line = Color(0xFFD5E6E8);
  static const background = Color(0xFFF1F9F8);
  static const surface = Color(0xFFFFFFFF);
  static const shadow = Color(0x1A0E5E66);

  // feedback: success = "Great!", almost = "Almost!", focus = "Let's try again"
  static const success = Color(0xFF2FA67A);
  static const successSoft = Color(0xFFDDF4EA);
  static const almost = Color(0xFFE99A2C);
  static const almostSoft = Color(0xFFFCEFD9);
  static const focus = sky;
  static const focusSoft = skySoft;

  // learner avatar backgrounds
  static const avatarPalette = [lake, lotus, sky, lilyPad, Color(0xFF9B7FD4)];

  /// The darker "edge" under a 3D button, tile or card of this color.
  static Color edgeOf(Color face) => Color.lerp(face, const Color(0xFF0B2F35), 0.28)!;
}

abstract final class AppGradients {
  /// Welcome screen: dawn sky over the lake.
  static const lakeDawn = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFCE6EF), Color(0xFFBFE9E4), Color(0xFF6CC4C0)],
  );

  /// Hero cards and the avatar stage.
  static const lake = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2BB3AC), Color(0xFF2F86C8)],
  );

  static const lotus = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59BBE), Color(0xFFE1679A)],
  );

  /// The avatar's stage: a pond, light in the middle, deeper blue at the edges.
  static const stage = RadialGradient(
    center: Alignment(0, -0.3),
    radius: 1.1,
    colors: [Color(0xFFE6F6F4), Color(0xFF6CC4C0), Color(0xFF2F86C8)],
    stops: [0, 0.6, 1],
  );
}
