import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/lighting/hand_presets.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';
import 'package:shoot_studio/features/poses/poses_controller.dart';
import 'package:shoot_studio/services/content_packs.dart';

/// Q5 手部动作 + 环境光门禁（D85–D88 / R34–R36）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('手部预设表（D86）', () {
    test('15 个预设（12 单手 + 3 双手组合），组合含手臂叠加', () {
      expect(kHandPresetList.length, 15);
      final List<HandPresetInfo> single = kHandPresetList
          .where((HandPresetInfo p) => !p.dual)
          .toList();
      final List<HandPresetInfo> dual = kHandPresetList
          .where((HandPresetInfo p) => p.dual)
          .toList();
      expect(single.length, 12);
      expect(dual.length, 3);
      expect(
        dual.map((HandPresetInfo p) => p.id),
        containsAll(<String>['gongshou', 'qigong', 'prayer']),
      );
      for (final HandPresetInfo p in kHandPresetList) {
        expect(p.label, isNotEmpty);
        expect(p.curls.length, 5, reason: '${p.id} 需含五指弯曲');
        for (final double v in p.curls.values) {
          expect(v, inInclusiveRange(0, 1));
        }
        expect(p.spread, inInclusiveRange(0, 1));
      }
      for (final HandPresetInfo p in dual) {
        expect(p.arms, isNotNull, reason: '${p.id} 缺手臂叠加');
        expect(p.arms!.keys.toSet(), <String>{'l', 'r'});
        for (final Map<String, List<double>> joints in p.arms!.values) {
          expect(
            joints.keys.toSet(),
            containsAll(<String>['shoulder', 'elbow']),
          );
          for (final List<double> v in joints.values) {
            expect(v.length, 3);
          }
        }
      }
    });

    test('引擎 bundle 含手部/环境光 API 与全部预设 id（静态门禁）', () {
      final String js = File(
        'assets/engine/js/engine.bundle.js',
      ).readAsStringSync();
      // 公开 API 与特性串（非局部标识符，压缩后仍保留）。
      for (final String token in <String>[
        'setAmbientEnabled',
        'getAmbientEnabled',
        'setHandPose',
        'setHandCurls',
        'getHandState',
        'listHandPresets',
        'resetHands',
        'hand-bones',
        'qaFocusHand',
      ]) {
        expect(js.contains(token), isTrue, reason: '引擎缺少 $token');
      }
      // 预设表 id（对象键，压缩不改名）。
      for (final HandPresetInfo p in kHandPresetList) {
        expect(
          RegExp('[^A-Za-z0-9_]${p.id}[^A-Za-z0-9_]').hasMatch(js),
          isTrue,
          reason: '引擎预设表缺少 ${p.id}',
        );
      }
      // R35：手部驱动走独立骨集（handSupport/getHandSupport 返回结构）。
      expect(js.contains('handSupport'), isTrue);
    });
  });

  group('场景 JSON 往返（D85/D88、R36）', () {
    test('hands + ambientEnabled 编码/解码；旧数据缺字段时默认 ambient=true', () {
      final LightingSceneData scene = LightingSceneData(
        id: 's1',
        name: '测试',
        devices: <DeviceSpec>[],
        hands: <String, Object?>{
          'l': <String, Object?>{
            'preset': 'peace',
            'spread': 0.7,
            'curls': <String, double>{'index': 0, 'ring': 1},
          },
          'r': <String, Object?>{'preset': 'fist', 'spread': 0},
        },
        ambientEnabled: false,
      );
      final LightingSceneData restored = LightingSceneData.fromJson(
        scene.toJson(),
      );
      expect(restored.ambientEnabled, isFalse);
      expect((restored.hands!['l'] as Map)['preset'], 'peace');
      final (HandPoseState? l, HandPoseState? r) = handsFromJson(
        restored.hands,
      );
      expect(l!.preset, 'peace');
      expect(l.spread, 0.7);
      expect(r!.preset, 'fist');

      // 旧场景（无 hands/ambientEnabled）。
      final LightingSceneData legacy = LightingSceneData.fromJson(
        <String, Object?>{'id': 's2', 'name': '旧', 'devices': <Object?>[]},
      );
      expect(legacy.ambientEnabled, isTrue);
      expect(legacy.hands, isNull);
      // R36：无 hand 字段时 toEngineJson 不注入 hands。
      expect(
        legacy.toEngineJson(poseJoints: <String, Object?>{}).toString(),
        isNot(contains('hands')),
      );
    });

    test('toEngineJson 手部与 12 关节互不干扰（R35）', () {
      final LightingSceneData scene = LightingSceneData(
        id: 's',
        name: 's',
        devices: <DeviceSpec>[],
      );
      final Map<String, Object?> joints = <String, Object?>{
        'spine': <double>[0, 10, 0],
        'rootY': 0.01,
      };
      final Map<String, Object?> engine = scene.toEngineJson(
        poseJoints: joints,
        hands: <String, Object?>{
          'l': <String, Object?>{'preset': 'fist'},
        },
      );
      final Map<String, Object?> subject = (engine['subject'] as Map)
          .cast<String, Object?>();
      expect((subject['pose'] as Map)['joints'], joints);
      expect((subject['hands'] as Map)['l'], <String, Object?>{
        'preset': 'fist',
      });
    });
  });

  group('LightingController 环境光 + 手部（D85–D88）', () {
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

    test('环境光开关持久化 + 场景保存/恢复', () async {
      final LightingController controller = container.read(
        lightingControllerProvider.notifier,
      );
      await controller.setAmbientEnabled(false);
      expect(
        container.read(lightingControllerProvider).ambientEnabled,
        isFalse,
      );
      expect(await db.getSetting('quality_ambient_enabled'), '0');
      await controller.save();
      final List<LightingScene> scenes = await db
          .select(db.lightingScenes)
          .get();
      final Map<String, Object?> saved =
          (jsonDecode(scenes.first.sceneJson) as Map).cast<String, Object?>();
      expect(saved['ambientEnabled'], isFalse);

      // 新容器载入同一 DB → 恢复关闭状态。
      final ProviderContainer container2 = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container2.dispose);
      await container2.read(lightingControllerProvider.notifier).init();
      expect(
        container2.read(lightingControllerProvider).ambientEnabled,
        isFalse,
      );
    });

    test('手部预设：单手/双手组合/自定义/重置（含场景同步）', () async {
      final LightingController controller = container.read(
        lightingControllerProvider.notifier,
      );
      controller.setHandPreset('l', 'peace');
      LightingState state = container.read(lightingControllerProvider);
      expect(state.handL.preset, 'peace');
      expect(state.handL.curls['ring'], 1);
      expect(state.scene.hands!['l'], isNotNull);

      // 双手组合：两侧写入 + 手臂叠加进 pendingPose。
      controller.injectPose(<String, Object?>{
        'spine': <double>[0, 0, 0],
        'rootY': 0.0,
        'rootPitch': 0.0,
      }, '测试姿势');
      final int seqBefore = container
          .read(lightingControllerProvider)
          .poseInjectionSeq;
      controller.setHandPreset('both', 'prayer');
      state = container.read(lightingControllerProvider);
      expect(state.handL.preset, 'prayer');
      expect(state.handR.preset, 'prayer');
      expect(state.pendingPose!['shoulder_l'], isA<List<double>>());
      expect(state.pendingPose!['elbow_r'], isA<List<double>>());
      expect(state.poseInjectionSeq, greaterThan(seqBefore));

      // 每指微调 → custom 且只改指定手指。
      controller.setHandCurl('r', 'index', 0.3);
      state = container.read(lightingControllerProvider);
      expect(state.handR.preset, 'custom');
      expect(state.handR.curls['index'], closeTo(0.3, 1e-9));
      expect((state.scene.hands!['r'] as Map)['preset'], 'custom');

      controller.setHandSpread('r', 0.8);
      expect(container.read(lightingControllerProvider).handR.spread, 0.8);

      controller.resetHands();
      state = container.read(lightingControllerProvider);
      expect(state.handL.preset, 'relax');
      expect(state.handR.preset, 'relax');
    });

    test('导入带手部的姿势（D88 往返）', () async {
      final LightingController controller = container.read(
        lightingControllerProvider.notifier,
      );
      controller.injectPose(
        <String, Object?>{
          'spine': <double>[0, 0, 0],
          'rootY': 0.0,
        },
        '带手部',
        handL: const HandPoseState(
          preset: 'peace',
          curls: <String, double>{'index': 0},
        ),
        handR: const HandPoseState(preset: 'fist'),
      );
      final LightingState state = container.read(lightingControllerProvider);
      expect(state.handL.preset, 'peace');
      expect(state.handR.preset, 'fist');
      expect((state.scene.hands!['l'] as Map)['preset'], 'peace');
    });
  });

  group('自定义姿势携带手部（D88）', () {
    test('saveCustomPose 写入 _hands 并可重新载入', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await ContentPacks.syncToDatabase(db);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final PosesController controller = container.read(
        posesControllerProvider.notifier,
      );
      await controller.init();
      await controller.saveCustomPose(
        name: '测试·带手部',
        joints: <String, Object?>{
          'spine': <double>[0, 5, 0],
          'rootY': 0.0,
          'rootPitch': 2.0,
        },
        handsL: const HandPoseState(preset: 'peace', spread: 0.7),
        handsR: const HandPoseState(preset: 'fist'),
      );
      final PoseEntry? entry = container
          .read(posesControllerProvider)
          .all
          .where((PoseEntry p) => p.name == '测试·带手部')
          .firstOrNull;
      expect(entry, isNotNull);
      expect(entry!.handsL!.preset, 'peace');
      expect(entry.handsR!.preset, 'fist');

      // DB 行内保留键 `_hands`。
      final List<Pose> poseRows = await db.select(db.poses).get();
      final Pose row = poseRows.firstWhere((Pose p) => p.name == '测试·带手部');
      final Map<String, Object?> stored = (jsonDecode(row.jointsJson) as Map)
          .cast<String, Object?>();
      expect(stored.containsKey('_hands'), isTrue);

      // 重新载入（模拟重启）→ 手部恢复。
      final ProviderContainer container2 = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container2.dispose);
      final PosesController controller2 = container2.read(
        posesControllerProvider.notifier,
      );
      await controller2.init();
      final PoseEntry? reloaded = container2
          .read(posesControllerProvider)
          .all
          .where((PoseEntry p) => p.name == '测试·带手部')
          .firstOrNull;
      expect(reloaded!.handsL!.preset, 'peace');
      expect(reloaded.handsR!.preset, 'fist');
      expect(
        reloaded.joints.containsKey('_hands'),
        isFalse,
        reason: '_hands 不应混入 12 关节',
      );
    });
  });
}
