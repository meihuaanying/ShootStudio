part of 'lighting_controller.dart';

/// 创意预演 / 校准曝光的场景操作。
mixin _LightingExposure on Notifier<LightingState> {
  void setMode(LightingMode mode) {
    state.scene.mode = mode;
    state = state.copyWith(
      dirty: true,
      status: mode == LightingMode.creative
          ? '创意预演：使用经验模型比较光位与光比'
          : '校准曝光：请输入当前场景的实测照度',
    );
  }

  void setExposure({int? iso, double? shutterSeconds}) {
    final ExposureSettings settings = state.scene.exposure;
    settings.iso = (iso ?? settings.iso).clamp(50, 12800);
    settings.shutterSeconds = (shutterSeconds ?? settings.shutterSeconds).clamp(
      1 / 2000,
      8,
    );
    state = state.copyWith(dirty: true);
  }

  bool calibrateExposure(double measuredLux) {
    try {
      final ExposureSettings settings = state.scene.exposure;
      settings.calibrationFactor = LightMeter.calibrationFactorFor(
        state.scene,
        measuredLux,
      );
      settings.measuredLux = measuredLux;
      settings.calibrationSignature = LightMeter.signatureOf(state.scene);
      state = state.copyWith(dirty: true, status: '已按 $measuredLux lux 校准当前场景');
      return true;
    } on ArgumentError {
      state = state.copyWith(status: '实测照度必须是大于 0 的有效数字');
      return false;
    } on StateError {
      state = state.copyWith(status: '请先打开或添加灯具，再进行校准');
      return false;
    }
  }
}
