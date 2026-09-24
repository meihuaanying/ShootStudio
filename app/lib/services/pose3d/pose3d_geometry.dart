/// V7/D141：RTMPose/RTMW3D 端上识别 —— 纯 Dart 预处理（与 rtmlib 逐字对齐，R62 离线可测）。
///
/// 口径来源（rtmlib 0.x / mmpose）：
/// - `bbox_xyxy2cs(padding=1.25)` → center/scale；
/// - `top_down_affine((288,384))`：3:4 等比扩展 + 均匀仿射（`cv2.warpAffine`
///   INTER_LINEAR，越界黑边 0，整数坐标约定）；
/// - 归一化 `(x-mean)/std`，ImageNet 常量；**通道顺序 BGR**；
/// - YOLOX letterbox：pad=114、左上角对齐、`cv2.resize` INTER_LINEAR
///   （半像素中心约定）、无归一化（原始 0–255）。
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// 矩形框（原图像素，xyxy）。
class Pose3dBox {
  const Pose3dBox(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  double get width => x2 - x1;
  double get height => y2 - y1;
  double get area => math.max(0, width) * math.max(0, height);

  Map<String, Object?> toJson() => <String, Object?>{
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
  };

  static Pose3dBox fromJson(Map<String, Object?> json) => Pose3dBox(
    (json['x1'] as num).toDouble(),
    (json['y1'] as num).toDouble(),
    (json['x2'] as num).toDouble(),
    (json['y2'] as num).toDouble(),
  );
}

/// 裁剪规格：`bbox_xyxy2cs` + 3:4 扩展后的 center/scale（rtmlib 口径）。
class Pose3dCropSpec {
  const Pose3dCropSpec({
    required this.centerX,
    required this.centerY,
    required this.scaleW,
    required this.outW,
    required this.outH,
  });

  final double centerX;
  final double centerY;

  /// 3:4 扩展后的 scale[0]（`get_warp_matrix` 只用 scale[0] 作为均匀尺度）。
  final double scaleW;
  final int outW;
  final int outH;

  /// 仿射缩放（输出像素 / 原图像素）。
  double get affineScale => outW / scaleW;

