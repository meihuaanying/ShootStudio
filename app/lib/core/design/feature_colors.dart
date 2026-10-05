import 'package:flutter/painting.dart';

/// §3 领域色令牌（domain colors）。
///
/// R71 要求颜色只允许来自令牌。这些色值不属于 [AppPalette] 的
/// 「纸面亮 / 暗房暗」两套语义角色（不是 bg/surface/ink/accent 那一类），
/// 而是**具体功能自身的固定标识色**，所以单列一份，而不是硬塞进 AppPalette：
///
/// - [poseMark]：骨骼/关节标记橙。摆姿页与关节微调器共用同一色，两处必须一致，
///   否则「调好了」和「看起来是这样」会对不上。
/// - [lightWarm] / [lightCool]：布光预览里暖光与冷光的示意色，属于 CustomPainter
///   内部绘图语义（R71 明令豁免 CustomPainter 内部绘图，但集中在此更利于换肤）。
/// - [sceneFace] / [sceneBackdrop]：布光预览画布里的「脸」与「暗背景」。
/// - [canvasIdle]：画布上未选中相机的中性色。
/// - [panelInk]：冷灰正文色，用于对话框/面板这类非 AppPalette 的中性容器。
abstract final class AppFeatureColor {
  /// 摆姿标记橙。
  static const Color poseMark = Color(0xFFFF8A3D);

  /// 暖光示意色。
  static const Color lightWarm = Color(0xFFFFE8C8);

  /// 冷光示意色。
  static const Color lightCool = Color(0xFFEAF2FF);

  /// 布光预览画布：脸部。
  static const Color sceneFace = Color(0xFF3A342E);

  /// 布光预览画布：暗背景。
  static const Color sceneBackdrop = Color(0xFF17130F);

  /// 画布上未选中相机的中性色。
  static const Color canvasIdle = Color(0xFF5B6B8C);

  /// 对话框/面板的冷灰正文色。
  static const Color panelInk = Color(0xFF8A919E);

  /// 画布上「已连接」状态指示绿。
  static const Color canvasLive = Color(0xFF2BA471);

  /// 中性容器上的浅色文字（模块编辑器的深底反白）。
  static const Color onNeutral = Color(0xFF1F2329);

  /// [onNeutral] 的 80% 不透明变体（压色底/次级文字）。
  static const Color onNeutralSoft = Color(0xCC1F2329);

  /// 灯光示意里的中性描边/辅助线灰。
  static const Color hintInk = Color(0xFFB9B2A8);

  /// 色值字符串解析失败时的占位灰。
  ///
  /// R71 清零前，四个模块各自复制了一份 `Color(0xFF000000 | (int.tryParse(…) ?? 0x888888))`
  /// 的 hex 解析器，兜底色都是这个灰。收编成 [fromHex] 时把它提成具名令牌，
  /// 这样「解析失败长什么样」有了统一且可查的定义，而不是继续散落成魔法数字。
  static const Color invalidHex = Color(0xFF888888);

  /// 压在**饱和/深色填充之上**的浅色前景（文字、图标、chip）。
  ///
  /// 这不是「主题的浅色」——纸面亮与暗房暗的前景色一个近黑一个近白，都不能压在
  /// accent 这类饱和填充上；真正需要的是「压在实心块上仍然可读」的那一个色值。
  /// §3.1 禁纯白**大面积铺底**，指的是页面/面板底色，不含这种小面积的前景色。
  static const Color onFill = Color(0xFFFFFFFF);

  /// 压在照片/缩略图之上的半透明压暗层（图上贴字时用）。
  static const Color imageScrim = Color(0x73000000);

  /// 浅底 chip 的填充色（导出面板的模块序号等）。
  ///
  /// 与 [onFill] 分开是因为语义相反：[onFill] 是「压在实心块上的浅色前景」，
  /// 这里是「浅色块本身」，用在需要靠描边与背景分离的小色块上。
  static const Color chipFill = Color(0xFFFFFFFF);

  /// 解析用户输入的 `#RRGGBB` 颜色串。
  ///
  /// 仓库里有 4 处曾各写一遍 `Color(0xFF000000 | int.tryParse(hex, 16))`，
  /// 靠按位或给 24 位 RGB 补一个不透明 alpha。那写法有三个问题：
  ///   1. 读起来像「纯黑」（§3.1 明令禁纯黑），其实只是借位或补 alpha；
  ///   2. 传进来 8 位带 alpha 的串时结果完全错，但没有任何迹象；
  ///   3. 4 份拷贝，改一处漏三处。
  ///
  /// 所以收口到这里，并显式处理 alpha 位：[fallback] 用于解析失败。
  static Color fromHex(String hex, {Color fallback = chipFill}) {
    String s = hex.trim().replaceFirst('#', '');
    if (s.length == 3) {
      // 允许 #abc 缩写。
      s = s.split('').map((String c) => '$c$c').join();
    }
    final int? v = int.tryParse(s, radix: 16);
    if (v == null || (s.length != 6 && s.length != 8)) return fallback;
    return Color(
      s.length == 8 ? (v >> 24) & 0xFF : 0xFF000000 | (v & 0xFFFFFF),
    );
  }
}
