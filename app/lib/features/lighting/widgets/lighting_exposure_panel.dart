import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';
import '../light_meter.dart';
import '../lighting_models.dart';

/// 创意预演 / 校准曝光的模式与校准控制。
class LightingExposurePanel extends StatefulWidget {
  const LightingExposurePanel({
    super.key,
    required this.scene,
    required this.onModeChanged,
    required this.onExposureChanged,
    required this.onCalibrate,
  });

  final LightingSceneData scene;
  final ValueChanged<LightingMode> onModeChanged;
  final void Function({int? iso, double? shutterSeconds}) onExposureChanged;
  final bool Function(double measuredLux) onCalibrate;

  @override
  State<LightingExposurePanel> createState() => _LightingExposurePanelState();
}

class _LightingExposurePanelState extends State<LightingExposurePanel> {
  late final TextEditingController _luxController;
  String? _error;

  ExposureSettings get _settings => widget.scene.exposure;

  @override
  void initState() {
    super.initState();
    _luxController = TextEditingController(
      text: _luxText(_settings.measuredLux),
    );
  }

  @override
  void didUpdateWidget(covariant LightingExposurePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene.exposure.measuredLux != _settings.measuredLux) {
      _luxController.text = _luxText(_settings.measuredLux);
      _error = null;
    }
  }

  @override
  void dispose() {
    _luxController.dispose();
    super.dispose();
  }

  static String _luxText(double? value) =>
      value == null ? '' : value.toStringAsFixed(value >= 100 ? 0 : 1);

  void _calibrate() {
    final double? lux = double.tryParse(_luxController.text.trim());
    if (lux == null || lux <= 0) {
      setState(() => _error = '请输入大于 0 的实测照度');
      return;
    }
    final bool saved = widget.onCalibrate(lux);
    setState(() => _error = saved ? null : '当前场景无法校准，请先检查灯光');
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final LightMeterReading reading = LightMeter.compute(widget.scene);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('布光模式', style: AppType.bodyLg.style(p.ink)),
          const SizedBox(height: AppSpace.s2),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<LightingMode>(
              segments: const <ButtonSegment<LightingMode>>[
                ButtonSegment<LightingMode>(
                  value: LightingMode.creative,
                  label: Text('创意预演'),
                  icon: Icon(Icons.palette_outlined),
                ),
                ButtonSegment<LightingMode>(
                  value: LightingMode.calibrated,
                  label: Text('校准曝光'),
                  icon: Icon(Icons.exposure_outlined),
                ),
              ],
              selected: <LightingMode>{widget.scene.mode},
              onSelectionChanged: (Set<LightingMode> selection) =>
                  widget.onModeChanged(selection.first),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            widget.scene.mode == LightingMode.creative
                ? '经验估算，用于比较光位、光比和影调，不代表绝对照度。'
                : '用照度计修正模型；修改布光后需要重新校准。',
            style: AppType.small.style(p.muted),
          ),
          if (widget.scene.mode == LightingMode.calibrated) ...<Widget>[
            const SizedBox(height: AppSpace.s3),
            if (reading.needsCalibration || reading.calibrationStale)
              _Warning(
                text: reading.needsCalibration
                    ? '尚未校准：在被摄体位置测量当前场景的总入射照度。'
                    : '布光已变化：以下结果沿用旧校准，请重新测量。',
              ),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _settings.iso,
                    decoration: const InputDecoration(labelText: 'ISO'),
                    items: const <int>[100, 200, 400, 800, 1600]
                        .map(
                          (int iso) => DropdownMenuItem<int>(
                            value: iso,
                            child: Text('$iso'),
                          ),
                        )
                        .toList(),
                    onChanged: (int? iso) => widget.onExposureChanged(iso: iso),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    initialValue: _settings.shutterSeconds,
                    decoration: const InputDecoration(labelText: '快门'),
                    items:
                        const <(double, String)>[
                              (1 / 250, '1/250'),
                              (1 / 125, '1/125'),
                              (1 / 60, '1/60'),
                              (1 / 30, '1/30'),
                              (1 / 15, '1/15'),
                            ]
                            .map(
                              ((double, String) item) =>
                                  DropdownMenuItem<double>(
                                    value: item.$1,
                                    child: Text(item.$2),
                                  ),
                            )
                            .toList(),
                    onChanged: (double? seconds) =>
                        widget.onExposureChanged(shutterSeconds: seconds),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('calibration-lux-input'),
              controller: _luxController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '实测照度（lux）',
                hintText: '例如 850',
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            SizedBox(
              width: double.infinity,
              child: SsButton(
                key: const Key('calibrate-exposure-button'),
                label: reading.calibrationStale ? '重新校准' : '按实测值校准',
                icon: Icons.tune_rounded,
                kind: SsButtonKind.outline,
                dense: true,
                onPressed: _calibrate,
              ),
            ),
            if (_settings.isCalibrated)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s2),
                child: Text(
                  '校准基准 ${_luxText(_settings.measuredLux)} lux · '
                  '修正 ×${_settings.calibrationFactor.toStringAsFixed(2)}',
                  style: AppType.small.style(p.inkSoft),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Text(
        text,
        style: AppType.small.style(Theme.of(context).colorScheme.error),
      ),
    );
  }
}
