import 'package:flutter/material.dart';

/// 设计令牌 —— 对齐 deepseek.com/harness 气质：
/// 大面积留白、克制的品牌色、等宽字体点缀、细腻边框、明暗双主题。
/// 全 App 与官网共用同一份令牌值（web 端见 web/src/styles/tokens.css）。
abstract final class AppTokens {
  // ---- 品牌色（明暗共用） ----
  static const Color accent = Color(0xFF4D6BFE); // harness 式蓝紫
  static const Color accent2 = Color(0xFF7B5CFF); // 渐变副色（橙紫）
  static const Color accentSoft = Color(0x1A4D6BFE);
  static const Color success = Color(0xFF2BA471);
  static const Color warning = Color(0xFFE37318);
  static const Color danger = Color(0xFFD54941);

  // ---- 亮色主题 ----
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F8FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF1F2329);
  static const Color lightMuted = Color(0xFF646A73);
  static const Color lightRule = Color(0xFFE5E7EB);

  // ---- 暗色主题（harness 式深空底） ----
  static const Color darkBg = Color(0xFF0B0E14);
  static const Color darkSurface = Color(0xFF11151D);
  static const Color darkCard = Color(0xFF161B25);
  static const Color darkInk = Color(0xFFE8EAF0);
  static const Color darkMuted = Color(0xFF8A919E);
  static const Color darkRule = Color(0xFF262D3A);

  // ---- 间距（4 的倍数） ----
  static const double s4 = 4,
      s8 = 8,
      s12 = 12,
      s16 = 16,
      s24 = 24,
      s32 = 32,
      s48 = 48,
      s64 = 64;

  // ---- 圆角 ----
  static const double rSm = 6, rMd = 10, rLg = 16, rXl = 24;

  // ---- 动效曲线与时长（完整叙事动效的基底） ----
  static const Duration dFast = Duration(milliseconds: 160);
  static const Duration dNormal = Duration(milliseconds: 320);
  static const Duration dSlow = Duration(milliseconds: 640);
  static const Curve cEmphasis = Curves.easeOutCubic;
  static const Curve cSpring = Curves.easeOutBack;

  // ---- 等宽字体（版本号、坐标、参数读数） ----
  static const String monoFamily = 'JetBrains Mono';
  static const String monoFallback = 'Consolas';

  static TextStyle mono(BuildContext context,
      {double size = 12, Color? color}) {
    final base = DefaultTextStyle.of(context).style;
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: const [monoFallback, 'monospace'],
      fontSize: size,
      color: color ?? base.color,
      letterSpacing: 0.2,
    );
  }
}
