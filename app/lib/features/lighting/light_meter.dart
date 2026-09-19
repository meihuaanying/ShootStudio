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
    final double distance =
        math.max(0.6, math.sqrt(light.x * light.x + light.y * light.y));
    // 柔光衰减较慢（大面积光源），硬光按平方反比。
    final double falloff = light.type == 'hard' ? 1.0 : 0.78;
    final double softening = 1 - (light.softness.clamp(0.02, 1) * 0.2);
    return base * falloff * softening / (distance * distance) + ambient;
  }

  static LightMeterReading compute(LightingSceneData scene) {
    final List<DeviceSpec> lights =
        scene.devices.where((DeviceSpec d) => d.isLight && d.on).toList();
    if (lights.isEmpty) {
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
    const double ambient = 12; // 白棚环境底光
    final List<double> luxes = lights
        .map((DeviceSpec d) => _luxOf(d, ambient))
        .toList()
      ..sort((double a, double b) => b.compareTo(a));
    final double key = luxes.first;
    final double fill =
        luxes.skip(1).fold<double>(0, (double a, double b) => a + b);
    final double ev = math.log(key / 2.5) / math.ln2;

    final int iso = 100;
    double? aperture;
    String shutter = '1/125';
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
    final double fNumber = _nearestStop(aperture ?? 8);

    final double ratio = key / math.max(12, fill);
    final String ratioLabel =
        ratio >= 2 ? '${(ratio.round())}:1' : '${ratio.toStringAsFixed(1)}:1';
    final String mood = key > 900
        ? (ratio >= 4 ? '硬调·高反差' : '明亮·硬光')
        : key > 350
            ? (ratio >= 4 ? '低调·戏剧感' : '柔和·自然')
            : '暗调·氛围感';
    final String advice = ratio >= 4
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
    );
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
