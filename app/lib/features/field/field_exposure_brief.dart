import 'package:flutter/material.dart';

import '../../core/design/widgets.dart';
import '../lighting/light_meter.dart';
import '../lighting/lighting_models.dart';

/// 现场页中的布光曝光摘要。
///
/// 只展示关联场景的计算结果，不复制编辑器能力；旧校准、尚未校准与创意
/// 估算都用不同文案标识，避免现场误用估算值。
class FieldExposureBrief extends StatelessWidget {
  const FieldExposureBrief({
    super.key,
    required this.sceneId,
    required this.scene,
    required this.onRefresh,
  });

  final String sceneId;
  final LightingSceneData? scene;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: p.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.exposure_rounded, size: 18, color: p.accent),
              const SizedBox(width: 6),
              Expanded(child: Text('现场曝光', style: AppType.h3.style(p.ink))),
              IconButton(
                key: const Key('field-exposure-refresh'),
                tooltip: '刷新布光参数',
                visualDensity: VisualDensity.compact,
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
          if (sceneId.isEmpty)
            Text(
              '本模块未关联布光方案。请在策划案中关联后再到现场查看。',
              style: AppType.small.style(p.inkSoft),
            )
          else if (scene == null)
            Text(
              '关联的布光方案不存在或无法读取，请回策划案重新关联。',
              style: AppType.small.style(Theme.of(context).colorScheme.error),
            )
          else
            _sceneReading(context),
        ],
      ),
    );
  }

  Widget _sceneReading(BuildContext context) {
    final AppPalette p = context.palette;
    final LightingSceneData current = scene!;
    final LightMeterReading reading = LightMeter.compute(current);
    final bool calibrated = current.mode == LightingMode.calibrated;
    final String title = calibrated
        ? reading.needsCalibration
              ? '校准曝光 · 尚未校准'
              : reading.calibrationStale
              ? '校准曝光 · 需要复校'
              : '校准曝光 · 现场参数'
        : '创意预演 · 经验参考';
    final bool actionable =
        !calibrated || (!reading.needsCalibration && !reading.calibrationStale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(current.name, style: AppType.small.style(p.inkSoft)),
        const SizedBox(height: 6),
        Text(
          title,
          style: AppType.bodyLg.style(
            calibrated && (reading.needsCalibration || reading.calibrationStale)
                ? Theme.of(context).colorScheme.error
                : p.ink,
          ),
        ),
        if (actionable) ...<Widget>[
          const SizedBox(height: AppSpace.s2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Text(
              'ISO ${reading.iso} · ${reading.shutter} · ${reading.aperture}',
              style: appMono(p.ink, size: AppType.body.size),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            calibrated
                ? 'EV100 ${reading.ev100.toStringAsFixed(1)} · '
                      '总照度 ${reading.totalLux.round()} lux'
                : 'EV100 ${reading.ev100.toStringAsFixed(1)} · '
                      '光比 ${reading.ratioLabel}',
            style: AppType.small.style(p.inkSoft),
          ),
        ],
        const SizedBox(height: AppSpace.s2),
        Text(
          reading.advice,
          style: AppType.small.style(
            calibrated && (reading.needsCalibration || reading.calibrationStale)
                ? Theme.of(context).colorScheme.error
                : p.muted,
          ),
        ),
        if (!calibrated)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1),
            child: Text(
              '创意预演不代表绝对测光；需要可执行曝光时请改用校准模式。',
              style: AppType.small.style(p.muted),
            ),
          ),
      ],
    );
  }
}
