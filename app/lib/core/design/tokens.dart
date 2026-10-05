/// V8/D147 · S3 设计系统落地：**设计令牌唯一来源**（合同 §3）。
///
/// R71：任何颜色/字号/字重/间距/圆角/时长只允许引用本文件的令牌，禁止硬编码字面值。
/// R72：S1 锁定后本文件为门禁口径，App 与官网 `web/src/styles/tokens.css` 逐字一致。
/// 旧令牌 `AppTokens`（曾位于 lib/core/theme/tokens.dart）已整体删除（R71/R76：本文件是唯一令牌来源）。
library;

import 'package:flutter/material.dart';

/// R73：字号阶梯与字体族拆到 typography.dart，这里原样转发，
/// 保证既有 `import .../tokens.dart` 的调用方无需改动。
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

/// 遗留微调档（**不在** §3.3 八点刻度内）。
///
/// R71 清零前，这些像素值作为裸数字散落在各处（2/3/5/6/7/9/10/20）。它们多半来自
/// 「在既有刻度上再挤一点」的微调，而不是有意的设计决策。把它们原样收编为令牌，
/// 是为了让 R71「间距只允许引用令牌」这条规则真正可执行——**全程零像素变化**，
/// 所以 golden 基线与视觉回归无需重录。
///
/// 反过来，**新增代码不应使用这一档**：能用 [AppSpace] 的八点刻度就用刻度。
/// 这里的常量存在的唯一理由是「保持历史渲染不变」，不是「这是推荐间距」。
abstract final class AppSpaceFine {
  /// 2px：比最小刻度还小的一半，用于标签与 chip 的紧贴留白。
  static const double n2 = 2;

  /// 3px：极紧留白。
  static const double n3 = 3;

  /// 5px。
  static const double n5 = 5;

  /// 6px：最常见的「刻度减二」微调。
  static const double n6 = 6;

  /// 7px。
  static const double n7 = 7;

  /// 9px。
  static const double n9 = 9;

  /// 10px：最常见的「刻度减二」微调（横向留白）。
  static const double n10 = 10;

  /// 20px：介于 s5(24) 与 s4(16) 之间的历史取值。
  static const double n20 = 20;
}

/// §3.4 之外的一族「非动效时长」：网络超时、轮询间隔、缓存 TTL。
///
/// 这些是「等外部世界多久」的预算，不是过渡动画，混进 [AppMotion] 会让
/// 动效曲线被 I/O 参数污染，所以单列一族。命名按语义而非按数值。
abstract final class AppWait {
  /// 第三方图源 HTTP 超时（§6 图库检索的默认预算）。
  static const Duration source = Duration(seconds: 25);

  /// 通用出网请求超时（net / net_router 默认档）。
  static const Duration network = Duration(seconds: 20);

  /// AI 成案长任务（走 SSE，耐心等）。
  static const Duration aiLong = Duration(seconds: 90);

  /// 轮询间隔（等待后台任务完成）。
  static const Duration poll = Duration(seconds: 3);

  /// 短轮询间隔（渲染帧级别的轻量等待）。
  static const Duration pollFast = Duration(milliseconds: 260);

  /// 检索缓存 TTL。
  static const Duration cacheTtl = Duration(seconds: 40);

  /// 地理编码 / 查询翻译等轻量外部调用。
  static const Duration lookup = Duration(seconds: 6);

  /// 图片检索的端到端预算。
  static const Duration imageSearch = Duration(seconds: 60);

  /// 引擎首帧 / 渲染就绪的等待上限。
  static const Duration engineReady = Duration(seconds: 12);

  /// 引擎交互响应的等待上限。
  static const Duration engineFrame = Duration(seconds: 5);

  /// 齿轮素材同步的容错窗口。
  static const Duration syncGrace = Duration(seconds: 25);

  /// 设备发现扫描的窗口。
  static const Duration discover = Duration(seconds: 10);

  /// 装备图谱批量抓取窗口。
  static const Duration catalogFetch = Duration(seconds: 30);

  /// 调试探针采样窗口。
  static const Duration probeSample = Duration(seconds: 20);

  /// 调试探针的整轮预算。
  static const Duration probeRun = Duration(seconds: 4);

  /// 规划页轮询间隔。
  static const Duration planPoll = Duration(seconds: 3);

  /// 方案详情页淡入时长（贴近 [AppMotion.normal]，此处保留既有像素值）。
  static const Duration planReveal = Duration(milliseconds: 220);

  /// 卡片 hover / 展开的过渡时长。
  static const Duration cardHover = Duration(milliseconds: 260);
}

/// 描边宽度族：只服务 [CircularProgressIndicator] 的环宽与图片投影模糊半径。
///
/// 这些不是「间距」也不是「动效」，是描边几何，单独一族避免污染 [AppSpace]。
abstract final class AppStroke {
  /// 环宽 · 细档：紧凑卡片内的加载环。
  static const double ringThin = 2;

  /// 环宽 · 中档：引擎视图的加载环。
  static const double ringMedium = 2.2;

  /// 环宽 · 粗档：主区域加载环，视觉重量最大的一档。
  static const double ringBold = 2.4;

  /// 缩略图投影的模糊半径。
  static const double thumbShadowBlur = 8;
}

/// 弹层遮罩色（scrim）。
///
/// §3.1 禁纯黑 `#000` 大面积铺底，但对话框/底部抽屉的遮罩本就是一层半透明压暗，
/// 这是唯一允许出现「黑 + alpha」的场合——所以单列一个令牌，避免调用点各自硬写。
abstract final class AppScrim {
  /// 底部抽屉/对话框遮罩：黑 60%。
  static const Color sheet = Color(0x99000000);
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

  /// 胶囊形（chip / 标签 / 头像）。§3.3 禁的是 >8 的**圆角**，
  /// 而 99 表达的是「圆到足以变成胶囊」这一形状意图，不是 99px 的圆角，
  /// 故单列一档并在此说明，避免有人以为可以随便改这个数。
  static const double pill = 999;

  /// 胶囊圆角。
  static const BorderRadius pillBorder = BorderRadius.all(
    Radius.circular(pill),
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
