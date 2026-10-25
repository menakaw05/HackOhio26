import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Spacing scale: 4 / 8 / 12 / 16 / 24 / 32 / 48.
abstract final class AppSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page padding on phones.
  static const double page = l;
}

abstract final class AppRadius {
  static const double card = 28;
  static const double chip = 16;
  static const double pill = 999;

  static const cardRadius = BorderRadius.all(Radius.circular(card));
  static const chipRadius = BorderRadius.all(Radius.circular(chip));
  static const pillRadius = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppSize {
  static const double minTouch = 48;
  static const double primaryButton = 56;
  static const double micButton = 96;
  static const double avatar = 44;

  /// Width at which the shell switches from bottom navigation to a sidebar.
  static const double sidebarBreakpoint = 840;
}

abstract final class AppShadows {
  /// A solid ledge under cards, so they look like chunky tiles.
  static const soft = [
    BoxShadow(color: AppColors.line, offset: Offset(0, 6)),
  ];
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 600);
}
