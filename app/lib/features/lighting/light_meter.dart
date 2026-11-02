import 'dart:math' as math;

import 'lighting_models.dart';

/// 虚拟测光表（G4/D33）：按灯位、功率、距离、柔度估算照度与曝光建议。
/// 物理为“摄影棚经验模型”：对用户的价值是相对关系与可执行参数，而非绝对光度。
class LightMeterReading {
  const LightMeterReading({
    required this.keyLux,
    required this.fillLux,
    required this.ev100,
    required this.iso,
    required this.shutter,
    required this.aperture,
    required this.ratioLabel,
    required this.moodLabel,
    required this.advice,
    this.isCalibrated = false,
    this.needsCalibration = false,
    this.calibrationStale = false,
    this.calibrationFactor = 1,
  });

  final double keyLux;
  final double fillLux;
  final double ev100;
  final int iso;
  final String shutter;
  final String aperture;

  /// 主光:辅光（含环境）比值文案，如 4:1。
  final String ratioLabel;

  /// 影调感受：硬光/柔光/高调/低调。
  final String moodLabel;
  final String advice;
  final bool isCalibrated;
  final bool needsCalibration;
  final bool calibrationStale;
  final double calibrationFactor;

  double get totalLux => keyLux + fillLux;
}

class LightMeter {
  LightMeter._();

  static const List<double> _apertureStops = <double>[
    1.4,
    2.0,
    2.8,
    4.0,
    5.6,
    8.0,
    11.0,
    16.0,
    22.0,
  ];
  static const List<double> _shutterSeconds = <double>[
    1 / 250,
    1 / 125,
    1 / 60,
    1 / 30,
    1 / 15,
    1 / 8,
    1 / 4,
  ];
  static const List<String> _shutterLabels = <String>[
    '1/250',
    '1/125',
    '1/60',
    '1/30',
    '1/15',
    '1/8',
    '1/4',
  ];

  /// V6/D112：控光件衰减表（与引擎 `LIGHT_MODIFIERS.intensity` 对齐，保证测光与 3D 一致）。
  static const Map<String, double> _modifierAttenuation = <String, double>{
    'bare': 1.0,
    'standard-reflector': 1.12,
    'softbox-medium': 0.76,
    'softbox-large': 0.68,
    'octa-softbox': 0.72,
    'strip-softbox': 0.74,
    'umbrella-silver': 0.9,
    'umbrella-translucent': 0.7,
    'honeycomb-grid': 0.82,
    'diffusion-cloth': 0.72,
    'beauty-dish': 1.05,
    'snoot': 0.9,
    'softbox-grid': 0.7,
    'flag': 0.85,
    'gel-cto': 0.86,
    'gel-ctb': 0.86,
  };

  /// 单灯在被摄体处的相对照度（lux 量级，物理化便于图例）。
  static double _luxOf(DeviceSpec light, double ambient) {
    if (!light.isLight || !light.on) return 0;
    final double power = light.type == 'panel'
        ? 5200
        : light.type == 'soft'
        ? 3800
        : 4600;
    final double modifier = _modifierAttenuation[light.modifier] ?? 1.0;
    final double base = (light.intensity / 100) * power * modifier;
    final double distance = math.max(
      0.6,
      math.sqrt(light.x * light.x + light.y * light.y),
    );
    // 柔光衰减较慢（大面积光源），硬光按平方反比。
    final double falloff = light.type == 'hard' ? 1.0 : 0.78;
    final double softening = 1 - (light.softness.clamp(0.02, 1) * 0.2);
    return base * falloff * softening / (distance * distance) + ambient;
  }

