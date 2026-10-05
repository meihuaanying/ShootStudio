// V8/S7 · D153：骨架关节点校正器（照片上拖拽关键点 → 实时回调）。
//
// 合同 §4.2③：命中半径 ≥12px；拖拽时显示角度读数（mono）；复位单关节 / 复位全部。
// 命中与坐标换算复用 PoseSkeletonPainter 的几何（layoutRect/offsetOf/hitTestJoint），
// 保证「画在哪就能拖到哪」。数学部分（夹角/读数）是纯函数，便于离线单测。

import '../../core/design/feature_colors.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';
import 'pose_skeleton.dart';

/// 12 个可控关节对应的（父点, 子点）关键点索引（BlazePose 33 点）。
/// 与 `pose_landmark_math.engineJoints` 一致：只覆盖上肢/下肢链，便于读数与复位。
const Map<String, (int parent, int child)> poseTunableJoints =
    <String, (int, int)>{
      'shoulder_l': (11, 13),
      'elbow_l': (13, 15),
      'wrist_l': (15, 19),
      'shoulder_r': (12, 14),
      'elbow_r': (14, 16),
      'wrist_r': (16, 20),
      'hip_l': (23, 25),
      'knee_l': (25, 27),
      'hip_r': (24, 26),
      'knee_r': (26, 28),
    };

