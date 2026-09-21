import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/utils/json_utils.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/poses/pose_landmark_math.dart';
import 'package:shoot_studio/features/poses/pose_skeleton.dart';
import 'package:shoot_studio/features/poses/poses_controller.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'package:shoot_studio/services/pose/pose_grounding.dart';
import 'package:shoot_studio/services/pose/pose_joint_mapper.dart';

/// V6 D 阶段门禁（D122–D128）：关节映射数学、接地校准、覆盖/恢复、
/// 自定义姿势往返、导入骨架数据契约。端上推理本体由本机精度 QA 覆盖
/// （`q6_pose_accuracy_test`，CI 跳过）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PoseJointMapper（D124/D128）', () {
    late List<List<double>> world;
    late Map<String, Object?> expected;

    setUpAll(() async {
      final Map<String, Object?> skeleton =
          (jsonDecode(
                    File(
                      'assets/content/poses3/photos/p001.skeleton.json',
                    ).readAsStringSync(),
                  )
                  as Map)
              .cast<String, Object?>();
      world = (skeleton['world3d'] as List<Object?>)
          .map(
            (Object? p) => (p as List<Object?>)
                .map((Object? v) => (v as num).toDouble())
                .toList(),
          )
          .toList();
      final Map<String, Object?> poses3 =
          (jsonDecode(
                    File(
                      'assets/content/poses3/poses3.json',
                    ).readAsStringSync(),
                  )
                  as Map)
              .cast<String, Object?>();
      for (final Object? raw in poses3['poses'] as List<Object?>) {
        final Map<String, Object?> pose = (raw as Map).cast<String, Object?>();
        if (pose['id'] == 'p001') {
          expected = (pose['joints'] as Map).cast<String, Object?>();
        }
      }
    });

    test('Python world3d → 12 关节：与 poses3 完全一致', () {
      final MappedPose mapped = PoseJointMapper.map(
        world,
        jointConfidence: <String, double>{
          for (final String joint in engineJoints) joint: 0.9,
        },
      );
      expect(mapped.joints.keys.toSet(), engineJoints.toSet());
      var maxError = 0.0;
      for (final MapEntry<String, Object?> entry in expected.entries) {
        final List<double> exp = (entry.value as List)
            .map((Object? v) => (v as num).toDouble())
            .toList();
        final List<double> act = mapped.joints[entry.key]!;
        for (int axis = 0; axis < 3; axis++) {
          final double err = (exp[axis] - act[axis]).abs();
          if (err > maxError) maxError = err;
        }
      }
      expect(maxError, lessThan(0.5), reason: '映射必须与 Python 管线同公式');
      expect(mapped.lowConfidence, isFalse);
      expect(mapped.warnings, isEmpty);
    });

    test('低置信关节 → 标注「仅供参考」', () {
      final MappedPose mapped = PoseJointMapper.map(
        world,
        jointConfidence: <String, double>{'knee_l': 0.2},
      );
      expect(mapped.lowConfidence, isTrue);
      expect(mapped.warnings.single, contains('knee_l'));
      expect(mapped.warnings.single, contains('仅供参考'));
    });

    test('world 点数不足抛错（不静默）', () {
      expect(
        () => PoseJointMapper.map(<List<double>>[
          <double>[0, 0, 0],
        ]),
        throwsArgumentError,
      );
    });

    test('toPoseJson 含 rootY/rootPitch 且 12 关节齐全', () {
      final MappedPose mapped = PoseJointMapper.map(world);
      final Map<String, Object?> json = mapped.toPoseJson();
      expect(json.length, 14);
      expect(json['rootY'], isA<double>());
      expect(json['rootPitch'], isA<double>());
    });
  });

  group('PoseGrounding（接地校准）', () {
    test('脚部可见：沿用世界坐标推导的 rootY', () {
      final DerivedPose derived = deriveJoints(_fakeWorld());
      final GroundedPose grounded = PoseGrounding.ground(
        derived: derived,
        landmarkVisibility: _visibilityWithFeet(0.9),
      );
      expect(grounded.feetVisible, isTrue);
      expect(grounded.rootY, derived.rootY);
      expect(grounded.note, isEmpty);
    });

    test('脚部不可见：退化为站立基准并给出提示（不静默）', () {
      final DerivedPose derived = deriveJoints(_fakeWorld());
      final GroundedPose grounded = PoseGrounding.ground(
        derived: derived,
        landmarkVisibility: _visibilityWithFeet(0.1),
      );
      expect(grounded.feetVisible, isFalse);
      expect(grounded.rootY, 0);
      expect(grounded.note, contains('脚部不可见'));
      expect(grounded.note, contains('rootY=0'));
    });
  });

  group('姿势库：覆盖/恢复/自定义（D126/D127）', () {
    late AppDatabase db;
    late ProviderContainer container;
    late Workspace workspace;
    late Directory tempDir;

    Future<PosesController> boot() async {
      final PosesController controller = container.read(
        posesControllerProvider.notifier,
      );
      await controller.init();
      return controller;
    }

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ss_poses_test');
      workspace = await Workspace.initAt(tempDir.path);
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await ContentPacks.syncToDatabase(db);
      container = ProviderContainer(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          workspaceProvider.overrideWithValue(workspace),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('init 合并覆盖：默认 120 条、无自定义', () async {
      await boot();
      final PosesState state = container.read(posesControllerProvider);
      expect(state.all.length, 120);
      expect(state.overriddenIds, isEmpty);
      expect(state.customIds, isEmpty);
    });

    test('覆盖内置 → 持久化重启仍在 → 一键恢复默认', () async {
      final PosesController controller = await boot();
      final PoseEntry target = container
          .read(posesControllerProvider)
          .all
          .firstWhere((PoseEntry p) => p.id == 'p001');
      final Map<String, Object?> joints = <String, Object?>{
        ...target.joints,
        'shoulder_l': <double>[-10, 0, 5],
        'rootY': 0.12,
        'rootPitch': 3.0,
      };
      await controller.saveOverride(target: target, joints: joints);

      PosesState state = container.read(posesControllerProvider);
      expect(state.isOverridden('p001'), isTrue);
      final PoseEntry overridden = state.all.firstWhere(
        (PoseEntry p) => p.id == 'p001',
      );
      expect(tripleOf(overridden.joints['shoulder_l'])[0], -10);
      expect(overridden.rootY, 0.12);

      // 新容器重读（模拟重启）：覆盖仍在。
      final ProviderContainer second = ProviderContainer(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          workspaceProvider.overrideWithValue(workspace),
        ],
      );
      addTearDown(second.dispose);
      await second.read(posesControllerProvider.notifier).init();
      final PosesState reloaded = second.read(posesControllerProvider);
      expect(reloaded.all.length, 120, reason: '覆盖不应新增条目');
      expect(reloaded.isOverridden('p001'), isTrue);

      await controller.restoreBuiltin('p001');
      state = container.read(posesControllerProvider);
      expect(state.isOverridden('p001'), isFalse);
      final PoseEntry restored = state.all.firstWhere(
        (PoseEntry p) => p.id == 'p001',
      );
      expect(tripleOf(restored.joints['shoulder_l'])[0], -32.74);
    });

    test('自定义姿势：保存（含 rootY/图片文件名）→ 重启仍在 → 删除', () async {
      final PosesController controller = await boot();
      await controller.saveCustomPose(
        name: '测试导入姿势',
        joints: <String, Object?>{
          'spine': <double>[0, 0, 0],
          'rootY': 0.2,
          'rootPitch': 1.5,
        },
        category: '站姿',
        photoFile: 'demo.jpg',
        skeletonFile: 'demo.skeleton.json',
      );
      PosesState state = container.read(posesControllerProvider);
      expect(state.all.length, 121);
      final PoseEntry custom = state.all.last;
      expect(state.isCustom(custom.id), isTrue);
      expect(custom.rootY, 0.2);
      expect(
        custom.photo.endsWith('demo.jpg'),
        isTrue,
        reason: '照片应解析到工作区 images/poses/',
      );

      final ProviderContainer second = ProviderContainer(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          workspaceProvider.overrideWithValue(workspace),
        ],
      );
      addTearDown(second.dispose);
      await second.read(posesControllerProvider.notifier).init();
      final PosesState reloaded = second.read(posesControllerProvider);
      final PoseEntry persisted = reloaded.all.firstWhere(
        (PoseEntry p) => p.id == custom.id,
      );
      expect(persisted.rootY, 0.2);
      expect(persisted.photo.endsWith('demo.jpg'), isTrue);

      await controller.deleteCustom(custom.id);
      state = container.read(posesControllerProvider);
      expect(state.all.length, 120);
      expect(state.all.where((PoseEntry p) => p.id == custom.id), isEmpty);
    });

    test('收藏切换不丢失自定义姿势的 rootY/图片', () async {
      final PosesController controller = await boot();
      await controller.saveCustomPose(
        name: '收藏保真',
        joints: <String, Object?>{
          'spine': <double>[0, 0, 0],
          'rootY': 0.33,
        },
        photoFile: 'keep.jpg',
      );
      final PosesState before = container.read(posesControllerProvider);
      final PoseEntry custom = before.all.last;
      controller.select(before.all.length - 1);
      // 选中：列表顺序变化，直接按 id 切到 filtered 对应位置。
      final PosesState filtered = container.read(posesControllerProvider);
      final int index = filtered.filtered.indexWhere(
        (PoseEntry p) => p.id == custom.id,
      );
      controller.select(index);
      await controller.toggleFavorite();
      final PosesState after = container.read(posesControllerProvider);
      final PoseEntry updated = after.all.firstWhere(
        (PoseEntry p) => p.id == custom.id,
      );
      expect(updated.rootY, 0.33);
      expect(updated.photo.endsWith('keep.jpg'), isTrue);
      expect(after.favorites.contains(custom.id), isTrue);
    });
  });

  group('导入数据契约（D124/D127）', () {
    test('导入骨架 JSON（工作区文件）可被 PoseSkeletonData 读取', () async {
      final Directory dir = await Directory.systemTemp.createTemp('ss_skel');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final File file = File('${dir.path}/demo.skeleton.json');
      await file.writeAsString(
        jsonEncode(<String, Object?>{
          'landmarks2d': <List<double>>[
            for (int i = 0; i < 33; i++) <double>[0.5, 0.5, 0, 0.9],
          ],
          'imageSize': <double>[800, 1200],
          'confidence': 0.88,
          'model': 'pose_detection-3.7',
        }),
      );
      final PoseSkeletonData? data = await PoseSkeletonData.load(file.path);
      expect(data, isNotNull);
      expect(data!.points.length, 33);
      expect(data.points.first!.visibility, 0.9);
      expect(data.imageSize, const Size(800, 1200));
      expect(data.confidence, 0.88);
      // 不存在的路径返回 null，不抛错。
      expect(await PoseSkeletonData.load('${dir.path}/missing.json'), isNull);
    });
  });
}

