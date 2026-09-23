/// V7/D139 相机辅助：焦段 → 视野/画幅换算、构图辅助设置与构图线绘制。
/// 与引擎侧 `rig.js focalToFov()` 同口径（全画幅 24mm 传感器高度 → 垂直视场角）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 全画幅传感器尺寸（垂直 24mm / 水平 36mm）。
const double sensorHeightMm = 24.0;
const double sensorWidthMm = 36.0;

/// 垂直视场角（度）。
double verticalFovDeg(double focalMm) =>
    2 * math.atan(sensorHeightMm / (2 * focalMm)) * 180 / math.pi;

/// 水平视场角（度）。
double horizontalFovDeg(double focalMm) =>
    2 * math.atan(sensorWidthMm / (2 * focalMm)) * 180 / math.pi;

/// 指定距离处的画幅高度（米）。
double frameHeightAt(double focalMm, double distanceM) =>
    2 * distanceM * math.tan(verticalFovDeg(focalMm) * math.pi / 360);

/// 指定距离处的画幅宽度（米，按 3:2 全画幅）。
double frameWidthAt(double focalMm, double distanceM) =>
    2 * distanceM * math.tan(horizontalFovDeg(focalMm) * math.pi / 360);

/// 焦段分档标签（超广角/广角/标准/中长焦/长焦）。
String focalClassLabel(int focalMm) {
  if (focalMm <= 21) return '超广角';
  if (focalMm <= 35) return '广角';
  if (focalMm <= 70) return '标准';
  if (focalMm <= 135) return '中长焦';
  return '长焦';
}

/// 构图辅助设置（仅叠加显示，不进入导出图）。
class CameraGuideSettings {
  const CameraGuideSettings({
    this.thirds = true,
    this.safeArea = true,
    this.centerCross = false,
    this.crop = 'none',
    this.info = true,
  });

  /// 三分线（九宫格）。
  final bool thirds;

  /// 安全框（动作安全 95% / 标题安全 90%）。
  final bool safeArea;

  /// 中心十字。
  final bool centerCross;

  /// 裁切预览（none / 16:9 / 9:16 / 1:1 / 2.35:1），裁切外区域压暗。
  final String crop;

  /// 左上角焦段/视野信息。
  final bool info;

  static const List<String> cropOptions = <String>[
    'none',
    '16:9',
    '9:16',
    '1:1',
    '2.35:1',
  ];

  /// 是否有任何叠加可见。
  bool get enabled =>
      thirds || safeArea || centerCross || crop != 'none' || info;

  /// 裁切比例（none → null）。
  double? get cropAspect => switch (crop) {
    '16:9' => 16 / 9,
    '9:16' => 9 / 16,
    '1:1' => 1,
    '2.35:1' => 2.35,
    _ => null,
  };

  CameraGuideSettings copyWith({
    bool? thirds,
    bool? safeArea,
    bool? centerCross,
    String? crop,
    bool? info,
  }) => CameraGuideSettings(
    thirds: thirds ?? this.thirds,
    safeArea: safeArea ?? this.safeArea,
    centerCross: centerCross ?? this.centerCross,
    crop: crop ?? this.crop,
    info: info ?? this.info,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'thirds': thirds,
    'safeArea': safeArea,
    'centerCross': centerCross,
    'crop': crop,
    'info': info,
  };

  static CameraGuideSettings fromJson(Map<String, Object?> json) =>
      CameraGuideSettings(
        thirds: json['thirds'] != false,
        safeArea: json['safeArea'] != false,
        centerCross: json['centerCross'] == true,
        crop: cropOptions.contains(json['crop'])
            ? json['crop']! as String
            : 'none',
        info: json['info'] != false,
      );
}

/// 构图线/安全框绘制（叠加在 3D 预览之上；POV 时使用）。
class CompositionGuidePainter extends CustomPainter {
  const CompositionGuidePainter({
    required this.settings,
    required this.focalMm,
    required this.distanceM,
    required this.color,
  });

  final CameraGuideSettings settings;
  final int focalMm;

  /// 相机到主体距离（米，用于画幅尺寸提示）。
  final double distanceM;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.55);
    final Paint faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.28);
    final Paint shade = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.42);

    // 裁切预览：裁切框外压暗。
    final double? aspect = settings.cropAspect;
    if (aspect != null) {
      final Rect box = _fitRect(size, aspect);
      final Path outside = Path()
        ..addRect(Offset.zero & size)
        ..addRect(box)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(outside, shade);
      canvas.drawRect(box, line);
    }

    if (settings.thirds) {
      for (int i = 1; i <= 2; i++) {
        final double dx = size.width * i / 3;
        final double dy = size.height * i / 3;
        canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), faint);
        canvas.drawLine(Offset(0, dy), Offset(size.width, dy), faint);
      }
    }

    if (settings.safeArea) {
      canvas.drawRect(_inset(size, 0.05), faint);
      canvas.drawRect(_inset(size, 0.10), line);
    }

    if (settings.centerCross) {
      final Offset c = size.center(Offset.zero);
      const double arm = 10;
      canvas.drawLine(c.translate(-arm, 0), c.translate(arm, 0), line);
      canvas.drawLine(c.translate(0, -arm), c.translate(0, arm), line);
    }

    if (settings.info) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text:
              '${focalMm}mm · ${focalClassLabel(focalMm)} · '
              '垂直 ${verticalFovDeg(focalMm.toDouble()).toStringAsFixed(1)}° · '
              '画幅 ${frameHeightAt(focalMm.toDouble(), distanceM).toStringAsFixed(2)}m',
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 16);
      tp.paint(canvas, const Offset(8, 8));
    }
  }

  static Rect _inset(Size size, double fraction) => Rect.fromLTRB(
    size.width * fraction,
    size.height * fraction,
    size.width * (1 - fraction),
    size.height * (1 - fraction),
  );

  /// 在容器内按比例取最大居中矩形（裁切框）。
  static Rect _fitRect(Size size, double aspect) {
    double w = size.width;
    double h = w / aspect;
    if (h > size.height) {
      h = size.height;
      w = h * aspect;
    }
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  @override
  bool shouldRepaint(CompositionGuidePainter old) =>
      old.settings.thirds != settings.thirds ||
      old.settings.safeArea != settings.safeArea ||
      old.settings.centerCross != settings.centerCross ||
      old.settings.crop != settings.crop ||
      old.settings.info != settings.info ||
      old.focalMm != focalMm ||
      old.distanceM != distanceM ||
      old.color != color;
}