/// 三点夹角（度，顶点为 b）；任一点缺失/退化返回 null。
double? includedAngleDeg(PosePoint? a, PosePoint? b, PosePoint? c) {
  if (a == null || b == null || c == null) return null;
  final double v1x = a.x - b.x;
  final double v1y = a.y - b.y;
  final double v2x = c.x - b.x;
  final double v2y = c.y - b.y;
  final double n1 = math.sqrt(v1x * v1x + v1y * v1y);
  final double n2 = math.sqrt(v2x * v2x + v2y * v2y);
  if (n1 < 1e-6 || n2 < 1e-6) return null;
  final double cos = ((v1x * v2x + v1y * v2y) / (n1 * n2)).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

/// 拖拽中的角度读数：优先取该关节的父子夹角；无映射时给与竖直方向的夹角。
double? poseJointReadoutDeg(
  List<PosePoint?> points,
  int index, {
  Map<int, String> labelOf = const <int, String>{},
  (int, int)? chain,
}) {
  if (index < 0 || index >= points.length) return null;
  final (int, int)? c = chain ?? _chainOf(points, index);
  if (c == null) {
    final PosePoint? p = points[index];
    if (p == null) return null;
    return (math.atan2(p.x, p.y) * 180 / math.pi).abs();
  }
  final double? angle = includedAngleDeg(
    points[c.$1],
    points[index],
    points[c.$2],
  );
  if (angle == null) return null;
  return angle;
}

/// 反查某关键点索引两侧的相邻点（谁把它当父 / 谁把它当子）。
///
/// 只有同时存在父点与子点时才算真正的「关节」（肩/肘/髋/膝）；手腕与踝是链的
/// 末端，返回 null → 读数退化为「与竖直方向的夹角」。
(int, int)? _chainOf(List<PosePoint?> points, int index) {
  (int, int)? asChild;
  (int, int)? asParent;
  for (final MapEntry<String, (int, int)> entry in poseTunableJoints.entries) {
    if (entry.value.$2 == index) asChild = entry.value;
    if (entry.value.$1 == index) asParent = entry.value;
  }
  if (asChild == null || asParent == null) return null;
  return (asChild.$1, asParent.$2);
}

/// 关节点校正器：底图 + 骨架叠加 + 拖拽命中。
class PoseJointTuner extends StatefulWidget {
  const PoseJointTuner({
    super.key,
    required this.image,
    required this.points,
    required this.imageSize,
    this.fit = BoxFit.contain,
    this.hitRadius = 14,
    this.onPointMoved,
    this.onDragStart,
    this.onDragEnd,
    this.activeColor = AppFeatureColor.poseMark,
  });

  /// 底图（由调用方决定 Image.asset / Image.file / 占位）。
  final Widget image;

  /// 可编辑关键点（归一化 0..1；null/低可见度不可拖）。
  final List<PosePoint?> points;

  /// 原图尺寸（与归一化坐标配套）。
  final Size imageSize;

  final BoxFit fit;

  /// D153：命中半径 ≥12px。
  final double hitRadius;

  /// 拖拽实时回调（index + 新归一化坐标）。
  final void Function(int index, double x, double y)? onPointMoved;

  final void Function(int index)? onDragStart;
  final void Function()? onDragEnd;
  final Color activeColor;

  @override
  State<PoseJointTuner> createState() => _PoseJointTunerState();
}

class _PoseJointTunerState extends State<PoseJointTuner> {
  int? _active;
  Size _size = Size.zero;

  PoseSkeletonPainter get _painter => PoseSkeletonPainter(
    data: _data,
    fit: widget.fit,
    color: widget.activeColor,
  );

  PoseSkeletonData get _data => PoseSkeletonData(
    points: widget.points,
    imageSize: widget.imageSize,
    confidence: 1,
  );

  /// 角度读数（mono 展示用）。
  String? get readout {
    final int? index = _active;
    if (index == null) return null;
    final double? deg = poseJointReadoutDeg(widget.points, index);
    if (deg == null) return null;
    return '${deg.toStringAsFixed(1)}°';
  }

  void _start(Offset local) {
    final int? hit = _painter.hitTestJoint(
      local,
      _size,
      radius: widget.hitRadius,
      prefer: _active,
    );
    if (hit == null) {
      if (_active != null) setState(() => _active = null);
      return;
    }
    setState(() => _active = hit);
    widget.onDragStart?.call(hit);
  }

  void _update(Offset local) {
    final int? index = _active;
    if (index == null) return;
    final Offset? normalized = _painter.toNormalized(local, _size);
    if (normalized == null) return;
    widget.onPointMoved?.call(index, normalized.dx, normalized.dy);
    setState(() {}); // 读数随拖拽实时刷新
  }

  void _end() {
    if (_active == null) return;
    setState(() => _active = null);
    widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) => _start(d.localPosition),
          onPanUpdate: (DragUpdateDetails d) => _update(d.localPosition),
          onPanEnd: (_) => _end(),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              widget.image,
              CustomPaint(painter: _painter),
              if (readout != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: p.surfaceSunken,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Text(readout!, style: appMono(p.ink, size: 12)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 世界坐标里「身体跨度」（米）：取所有可见点的 y 极差，退化时返回 0。
double poseWorldSpan(List<List<double>> world) {
  double minY = double.infinity;
  double maxY = double.negativeInfinity;
  for (final List<double> p in world) {
    if (p.length < 2) continue;
    if (p[1] < minY) minY = p[1];
    if (p[1] > maxY) maxY = p[1];
  }
  if (!minY.isFinite || !maxY.isFinite) return 0;
  return maxY - minY;
}

/// 2D 归一化点的 y 跨度（像素）；退化返回 0。
double posePointsPixelSpan(List<PosePoint?> points, Size imageSize) {
  double minY = double.infinity;
  double maxY = double.negativeInfinity;
  for (final PosePoint? p in points) {
    if (p == null) continue;
    final double y = p.y * imageSize.height;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  if (!minY.isFinite || !maxY.isFinite) return 0;
  return maxY - minY;
}

/// 把「用户拖拽 2D 关节点」折算回 3D 世界坐标（增量法）。
///
/// 识别结果 [world] 是米制（髋中心原点，y 向下），关键点 [pointsBefore] 是归一化 2D。
/// 校正只应改变用户拖动的那些点，因此这里不重建整条骨架，而是把每个点的
/// **像素位移**按「世界跨度 / 像素跨度」折算成米制位移后叠加：
/// 拖腕 → 腕的世界坐标跟着动 → `deriveJoints` 的 12 关节实时变化，未动的点不受影响。
/// 跨度退化（照片里只有一个可见点）时按 [fallbackMetersPerPixel] 兜底。
List<List<double>> applyPosePointEdits({
  required List<List<double>> world,
  required List<PosePoint?> pointsBefore,
  required List<PosePoint?> pointsAfter,
  required Size imageSize,
  double fallbackMetersPerPixel = 0.005,
}) {
  final int n = world.length < pointsBefore.length
      ? world.length
      : pointsBefore.length;
  final double worldSpan = poseWorldSpan(world);
  final double pixelSpan = posePointsPixelSpan(pointsBefore, imageSize);
  final double ratio = (worldSpan > 0 && pixelSpan > 0)
      ? worldSpan / pixelSpan
      : fallbackMetersPerPixel;
  final List<List<double>> out = world
      .map((List<double> p) => List<double>.from(p))
      .toList();
  for (int i = 0; i < n && i < pointsAfter.length; i++) {
    final PosePoint? before = pointsBefore[i];
    final PosePoint? after = pointsAfter[i];
    if (before == null || after == null || out[i].length < 2) continue;
    final double dx = (after.x - before.x) * imageSize.width * ratio;
    final double dy = (after.y - before.y) * imageSize.height * ratio;
    if (dx == 0 && dy == 0) continue;
    out[i][0] = out[i][0] + dx;
    out[i][1] = out[i][1] + dy;
  }
  return out;
}

/// 复位条：复位单关节 / 复位全部（D153）。
class PoseTunerResetBar extends StatelessWidget {
  const PoseTunerResetBar({
    super.key,
    required this.onResetJoint,
    required this.onResetAll,
    this.joints = const <String>[],
    this.canReset = false,
  });

  final void Function(String joint) onResetJoint;
  final VoidCallback onResetAll;
  final List<String> joints;

  /// 有任一关节被改过才允许复位。
  final bool canReset;

  @override
  Widget build(BuildContext context) {
    // 关节复位按钮较多且标签较长（复位 elbow_l …），用 Wrap 换行而不是 Row，
    // 否则窄栏（导入页右栏 340px）会溢出，且「复位全部」会被挤出视口。
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SsButton(
          label: '复位全部',
          kind: SsButtonKind.text,
          dense: true,
          onPressed: canReset ? onResetAll : null,
        ),
        for (final String joint in joints)
          SsButton(
            label: '复位 $joint',
            kind: SsButtonKind.text,
            dense: true,
            onPressed: canReset ? () => onResetJoint(joint) : null,
          ),
      ],
    );
  }
}
