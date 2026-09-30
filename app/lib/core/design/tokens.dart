/// V8/D147 · S3 设计系统落地：**设计令牌唯一来源**（合同 §3）。
///
/// R71：任何颜色/字号/字重/间距/圆角/时长只允许引用本文件的令牌，禁止硬编码字面值。
/// R72：S1 锁定后本文件为门禁口径，App 与官网 `web/src/styles/tokens.css` 逐字一致。
/// 旧令牌 `AppTokens`（lib/core/theme/tokens.dart）已 @Deprecated，一个迭代后删除（R71/R76）。
library;

import 'package:flutter/material.dart';

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
    bg: Color(0xFF131110),
    surface: Color(0xFF1B1815),
    surfaceSunken: Color(0xFF100E0C),
    ink: Color(0xFFF0EBE3),
    inkSoft: Color(0xFFA8A29A),
    muted: Color(0xFF78716B),
    rule: Color(0xFF2E2A24),
    accent: Color(0xFFD9563F),
    accentSoft: Color(0x1FD9563F),
    film: Color(0xFF4E8A77),
    gold: Color(0xFFC9A24B),
    danger: Color(0xFFE06C60),
  );
}

/// §3.2 字体族。
abstract final class AppFonts {
  /// 展示/标题：Noto Serif SC（随包子集，OFL）。
  static const String display = 'NotoSerifSC';

  /// 正文：系统无衬线（Windows: Microsoft YaHei UI；Android: Roboto）。
  static const String body = 'Microsoft YaHei';

  /// 数据读数：JetBrains Mono（延续）。
  static const String mono = 'JetBrainsMono';

  /// 回退链（渲染引擎缺失时按序回退）。
  static const List<String> displayFallback = <String>['Songti SC', 'SimSun'];
  // mono 字体无 CJK 字形 → 末尾追加正文字族，保证 eyebrow/KV 里的中文不出现豆腐块。
  static const List<String> monoFallback = <String>[
    'Consolas',
    'monospace',
    'Microsoft YaHei',
    'Noto Sans SC',
  ];
}

/// §3.2 字号阶梯（pt，行高/字号）。
enum AppType {
  display(40, 1.2, AppFonts.display),
  h1(28, 1.3, AppFonts.display),
  h2(22, 1.35, AppFonts.display),
  h3(17, 1.4, AppFonts.display),
  body(14, 1.6, AppFonts.body),
  small(12.5, 1.5, AppFonts.body),
  caption(11, 1.4, AppFonts.body);

  const AppType(this.size, this.lineHeight, this.family);

  /// Eyebrow 字距（§3.2：mono 11pt + 字距 1.5）。
  static const double eyebrowLetterSpacing = 1.5;

  final double size;
  final double lineHeight;
  final String family;

  bool get isHeading =>
      this == AppType.display ||
      this == AppType.h1 ||
      this == AppType.h2 ||
      this == AppType.h3;

  TextStyle style(
    Color ink, {
    String? font,
    FontWeight? weight,
    double? spacing,
  }) => TextStyle(
    fontFamily: font ?? family,
    fontFamilyFallback: font == AppFonts.mono
        ? AppFonts.monoFallback
        : font == AppFonts.display
        ? AppFonts.displayFallback
        : null,
    fontSize: size,
    height: lineHeight,
    fontWeight: weight ?? (isHeading ? FontWeight.w600 : FontWeight.w400),
    color: ink,
    letterSpacing: spacing,
  );
}

/// Eyebrow 眉题：mono 11pt + 字距 1.5（画册风标志性元素，§3.2）。
TextStyle appEyebrow(Color color) => AppType.caption
    .style(color, font: AppFonts.mono, weight: FontWeight.w500)
    .copyWith(letterSpacing: AppType.eyebrowLetterSpacing);

/// 数据读数样式（mono，§3.2）。
TextStyle appMono(
  Color color, {
  double size = 11,
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0.2,
}) => AppType.caption
    .style(color, font: AppFonts.mono, weight: weight)
    .copyWith(fontSize: size, letterSpacing: letterSpacing);

/// §3.3 8pt 间距体系：4/8/12/16/24/32/48/64。
abstract final class AppSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;

  /// 常用内边距：卡片 16 / 区块 24。
  static const EdgeInsets card = EdgeInsets.all(s4);
  static const EdgeInsets block = EdgeInsets.all(s5);
  static const EdgeInsets rowGap = EdgeInsets.symmetric(horizontal: s3);
}

/// §3.3 圆角：2（标签/chip）/ 4（按钮·输入框·卡片）/ 8（对话框·大图）；禁止 >8。
abstract final class AppRadius {
  static const double chip = 2;
  static const double control = 4;
  static const double frame = 8;

  static const BorderRadius chipBorder = BorderRadius.all(
    Radius.circular(chip),
  );
  static const BorderRadius controlBorder = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius frameBorder = BorderRadius.all(
    Radius.circular(frame),
  );
}

/// §3.3 阴影：仅一级纸感（y=1 blur=4 8% 黑）+ 弹层两级（y=8 blur=24 12%）。
List<BoxShadow> appShadowPaper(Color ink) => <BoxShadow>[
  BoxShadow(
    color: ink.withValues(alpha: 0.08),
    blurRadius: 4,
    offset: const Offset(0, 1),
  ),
];

List<BoxShadow> appShadowOverlay(Color ink) => <BoxShadow>[
  BoxShadow(
    color: ink.withValues(alpha: 0.12),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
];

/// §3.4 动效：fast 160 / normal 280 / slow 420 · easeOutCubic；页面切换 200ms 淡入 + 8px 上浮。
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;
  static const Offset pageRise = Offset(0, 0.008);
}

/// §3.3 栅格：内容区最大宽 1280、12 列、列间距 24、页边距 32（≥1600）/ 24。
abstract final class AppGrid {
  static const double maxContentWidth = 1280;
  static const int columns = 12;
  static const double gutter = AppSpace.s5;

  static double pageMargin(double width) =>
      width >= 1600 ? AppSpace.s6 : AppSpace.s5;

  static double columnWidth(double contentWidth) =>
      (contentWidth - gutter * (columns - 1)) / columns;

  /// 杂志式不对称：按列跨度取宽度（7+5 / 8+4 等）。
  static double span(double contentWidth, double columnsSpan) =>
      columnWidth(contentWidth) * columnsSpan + gutter * (columnsSpan - 1);
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
