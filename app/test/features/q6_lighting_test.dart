import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/lighting/light_meter.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';

/// V6 阶段 B 门禁：布光预设一致性 / 机位模型 / 瞄准与光锥接线（D105–D112、R49–R52）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('布光预设数据（D110/R50）', () {
    late List<Map<String, Object?>> presets;
    late String bundle;
    setUpAll(() {
      final File file = File('assets/content/light_presets/light_presets.json');
      expect(file.existsSync(), isTrue, reason: '缺少 light_presets.json');
      final Map<String, Object?> json =
          (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
      presets = (json['presets'] as List<Object?>)
          .map((Object? e) => (e as Map).cast<String, Object?>())
          .toList();
      bundle = File('assets/engine/js/engine.bundle.js').readAsStringSync();
    });

    test('32 套预设；全部设备带 stand/offsetYaw/offsetPitch 且 rotationY=0', () {
      expect(presets.length, 32);
      for (final Map<String, Object?> preset in presets) {
        final List<Map<String, Object?>> devices =
            ((preset['devices'] as List<Object?>?) ?? <Object?>[])
                .map((Object? e) => (e as Map).cast<String, Object?>())
                .toList();
        expect(devices, isNotEmpty, reason: '${preset['id']} 无设备');
        for (final Map<String, Object?> device in devices) {
          expect(
            device['rotationY'],
            0,
            reason: '${preset['id']} 仍依赖 rotationY',
          );
          expect(
            device['offsetYaw'],
            isA<num>(),
            reason: '${preset['id']}/${device['name']} 缺 offsetYaw',
          );
          expect(
            device['offsetPitch'],
            isA<num>(),
            reason: '${preset['id']}/${device['name']} 缺 offsetPitch',
          );
          expect(
            <String>['normal', 'c', 'boom'],
            contains('${device['stand'] ?? ''}'),
            reason: '${preset['id']}/${device['name']} stand 非法',
          );
          // 数据引用的 fixture/modifier 必须真实存在于引擎（防笔误）。
          final String fixture = '${device['fixture'] ?? ''}';
          final String modifier = '${device['modifier'] ?? ''}';
          if (fixture.isNotEmpty) {
            expect(
              bundle.contains('"$fixture"'),
              isTrue,
              reason: '引擎缺少灯型 $fixture',
            );
          }
          if (modifier.isNotEmpty) {
            expect(
              bundle.contains('"$modifier"'),
              isTrue,
              reason: '引擎缺少附件 $modifier',
            );
          }
        }
      }
    });

    test('新增预设（美人光/发丝光/双轮廓/色光派对）存在且用新附件', () {
      final Set<String> ids = presets
          .map((Map<String, Object?> p) => '${p['id']}')
          .toSet();
      expect(
        ids,
        containsAll(<String>[
          'clamshell',
          'hair-light',
          'split-rim',
          'gel-party',
        ]),
      );
      final Map<String, Object?> clamshell = presets.firstWhere(
        (Map<String, Object?> p) => p['id'] == 'clamshell',
      );
      final Iterable<String> modifiers = (clamshell['devices'] as List<Object?>)
          .map((Object? e) => '${(e as Map)['modifier']}');
      expect(modifiers, everyElement('octa-softbox'));
    });

    test('V7/D138 扩充预设（28→32）：百叶硬光/硬光夹光/霓虹灯管/办公室窗光', () {
      final Set<String> ids = presets
          .map((Map<String, Object?> p) => '${p['id']}')
          .toSet();
      expect(
        ids,
        containsAll(<String>[
          'blinds-window-hard',
          'clamshell-hard',
          'neon-tube',
          'office-window',
        ]),
      );
      // 百叶变体仍用 gobo-blinds（与 blinds-window 同附件、更强对比）。
      final Map<String, Object?> blindsHard = presets.firstWhere(
        (Map<String, Object?> p) => p['id'] == 'blinds-window-hard',
      );
      final List<Map<String, Object?>> blindsDevices =
          (blindsHard['devices'] as List<Object?>)
              .map((Object? e) => (e as Map).cast<String, Object?>())
              .toList();
      expect(blindsDevices.first['modifier'], 'gobo-blinds');
      expect(
        (blindsDevices.first['intensity'] as num).toInt() >
            (blindsDevices.last['intensity'] as num).toInt(),
        isTrue,
        reason: '硬光变体应保持高对比（主光 > 补光）',
      );
      // 霓虹灯管使用此前未用的 rgb-tube 灯型。
      final Map<String, Object?> neon = presets.firstWhere(
        (Map<String, Object?> p) => p['id'] == 'neon-tube',
      );
      expect(
        (neon['devices'] as List<Object?>).map(
          (Object? e) => '${(e as Map)['fixture']}',
        ),
        everyElement('rgb-tube'),
      );
      // 硬光夹光：上雷达罩 + 下标准罩，且下灯强度约为上灯一半以内。
      final Map<String, Object?> hard = presets.firstWhere(
        (Map<String, Object?> p) => p['id'] == 'clamshell-hard',
      );
      final List<Map<String, Object?>> hardDevices =
          (hard['devices'] as List<Object?>)
              .map((Object? e) => (e as Map).cast<String, Object?>())
              .toList();
      expect(hardDevices.first['modifier'], 'beauty-dish');
      expect(hardDevices.last['modifier'], 'standard-reflector');
      expect(
        (hardDevices.last['intensity'] as num) <=
            (hardDevices.first['intensity'] as num) * 0.5,
        isTrue,
      );
    });
  });

  group('机位模型与场景往返（D105）', () {
    test('CameraRigData 往返 + 旧场景缺 camera 字段默认值', () {
      final CameraRigData rig = CameraRigData(
        x: 1.2,
        y: 3.6,
        height: 1.5,
        yaw: 12,
        pitch: -4,
        focal: 85,
        enabled: false,
      );
      final CameraRigData restored = CameraRigData.fromJson(
        rig.toJson().cast<String, Object?>(),
      );
      expect(restored.x, 1.2);
      expect(restored.y, 3.6);
      expect(restored.height, 1.5);
      expect(restored.yaw, 12);
      expect(restored.pitch, -4);
      expect(restored.focal, 85);
      expect(restored.enabled, isFalse);

      final LightingSceneData legacy = LightingSceneData.fromJson(
        <String, Object?>{'id': 's', 'name': '旧', 'devices': <Object?>[]},
      );
      expect(legacy.camera.y, 3.2);
      expect(legacy.camera.focal, 50);
      // 旧场景 toJson 自动带上默认机位（前向兼容）。
      expect(legacy.toJson().containsKey('camera'), isTrue);
    });

    test('toEngineJson 带 camera；DeviceSpec stand/offset 往返', () {
      final LightingSceneData scene = LightingSceneData(
        id: 's',
        name: 's',
        devices: <DeviceSpec>[],
      );
      scene.camera.focal = 135;
      final Map<String, Object?> engine = scene.toEngineJson();
      final Map<String, Object?> camera = (engine['camera'] as Map)
          .cast<String, Object?>();
      expect(camera['focal'], 135);

      final DeviceSpec spec = DeviceSpec(
        id: 'd1',
        kind: 'light',
        name: '灯',
        type: 'hard',
        stand: 'boom',
        offsetYaw: 8,
        offsetPitch: -3,
      );
      final DeviceSpec restored = DeviceSpec.fromJson(
        spec.toJson().cast<String, Object?>(),
      );
      expect(restored.stand, 'boom');
      expect(restored.offsetYaw, 8);
      expect(restored.offsetPitch, -3);
    });
  });

  group('引擎 bundle 静态门禁（V6 阶段 B）', () {
    test('机位/光锥/新附件/瞄准特性串存在', () {
      final String js = File(
        'assets/engine/js/engine.bundle.js',
      ).readAsStringSync();
      for (final String token in <String>[
        'setCameraRig',
        'setCameraView',
        'getCameraRig',
        'setLightCones',
        'getLightCones',
        'cameraRig',
        'lightCone',
        'offsetYaw',
        'offsetPitch',
        'octa-softbox',
        'strip-softbox',
        'umbrella-silver',
        'umbrella-translucent',
        'softbox-grid',
        'gel-cto',
        'gel-ctb',
        'performance-profile',
        // V7/D137：软阴影 + 图案片投光
        'setSoftShadows',
        'getSoftShadows',
        'gobo-blinds',
        // V7/D138：路径追踪静帧导出 + A/B 冻结 + 诊断
        'renderStill',
        'warmPathTracer',
        'path-tracer',
        'supersample',
        'stillProgress',
        'stillRendered',
        'capture-token',
        'getLightDebug',
        // V7/D139：相机辅助（景深物理相机 + 焦段/视野信息）
        'camera-assist',
        'getCameraAssist',
        'fStop',
        'focusDistance',
        'PhysicalCamera',
        'dofFallback',
      ]) {
        expect(js.contains(token), isTrue, reason: '引擎缺少 $token');
      }
    });

    test('V7/D138 路径追踪包随包且导出 SSPathTracer（R64/R69）', () {
      final File bundle = File('assets/engine/js/pathtracer.bundle.js');
      expect(bundle.existsSync(), isTrue, reason: '缺少 pathtracer.bundle.js');
      final String js = bundle.readAsStringSync();
      expect(js.contains('SSPathTracer'), isTrue);
      expect(js.contains('PathTracingRenderer'), isTrue);
      // 许可文件随包（R63）。
      expect(
        File('assets/engine/js/vendor/PATHTRACER_LICENSE').existsSync(),
        isTrue,
      );
      expect(
        File('assets/engine/js/vendor/MESHBVH_LICENSE').existsSync(),
        isTrue,
      );
      // 低配/加载失败回退路径必须有实现（R69）。
      final String engine = File(
        'assets/engine/js/engine.js',
      ).readAsStringSync();
      expect(engine.contains('fallbackReason'), isTrue);
    });

    test('瞄准数学单测脚本存在（Node 纯函数门禁）', () {
      expect(File('tool/test_aim.mjs').existsSync(), isTrue);
      final String aim = File('assets/engine/js/aim.js').readAsStringSync();
      expect(aim.contains('export function computeAim'), isTrue);
      expect(aim.contains('export function aimDirection'), isTrue);
    });
  });

  group('LightingController 机位/光锥（D105/D111）', () {
    late AppDatabase db;
    late ProviderContainer container;
    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      await container.read(lightingControllerProvider.notifier).init();
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('机位变更序号递增 + POV 开关 + 场景持久化', () async {
      final LightingController controller = container.read(
        lightingControllerProvider.notifier,
      );
      final int seq0 = container.read(lightingControllerProvider).cameraSeq;
      controller.moveCamera(1.5, 2.5);
      controller.updateCamera((CameraRigData c) => c.focal = 85);
      final LightingState state = container.read(lightingControllerProvider);
      expect(state.cameraSeq, seq0 + 2);
      expect(state.scene.camera.x, 1.5);
      expect(state.scene.camera.focal, 85);

      controller.setCameraView(true);
      expect(container.read(lightingControllerProvider).cameraView, isTrue);

      await controller.save();
      final LightingScene scene =
          (await db.select(db.lightingScenes).get()).first;
      final Map<String, Object?> saved = (jsonDecode(scene.sceneJson) as Map)
          .cast<String, Object?>();
      expect(((saved['camera'] as Map)['focal'] as num).toInt(), 85);
    });

    test('光锥开关持久化 + 测光表按控光件衰减（D112）', () async {
      final LightingController controller = container.read(
        lightingControllerProvider.notifier,
      );
      await controller.setLightCones(true);
      expect(container.read(lightingControllerProvider).lightCones, isTrue);
      expect(await db.getSetting('quality_light_cones'), '1');

      // 同一盏灯：裸灯 vs 大柔光箱，照度比应约等于 0.68。
      final LightingSceneData bare = LightingSceneData(
        id: 'a',
        name: 'a',
        devices: <DeviceSpec>[
          DeviceSpec(
            id: 'l1',
            kind: 'light',
            name: 'K',
            type: 'hard',
            modifier: 'bare',
          ),
        ],
      );
      final LightingSceneData boxed = LightingSceneData(
        id: 'b',
        name: 'b',
        devices: <DeviceSpec>[
          DeviceSpec(
            id: 'l1',
            kind: 'light',
            name: 'K',
            type: 'hard',
            modifier: 'softbox-large',
          ),
        ],
      );
      // 环境底光常量 12 会同时加在两盏灯上，先扣除再比。
      final double bareLux = LightMeter.compute(bare).keyLux - 12;
      final double boxLux = LightMeter.compute(boxed).keyLux - 12;
      expect(boxLux / bareLux, closeTo(0.68, 0.02));
    });
  });
}
