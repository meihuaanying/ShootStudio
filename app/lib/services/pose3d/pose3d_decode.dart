/// V7/D141：RTMPose/RTMW3D 端上识别 —— 纯 Dart 后处理（simcc 解码 + YOLOX 解码/NMS）。
///
/// 口径来源（rtmlib / mmpose，逐字对齐）：
/// - `get_simcc_maximum3d`：`locs=argmax`、`vals=min(max_x,max_y)`、`vals<=0 → -1`；
/// - `RTMPose3d.postprocess`：`keypoints=locs/2`、
///   `z_m=(z_simcc/(H/2)-1)*z_range`（H=384，z_range=2.1744869）、
///   `kp2d=kp_xy/(W,H)*scale+center-0.5*scale`；
/// - `YOLOX.postprocess`：anchor-free 解码（strides 8/16/32）+ 逐类 NMS。
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'pose3d_geometry.dart';

/// RTMW3D 解码结果（133 个关键点，crop 像素 + 米制 z + 原图 2D 重投影）。
class Pose3dKeypoints {
  const Pose3dKeypoints({
    required this.count,
    required this.x,
    required this.y,
    required this.z,
    required this.scores,
    required this.x2d,
    required this.y2d,
  });

  final int count;

  /// crop 像素（288×384 空间）。
  final Float32List x;
  final Float32List y;

  /// 米（`z_range` 换算后；负值朝相机）。
  final Float32List z;

  /// `min(max_x, max_y)`（simcc 峰值）。
  final Float32List scores;

  /// 原图像素（2D 重投影）。
  final Float32List x2d;
  final Float32List y2d;
}

/// simcc 解码（`get_simcc_maximum3d` + `RTMPose3d.postprocess` 口径）。
Pose3dKeypoints decodeSimcc3d({
  required Float32List simccX,
  required Float32List simccY,
  required Float32List simccZ,
  required int numKeypoints,
  required int simccW,
  required int simccH,
  required int simccZLen,
  required Pose3dCropSpec spec,
  double zRange = 2.1744869,
  double splitRatio = 2.0,
}) {
  final Float32List x = Float32List(numKeypoints);
  final Float32List y = Float32List(numKeypoints);
  final Float32List z = Float32List(numKeypoints);
  final Float32List scores = Float32List(numKeypoints);
  final Float32List x2d = Float32List(numKeypoints);
  final Float32List y2d = Float32List(numKeypoints);
  final double scaleW = spec.scaleW;
  final double scaleH = spec.scaleW * spec.outH / spec.outW;
  for (int k = 0; k < numKeypoints; k++) {
    final int baseX = k * simccW;
    final int baseY = k * simccH;
    final int baseZ = k * simccZLen;
    int locX = 0;
    double maxX = simccX[baseX];
    for (int i = 1; i < simccW; i++) {
      final double v = simccX[baseX + i];
      if (v > maxX) {
        maxX = v;
        locX = i;
      }
    }
    int locY = 0;
    double maxY = simccY[baseY];
    for (int i = 1; i < simccH; i++) {
      final double v = simccY[baseY + i];
      if (v > maxY) {
        maxY = v;
        locY = i;
      }
    }
    int locZ = 0;
    double maxZ = simccZ[baseZ];
    for (int i = 1; i < simccZLen; i++) {
      final double v = simccZ[baseZ + i];
      if (v > maxZ) {
        maxZ = v;
        locZ = i;
      }
    }
    final double score = math.min(maxX, maxY);
    scores[k] = score;
    if (score <= 0) {
      x[k] = -1;
      y[k] = -1;
      z[k] = -1;
      x2d[k] = -1;
      y2d[k] = -1;
      continue;
    }
    final double kx = locX / splitRatio;
    final double ky = locY / splitRatio;
    final double kz = locZ / splitRatio;
    x[k] = kx;
    y[k] = ky;
    z[k] = (kz / (spec.outH / 2.0) - 1) * zRange;
    // 2D 重投影：kp / (outW,outH) * scale + center - 0.5*scale
    x2d[k] = kx / spec.outW * scaleW + spec.centerX - 0.5 * scaleW;
    y2d[k] = ky / spec.outH * scaleH + spec.centerY - 0.5 * scaleH;
  }
  return Pose3dKeypoints(
    count: numKeypoints,
    x: x,
    y: y,
    z: z,
    scores: scores,
    x2d: x2d,
    y2d: y2d,
  );
}

