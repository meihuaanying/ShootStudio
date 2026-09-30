/// V8/D147 · S3：**旧令牌已弃用**（保留一个迭代，R71/R76）。
///
/// 新代码一律使用 `core/design/tokens.dart`：
///   色板 `AppPalette` / `AppTokensV2.of(context)` / `context.palette`
///   字号 `AppType` · 间距 `AppSpace` · 圆角 `AppRadius`
///   阴影 `appShadowPaper/appShadowOverlay` · 动效 `AppMotion` · 栅格 `AppGrid`
///   Eyebrow `appEyebrow` · mono 读数 `appMono`
///
/// 全局引用已清零（grep 证据见 docs/qa/v8-s3-design-system.md）；下一个迭代删除本文件。
@Deprecated(
  'V8/D147：旧令牌已弃用，请改用 core/design/tokens.dart（AppTokensV2/AppType/AppSpace…）。',
)
library;

import 'package:flutter/material.dart';

/// V1–V7 令牌（深空蓝紫 harness 气质），V8 起不再使用。
@Deprecated('请改用 core/design/tokens.dart')
abstract final class AppTokens {
  @Deprecated('请改用 AppPalette.accent（core/design/tokens.dart）')
  static const Color accent = Color(0xFF4D6BFE);
  @Deprecated('请改用 AppPalette.film')
  static const Color accent2 = Color(0xFF7B5CFF);
  @Deprecated('请改用 AppPalette.accentSoft')
  static const Color accentSoft = Color(0x1A4D6BFE);
  @Deprecated('请改用 AppPalette.film')
  static const Color success = Color(0xFF2BA471);
  @Deprecated('请改用 AppPalette.gold')
  static const Color warning = Color(0xFFE37318);
  @Deprecated('请改用 AppPalette.danger')
  static const Color danger = Color(0xFFD54941);
  @Deprecated('请改用 AppPalette.bg')
  static const Color lightBg = Color(0xFFFFFFFF);
  @Deprecated('请改用 AppPalette.surface')
  static const Color lightSurface = Color(0xFFF7F8FA);
  @Deprecated('请改用 AppPalette.surface')
  static const Color lightCard = Color(0xFFFFFFFF);
  @Deprecated('请改用 AppPalette.ink')
  static const Color lightInk = Color(0xFF1F2329);
  @Deprecated('请改用 AppPalette.inkSoft')
  static const Color lightMuted = Color(0xFF646A73);
  @Deprecated('请改用 AppPalette.rule')
  static const Color lightRule = Color(0xFFE5E7EB);
  @Deprecated('请改用 AppPalette.bg（darkroom）')
  static const Color darkBg = Color(0xFF0B0E14);
  @Deprecated('请改用 AppPalette.surface（darkroom）')
  static const Color darkSurface = Color(0xFF11151D);
  @Deprecated('请改用 AppPalette.surface（darkroom）')
  static const Color darkCard = Color(0xFF161B25);
  @Deprecated('请改用 AppPalette.ink（darkroom）')
  static const Color darkInk = Color(0xFFE8EAF0);
  @Deprecated('请改用 AppPalette.inkSoft（darkroom）')
  static const Color darkMuted = Color(0xFF8A919E);
  @Deprecated('请改用 AppPalette.rule（darkroom）')
  static const Color darkRule = Color(0xFF262D3A);
  @Deprecated('请改用 AppSpace.s1')
  static const double s4 = 4;
  @Deprecated('请改用 AppSpace.s2')
  static const double s8 = 8;
  @Deprecated('请改用 AppSpace.s3')
  static const double s12 = 12;
  @Deprecated('请改用 AppSpace.s4')
  static const double s16 = 16;
  @Deprecated('请改用 AppSpace.s5')
  static const double s24 = 24;
  @Deprecated('请改用 AppSpace.s6')
  static const double s32 = 32;
  @Deprecated('请改用 AppSpace.s7')
  static const double s48 = 48;
  @Deprecated('请改用 AppSpace.s8')
  static const double s64 = 64;
  @Deprecated('请改用 AppRadius.chip')
  static const double rSm = 6;
  @Deprecated('请改用 AppRadius.control')
  static const double rMd = 10;
  @Deprecated('请改用 AppRadius.frame')
  static const double rLg = 16;
  @Deprecated('请改用 AppRadius.frame')
  static const double rXl = 24;
  @Deprecated('请改用 AppMotion.fast')
  static const Duration dFast = Duration(milliseconds: 160);
  @Deprecated('请改用 AppMotion.normal')
  static const Duration dNormal = Duration(milliseconds: 320);
  @Deprecated('请改用 AppMotion.slow')
  static const Duration dSlow = Duration(milliseconds: 640);
  @Deprecated('请改用 AppMotion.curve')
  static const Curve cEmphasis = Curves.easeOutCubic;
  @Deprecated('请改用 AppMotion.curve')
  static const Curve cSpring = Curves.easeOutBack;
  @Deprecated('请改用 AppFonts.mono')
  static const String monoFamily = 'JetBrains Mono';
  @Deprecated('请改用 AppFonts.monoFallback')
  static const String monoFallback = 'Consolas';

  @Deprecated('请改用 appMono(color, size: ...)（core/design/tokens.dart）')
  static TextStyle mono(
    BuildContext context, {
    double size = 12,
    Color? color,
  }) {
    final TextStyle base = DefaultTextStyle.of(context).style;
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: const <String>[monoFallback, 'monospace'],
      fontSize: size,
      color: color ?? base.color,
      letterSpacing: 0.2,
    );
  }
}
