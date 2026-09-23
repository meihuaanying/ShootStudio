import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// V7/D138：A/B 布光对比 —— 逐像素 RGB 平均差（0–255）；差值 > [abDiffThreshold] 记为变化像素。
/// 阈值与 QA 脚本（tool/light_still_qa.mjs）保持一致，便于证据互相对照。
const int abDiffThreshold = 12;

/// 对比缩略尺寸（宽 × 高），与合成图版式一致。
const int abPaneWidth = 480;
const int abPaneHeight = 360;

class AbDiffStats {
  const AbDiffStats({
    required this.meanAbs,
    required this.changedRatio,
    required this.maxDelta,
    required this.pixels,
  });

  /// 全图平均差（0–255）。
  final double meanAbs;

  /// 变化像素占比（差值 > [abDiffThreshold]）。
  final double changedRatio;

  /// 最大单像素差。
  final double maxDelta;

  /// 参与统计的像素数。
  final int pixels;

  /// 结论口径：<2% 轻微 / <10% 中等 / 其余显著。
  String get verdict =>
      changedRatio < 0.02 ? '差异轻微' : (changedRatio < 0.10 ? '差异中等' : '差异显著');

  Map<String, Object?> toJson() => <String, Object?>{
    'meanAbs': double.parse(meanAbs.toStringAsFixed(2)),
    'changedRatio': double.parse(changedRatio.toStringAsFixed(4)),
    'maxDelta': double.parse(maxDelta.toStringAsFixed(1)),
    'pixels': pixels,
    'verdict': verdict,
    'threshold': abDiffThreshold,
  };
}

/// 安全解码（package:image 对非图片字节会抛异常而非返回 null）。
img.Image? _decode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}

/// 计算两张 PNG 的差异统计（内部缩放到同一尺寸后逐像素比较）。
/// 解码失败返回 null。
AbDiffStats? abDiffStats(Uint8List pngA, Uint8List pngB) {
  final img.Image? a = _decode(pngA);
  final img.Image? b = _decode(pngB);
  if (a == null || b == null) return null;
  final img.Image ra = img.copyResize(
    a,
    width: abPaneWidth,
    height: abPaneHeight,
    interpolation: img.Interpolation.average,
  );
  final img.Image rb = img.copyResize(
    b,
    width: abPaneWidth,
    height: abPaneHeight,
    interpolation: img.Interpolation.average,
  );
  double sum = 0;
  double max = 0;
  int changed = 0;
  for (int y = 0; y < abPaneHeight; y++) {
    for (int x = 0; x < abPaneWidth; x++) {
      final img.Pixel pa = ra.getPixel(x, y);
      final img.Pixel pb = rb.getPixel(x, y);
      final double d =
          ((pa.r - pb.r).abs() + (pa.g - pb.g).abs() + (pa.b - pb.b).abs()) / 3;
      sum += d;
      if (d > max) max = d;
      if (d > abDiffThreshold) changed++;
    }
  }
  final int pixels = abPaneWidth * abPaneHeight;
  return AbDiffStats(
    meanAbs: sum / pixels,
    changedRatio: changed / pixels,
    maxDelta: max,
    pixels: pixels,
  );
}

/// 合成 A/B 并排对比图（左 A 右 B + 底部统计，ASCII 标注避免中文字形缺失）。
/// 解码失败返回 null。
Uint8List? abComposeSideBySide(
  Uint8List pngA,
  Uint8List pngB,
  AbDiffStats stats,
) {
  final img.Image? a = _decode(pngA);
  final img.Image? b = _decode(pngB);
  if (a == null || b == null) return null;
  final int footer = 56;
  final img.Image canvas = img.Image(
    width: abPaneWidth * 2,
    height: abPaneHeight + footer,
  );
  img.fill(canvas, color: img.ColorRgb8(17, 21, 29));
  img.compositeImage(
    canvas,
    img.copyResize(
      a,
      width: abPaneWidth,
      height: abPaneHeight,
      interpolation: img.Interpolation.average,
    ),
    dstX: 0,
    dstY: 0,
  );
  img.compositeImage(
    canvas,
    img.copyResize(
      b,
      width: abPaneWidth,
      height: abPaneHeight,
      interpolation: img.Interpolation.average,
    ),
    dstX: abPaneWidth,
    dstY: 0,
  );
  img.drawString(
    canvas,
    'A (frozen)',
    font: img.arial24,
    x: 12,
    y: abPaneHeight + 14,
    color: img.ColorRgb8(230, 235, 245),
  );
  img.drawString(
    canvas,
    'B (after change)',
    font: img.arial24,
    x: abPaneWidth + 12,
    y: abPaneHeight + 14,
    color: img.ColorRgb8(230, 235, 245),
  );
  img.drawString(
    canvas,
    'mean ${stats.meanAbs.toStringAsFixed(2)}/255  '
    'changed ${(stats.changedRatio * 100).toStringAsFixed(1)}%  '
    'max ${stats.maxDelta.toStringAsFixed(0)}',
    font: img.arial14,
    x: 12,
    y: abPaneHeight + 38,
    color: img.ColorRgb8(159, 176, 200),
  );
  return Uint8List.fromList(img.encodePng(canvas));
}

/// A/B 两个冻结槽（dataUrl 为空表示未冻结）。
class AbSlots {
  const AbSlots({this.a, this.b});

  final String? a;
  final String? b;

  bool get hasBoth => (a?.isNotEmpty ?? false) && (b?.isNotEmpty ?? false);

  AbSlots withSlot(String slot, String dataUrl) =>
      slot == 'b' ? AbSlots(a: a, b: dataUrl) : AbSlots(a: dataUrl, b: b);

  AbSlots cleared() => const AbSlots();

  Map<String, Object?> toJson() => <String, Object?>{
    'hasA': a?.isNotEmpty ?? false,
    'hasB': b?.isNotEmpty ?? false,
  };
}
