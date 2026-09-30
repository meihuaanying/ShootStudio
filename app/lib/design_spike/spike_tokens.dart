/// V8/D147 · S1 设计 spike：设计令牌（§3 唯一来源的 spike 实现）
///
/// 本文件是 S1 spike 的设计探索载体，**不改生产代码**；S3 落地时按本合同 §3
/// 逐字提升为 `lib/core/design/tokens_v2.dart`（`AppTokensV2`），官网侧同步
/// `web/src/styles/tokens.css`（值必须与本文件逐字一致）。
///
/// §3 允许的微调范围：色值明度 ±1 档；字体/栅格/组件结构不可动。
library;

import 'package:flutter/material.dart';

/// 主题枚举：纸面亮 / 暗房暗（§3.1）
enum SpikeThemeMode { paper, darkroom }

/// 单主题色板（§3.1 十二个语义令牌）
@immutable
class SpikePalette {
  const SpikePalette({
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

  final Color bg;
  final Color surface;
  final Color surfaceSunken;
  final Color ink;
  final Color inkSoft;
  final Color muted;
  final Color rule;
  final Color accent;
  final Color accentSoft;
  final Color film;
  final Color gold;
  final Color danger;

  bool get isPaper => bg.computeLuminance() > 0.5;
}

/// §3.1 纸面亮（warm paper）
const SpikePalette kPaperPalette = SpikePalette(
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

/// §3.1 暗房暗（darkroom）
const SpikePalette kDarkroomPalette = SpikePalette(
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

SpikePalette spikePaletteOf(SpikeThemeMode mode) =>
    mode == SpikeThemeMode.paper ? kPaperPalette : kDarkroomPalette;

/// §3.2 字体族
class SpikeFonts {
  /// 展示（Display）/ 标题：Noto Serif SC（随包，OFL）
  static const String display = 'NotoSerifSC';

  /// 正文：系统无衬线（Windows: Microsoft YaHei UI；Android: Roboto；回退 sans）
  static const String body = 'Microsoft YaHei';

  /// 数据（mono）：JetBrains Mono（延续）
  static const String mono = 'JetBrainsMono';
}

/// §3.2 字号阶梯（pt，行高/字号）
enum SpikeType {
  display(40, 1.2, SpikeFonts.display),
  h1(28, 1.3, SpikeFonts.display),
  h2(22, 1.35, SpikeFonts.display),
  h3(17, 1.4, SpikeFonts.display),
  body(14, 1.6, SpikeFonts.body),
  small(12.5, 1.5, SpikeFonts.body),
  caption(11, 1.4, SpikeFonts.body);

  const SpikeType(this.size, this.lineHeight, this.family);

  /// Eyebrow 字距（§3.2：mono 11pt + 字距 1.5）
  static const double eyebrowLetterSpacing = 1.5;

  final double size;
  final double lineHeight;

  /// 该档默认字族（标题衬线 / 正文无衬线；mono 仅用于数据与眉题）
  final String family;

  bool get isHeading =>
      this == SpikeType.display ||
      this == SpikeType.h1 ||
      this == SpikeType.h2 ||
      this == SpikeType.h3;

  TextStyle style(
    Color ink, {
    String? font,
    FontWeight? weight,
    double? spacing,
  }) => TextStyle(
    fontFamily: font ?? family,
    fontSize: size,
    height: lineHeight,
    fontWeight: weight ?? (isHeading ? FontWeight.w600 : FontWeight.w400),
    color: ink,
    letterSpacing: spacing,
  );
}

/// §3.2 Eyebrow（mono 11pt + 字距 1.5 + 大写/全角）——画册风标志性元素
TextStyle spikeEyebrow(Color muted) => SpikeType.caption
    .style(muted, font: SpikeFonts.mono, weight: FontWeight.w500)
    .copyWith(letterSpacing: SpikeType.eyebrowLetterSpacing);

/// §3.3 8pt 间距体系
class SpikeSpace {
  const SpikeSpace._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;
}

/// §3.3 圆角（2 标签 / 4 按钮·输入框·卡片 / 8 对话框·大图；禁止 >8）
class SpikeRadius {
  const SpikeRadius._();
  static const double chip = 2;
  static const double control = 4;
  static const double frame = 8;
}

/// §3.3 阴影（仅一级纸感 + 弹层两级；其余禁用）
List<BoxShadow> spikeShadowPaper(Color ink) => <BoxShadow>[
  BoxShadow(
    color: ink.withValues(alpha: 0.08),
    blurRadius: 4,
    offset: const Offset(0, 1),
  ),
];

List<BoxShadow> spikeShadowOverlay(Color ink) => <BoxShadow>[
  BoxShadow(
    color: ink.withValues(alpha: 0.12),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
];

/// §3.4 动效（fast 160 / normal 280 / slow 420 · easeOutCubic）
class SpikeMotion {
  const SpikeMotion._();
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
}

/// §3.3 栅格：内容区最大宽 1280、12 列、列间距 24、页边距 32（≥1600）/ 24（<1600）
class SpikeGrid {
  const SpikeGrid._();
  static const double maxContentWidth = 1280;
  static const int columns = 12;
  static const double gutter = SpikeSpace.s5;

  static double pageMargin(double width) =>
      width >= 1600 ? SpikeSpace.s6 : SpikeSpace.s5;

  static double columnWidth(double contentWidth) =>
      (contentWidth - gutter * (columns - 1)) / columns;

  /// 杂志式不对称：按列跨度取宽度（7+5 / 8+4 等）
  static double span(double contentWidth, double columnsSpan) =>
      columnWidth(contentWidth) * columnsSpan + gutter * (columnsSpan - 1);
}

/// §3.6 图片比例锁
class SpikeFrameRatio {
  const SpikeFrameRatio._();
  static const double threeTwo = 3 / 2;
  static const double fourFive = 4 / 5;
  static const double sixteenNine = 16 / 9;
}

/// spike 主题（供 S1 样板页与后续 S3 落地共用同一份色板）
ThemeData spikeTheme(SpikeThemeMode mode) {
  final SpikePalette p = spikePaletteOf(mode);
  return ThemeData(
    useMaterial3: true,
    brightness: mode == SpikeThemeMode.paper
        ? Brightness.light
        : Brightness.dark,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.rule,
    colorScheme: ColorScheme(
      brightness: mode == SpikeThemeMode.paper
          ? Brightness.light
          : Brightness.dark,
      primary: p.accent,
      onPrimary: p.surface,
      secondary: p.film,
      onSecondary: p.surface,
      error: p.danger,
      onError: p.surface,
      surface: p.surface,
      onSurface: p.ink,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accentSoft,
    ),
  );
}
