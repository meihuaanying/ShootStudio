import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../lighting_models.dart';

/// 俯视灯位画布（拖动设备、选中高亮、方位角/距离实时读数）。
class LightingCanvasView extends StatefulWidget {
  const LightingCanvasView({
    super.key,
    required this.scene,
    required this.selectedId,
    required this.onSelect,
    required this.onMove,
    this.onMoveEnd,
    this.onCameraMove,
    this.onCameraMoveEnd,
    this.cameraSelected = false,
    this.pixelsPerMeter = 64,
  });

  final LightingSceneData scene;
  final String? selectedId;
  final void Function(String id) onSelect;
  final void Function(String id, double x, double y) onMove;
  final VoidCallback? onMoveEnd;

  /// V6/D105：相机机位拖动。
  final void Function(double x, double y)? onCameraMove;
  final VoidCallback? onCameraMoveEnd;
  final bool cameraSelected;
  final double pixelsPerMeter;

  @override
  State<LightingCanvasView> createState() => _LightingCanvasViewState();
}

class _LightingCanvasViewState extends State<LightingCanvasView> {
  String? _draggingId;
  bool _draggingCamera = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) =>
              _onPanStart(d.localPosition, size),
          onPanUpdate: (DragUpdateDetails d) =>
              _onPanUpdate(d.localPosition, size),
          onPanEnd: (DragEndDetails d) {
            _draggingId = null;
            final bool wasCamera = _draggingCamera;
            _draggingCamera = false;
            widget.onMoveEnd?.call();
            if (wasCamera) widget.onCameraMoveEnd?.call();
          },
          onTapUp: (TapUpDetails d) => _onTap(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _StagePainter(
              scene: widget.scene,
              selectedId: widget.selectedId,
              cameraSelected: widget.cameraSelected,
              pixelsPerMeter: widget.pixelsPerMeter,
              gridColor: theme.colorScheme.outline.withValues(alpha: 0.55),
              inkColor: theme.colorScheme.onSurface,
              mutedColor: theme.colorScheme.onSurfaceVariant,
              accent: AppTokens.accent,
            ),
          ),
        );
      },
    );
  }

  DeviceSpec? _hit(Offset p, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    DeviceSpec? best;
    var bestDist = 24.0;
    for (final DeviceSpec device in widget.scene.devices) {
      final pos =
          center +
          Offset(
            device.x * widget.pixelsPerMeter,
            device.y * widget.pixelsPerMeter,
          );
      final dist = (pos - p).distance;
      if (dist <= bestDist) {
        best = device;
        bestDist = dist;
      }
    }
    return best;
  }

  /// V6/D105：相机机位命中（半径 16px）。
  bool _hitCamera(Offset p, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pos =
        center +
        Offset(
          widget.scene.camera.x * widget.pixelsPerMeter,
          widget.scene.camera.y * widget.pixelsPerMeter,
        );
    return (pos - p).distance <= 16;
  }

  void _onPanStart(Offset p, Size size) {
    if (_hitCamera(p, size)) {
      _draggingCamera = true;
      return;
    }
    final hit = _hit(p, size);
    if (hit != null) {
      widget.onSelect(hit.id);
      _draggingId = hit.id;
    }
  }

  void _onPanUpdate(Offset p, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final canvasPoint = (p - center) / widget.pixelsPerMeter;
    if (_draggingCamera) {
      widget.onCameraMove?.call(canvasPoint.dx, canvasPoint.dy);
      return;
    }
    final id = _draggingId;
    if (id == null) return;
    final maxX = widget.scene.width / 2;
    final maxY = widget.scene.depth / 2;
    final x = canvasPoint.dx.clamp(-maxX, maxX);
    final y = canvasPoint.dy.clamp(-maxY, maxY);
    widget.onMove(id, x, y);
  }

  void _onTap(Offset p, Size size) {
    final hit = _hit(p, size);
    if (hit != null) widget.onSelect(hit.id);
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.scene,
    required this.selectedId,
    required this.cameraSelected,
    required this.pixelsPerMeter,
    required this.gridColor,
    required this.inkColor,
    required this.mutedColor,
    required this.accent,
  });

  final LightingSceneData scene;
  final String? selectedId;
  final bool cameraSelected;
  final double pixelsPerMeter;
  final Color gridColor;
  final Color inkColor;
  final Color mutedColor;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 影棚边界。
    final stageRect = Rect.fromCenter(
      center: center,
      width: scene.width * pixelsPerMeter,
      height: scene.depth * pixelsPerMeter,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(stageRect, const Radius.circular(10)),
      Paint()..color = gridColor.withValues(alpha: 0.12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(stageRect, const Radius.circular(10)),
      Paint()
        ..color = gridColor
        ..style = PaintingStyle.stroke,
    );

    // 米格。
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var m = -scene.width / 2; m <= scene.width / 2; m += 1) {
      final x = center.dx + m * pixelsPerMeter;
      canvas.drawLine(
        Offset(x, stageRect.top),
        Offset(x, stageRect.bottom),
        grid,
      );
    }
    for (var m = -scene.depth / 2; m <= scene.depth / 2; m += 1) {
      final y = center.dy + m * pixelsPerMeter;
      canvas.drawLine(
        Offset(stageRect.left, y),
        Offset(stageRect.right, y),
        grid,
      );
    }

    // 方位角参考环。
    final ringPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 1 * pixelsPerMeter, ringPaint);
    canvas.drawCircle(center, 2 * pixelsPerMeter, ringPaint);

    // 被摄体朝向锥（正面朝上）。
    final conePath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: 1.1 * pixelsPerMeter),
        -math.pi / 2 - math.pi / 7,
        math.pi * 2 / 7,
        false,
      )
      ..close();
    canvas.drawPath(conePath, Paint()..color = accent.withValues(alpha: 0.14));

    // 被摄体。
    canvas.drawCircle(center, 10, Paint()..color = inkColor);
    _label(
      canvas,
      '被摄体（面向↑）',
      center + const Offset(-34, 16),
      10.5,
      mutedColor,
    );

    // V6/D105：相机机位 + 视野扇形（随焦段变化）。
    {
      final CameraRigData cam = scene.camera;
      final Offset camPos =
          center + Offset(cam.x * pixelsPerMeter, cam.y * pixelsPerMeter);
      // 水平视场角（全画幅 36mm 宽）。
      final double hfov = 2 * math.atan(18 / math.max(8, cam.focal.toDouble()));
      final double base = math.atan2(
        center.dy - camPos.dy,
        center.dx - camPos.dx,
      );
      final double dir = base + cam.yaw * math.pi / 180;
      final double len = 3.2 * pixelsPerMeter;
      final Path wedge = Path()
        ..moveTo(camPos.dx, camPos.dy)
        ..lineTo(
          camPos.dx + math.cos(dir - hfov / 2) * len,
          camPos.dy + math.sin(dir - hfov / 2) * len,
        )
        ..lineTo(
          camPos.dx + math.cos(dir + hfov / 2) * len,
          camPos.dy + math.sin(dir + hfov / 2) * len,
        )
        ..close();
      canvas.drawPath(
        wedge,
        Paint()
          ..color = (cameraSelected ? inkColor : accent).withValues(
            alpha: cameraSelected ? 0.16 : 0.09,
          ),
      );
      canvas.drawLine(
        camPos,
        center,
        Paint()
          ..color = mutedColor.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      // 相机图标（机身 + 镜头三角）。
      final camColor = cameraSelected ? inkColor : const Color(0xFF5B6B8C);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: camPos, width: 16, height: 12),
          const Radius.circular(2.5),
        ),
        Paint()..color = camColor,
      );
      canvas.drawCircle(
        camPos,
        3.2,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      if (cameraSelected) {
        canvas.drawCircle(
          camPos,
          15,
          Paint()
            ..color = inkColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      _label(
        canvas,
        '机位 ${cam.focal}mm',
        camPos + const Offset(12, -6),
        10,
        mutedColor,
      );
    }

    // 设备。
    for (final DeviceSpec device in scene.devices) {
      final pos =
          center + Offset(device.x * pixelsPerMeter, device.y * pixelsPerMeter);
      final selected = device.id == selectedId;
      final Color color = device.isLight
          ? (device.on ? accent : mutedColor)
          : const Color(0xFF2BA471);

      // 灯光方向线（指向被摄体）。
      if (device.isLight) {
        canvas.drawLine(
          pos,
          center,
          Paint()
            ..color = color.withValues(alpha: selected ? 0.5 : 0.22)
            ..strokeWidth = selected ? 1.6 : 1,
        );
      }

      if (device.isLight) {
        // 灯图标：圆 + 放射。
        canvas.drawCircle(pos, selected ? 12 : 9, Paint()..color = color);
        if (selected) {
          canvas.drawCircle(
            pos,
            15,
            Paint()
              ..color = inkColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
        }
      } else {
        // 道具图标：方块。
        final rect = Rect.fromCenter(
          center: pos,
          width: selected ? 20 : 16,
          height: selected ? 20 : 16,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = color.withValues(alpha: 0.85),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..color = inkColor.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke,
        );
      }
      _label(canvas, device.name, pos + const Offset(-18, 14), 10, mutedColor);
    }
  }

  void _label(Canvas canvas, String text, Offset at, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_StagePainter old) => true;
}
