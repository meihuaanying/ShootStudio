/// V7/D141：RTMW3D 133 点 → BlazePose 33 子集 → 12 关节（与 spike 脚本一致）。
///
/// `kPose3dMap33` 键为 **BlazePose 33 索引**，值为 **RTMW3D 133 点索引**
/// （如 `27: 15` = BlazePose 左踝 ← RTMW/COCO 左踝）。
/// 尺度估计：以骨长先验（1.70m 成人）对每条骨求 `s_i = sqrt(prior²-dz²)/dxy`
/// 后取中位数（米/crop 像素）；world 为髋中心、y 向下（与引擎/BlazePose 一致）。
library;

import 'dart:math' as math;

import 'pose3d_decode.dart';

/// RTMW3D 133 点索引 → BlazePose 33 索引（spike `MAP33`）。
const Map<int, int> kPose3dMap33 = <int, int>{
  0: 0, // nose
  7: 3, // left ear
  8: 4, // right ear
  11: 5, // left shoulder
  12: 6, // right shoulder
  13: 7, // left elbow
  14: 8, // right elbow
  15: 9, // left wrist
  16: 10, // right wrist
  19: 99, // left index tip
  20: 120, // right index tip
  23: 11, // left hip
  24: 12, // right hip
  25: 13, // left knee
  26: 14, // right knee
  27: 15, // left ankle
  28: 16, // right ankle
  29: 19, // left heel
  30: 22, // right heel
  31: 17, // left big toe
  32: 20, // right big toe
};

/// 骨长先验：(RTMW3D 端点 a, 端点 b, 先验长度米)。
const List<(int, int, double)> kPose3dBones = <(int, int, double)>[
  (5, 7, 0.316), // 左肱骨
  (7, 9, 0.248), // 左前臂
  (6, 8, 0.316), // 右肱骨
  (8, 10, 0.248), // 右前臂
  (11, 13, 0.417), // 左股骨
  (13, 15, 0.418), // 左胫骨
  (12, 14, 0.417), // 右股骨
  (14, 16, 0.418), // 右胫骨
  (5, 6, 0.440), // 肩宽
  (11, 12, 0.325), // 髋宽
];

/// 由骨长先验估计尺度（米/crop 像素）；返回 (s, 有效骨数)。
({double scale, int bonesUsed}) scaleFromBones(Pose3dKeypoints kp) {
  final List<double> est = <double>[];
  for (final (int a, int b, double prior) in kPose3dBones) {
    final double dxy = math.sqrt(
      math.pow(kp.x[a] - kp.x[b], 2) + math.pow(kp.y[a] - kp.y[b], 2),
    );
    final double dz = (kp.z[a] - kp.z[b]).abs();
    if (dxy < 4.0) continue;
    final double v = prior * prior - dz * dz;
    if (v <= 0.01) continue;
    est.add(math.sqrt(v) / dxy);
  }
  if (est.isEmpty) return (scale: 0, bonesUsed: 0);
  est.sort();
  final int n = est.length;
  final double median = n.isOdd
      ? est[n ~/ 2]
      : (est[n ~/ 2 - 1] + est[n ~/ 2]) / 2;
  return (scale: median, bonesUsed: n);
}

/// world 33 结果（髋中心、y 向下、米）。
class Pose3dWorld33 {
  const Pose3dWorld33({
    required this.world,
    required this.confidence,
    required this.scale,
    required this.bonesUsed,
  });

  /// 33×3（米；未映射点为 (0,0,0)）。
  final List<List<double>> world;

  /// 33 点置信度（未映射点 0）。
  final List<double> confidence;

  /// 米/crop 像素。
  final double scale;
  final int bonesUsed;
}

/// RTMW3D 133 → world 33（髋中心、y 向下），供 `deriveJoints()` 推导 12 关节。
Pose3dWorld33 toWorld33(Pose3dKeypoints kp) {
  final ({double scale, int bonesUsed}) s = scaleFromBones(kp);
  final List<List<double>> world = <List<double>>[
    for (int i = 0; i < 33; i++) <double>[0, 0, 0],
  ];
  final List<double> confidence = List<double>.filled(33, 0);
  for (final MapEntry<int, int> e in kPose3dMap33.entries) {
    final int bp = e.key;
    final int rtmw = e.value;
    world[bp] = <double>[
      kp.x[rtmw] * s.scale,
      kp.y[rtmw] * s.scale,
      kp.z[rtmw],
    ];
    confidence[bp] = kp.scores[rtmw];
  }
  final List<double> hipCenter = <double>[
    (world[23][0] + world[24][0]) / 2,
    (world[23][1] + world[24][1]) / 2,
    (world[23][2] + world[24][2]) / 2,
  ];
  for (int i = 0; i < 33; i++) {
    world[i] = <double>[
      world[i][0] - hipCenter[0],
      world[i][1] - hipCenter[1],
      world[i][2] - hipCenter[2],
    ];
  }
  return Pose3dWorld33(
    world: world,
    confidence: confidence,
    scale: s.scale,
    bonesUsed: s.bonesUsed,
  );
}