  /// `bbox_xyxy2cs(padding)` → 3:4 扩展（与 `top_down_affine` 一致）。
  factory Pose3dCropSpec.fromBox(
    Pose3dBox box, {
    double padding = 1.25,
    int outW = 288,
    int outH = 384,
  }) {
    final double bw = box.width * padding;
    final double bh = box.height * padding;
    final double aspect = outW / outH;
    final double scaleW = bw > bh * aspect ? bw : bh * aspect;
    return Pose3dCropSpec(
      centerX: (box.x1 + box.x2) * 0.5,
      centerY: (box.y1 + box.y2) * 0.5,
      scaleW: scaleW,
      outW: outW,
      outH: outH,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'centerX': centerX,
    'centerY': centerY,
    'scaleW': scaleW,
    'outW': outW,
    'outH': outH,
  };
}

/// ImageNet 归一化常量（rtmlib `RTMPose3d` 默认，BGR 顺序）。
const List<double> kPose3dMean = <double>[123.675, 116.28, 103.53];
const List<double> kPose3dStd = <double>[58.395, 57.12, 57.375];

/// 双线性采样（越界 → 0；RGBA 输入，返回单通道值 0–255）。
double _bilinear(
  Uint8List rgba,
  int w,
  int h,
  double x,
  double y,
  int channel,
) {
  final int x0 = x.floor();
  final int y0 = y.floor();
  final double dx = x - x0;
  final double dy = y - y0;
  double v00 = 0, v10 = 0, v01 = 0, v11 = 0;
  if (x0 >= 0 && x0 < w && y0 >= 0 && y0 < h) {
    v00 = rgba[(y0 * w + x0) * 4 + channel].toDouble();
  }
  if (x0 + 1 >= 0 && x0 + 1 < w && y0 >= 0 && y0 < h) {
    v10 = rgba[(y0 * w + x0 + 1) * 4 + channel].toDouble();
  }
  if (x0 >= 0 && x0 < w && y0 + 1 >= 0 && y0 + 1 < h) {
    v01 = rgba[((y0 + 1) * w + x0) * 4 + channel].toDouble();
  }
  if (x0 + 1 >= 0 && x0 + 1 < w && y0 + 1 >= 0 && y0 + 1 < h) {
    v11 = rgba[((y0 + 1) * w + x0 + 1) * 4 + channel].toDouble();
  }
  final double top = v00 + (v10 - v00) * dx;
  final double bottom = v01 + (v11 - v01) * dx;
  return top + (bottom - top) * dy;
}

/// RTMW3D 预处理：裁剪仿射（`warpAffine` 整数坐标约定）+ BGR + 归一化 → NCHW。
///
/// 返回 float32 `[1,3,outH,outW]` 扁平数组（C 顺序）。
Float32List warpCropBgrNormalized(
  Uint8List rgba,
  int srcW,
  int srcH,
  Pose3dCropSpec spec,
) {
  final int outW = spec.outW;
  final int outH = spec.outH;
  final int plane = outW * outH;
  final Float32List out = Float32List(3 * plane);
  final double s = spec.affineScale;
  final double ox = outW / 2.0;
  final double oy = outH / 2.0;
  for (int y = 0; y < outH; y++) {
    final double sy = (y - oy) / s + spec.centerY;
    for (int x = 0; x < outW; x++) {
      final double sx = (x - ox) / s + spec.centerX;
      final int idx = y * outW + x;
      for (int c = 0; c < 3; c++) {
        // 通道 0/1/2 = B/G/R（RGBA 中 B=2、G=1、R=0）。
        final int srcChannel = 2 - c;
        final double v = _bilinear(rgba, srcW, srcH, sx, sy, srcChannel);
        final double rounded = v.roundToDouble().clamp(0, 255);
        out[c * plane + idx] = (rounded - kPose3dMean[c]) / kPose3dStd[c];
      }
    }
  }
  return out;
}

/// YOLOX letterbox 结果。
class Pose3dLetterbox {
  const Pose3dLetterbox({required this.tensor, required this.ratio});

  /// float32 `[1,3,outH,outW]`（原始 0–255，无归一化）。
  final Float32List tensor;

  /// `min(outH/srcH, outW/srcW)`（后处理还原坐标用）。
  final double ratio;
}

/// YOLOX 预处理：letterbox（pad=114、左上对齐）+ CHW float32（0–255）。
Pose3dLetterbox letterboxChw(
  Uint8List rgba,
  int srcW,
  int srcH,
  int outW,
  int outH, {
  int pad = 114,
}) {
  final double ratio = math.min(outH / srcH, outW / srcW);
  final int rw = (srcW * ratio).toInt();
  final int rh = (srcH * ratio).toInt();
  final int plane = outW * outH;
  final Float32List out = Float32List(3 * plane);
  final double scaleX = rw > 0 ? srcW / rw : 0;
  final double scaleY = rh > 0 ? srcH / rh : 0;
  for (int y = 0; y < outH; y++) {
    final bool inRow = y < rh;
    for (int x = 0; x < outW; x++) {
      final int idx = y * outW + x;
      final bool inside = inRow && x < rw;
      if (!inside) {
        for (int c = 0; c < 3; c++) {
          out[c * plane + idx] = pad.toDouble();
        }
        continue;
      }
      // cv2.resize INTER_LINEAR：半像素中心约定。
      final double fx = (x + 0.5) * scaleX - 0.5;
      final double fy = (y + 0.5) * scaleY - 0.5;
      for (int c = 0; c < 3; c++) {
        final int srcChannel = 2 - c;
        out[c * plane + idx] = _bilinear(rgba, srcW, srcH, fx, fy, srcChannel);
      }
    }
  }
  return Pose3dLetterbox(tensor: out, ratio: ratio);
}
