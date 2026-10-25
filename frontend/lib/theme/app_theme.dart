import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_text.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.lake,
      primary: AppColors.lake,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lakeMist,
      onPrimaryContainer: AppColors.lakeDeep,
      secondary: AppColors.lotus,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.lotusBlush,
      onSecondaryContainer: AppColors.lotusDeep,
      tertiary: AppColors.sky,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
      // system errors (network etc.) only; never used for a child's attempt
      error: AppColors.lotusDeep,
    );

    final textTheme = TextTheme(
      displayLarge: AppText.wordHero,
      displayMedium: AppText.display,
      headlineSmall: AppText.title,
      titleLarge: AppText.title,
      titleMedium: AppText.section,
      titleSmall: AppText.bodyStrong,
      bodyLarge: AppText.bodyText,
      bodyMedium: AppText.bodyText,
      bodySmall: AppText.caption,
      labelLarge: AppText.button,
      labelMedium: AppText.caption,
      labelSmall: AppText.caption,
    );

    const buttonShape = StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppText.body,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.title,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSize.minTouch, AppSize.primaryButton),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          shape: buttonShape,
          textStyle: AppText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSize.minTouch, AppSize.primaryButton),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          shape: buttonShape,
          side: const BorderSide(color: AppColors.lake, width: 2),
          foregroundColor: AppColors.lakeDeep,
          textStyle: AppText.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSize.minTouch, AppSize.minTouch),
          foregroundColor: AppColors.lakeDeep,
          textStyle: AppText.button,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSize.minTouch, AppSize.minTouch),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
        side: BorderSide.none,
        backgroundColor: AppColors.lakeMist,
        labelStyle: AppText.caption.copyWith(color: AppColors.lakeDeep),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: AppRadius.chipRadius,
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.chipRadius,
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.chipRadius,
          borderSide: BorderSide(color: AppColors.lake, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.lakeMist,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
            AppText.caption.copyWith(color: AppColors.ink)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.lakeDeep
                  : AppColors.inkSoft,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.lakeMist,
        selectedIconTheme: const IconThemeData(color: AppColors.lakeDeep),
        unselectedIconTheme: const IconThemeData(color: AppColors.inkSoft),
        selectedLabelTextStyle: AppText.bodyStrong.copyWith(color: AppColors.lakeDeep),
        unselectedLabelTextStyle: AppText.bodyText.copyWith(color: AppColors.inkSoft),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.lakeMist,
          selectedForegroundColor: AppColors.lakeDeep,
          minimumSize: const Size(AppSize.minTouch, AppSize.minTouch),
          textStyle: AppText.bodyStrong,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.bodyText.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
      ),
    );
  }
}
