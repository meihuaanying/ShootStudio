import '../../core/utils/json_utils.dart';

/// 创意预演使用经验模型；校准曝光使用现场实测照度修正经验模型。
enum LightingMode {
  creative('创意预演'),
  calibrated('校准曝光');

  const LightingMode(this.label);
  final String label;

  static LightingMode fromName(String? name) => LightingMode.values.firstWhere(
    (LightingMode mode) => mode.name == name,
    orElse: () => LightingMode.creative,
  );
}

/// 随场景保存的曝光设置与校准凭证。
///
/// [calibrationFactor] 在用户点击“校准”时固定，而不是每次动态重算，
/// 因此后续改变灯距或功率仍会改变曝光结果。[calibrationSignature]
/// 用于识别校准后的布光变化，避免把旧校准伪装成当前场景的实测结果。
class ExposureSettings {
  ExposureSettings({
    this.iso = 100,
    this.shutterSeconds = 1 / 125,
    this.measuredLux,
    this.calibrationFactor = 1,
    this.calibrationSignature = '',
  });

  int iso;
  double shutterSeconds;
  double? measuredLux;
  double calibrationFactor;
  String calibrationSignature;

  bool get isCalibrated =>
      measuredLux != null &&
      measuredLux! > 0 &&
      calibrationFactor > 0 &&
      calibrationSignature.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'iso': iso,
    'shutterSeconds': shutterSeconds,
    if (isCalibrated) ...<String, Object?>{
      'measuredLux': measuredLux,
      'calibrationFactor': calibrationFactor,
      'calibrationSignature': calibrationSignature,
    },
  };

  static ExposureSettings fromJson(Map<String, Object?>? json) {
    final Map<String, Object?> value = json ?? <String, Object?>{};
    return ExposureSettings(
      iso: asInt(value['iso'], 100).clamp(50, 12800),
      shutterSeconds: asDouble(
        value['shutterSeconds'],
        1 / 125,
      ).clamp(1 / 2000, 8),
      measuredLux: value['measuredLux'] == null
          ? null
          : asDouble(value['measuredLux']),
      calibrationFactor: asDouble(value['calibrationFactor'], 1),
      calibrationSignature: value['calibrationSignature'] as String? ?? '',
    );
  }

  ExposureSettings copy() => ExposureSettings.fromJson(deepCopy(toJson()));
}