  static LightMeterReading compute(LightingSceneData scene) {
    if (!scene.lights.any((DeviceSpec light) => light.on)) {
      return const LightMeterReading(
        keyLux: 0,
        fillLux: 0,
        ev100: 0,
        iso: 100,
        shutter: '—',
        aperture: '—',
        ratioLabel: '—',
        moodLabel: '无灯',
        advice: '打开或添加灯具后显示测光建议',
      );
    }

    final (double rawKey, double rawFill) = _baseLux(scene);
    final ExposureSettings settings = scene.exposure;
    final bool calibrated = scene.mode == LightingMode.calibrated;
    final bool stale =
        calibrated &&
        settings.isCalibrated &&
        settings.calibrationSignature != signatureOf(scene);
    if (calibrated && !settings.isCalibrated) {
      return LightMeterReading(
        keyLux: 0,
        fillLux: 0,
        ev100: 0,
        iso: settings.iso,
        shutter: _shutterLabel(settings.shutterSeconds),
        aperture: '—',
        ratioLabel: '—',
        moodLabel: '等待现场校准',
        advice: '在被摄体位置测量当前场景的入射照度，再输入实测 lux',
        isCalibrated: true,
        needsCalibration: true,
      );
    }

    final double scale = calibrated ? settings.calibrationFactor : 1;
    final double key = rawKey * scale;
    final double fill = rawFill * scale;
    final double exposureLux = calibrated ? key + fill : key;
    final double ev = math.log(exposureLux / 2.5) / math.ln2;
    final int iso = calibrated ? settings.iso : 100;

    double? aperture;
    String shutter = calibrated
        ? _shutterLabel(settings.shutterSeconds)
        : '1/125';
    if (calibrated) {
      final double av =
          ev +
          math.log(iso / 100) / math.ln2 +
          math.log(settings.shutterSeconds) / math.ln2;
      aperture = math.pow(2, av / 2).toDouble();
    } else {
      for (final (double seconds, String label) in _shutterPairs()) {
        final double tv = -math.log(seconds) / math.ln2;
        final double av = ev + math.log(iso / 100) / math.ln2 - tv;
        final double f = math.pow(2, av / 2).toDouble();
        if (f >= 1.4 && f <= 22) {
          aperture = f;
          shutter = label;
          break;
        }
      }
    }
    final double fNumber = _nearestStop(aperture ?? 8);

    final double ratio = key / math.max(12 * scale, fill);
    final String ratioLabel = ratio >= 2
        ? '${(ratio.round())}:1'
        : '${ratio.toStringAsFixed(1)}:1';
    final String mood = key > 900
        ? (ratio >= 4 ? '硬调·高反差' : '明亮·硬光')
        : key > 350
        ? (ratio >= 4 ? '低调·戏剧感' : '柔和·自然')
        : '暗调·氛围感';
    final bool apertureOutOfRange =
        calibrated &&
        aperture != null &&
        (aperture < _apertureStops.first || aperture > _apertureStops.last);
    final String advice = stale
        ? '布光已在校准后变化，请重新测量并校准当前场景'
        : apertureOutOfRange
        ? '所需光圈超出 f/1.4–f/22，请调整 ISO 或快门后复核'
        : calibrated
        ? '已按现场照度修正；光圈取就近标准档，建议试拍复核'
        : ratio >= 4
        ? '光比大：注意阴影补光或反光板距离'
        : ratio >= 2
        ? '光比适中：可直接拍摄，留出面部转折'
        : '光比小：画面偏平，可降低辅光或拉开主光';
    return LightMeterReading(
      keyLux: key,
      fillLux: fill,
      ev100: ev,
      iso: iso,
      shutter: shutter,
      aperture: 'f/${fNumber.toStringAsFixed(fNumber >= 10 ? 0 : 1)}',
      ratioLabel: ratioLabel,
      moodLabel: mood,
      advice: advice,
      isCalibrated: calibrated,
      calibrationStale: stale,
      calibrationFactor: scale,
    );
  }

  static (double, double) _baseLux(LightingSceneData scene) {
    final double ambient = scene.ambientEnabled ? 12 : 0;
    final List<double> luxes =
        scene.lights
            .where((DeviceSpec light) => light.on)
            .map((DeviceSpec light) => _luxOf(light, ambient))
            .toList()
          ..sort((double a, double b) => b.compareTo(a));
    return (
      luxes.first,
      luxes.skip(1).fold<double>(0, (double a, double b) => a + b),
    );
  }

  /// 用当前场景的实测总入射照度生成固定校准系数。
  static double calibrationFactorFor(
    LightingSceneData scene,
    double measuredLux,
  ) {
    if (!measuredLux.isFinite || measuredLux <= 0) {
      throw ArgumentError.value(measuredLux, 'measuredLux', '实测照度必须大于 0');
    }
    if (!scene.lights.any((DeviceSpec light) => light.on)) {
      throw StateError('请先打开或添加灯具');
    }
    final (double key, double fill) = _baseLux(scene);
    return measuredLux / (key + fill);
  }

  /// 只签名测光实际消费的参数，避免无关编辑造成误报。
  static String signatureOf(LightingSceneData scene) {
    final String lights = scene.lights
        .map(
          (DeviceSpec d) => <Object>[
            d.id,
            d.x.toStringAsFixed(4),
            d.y.toStringAsFixed(4),
            d.type,
            d.intensity,
            d.modifier,
            d.softness.toStringAsFixed(4),
            d.on,
          ].join(':'),
        )
        .join('|');
    return '${scene.ambientEnabled}|$lights';
  }

  static String _shutterLabel(double seconds) {
    var best = _shutterLabels.first;
    var bestDelta = double.infinity;
    for (int i = 0; i < _shutterSeconds.length; i++) {
      final double delta = (_shutterSeconds[i] - seconds).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = _shutterLabels[i];
      }
    }
    return best;
  }

  static List<(double, String)> _shutterPairs() {
    final List<(double, String)> pairs = <(double, String)>[];
    for (var i = 0; i < _shutterSeconds.length; i++) {
      pairs.add((_shutterSeconds[i], _shutterLabels[i]));
    }
    return pairs;
  }

  static double _nearestStop(double f) {
    var best = _apertureStops.first;
    var bestDelta = (best - f).abs();
    for (final double stop in _apertureStops) {
      final double delta = (stop - f).abs();
      if (delta < bestDelta) {
        best = stop;
        bestDelta = delta;
      }
    }
    return best;
  }
}
