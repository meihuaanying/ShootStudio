import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/utils/json_utils.dart';

/// 骨架关键点（归一化坐标 + 可见度）。
class PosePoint {
  const PosePoint(this.x, this.y, this.visibility);

  final double x;
  final double y;
  final double visibility;
}

/// MediaPipe BlazePose 骨架数据（33 关键点；V4 / R20）。
class PoseSkeletonData {
  const PoseSkeletonData({
    required this.points,
    required this.imageSize,
    required this.confidence,
  });

  /// 归一化 2D 关键点（0..1）；不可见点为 null。
  final List<PosePoint?> points;
  final Size imageSize;
  final double confidence;

  static final Map<String, Future<PoseSkeletonData?>> _cache =
      <String, Future<PoseSkeletonData?>>{};

  /// 读取并缓存骨架 JSON（asset 为空或失败时返回 null，不抛错）。
  static Future<PoseSkeletonData?> load(String asset) {
    if (asset.isEmpty) return Future<PoseSkeletonData?>.value(null);
    return _cache.putIfAbsent(asset, () => _load(asset));
  }

  static Future<PoseSkeletonData?> _load(String asset) async {
    try {
      final raw = await rootBundle.loadString(asset);
      final map = asMap(jsonDecode(raw));
      return PoseSkeletonData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static PoseSkeletonData fromJson(Map<String, Object?> json) {
    final List<Object?> raw = asList(json['landmarks2d']);
    final points = <PosePoint?>[
      for (final Object? item in raw)
        if (item is List && item.length >= 4)
          PosePoint(
            asDouble(item[0]),
            asDouble(item[1]),
            asDouble(item[3]),
          )
        else if (item is List && item.length >= 2)
          PosePoint(asDouble(item[0]), asDouble(item[1]), 1)
        else
          null,
    ];
    final List<Object?> size = asList(json['imageSize']);
    final double w = size.isNotEmpty ? asDouble(size[0]) : 0;
    final double h = size.length > 1 ? asDouble(size[1]) : 0;
    return PoseSkeletonData(
      points: points,
      imageSize: Size(w <= 0 ? 3 : w, h <= 0 ? 4 : h),
      confidence: asDouble(json['confidence']),
    );
  }
}

/// 实时骨架叠加绘制（D69：用 skeleton.json 绘制，不依赖叠加 PNG）。
class PoseSkeletonPainter extends CustomPainter {
  PoseSkeletonPainter({
    required this.data,
    this.fit = BoxFit.cover,
    this.color = const Color(0xFFFF8A3D),
  });

  final PoseSkeletonData data;
  final BoxFit fit;
  final Color color;

  /// BlazePose 33 点骨骼连接（与 pose_detection 的 poseLandmarkConnections 同源）。
  static const List<List<int>> bones = <List<int>>[
    <int>[0, 1],
    <int>[1, 2],
    <int>[2, 3],
    <int>[3, 7],
    <int>[0, 4],
    <int>[4, 5],
    <int>[5, 6],
    <int>[6, 8],
    <int>[9, 10],
    <int>[11, 12],
    <int>[11, 13],
    <int>[13, 15],
    <int>[15, 17],
    <int>[15, 19],
    <int>[15, 21],
    <int>[17, 19],
    <int>[12, 14],
    <int>[14, 16],
    <int>[16, 18],
    <int>[16, 20],
    <int>[16, 22],
    <int>[18, 20],
    <int>[11, 23],
    <int>[12, 24],
    <int>[23, 24],
    <int>[23, 25],
    <int>[25, 27],
    <int>[27, 29],
    <int>[29, 31],
    <int>[31, 27],
    <int>[24, 26],
    <int>[26, 28],
    <int>[28, 30],
    <int>[30, 32],
    <int>[32, 28],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (data.points.isEmpty || size.isEmpty) return;
    final double scale = fit == BoxFit.contain
        ? math.min(size.width / data.imageSize.width,
            size.height / data.imageSize.height)
        : math.max(size.width / data.imageSize.width,
            size.height / data.imageSize.height);
    final Size dest =
        Size(data.imageSize.width * scale, data.imageSize.height * scale);
    final Rect rect = Alignment.center.inscribe(dest, Offset.zero & size);

    Offset? map(int index) {
      if (index < 0 || index >= data.points.length) return null;
      final PosePoint? p = data.points[index];
      if (p == null || p.visibility < 0.5) return null;
      return Offset(
        rect.left + p.x * data.imageSize.width * scale,
        rect.top + p.y * data.imageSize.height * scale,
      );
    }

    final Paint bonePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.6, size.shortestSide * 0.012);
    final Paint boneOutline = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bonePaint.strokeWidth + 1.6;
    final Paint jointPaint = Paint()..color = Colors.white;
    final Paint jointCore = Paint()..color = color;

    for (final List<int> bone in bones) {
      final Offset? a = map(bone[0]);
      final Offset? b = map(bone[1]);
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, boneOutline);
      canvas.drawLine(a, b, bonePaint);
    }
    for (int i = 0; i < data.points.length; i++) {
      final Offset? p = map(i);
      if (p == null) continue;
      canvas.drawCircle(p, bonePaint.strokeWidth * 1.5, jointPaint);
      canvas.drawCircle(p, bonePaint.strokeWidth * 0.85, jointCore);
    }
  }

  @override
  bool shouldRepaint(PoseSkeletonPainter old) =>
      old.data != data || old.fit != fit || old.color != color;
}

/// 照片 + 骨架叠加（失败时回退为纯照片，不阻塞）。
class PosePhotoView extends StatelessWidget {
  const PosePhotoView({
    super.key,
    required this.photo,
    required this.skeleton,
    this.showSkeleton = true,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });

  final String photo;
  final String skeleton;
  final bool showSkeleton;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (photo.isEmpty) {
      return Container(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.accessibility_new_outlined,
              size: 28, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
        ),
      );
    }
    final Widget image = Image.asset(
      photo,
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          Container(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              size: 24, color: scheme.onSurfaceVariant),
        ),
      ),
    );
    if (!showSkeleton || skeleton.isEmpty) return image;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        image,
        FutureBuilder<PoseSkeletonData?>(
          future: PoseSkeletonData.load(skeleton),
          builder: (BuildContext context,
              AsyncSnapshot<PoseSkeletonData?> snapshot) {
            final PoseSkeletonData? data = snapshot.data;
            if (data == null) return const SizedBox.shrink();
            return CustomPaint(
              painter: PoseSkeletonPainter(data: data, fit: fit),
              child: const SizedBox.expand(),
            );
          },
        ),
      ],
    );
  }
}