/// 检测框（原图像素）。
class Pose3dDetection {
  const Pose3dDetection({
    required this.box,
    required this.score,
    required this.classId,
  });

  final Pose3dBox box;
  final double score;
  final int classId;
}

/// YOLOX anchor-free 解码 + 逐类 NMS（rtmlib `YOLOX.postprocess` 口径）。
///
/// [output] 为 `[1, rows, cols]` 扁平输出（cols = 85），[inH]/[inW] 为模型输入
/// 尺寸（416/640），[ratio] 为 letterbox 缩放比。
List<Pose3dDetection> decodeYolox({
  required Float32List output,
  required int rows,
  required int cols,
  required int inH,
  required int inW,
  required double ratio,
  double scoreThr = 0.7,
  double nmsThr = 0.45,
}) {
  const List<int> strides = <int>[8, 16, 32];
  final List<double> gridX = <double>[];
  final List<double> gridY = <double>[];
  final List<double> gridStride = <double>[];
  for (final int stride in strides) {
    final int hs = inH ~/ stride;
    final int ws = inW ~/ stride;
    for (int gy = 0; gy < hs; gy++) {
      for (int gx = 0; gx < ws; gx++) {
        gridX.add(gx.toDouble());
        gridY.add(gy.toDouble());
        gridStride.add(stride.toDouble());
      }
    }
  }
  final int numClasses = cols - 5;
  final List<Pose3dDetection> dets = <Pose3dDetection>[];
  for (int i = 0; i < rows; i++) {
    final int base = i * cols;
    final double stride = gridStride[i];
    final double cx = (output[base] + gridX[i]) * stride;
    final double cy = (output[base + 1] + gridY[i]) * stride;
    final double w = math.exp(output[base + 2]) * stride;
    final double h = math.exp(output[base + 3]) * stride;
    final double obj = output[base + 4];
    final double x1 = (cx - w / 2) / ratio;
    final double y1 = (cy - h / 2) / ratio;
    final double x2 = (cx + w / 2) / ratio;
    final double y2 = (cy + h / 2) / ratio;
    for (int c = 0; c < numClasses; c++) {
      final double score = obj * output[base + 5 + c];
      if (score <= scoreThr) continue;
      dets.add(
        Pose3dDetection(
          box: Pose3dBox(x1, y1, x2, y2),
          score: score,
          classId: c,
        ),
      );
    }
  }
  // 逐类 NMS（与 rtmlib `multiclass_nms` 相同口径）。
  final List<Pose3dDetection> kept = <Pose3dDetection>[];
  final Map<int, List<Pose3dDetection>> byClass =
      <int, List<Pose3dDetection>>{};
  for (final Pose3dDetection d in dets) {
    byClass.putIfAbsent(d.classId, () => <Pose3dDetection>[]).add(d);
  }
  for (final List<Pose3dDetection> group in byClass.values) {
    final List<Pose3dDetection> sorted = List<Pose3dDetection>.from(group)
      ..sort(
        (Pose3dDetection a, Pose3dDetection b) => b.score.compareTo(a.score),
      );
    final List<bool> removed = List<bool>.filled(sorted.length, false);
    for (int i = 0; i < sorted.length; i++) {
      if (removed[i]) continue;
      kept.add(sorted[i]);
      final Pose3dBox a = sorted[i].box;
      final double areaA = (a.x2 - a.x1 + 1) * (a.y2 - a.y1 + 1);
      for (int j = i + 1; j < sorted.length; j++) {
        if (removed[j]) continue;
        final Pose3dBox b = sorted[j].box;
        final double xx1 = math.max(a.x1, b.x1);
        final double yy1 = math.max(a.y1, b.y1);
        final double xx2 = math.min(a.x2, b.x2);
        final double yy2 = math.min(a.y2, b.y2);
        final double w = math.max(0.0, xx2 - xx1 + 1);
        final double h = math.max(0.0, yy2 - yy1 + 1);
        final double inter = w * h;
        final double areaB = (b.x2 - b.x1 + 1) * (b.y2 - b.y1 + 1);
        final double ovr = inter / (areaA + areaB - inter);
        if (ovr > nmsThr) removed[j] = true;
      }
    }
  }
  return kept;
}
