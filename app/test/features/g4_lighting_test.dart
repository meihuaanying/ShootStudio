import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/lighting/light_meter.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';

LightingSceneData _scene(List<DeviceSpec> lights) =>
    LightingSceneData(id: 's', name: '测试场景', devices: lights);

DeviceSpec _light({
  required String id,
  double x = -1.2,
  double y = -1.6,
  String type = 'hard',
  int intensity = 70,
  double softness = 0.2,
  bool on = true,
}) => DeviceSpec(
  id: id,
  kind: 'light',
  name: id,
  type: type,
  x: x,
  y: y,
  intensity: intensity,
  softness: softness,
  on: on,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('G4 虚拟测光表', () {
    test('无灯时给出引导文案', () {
      final LightMeterReading r = LightMeter.compute(_scene(<DeviceSpec>[]));
      expect(r.ev100, 0);
      expect(r.aperture, '—');
      expect(r.advice, contains('打开'));
    });

    test('单灯：EV 与标准档位光圈，比例与影调可读', () {
      final LightMeterReading r = LightMeter.compute(
        _scene(<DeviceSpec>[_light(id: 'key')]),
      );
      expect(r.ev100, greaterThan(4));
      expect(r.aperture, startsWith('f/'));
      expect(<String>[
        'f/1.4',
        'f/2.0',
        'f/2.8',
        'f/4.0',
        'f/5.6',
        'f/8',
        'f/11',
        'f/16',
        'f/22',
      ], contains(r.aperture));
      expect(r.shutter, isNot('—'));
      expect(r.moodLabel, isNotEmpty);
    });

    test('主辅灯光比：4:1 时提示补光注意', () {
      final LightMeterReading r = LightMeter.compute(
        _scene(<DeviceSpec>[
          _light(id: 'key', intensity: 90, x: -1.2, y: -1.6),
          _light(id: 'fill', intensity: 15, x: 1.8, y: -1.0, type: 'soft'),
        ]),
      );
      final double ratio = r.keyLux / r.fillLux;
      expect(ratio, greaterThan(3));
      expect(r.ratioLabel, isNotEmpty);
    });

    test('关灯不计入照度', () {
      final LightMeterReading a = LightMeter.compute(
        _scene(<DeviceSpec>[
          _light(id: 'key', intensity: 70),
          _light(id: 'off', intensity: 100, on: false),
        ]),
      );
      final LightMeterReading b = LightMeter.compute(
        _scene(<DeviceSpec>[_light(id: 'key', intensity: 70)]),
      );
      expect(a.keyLux, closeTo(b.keyLux, 0.001));
    });

    test('光比接近 1 时提示画面偏平', () {
      final LightMeterReading r = LightMeter.compute(
        _scene(<DeviceSpec>[
          _light(id: 'a', intensity: 60, x: -1.2, y: -1.6),
          _light(id: 'b', intensity: 58, x: 1.2, y: -1.6),
        ]),
      );
      expect(r.advice, contains('偏平'));
    });

    test('校准模式在没有实测值时不伪造曝光建议', () {
      final LightingSceneData scene = _scene(<DeviceSpec>[_light(id: 'key')])
        ..mode = LightingMode.calibrated;
      final LightMeterReading r = LightMeter.compute(scene);
      expect(r.needsCalibration, isTrue);
      expect(r.aperture, '—');
      expect(r.totalLux, 0);
      expect(r.advice, contains('入射照度'));
    });

    test('实测总照度驱动 EV，并使用固定 ISO 与快门', () {
      final LightingSceneData scene = _scene(<DeviceSpec>[_light(id: 'key')])
        ..mode = LightingMode.calibrated;
      scene.exposure
        ..iso = 200
        ..shutterSeconds = 1 / 60
        ..measuredLux = 1000
        ..calibrationFactor = LightMeter.calibrationFactorFor(scene, 1000)
        ..calibrationSignature = LightMeter.signatureOf(scene);
      final LightMeterReading r = LightMeter.compute(scene);
      expect(r.needsCalibration, isFalse);
      expect(r.calibrationStale, isFalse);
      expect(r.totalLux, closeTo(1000, 0.001));
      expect(r.ev100, closeTo(math.log(1000 / 2.5) / math.ln2, 0.001));
      expect(r.iso, 200);
      expect(r.shutter, '1/60');
      expect(r.aperture, 'f/4.0');
    });

    test('改灯保留固定系数、改变读数并提示重新校准', () {
      final LightingSceneData scene = _scene(<DeviceSpec>[_light(id: 'key')])
        ..mode = LightingMode.calibrated;
      scene.exposure
        ..measuredLux = 800
        ..calibrationFactor = LightMeter.calibrationFactorFor(scene, 800)
        ..calibrationSignature = LightMeter.signatureOf(scene);
      final LightMeterReading before = LightMeter.compute(scene);
      scene.lights.single.intensity = 100;
      final LightMeterReading after = LightMeter.compute(scene);
      expect(after.totalLux, greaterThan(before.totalLux));
      expect(after.calibrationFactor, before.calibrationFactor);
      expect(after.calibrationStale, isTrue);
      expect(after.advice, contains('重新测量'));
    });

    test('所需光圈超出常见范围时要求调整曝光参数', () {
      final LightingSceneData scene = _scene(<DeviceSpec>[_light(id: 'key')])
        ..mode = LightingMode.calibrated;
      scene.exposure
        ..measuredLux = 1
        ..calibrationFactor = LightMeter.calibrationFactorFor(scene, 1)
        ..calibrationSignature = LightMeter.signatureOf(scene);
      final LightMeterReading r = LightMeter.compute(scene);
      expect(r.aperture, 'f/1.4');
      expect(r.advice, contains('调整 ISO 或快门'));
    });

    test('无效实测照度与无灯场景不能生成校准系数', () {
      final LightingSceneData scene = _scene(<DeviceSpec>[_light(id: 'key')]);
      expect(
        () => LightMeter.calibrationFactorFor(scene, 0),
        throwsArgumentError,
      );
      expect(
        () => LightMeter.calibrationFactorFor(_scene(<DeviceSpec>[]), 800),
        throwsStateError,
      );
    });
  });

  group('G4 rotationY 全链路', () {
    test('DeviceSpec 序列化包含 rotationY 且引擎场景携带朝向', () {
      final LightingSceneData scene = _scene(<DeviceSpec>[
        DeviceSpec(
          id: 'l1',
          kind: 'light',
          name: '主光',
          type: 'soft',
          x: -1.2,
          y: -1.6,
          rotation: 135,
        ),
      ]);
      final Map<String, Object?> lightJson = scene.lights.first.toJson();
      expect(lightJson['rotationY'], 135);
      final Map<String, Object?> engine = scene.toEngineJson();
      final List<Object?> lights = engine['lights'] as List<Object?>;
      expect((lights.first as Map)['rotationY'], 135);
      // 往返不丢。
      final LightingSceneData copy = LightingSceneData.fromJson(scene.toJson());
      expect(copy.lights.first.rotation, 135);
    });

    test('道具不使用 rotationY（保留 rotation 语义）', () {
      final DeviceSpec prop = DeviceSpec(
        id: 'p1',
        kind: 'prop',
        name: '椅子',
        type: 'crate',
        x: 1,
        y: 1,
        rotation: 45,
      );
      expect(prop.toJson().containsKey('rotationY'), isFalse);
      expect(prop.toJson()['rotation'], 45);
    });
  });

  test('G4 引擎包：骨骼/性别/面光均已内置', () {
    final File bundle = File('assets/engine/js/engine.bundle.js');
    expect(bundle.existsSync(), isTrue);
    final String js = bundle.readAsStringSync();
    expect(js.contains('setSkeletonMode'), isTrue);
    expect(js.contains('setGender'), isTrue);
    expect(js.contains('LTC_FLOAT_1'), isTrue); // LTC 面光贴图已内联
    expect(bundle.lengthSync() < 1500 * 1024, isTrue, reason: 'bundle 超出预算');
  });
}
