// V8/S6 · D152：效果预览（脸部受光示意）+ 测光表卡片（布光预演右栏）。
// 从 lighting_page.dart 拆出（R73 行数门禁）；版面与行为不变。

import '../../../core/design/feature_colors.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';

import '../light_meter.dart';
import '../lighting_models.dart';

class LightingEffectPreview extends StatelessWidget {
  const LightingEffectPreview({super.key, required this.scene});
  final LightingSceneData scene;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SsSectionTitle('效果预览', subtitle: '主视角度明暗示意'),
        const SizedBox(height: AppSpace.s2),
        Container(
          height: 132,
          decoration: BoxDecoration(
            color: AppFeatureColor.sceneBackdrop,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: CustomPaint(
            painter: FaceLightPainter(
              devices: scene.lights.where((DeviceSpec d) => d.on).toList(),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class FaceLightPainter extends CustomPainter {
  FaceLightPainter({required this.devices});
  final List<DeviceSpec> devices;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.3;
    // 暗背景。
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppFeatureColor.sceneBackdrop,
    );
    // 脸。
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppFeatureColor.sceneFace,
    );
    if (devices.isEmpty) {
      _hint(canvas, size, '未布置任何灯光');
      return;
    }
    // 取最亮灯为主光。
    devices.sort(
      (DeviceSpec a, DeviceSpec b) => b.intensity.compareTo(a.intensity),
    );
    final key = devices.first;
    final g = geometryOf(key.x, key.y);
    final int kelvin = key.kelvin;
    final double brightness = key.intensity / 100;
    // 受光半侧。
    final rad = (g.azimuth - 90) * math.pi / 180;
    final litPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius),
        rad - math.pi / 2,
        math.pi,
      )
      ..close();
    final warm = kelvin < 4200;
    final Color lightColor = Color.lerp(
      AppFeatureColor.lightWarm,
      AppFeatureColor.lightCool,
      warm ? 0.15 : 0.85,
    )!.withValues(alpha: 0.25 + 0.55 * brightness);
    canvas.drawPath(litPath, Paint()..color = lightColor);
    // 面部轮廓。
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // 鼻梁高光线（提示光向）。
    final nose = Offset(
      center.dx + math.cos(rad) * radius * 0.6,
      center.dy + math.sin(rad) * radius * 0.6,
    );
    canvas.drawLine(
      center,
      nose,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 1.4,
    );
    // 读数。
    final tp = TextPainter(
      text: TextSpan(
        text:
            '主光 ${_dirLabel(g.azimuth)} · ${g.distanceLabel} · ${key.intensity}% · ${key.kelvin}K',
        style: const TextStyle(
          fontSize: AppFontSize.tiny,
          color: AppFeatureColor.hintInk,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 12);
    tp.paint(canvas, const Offset(6, 6));
  }

  String _dirLabel(double az) {
    if (az >= 315 || az < 45) return '正面';
    if (az < 135) return '右侧';
    if (az < 225) return '背面';
    return '左侧';
  }

  void _hint(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: AppFontSize.smallSm,
          color: AppFeatureColor.panelInk,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(FaceLightPainter old) => true;
}

/// 虚拟测光表（G4/D33）：EV / 曝光建议 / 光比 / 影调。
class LightingMeterCard extends StatelessWidget {
  const LightingMeterCard({super.key, required this.scene});
  final LightingSceneData scene;
  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final LightMeterReading r = LightMeter.compute(scene);
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.exposure_rounded, size: 16, color: p.accent),
              const SizedBox(width: 6),
              const Text(
                '虚拟测光表',
                style: TextStyle(
                  fontSize: AppFontSize.small,
                  fontWeight: AppFontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'EV100 ${r.ev100.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: AppFontSize.smallSm,
                  fontWeight: AppFontWeight.medium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _cell(
                context,
                '建议曝光',
                'ISO ${r.iso} · ${r.shutter} · ${r.aperture}',
              ),
              const SizedBox(width: 10),
              _cell(context, '光比', r.ratioLabel),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              _cell(context, '影调', r.moodLabel),
              const SizedBox(width: 10),
              _cell(context, '照度', '${r.keyLux.round()} lux'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r.advice,
            style: TextStyle(
              fontSize: AppFontSize.caption,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String label, String value) => Expanded(
    child: RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(
          context,
        ).style.copyWith(fontSize: AppFontSize.captionLg),
        children: <TextSpan>[
          TextSpan(
            text: '$label ',
            style: TextStyle(color: context.palette.inkSoft),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: AppFontWeight.medium),
          ),
        ],
      ),
    ),
  );
}

/// 可折叠小节（A3/B2：关节微调与画质）。
