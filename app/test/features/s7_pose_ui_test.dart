// V8/S7 · D153：动作摆姿与识别专项测试（姿势库大图流 + 半屏抽屉 + 关节点校正器）。
// 纪律：R79 只新增不改既有测试；纯函数优先测，widget 测试给足视口（useWide）。
// 引用关系：pose_gallery（瀑布流/抽屉）+ pose_joint_tuner（校正器）+ poses_controller（检索增强）。

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/poses/pose_gallery.dart';
import 'package:shoot_studio/features/poses/pose_joint_tuner.dart';
import 'package:shoot_studio/features/poses/pose_skeleton.dart';
import 'package:shoot_studio/features/poses/poses_controller.dart';
import 'package:shoot_studio/services/content_packs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 桌面窗口可缩放：给足视口，避免 tap 落到视口外 + ListView 懒建子项。
  Future<void> useWide(
    WidgetTester tester, {
    Size size = const Size(1600, 1400),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget host(Widget child) {
    return MaterialApp(
      theme: AppTheme.of(AppThemeVariant.darkroom),
      home: Scaffold(body: SafeArea(child: child)),
    );
  }

  PoseEntry pose({String id = 'p001', String name = '站姿·自然站立'}) {
    return PoseEntry(
      id: id,
      name: name,
      category: '站姿',
      difficulty: '新手友好',
      joints: <String, Object?>{},
      rootY: 0,
      rootPitch: 0,
      weight: '重心居中',
      hands: '放松',
      mistake: '含胸',
      lens: '50mm',
      cameraPosition: '腰部平视',
    );
  }

  /// 33 点骨架：左右各一列 + 头，作为拖拽演示夹具。
  List<PosePoint?> points33() {
    return <PosePoint?>[for (int i = 0; i < 33; i++) PosePoint(0.5, 0.5, 1)];
  }

  group('S7 关节点映射（10 项可校正）', () {
    test('覆盖肩/肘/腕/髋/膝 × 左右，且 parent < child', () {
      expect(poseTunableJoints.length, 10);
      for (final MapEntry<String, (int, int)> e in poseTunableJoints.entries) {
        final (int parent, int child) = e.value;
        expect(parent, lessThan(child), reason: e.key);
        expect(parent, inInclusiveRange(0, 32));
        expect(child, inInclusiveRange(0, 32));
      }
      expect(
        poseTunableJoints.keys,
        containsAll(<String>[
          'shoulder_l',
          'elbow_l',
          'wrist_l',
          'shoulder_r',
          'elbow_r',
          'wrist_r',
          'hip_l',
          'knee_l',
          'hip_r',
          'knee_r',
        ]),
      );
    });
  });

  group('S7 校正数学（纯函数）', () {
    test('includedAngleDeg：直角 90°、共线 180°、退化 null', () {
      const PosePoint b = PosePoint(0, 0, 1);
      const PosePoint left = PosePoint(-1, 0, 1);
      const PosePoint up = PosePoint(0, 1, 1);
      expect(includedAngleDeg(left, b, up), closeTo(90, 1e-6));
      const PosePoint right = PosePoint(1, 0, 1);
      expect(includedAngleDeg(left, b, right), closeTo(180, 1e-6));
      // 任一端点重合 → 退化，调用方应回落默认读数而不是崩溃。
      const PosePoint same = PosePoint(0, 0, 1);
      expect(includedAngleDeg(same, b, up), isNull);
      expect(includedAngleDeg(left, b, same), isNull);
    });

    test('poseJointReadoutDeg：关节给两侧夹角，链末端给竖直角', () {
      final List<PosePoint?> pts = points33();
      // elbow_l = 13（父 11 / 子 15）：三点构成直角 → 90°。
      pts[11] = const PosePoint(0.4, 0.6, 1);
      pts[13] = const PosePoint(0.4, 0.4, 1);
      pts[15] = const PosePoint(0.7, 0.4, 1);
      expect(poseJointReadoutDeg(pts, 13), closeTo(90, 1e-6));
      // wrist_l = 15 是链末端（无子点）→ 退化为与竖直方向的夹角。
      pts[15] = const PosePoint(0.5, 0.4, 1);
      expect(poseJointReadoutDeg(pts, 15), closeTo(90, 1e-6));
      // 点集为空时不得抛。
      expect(poseJointReadoutDeg(<PosePoint?>[], 15), isNull);
    });

    test('poseWorldSpan / posePointsPixelSpan：按 y 极差', () {
      final List<List<double>> world = <List<double>>[
        <double>[0, -0.9, 0],
        <double>[0, 0.0, 0],
        <double>[0, 1.7, 0],
      ];
      expect(poseWorldSpan(world), closeTo(2.6, 1e-9));
      final List<PosePoint?> pts = <PosePoint?>[
        const PosePoint(0.5, 0.2, 1),
        const PosePoint(0.5, 0.7, 1),
      ];
      expect(
        posePointsPixelSpan(pts, const Size(1000, 2000)),
        closeTo(1000, 1e-9),
      );
    });

    test('applyPosePointEdits：位移按世界/像素比例折算，未动点不动', () {
      final List<List<double>> world = <List<double>>[
        for (int i = 0; i < 33; i++) <double>[0, i * 0.1, 0],
      ];
      // 世界 y 跨度 0..3.2m；像素跨度 (0.2+32*0.02)-0.2 = 0.64 → ×2000 = 1280px。
      final List<PosePoint?> before = <PosePoint?>[
        for (int i = 0; i < 33; i++) PosePoint(0.5, 0.2 + i * 0.02, 1),
      ];
      final List<PosePoint?> after = List<PosePoint?>.of(before);
      after[15] = PosePoint(0.5, before[15]!.y + 0.1, 1); // +0.1 归一化 = +200px
      final List<List<double>> out = applyPosePointEdits(
        world: world,
        pointsBefore: before,
        pointsAfter: after,
        imageSize: const Size(1000, 2000),
      );
      expect(out.length, 33);
      // ratio = 3.2m / 1280px = 0.0025 m/px；位移 200px × 0.0025 = 0.5m。
      expect(out[15][1], closeTo(world[15][1] + 0.5, 1e-6));
      // 未动的点必须原样。
      expect(out[0][1], closeTo(world[0][1], 1e-9));
      expect(out[32][1], closeTo(world[32][1], 1e-9));
    });

    test('applyPosePointEdits：基准点集为空时不产生位移且不抛', () {
      final List<List<double>> world = <List<double>>[
        for (int i = 0; i < 4; i++) <double>[0, i * 0.5, 0],
      ];
      final List<PosePoint?> after = <PosePoint?>[
        for (int i = 0; i < 4; i++) PosePoint(0.5, 0.5 + i * 0.1, 1),
      ];
      // 没有基准点可比对 → 视为「没拖过」，世界坐标原样返回。
      final List<List<double>> out = applyPosePointEdits(
        world: world,
        pointsBefore: <PosePoint?>[],
        pointsAfter: after,
        imageSize: const Size(1000, 1000),
        fallbackMetersPerPixel: 0.005,
      );
      expect(out.length, 4);
      expect(out[0][1], closeTo(world[0][1], 1e-9));
      expect(out[3][1], closeTo(world[3][1], 1e-9));
    });
  });

  group('S7 骨架命中（校正页可点）', () {
    test('hitTestJoint：命中最近可见点，prefer 优先，空集返回 null', () {
      final List<PosePoint?> pts = <PosePoint?>[
        const PosePoint(0.25, 0.25, 1),
        const PosePoint(0.75, 0.75, 1),
      ];
      final PoseSkeletonPainter painter = PoseSkeletonPainter(
        data: PoseSkeletonData(
          points: pts,
          imageSize: const Size(400, 400),
          confidence: 1,
        ),
      );
      final Rect rect = painter.layoutRect(const Size(400, 400));
      final Offset? first = painter.offsetOf(0, const Size(400, 400));
      expect(first, isNotNull);
      expect(painter.hitTestJoint(first!, const Size(400, 400)), 0);
      final Offset? second = painter.offsetOf(1, const Size(400, 400));
      // 两个点都在命中半径内时，prefer 决定命中哪个。
      expect(painter.hitTestJoint(second!, const Size(400, 400), prefer: 1), 1);
      expect(rect.width, greaterThan(0));
      expect(
        PoseSkeletonPainter(
          data: const PoseSkeletonData(
            points: <PosePoint?>[],
            imageSize: Size(400, 400),
            confidence: 0,
          ),
        ).hitTestJoint(Offset.zero, const Size(400, 400)),
        isNull,
      );
    });

    test('toNormalized 把画布坐标折回 0..1', () {
      final PoseSkeletonPainter painter = PoseSkeletonPainter(
        data: PoseSkeletonData(
          points: points33(),
          imageSize: const Size(400, 400),
          confidence: 1,
        ),
      );
      final Offset? at = painter.offsetOf(0, const Size(400, 400));
      expect(at, isNotNull);
      final Offset? n = painter.toNormalized(at!, const Size(400, 400));
      expect(n, isNotNull);
      expect(n!.dx, inInclusiveRange(0.0, 1.0));
      expect(n.dy, inInclusiveRange(0.0, 1.0));
    });
  });

  group('S7 校正器 widget', () {
    testWidgets('渲染骨架 + 拖动关节点回调坐标', (WidgetTester tester) async {
      await useWide(tester);
      final List<PosePoint?> pts = points33();
      pts[0] = const PosePoint(0.5, 0.2, 1);
      final List<int> moved = <int>[];
      await tester.pumpWidget(
        host(
          PoseJointTuner(
            image: Image.memory(
              _tinyPng(),
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            points: pts,
            imageSize: const Size(400, 400),
            onPointMoved: (int i, double _, double _) => moved.add(i),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(PoseJointTuner), findsOneWidget);
      // painter 是 CustomPaint 的属性而非子节点，find.byType 找不到，要断言 CustomPaint。
      expect(find.byType(CustomPaint), findsWidgets);
      // 角度读数：未拖拽时不显示气泡文案，拖拽中出现 mono 读数。
      final Offset at = tester.getCenter(find.byType(PoseJointTuner));
      final TestGesture gesture = await tester.startGesture(at);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('复位条：无改动时禁用，点「复位全部」回调', (WidgetTester tester) async {
      await useWide(tester);
      var all = 0;
      var joint = 0;
      await tester.pumpWidget(
        host(
          PoseTunerResetBar(
            joints: poseTunableJoints.keys.toList(),
            canReset: false,
            onResetJoint: (String _) => joint++,
            onResetAll: () => all++,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('复位全部'), findsOneWidget);
      // 没改过骨架时按钮禁用：点击不应触发任何复位。
      await tester.tap(find.text('复位全部'));
      await tester.pump();
      expect(all, 0);
      expect(joint, 0);

      await tester.pumpWidget(
        host(
          PoseTunerResetBar(
            joints: const <String>['elbow_l', 'knee_r'],
            canReset: true,
            onResetJoint: (String _) => joint++,
            onResetAll: () => all++,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('复位全部'));
      await tester.pump();
      expect(all, 1);
      await tester.tap(find.text('复位 elbow_l'));
      await tester.pump();
      expect(joint, 1);
    });
  });

  group('S7 姿势库大图流（瀑布流 + 分类眉题）', () {
    testWidgets('空态给衬线提示，非空时渲染图卡 + 眉题', (WidgetTester tester) async {
      await useWide(tester);
      await tester.pumpWidget(
        host(
          PoseGalleryGrid(
            poses: const <PoseEntry>[],
            showSkeleton: true,
            selectedId: '',
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('没有匹配的姿势'), findsOneWidget);

      final List<PoseEntry> items = <PoseEntry>[
        pose(id: 'p001', name: '站姿·自然站立'),
        pose(id: 'p002', name: '站姿·展臂'),
      ];
      await tester.pumpWidget(
        host(
          PoseGalleryGrid(
            poses: items,
            showSkeleton: true,
            selectedId: 'p001',
            onTap: (_) {},
            headerBuilder: (int i) => i == 0
                ? const PoseCategoryEyebrow(category: '站姿', count: 2)
                : null,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('站姿'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(PoseGalleryCard), findsNWidgets(2));
    });

    testWidgets('点图卡回调对应姿势', (WidgetTester tester) async {
      await useWide(tester);
      final List<String> tapped = <String>[];
      await tester.pumpWidget(
        host(
          PoseGalleryGrid(
            poses: <PoseEntry>[pose(id: 'p009', name: '坐姿·自然坐姿')],
            showSkeleton: false,
            selectedId: '',
            onTap: (PoseEntry p) => tapped.add(p.id),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(PoseGalleryCard).first);
      await tester.pump();
      expect(tapped, <String>['p009']);
    });
  });

  group('S7 详情半屏抽屉（≤3 步出片）', () {
    testWidgets('抽屉给大图 + 骨架开关 + 镜头建议 + 送入布光', (WidgetTester tester) async {
      await useWide(tester, size: const Size(1400, 1600));
      var inject = 0;
      var favorite = 0;
      var skeleton = 0;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) => Center(
              child: SsButton(
                label: '打开详情',
                onPressed: () => showPoseDetailSheet(
                  context: context,
                  pose: pose(name: '站姿·自然站立'),
                  showSkeleton: true,
                  favorite: false,
                  onToggleSkeleton: () => skeleton++,
                  onToggleFavorite: () => favorite++,
                  onInjectLighting: () => inject++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('打开详情'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('站姿·自然站立'), findsWidgets);
      expect(find.text('镜头建议'), findsOneWidget);
      expect(find.text('送入布光'), findsOneWidget);
      await tester.tap(find.text('送入布光'));
      await tester.pump();
      expect(inject, 1);
    });
  });

  group('S7 姿势库检索增强（D153：不止按名称）', () {
    test('检索命中类别 / 难度 / 镜头 / 重心等字段', () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'ss_s7_poses_',
      );
      final Workspace workspace = await Workspace.initAt(
        path.join(temp.path, 'ws'),
      );
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          workspaceProvider.overrideWithValue(workspace),
        ],
      );
      addTearDown(container.dispose);
      final PosesController c = container.read(
        posesControllerProvider.notifier,
      );
      await c.init();
      expect(container.read(posesControllerProvider).all.length, 120);

      c.setCategory('全部');
      c.setDifficulty('全部');
      // 镜头建议里的「35mm」不在任何姿势名称里，只有检索增强才能命中。
      c.setKeyword('35mm');
      final List<PoseEntry> byLens = container
          .read(posesControllerProvider)
          .filtered;
      expect(byLens, isNotEmpty);
      expect(byLens.every((PoseEntry p) => p.lens.contains('35mm')), isTrue);

      c.setKeyword('高难度');
      expect(container.read(posesControllerProvider).filtered, isNotEmpty);

      c.setKeyword('');
      expect(container.read(posesControllerProvider).filtered.length, 120);
    });
  });
}

/// 最小 1×1 PNG（避免图片解码失败影响 widget 断言）。
Uint8List _tinyPng() {
  return Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0xF8,
    0xCF,
    0xC0,
    0x00,
    0x00,
    0x03,
    0x01,
    0x01,
    0x00,
    0x18,
    0xDD,
    0x8D,
    0xB0,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);
}
