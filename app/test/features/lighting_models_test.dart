import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';

void main() {
  group('几何推导（方位角 0°=被摄体正面=画布上方，顺时针）', () {
    test('正前 / 右侧 / 后方 / 左侧', () {
      expect(geometryOf(0, -2).azimuth, closeTo(0, 0.01));
      expect(geometryOf(2, 0).azimuth, closeTo(90, 0.01));
      expect(geometryOf(0, 2).azimuth, closeTo(180, 0.01));
      expect(geometryOf(-2, 0).azimuth, closeTo(270, 0.01));
    });

    test('45° 侧前与距离', () {
      final g = geometryOf(1.4142, -1.4142);
      expect(g.azimuth, closeTo(45, 0.1));
      expect(g.distance, closeTo(2.0, 0.01));
    });

    test('距离换算（米）', () {
      expect(geometryOf(3, -4).distance, closeTo(5, 0.001));
    });
  });

  group('场景与引擎 JSON', () {
    test('toEngineJson 输出灯/道具/被摄体', () {
      final scene = LightingSceneData(
        id: 's1',
        name: '测试',
        devices: <DeviceSpec>[
          DeviceSpec(
            id: 'l1',
            kind: 'light',
            name: '主光',
            type: 'hard',
            x: 1,
            y: -2,
            height: 2.1,
          ),
          DeviceSpec(
            id: 'p1',
            kind: 'prop',
            name: '箱体',
            type: 'crate',
            x: -1,
            y: 1,
          ),
        ],
      );
      final json = scene.toEngineJson(
        poseJoints: <String, Object?>{
          'spine': <double>[1, 2, 3],
        },
      );
      expect(json['lights'], hasLength(1));
      expect(json['props'], hasLength(1));
      final subject = json['subject']! as Map<String, Object?>;
      expect(subject['height'], 1.7);
      expect((subject['pose']! as Map<String, Object?>)['joints'], isNotNull);
    });

    test('预设实例化产生独立 id，灯光/道具分类正确', () {
      final devices = instantiatePresetDevices(<Map<String, Object?>>[
        <String, Object?>{'name': '主光', 'x': 1, 'y': -2, 'type': 'hard'},
        <String, Object?>{
          'name': '反光板',
          'x': -1,
          'y': 0.8,
          'type': 'reflector',
        },
      ]);
      expect(devices, hasLength(2));
      expect(devices[0].isLight, isTrue);
      expect(devices[1].isLight, isFalse);
      expect(devices[0].id == devices[1].id, isFalse);
    });

    test('JSON 往返保持一致', () {
      final scene = LightingSceneData(
        id: 's2',
        name: '往返',
        devices: <DeviceSpec>[
          DeviceSpec(
            id: 'l1',
            kind: 'light',
            name: 'Key',
            type: 'soft',
            x: 0.5,
            y: -0.5,
            intensity: 88,
            kelvin: 4300,
            beamAngle: 66,
            softness: 0.5,
            modifier: 'softbox-large',
          ),
        ],
      );
      final back = LightingSceneData.fromJson(scene.toJson());
      expect(back.devices.single.intensity, 88);
      expect(back.devices.single.kelvin, 4300);
      expect(back.devices.single.modifier, 'softbox-large');
    });

    test('设备上限常量 = 40（PRD 边界）', () {
      expect(LightingSceneData.maxDevices, 40);
    });
  });
}
