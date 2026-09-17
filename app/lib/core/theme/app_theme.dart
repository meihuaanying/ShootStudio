import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// 明暗双主题 ThemeData 构建器（D12）。
abstract final class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        bg: AppTokens.lightBg,
        surface: AppTokens.lightSurface,
        card: AppTokens.lightCard,
        ink: AppTokens.lightInk,
        muted: AppTokens.lightMuted,
        rule: AppTokens.lightRule,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        bg: AppTokens.darkBg,
        surface: AppTokens.darkSurface,
        card: AppTokens.darkCard,
        ink: AppTokens.darkInk,
        muted: AppTokens.darkMuted,
        rule: AppTokens.darkRule,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color card,
    required Color ink,
    required Color muted,
    required Color rule,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppTokens.accent,
      onPrimary: Colors.white,
      secondary: AppTokens.accent,
      onSecondary: Colors.white,
      error: AppTokens.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
      surfaceContainerHighest: card,
      outline: rule,
      outlineVariant: rule,
    );

    // 注意：Typography.material2021 断言要求 platform 非空（或显式 black+white），
    // platform: null 会在首帧构建时抛出断言——release 下将导致灰屏（v1.0.0 事故根因）。
    final typography = Typography.material2021(platform: defaultTargetPlatform);
    final textTheme = typography.black
        .merge(brightness == Brightness.dark ? typography.white : null)
        .apply(bodyColor: ink, displayColor: ink);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      dividerColor: rule,
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          side: BorderSide(color: rule),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: BorderSide(color: rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: BorderSide(color: rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.rMd)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: rule),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.rMd)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: AppTokens.accentSoft,
        side: BorderSide(color: rule),
        labelStyle: TextStyle(color: ink, fontSize: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rSm)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? AppTokens.darkCard
            : AppTokens.lightInk,
        contentTextStyle: TextStyle(
            color: brightness == Brightness.dark
                ? AppTokens.darkInk
                : Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
