/// V8/D147 · S3：ThemeData 由 §3 令牌构建（唯一来源：tokens.dart）。
///
/// - 保留 `AppTheme.light()` / `AppTheme.dark()` 入口（R76：旧调用点不破坏）；
/// - 新增 `AppTheme.of(AppThemeVariant)` 与 `AppTheme.paletteOf(context)`；
/// - `lib/core/theme/app_theme.dart` 已改为 @Deprecated 转发壳（R71：一个迭代后删）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// 明暗双主题 ThemeData 构建器（§3.1–§3.4）。
abstract final class AppTheme {
  /// 纸面亮主题。
  static ThemeData light() => of(AppThemeVariant.paper);

  /// 暗房暗主题。
  static ThemeData dark() => of(AppThemeVariant.darkroom);

  /// 按主题变体构建。
  static ThemeData of(AppThemeVariant variant) =>
      _build(AppTokensV2.paletteOf(variant));

  /// 当前 BuildContext 下的色板（组件取色统一入口）。
  static AppPalette paletteOf(BuildContext context) => AppTokensV2.of(context);

  static ThemeData _build(AppPalette p) {
    final Brightness brightness = p.brightness;
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.surface,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: p.accent,
      secondary: p.film,
      onSecondary: p.surface,
      error: p.danger,
      onError: p.surface,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.inkSoft,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceSunken,
      surfaceContainerHighest: p.surfaceSunken,
      surfaceBright: p.surface,
      surfaceDim: p.bg,
      outline: p.rule,
      outlineVariant: p.rule,
      shadow: p.ink,
      scrim: p.ink,
      inverseSurface: p.ink,
      onInverseSurface: p.bg,
      inversePrimary: p.accent,
    );

    // Typography.material2021 断言要求 platform 非空（v1.0.0 灰屏事故根因，见 app_theme 旧注释）。
    final Typography base = Typography.material2021(
      platform: defaultTargetPlatform,
    );
    final TextTheme text =
        (brightness == Brightness.dark ? base.white : base.black)
            .apply(bodyColor: p.ink, displayColor: p.ink)
            .copyWith(
              displayLarge: AppType.display.style(p.ink),
              displayMedium: AppType.display.style(p.ink),
              headlineLarge: AppType.h1.style(p.ink),
              headlineMedium: AppType.h1.style(p.ink),
              headlineSmall: AppType.h2.style(p.ink),
              titleLarge: AppType.h2.style(p.ink),
              titleMedium: AppType.h3.style(p.ink),
              titleSmall: AppType.h3.style(p.ink),
              bodyLarge: AppType.body.style(p.ink),
              bodyMedium: AppType.body.style(p.ink),
              bodySmall: AppType.small.style(p.inkSoft),
              labelLarge: AppType.body.style(p.ink, weight: FontWeight.w600),
              labelMedium: AppType.small.style(p.inkSoft),
              labelSmall: AppType.caption.style(p.muted),
            );

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: AppRadius.controlBorder,
      borderSide: BorderSide(color: color),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.rule,
      textTheme: text,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accentSoft,
      ),
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: p.ink,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlBorder,
          side: BorderSide(color: p.rule),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.frameBorder,
          side: BorderSide(color: p.rule),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.frame),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: AppType.body.style(p.muted),
        labelStyle: AppType.small.style(p.inkSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s3,
        ),
        border: border(p.rule),
        enabledBorder: border(p.rule),
        focusedBorder: border(p.accent),
        errorBorder: border(p.danger),
        focusedErrorBorder: border(p.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s3,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.controlBorder,
          ),
          textStyle: AppType.body.style(p.surface, weight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.rule),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s3,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.controlBorder,
          ),
          textStyle: AppType.body.style(p.ink, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.controlBorder,
          ),
          textStyle: AppType.body.style(p.accent, weight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.inkSoft),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accentSoft,
        side: BorderSide(color: p.rule),
        labelStyle: AppType.small.style(p.ink),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipBorder),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.ink,
        unselectedLabelColor: p.muted,
        indicatorColor: p.accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: p.rule,
        labelStyle: AppType.small.style(p.ink, weight: FontWeight.w600),
        unselectedLabelStyle: AppType.small.style(p.muted),
      ),
      dividerTheme: DividerThemeData(color: p.rule, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceSunken,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.rule,
        thumbColor: p.accent,
        overlayColor: p.accentSoft,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? p.accent : p.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? p.accentSoft
              : p.surfaceSunken,
        ),
        trackOutlineColor: WidgetStatePropertyAll<Color>(p.rule),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: AppType.small.style(p.bg),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.controlBorder,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: AppRadius.chipBorder,
        ),
        textStyle: AppType.caption.style(p.bg),
        waitDuration: AppMotion.fast,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
