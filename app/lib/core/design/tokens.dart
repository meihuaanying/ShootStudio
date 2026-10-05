/// V8/D147 · S3 设计系统落地：**设计令牌唯一来源**（合同 §3）。
///
/// R71：任何颜色/字号/字重/间距/圆角/时长只允许引用本文件的令牌，禁止硬编码字面值。
/// R72：S1 锁定后本文件为门禁口径，App 与官网 `web/src/styles/tokens.css` 逐字一致。
/// 旧令牌 `AppTokens`（曾位于 lib/core/theme/tokens.dart）已整体删除（R71/R76：本文件是唯一令牌来源）。
library;

import 'package:flutter/material.dart';

/// R73：字号阶梯与字体族拆到 typography.dart，这里原样转发，
/// 保证既有 `import .../tokens.dart` 的调用方无需改动。
export 'spacing.dart';
export 'typography.dart';

/// 主题变体：纸面亮（paper）/ 暗房暗（darkroom）（§3.1）。
enum AppThemeVariant { paper, darkroom }

/// 单主题色板：十二个语义令牌（§3.1）。
@immutable
class AppPalette {
  const AppPalette({
    required this.variant,
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.rule,
    required this.accent,
    required this.accentSoft,
    required this.film,
    required this.gold,
    required this.danger,
  });

  final AppThemeVariant variant;

  /// 页面底色（暖纸 / 暗房黑）。
  final Color bg;

  /// 卡片/面板底。
  final Color surface;

  /// 凹陷区/图片占位底。
  final Color surfaceSunken;

  /// 主文字。
  final Color ink;

  /// 次文字。
  final Color inkSoft;

  /// 辅助文字。
  final Color muted;

  /// hairline 边框（1px，禁用 2px+）。
  final Color rule;

  /// 印相红：主行动/选中态。
  final Color accent;

  /// 选中底。
  final Color accentSoft;

  /// 胶片绿：成功/正向数据。
  final Color film;

  /// 暖金：强调标签/推荐。
  final Color gold;

  /// 错误。
  final Color danger;

  bool get isPaper => variant == AppThemeVariant.paper;

  Brightness get brightness => isPaper ? Brightness.light : Brightness.dark;

  // 暗房暗各角色的字面值单列成 static const：
  // Dart 不允许在 const 表达式里做实例属性访问（`AppPalette.darkroom.bg` 编译不过），
  // 而 `main.dart` 的错误兜底页、`dev/perf_probe.dart` 这些没有 BuildContext
  // 也拿不到 context.palette 的地方，正需要能在 const 里引用色值。
  // 这里仍是**唯一一份数值定义**：下面的 darkroom 实例引用这些常量，不会漂移。
  static const Color darkroomBg = Color(0xFF131110);
  static const Color darkroomSurface = Color(0xFF1B1815);
  static const Color darkroomSurfaceSunken = Color(0xFF100E0C);
  static const Color darkroomInk = Color(0xFFF0EBE3);
  static const Color darkroomInkSoft = Color(0xFFA8A29A);
  static const Color darkroomMuted = Color(0xFF78716B);
  static const Color darkroomAccent = Color(0xFFD9563F);
  static const Color darkroomGold = Color(0xFFC9A24B);

  /// §3.1 纸面亮（warm paper）。
  static const AppPalette paper = AppPalette(
    variant: AppThemeVariant.paper,
    bg: Color(0xFFFAF7F1),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF3EFE7),
    ink: Color(0xFF1C1917),
    inkSoft: Color(0xFF57534E),
    muted: Color(0xFF8A857C),
    rule: Color(0xFFE4DECF),
    accent: Color(0xFFB43A2B),
    accentSoft: Color(0x14B43A2B),
    film: Color(0xFF2F5D50),
    gold: Color(0xFFA97E2F),
    danger: Color(0xFFB3261E),
  );

  /// §3.1 暗房暗（darkroom）。
  static const AppPalette darkroom = AppPalette(
    variant: AppThemeVariant.darkroom,
    bg: darkroomBg,
    surface: darkroomSurface,
    surfaceSunken: darkroomSurfaceSunken,
    ink: darkroomInk,
    inkSoft: darkroomInkSoft,
    muted: darkroomMuted,
    rule: Color(0xFF2E2A24),
    accent: darkroomAccent,
    accentSoft: Color(0x1FD9563F),
    film: Color(0xFF4E8A77),
    gold: darkroomGold,
    danger: Color(0xFFE06C60),
  );
}

/// §3.6 图片比例锁（图片框只用这三档）。
abstract final class AppFrameRatio {
  static const double threeTwo = 3 / 2;
  static const double fourFive = 4 / 5;
  static const double sixteenNine = 16 / 9;
}

/// §3.1 令牌入口：按主题变体或 BuildContext 解析色板。
abstract final class AppTokensV2 {
  const AppTokensV2._();

  static AppPalette paletteOf(AppThemeVariant variant) =>
      variant == AppThemeVariant.paper ? AppPalette.paper : AppPalette.darkroom;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppPalette.darkroom
      : AppPalette.paper;
}

/// R71 便捷入口：`context.palette` 取当前主题色板。
extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppTokensV2.of(this);
}
