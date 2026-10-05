/// V8/D147 · S3 设计令牌：**间距/圆角/时长/描边**的唯一来源。
///
/// R73：tokens.dart 已超 300 行，本次拆出；旧路径 `import
/// .../tokens.dart` 仍可见到全部令牌（tokens.dart 原样转发）。
library;

import 'package:flutter/material.dart';

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

  /// 1px：仅用于 hairline 级微调。
  static const double n1 = 1;
}

/// [AppRadius] 之外的圆角档，同样是「为保持历史渲染不变」而收编。
abstract final class AppRadiusFine {
  /// 1.5px：空态插画内圈的极小圆角，比 chip(2) 还小。
  static const double n1_5 = 1.5;

  /// 6px：介于 control(4) 与 frame(8) 之间的历史取值。
  static const double n6 = 6;

  /// **合同偏差（§3.3「圆角禁止 >8」）**：器材卡缩略图用了 10px 圆角。
  ///
  /// 这里刻意**保留原值**：把它改成 [AppRadius.frame] 会改变像素、连带重录
  /// golden，而这是视觉决策而非机械清理，应当单独做视觉复核后再统一降档。
  /// 登记见 `docs/qa/v8-r71-deviations.md`。
  static const double oversizeSoft10 = 10;

  /// **合同偏差（§3.3「圆角禁止 >8」）**：器材卡封面用了 20px 圆角。
  /// 同 [oversizeSoft10]，为保渲染不变而原样收编。
  static const double oversizeSoft20 = 20;
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
