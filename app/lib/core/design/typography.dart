/// V8/D147 · §3.2 字体族与字号阶梯（从 tokens.dart 拆出，R73 单文件 ≤300 行）。
///
/// 与 tokens.dart 同属设计令牌体系，**由 tokens.dart 原样 `export`**，
/// 因此既有 `import '.../core/design/tokens.dart'` 的调用方无需改动。
library;

import 'package:flutter/material.dart';

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

/// 字号数值的**编译期常量**镜像（R71）。
///
/// 为什么需要它：Dart 的枚举成员属性（`AppFontSize.caption`）不是编译期常量，
/// 因此无法写进 `const TextStyle(fontSize: …)`。而仓库里有大量
/// `const TextStyle(fontSize: 11)` 这样的字面量正是要消灭的对象 —— 若唯一的
/// 取值方式不可用于 const 上下文，就只能保留字面量，R71 永远收不了口。
///
/// 所以数值真相放在这里（`static const double`），[AppType] 的每一档都引用
/// 同一个常量，两者不可能漂移；测试用 [AppType.bySize] 交叉验证二者一致。
abstract final class AppFontSize {
  // —— 合同锁定的七档（数值不可动，D147）——
  static const double display = 40;
  static const double h1 = 28;
  static const double h2 = 22;
  static const double h3 = 17;
  static const double body = 14;
  static const double small = 12.5;
  static const double caption = 11;

  // —— 档间细阶（R71 收口补齐，等值对应既有字面量）——
  static const double h1Lg = 26;
  static const double h2Lg = 24;
  static const double subhead = 20;
  static const double h3Lg = 18;
  static const double bodyXl = 16;
  static const double bodyLg = 15;
  static const double smallXl = 13.5;
  static const double smallLg = 13;
  static const double smallSm = 12;
  static const double captionLg = 11.5;
  static const double tinyLg = 10.5;
  static const double tiny = 10;
  static const double microLg = 9.5;
  static const double micro = 9;
  static const double micro2 = 8.5;
}

/// §3.2 字号阶梯（pt，行高/字号）。
///
/// 合同 §3.2 锁定的七档是 [display] / [h1] / [h2] / [h3] / [body] / [small] /
/// [caption] —— 这七档的**数值不得改动**（D147 锁定口径）。
///
/// R71 收口时补了档间细阶（`micro*` / `tiny*` / `captionLg` / `smallSm` /
/// `smallLg` / `smallXl` / `bodyLg` / `bodyXl` / `h3Lg` / `subhead` /
/// `h2Lg` / `h1Lg`）：仓库里原本散落着 19 个互不相同的字号字面量，若不建档，
/// 只能保留字面量（违反 R71）或粗暴四舍五入（改动既有渲染）。
/// 补档后每个字面量都有一一对应、**数值完全相同**的档位，因此替换是
/// 等值改写：渲染结果不变，也不需要改任何既有断言。
enum AppType {
  // —— 合同锁定的七档（数值不可动，D147）——
  display(AppFontSize.display, 1.2, AppFonts.display),
  h1(AppFontSize.h1, 1.3, AppFonts.display),
  h2(AppFontSize.h2, 1.35, AppFonts.display),
  h3(AppFontSize.h3, 1.4, AppFonts.display),
  body(AppFontSize.body, 1.6, AppFonts.body),
  small(AppFontSize.small, 1.5, AppFonts.body),
  caption(AppFontSize.caption, 1.4, AppFonts.body),

  // —— 档间细阶（R71 收口补齐，等值对应既有字面量）——
  h1Lg(AppFontSize.h1Lg, 1.3, AppFonts.display),
  h2Lg(AppFontSize.h2Lg, 1.35, AppFonts.display),
  subhead(AppFontSize.subhead, 1.4, AppFonts.body),
  h3Lg(AppFontSize.h3Lg, 1.4, AppFonts.display),
  bodyXl(AppFontSize.bodyXl, 1.5, AppFonts.body),
  bodyLg(AppFontSize.bodyLg, 1.55, AppFonts.body),
  smallXl(AppFontSize.smallXl, 1.5, AppFonts.body),
  smallLg(AppFontSize.smallLg, 1.5, AppFonts.body),
  smallSm(AppFontSize.smallSm, 1.5, AppFonts.body),
  captionLg(AppFontSize.captionLg, 1.4, AppFonts.body),
  tinyLg(AppFontSize.tinyLg, 1.4, AppFonts.body),
  tiny(AppFontSize.tiny, 1.4, AppFonts.body),
  microLg(AppFontSize.microLg, 1.4, AppFonts.body),
  micro(AppFontSize.micro, 1.4, AppFonts.body),
  micro2(AppFontSize.micro2, 1.4, AppFonts.body);

  const AppType(this.size, this.lineHeight, this.family);

  /// Eyebrow 字距（§3.2：mono 11pt + 字距 1.5）。
  static const double eyebrowLetterSpacing = 1.5;

  /// 按 pt 数值反查档位。R71 收口补档后，阶梯对 8.5–40 的覆盖是连续的，
  /// 因此任何既字号面量都能换成等值令牌；返回值用于测试与门禁工具自证
  /// 「替换是等值的」，避免有人偷偷改成邻近档位。
  static AppType? bySize(double pt) {
    for (final AppType t in AppType.values) {
      if (t.size == pt) return t;
    }
    return null;
  }

  final double size;
  final double lineHeight;
  final String family;

  /// 标题量级（衬线族 + 默认 w600）。合同锁定的四档，加上 R71 补的
  /// heading 量级细阶（h1Lg/h2Lg/h3Lg）—— 它们只比锁定档大一档，
  /// 语义上仍是标题而非正文。
  bool get isHeading =>
      this == AppType.display ||
      this == AppType.h1 ||
      this == AppType.h2 ||
      this == AppType.h3 ||
      this == AppType.h1Lg ||
      this == AppType.h2Lg ||
      this == AppType.h3Lg;

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
  double size = AppFontSize.caption,
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0.2,
}) => AppType.caption
    .style(color, font: AppFonts.mono, weight: weight)
    .copyWith(fontSize: size, letterSpacing: letterSpacing);