/// 简易站立世界坐标（hip 中心，y 向下，单位米）。
List<List<double>> _fakeWorld() => <List<double>>[
  <double>[0, -0.7, 0], // 0 nose
  <double>[-0.05, -0.68, 0],
  <double>[0.05, -0.68, 0],
  <double>[-0.08, -0.66, 0],
  <double>[0.08, -0.66, 0],
  <double>[-0.1, -0.65, 0],
  <double>[0.1, -0.65, 0],
  <double>[-0.09, -0.67, 0],
  <double>[0.09, -0.67, 0],
  <double>[-0.12, -0.62, 0],
  <double>[0.12, -0.62, 0],
  <double>[-0.18, -0.5, 0],
  <double>[0.18, -0.5, 0],
  <double>[-0.2, -0.2, 0],
  <double>[0.2, -0.2, 0],
  <double>[-0.22, 0.05, 0],
  <double>[0.22, 0.05, 0],
  <double>[-0.25, 0.02, 0],
  <double>[0.25, 0.02, 0],
  <double>[-0.23, 0.05, 0],
  <double>[0.23, 0.05, 0],
  <double>[-0.26, 0.04, 0],
  <double>[0.26, 0.04, 0],
  <double>[-0.09, 0, 0],
  <double>[0.09, 0, 0],
  <double>[-0.1, 0.45, 0],
  <double>[0.1, 0.45, 0],
  <double>[-0.1, 0.9, 0],
  <double>[0.1, 0.9, 0],
  <double>[-0.1, 0.95, -0.05],
  <double>[0.1, 0.95, -0.05],
  <double>[-0.1, 0.98, 0.08],
  <double>[0.1, 0.98, 0.08],
];

List<double> _visibilityWithFeet(double value) => <double>[
  for (int i = 0; i < 33; i++)
    if (i >= 27) value else 0.9,
];
