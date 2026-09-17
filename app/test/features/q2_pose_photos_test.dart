import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/poses/pose_landmark_math.dart';
import 'package:shoot_studio/features/poses/pose_recognize_notice.dart';
import 'package:shoot_studio/services/content_packs.dart';

// Q2 照片姿势库硬门禁（D65–D70、R19/R20/R24/R27）。
// 数据来源：tool/gen_pose_photos.py + extract_pose_skeletons.py + skeleton_to_joints.py。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const List<String> forbiddenTitles = <String>[
    '双人',
    '背靠背',
    '并肩',
    '面对面',
    '比耶',
    'OK 手势',
    '竖大拇指',
    '拳头',
    '握紧',
    '闭目',
    '羞涩',
    '掩面',
    '落泪',
  ];

  late List<PoseEntry> poses;
  late Set<String> attributedFiles;

  setUpAll(() async {
    poses = await ContentPacks.poses();
    final File attr = File('assets/content/attribution.json');
    expect(attr.existsSync(), isTrue, reason: '缺 attribution.json（R24）');
    final Map<String, Object?> json =
        (jsonDecode(attr.readAsStringSync()) as Map).cast<String, Object?>();
    attributedFiles = (json['items'] as List<Object?>? ?? <Object?>[])
        .whereType<Map>()
        .map((Map m) => '${m.cast<String, Object?>()['file']}')
        .toSet();
  });

  group('Q2 照片姿势库', () {
    test('120 条、10 类目 × 12、每张照片/骨架/叠加图存在（D65/D66/R19）', () {
      expect(poses.length, 120);
      final Map<String, int> byCategory = <String, int>{};
      for (final PoseEntry pose in poses) {
        byCategory[pose.category] = (byCategory[pose.category] ?? 0) + 1;
        expect(pose.photo, startsWith('assets/content/poses3/photos/'),
            reason: '${pose.id} 照片路径');
        expect(pose.skeleton, startsWith('assets/content/poses3/photos/'),
            reason: '${pose.id} 骨架路径');
        expect(pose.overlay, startsWith('assets/content/poses3/photos/'),
            reason: '${pose.id} 叠加图路径');
        final File photo = File(pose.photo);
        expect(photo.existsSync(), isTrue, reason: '${pose.id} 缺照片文件');
        expect(photo.lengthSync(), greaterThan(20 * 1024),
            reason: '${pose.id} 照片过小');
        expect(File(pose.skeleton).existsSync(), isTrue,
            reason: '${pose.id} 缺骨架 JSON');
        expect(File(pose.overlay).existsSync(), isTrue,
            reason: '${pose.id} 缺骨架叠加图（D66 证据）');
      }
      expect(
        byCategory.keys.toSet(),
        <String>{'站姿', '坐姿', '蹲姿', '跪姿', '靠姿', '躺姿', '动态', '手部', '神态', '道具互动'},
      );
      for (final MapEntry<String, int> entry in byCategory.entries) {
        expect(entry.value, 12, reason: '${entry.key} 应为 12 条');
      }
    });

    test('许可与署名覆盖（D65/D71/R24）：逐图可查、禁 NC', () {
      const Set<String> allowed = <String>{
        'Pexels License',
        'CC0',
        'CC0-1.0',
        'CC BY 2.0',
        'CC BY 4.0',
        'CC BY-SA 2.0',
        'CC BY-SA 4.0',
        'Public domain',
        'PD',
      };
      for (final PoseEntry pose in poses) {
        expect(pose.author, isNotEmpty, reason: '${pose.id} 缺署名');
        expect(pose.license, isNotEmpty, reason: '${pose.id} 缺许可');
        expect(pose.license.toUpperCase(), isNot(contains('NC')),
            reason: '${pose.id} 禁商用许可（R24）');
        expect(allowed, contains(pose.license),
            reason: '${pose.id} 许可不在白名单：${pose.license}');
        expect(pose.source, isNotEmpty, reason: '${pose.id} 缺来源链接');
        expect(attributedFiles, contains(pose.photo),
            reason: '${pose.id} 未登记 attribution.json');
      }
    });

    test('confidence 字段与 referenceOnly 规则（D68/R20）', () {
      int referenceOnly = 0;
      for (final PoseEntry pose in poses) {
        expect(pose.confidence, inInclusiveRange(0, 1),
            reason: '${pose.id} confidence 越界');
        expect(pose.referenceOnly, pose.confidence < 0.6,
            reason: '${pose.id} referenceOnly 与 confidence 不一致');
        if (pose.referenceOnly) referenceOnly++;
      }
      expect(referenceOnly, greaterThan(0), reason: '低置信度姿势必须显式标注（R20）');
    });

    test('12 关节齐全且在限位内（R20）', () {
      for (final PoseEntry pose in poses) {
        for (final String joint in engineJoints) {
          final Object? value = pose.joints[joint];
          expect(value, isA<List<Object?>>(), reason: '${pose.id} 缺 $joint');
          final List<Object?> triple = value! as List<Object?>;
          expect(triple.length, greaterThanOrEqualTo(3));
          final List<double> v =
              triple.map((Object? e) => (e as num).toDouble()).toList();
          final String base = joint.split('_').first;
          if (base == 'elbow') {
            expect(v[0], inInclusiveRange(-150, 5),
                reason: '${pose.id} $joint rx');
          } else if (base == 'knee') {
            expect(v[0], inInclusiveRange(0, 140),
                reason: '${pose.id} $joint rx');
          } else if (base == 'hip') {
            expect(v[0], inInclusiveRange(-120, 40),
                reason: '${pose.id} $joint rx');
          } else if (base == 'shoulder') {
            expect(v[2], inInclusiveRange(-90, 90),
                reason: '${pose.id} $joint rz');
          }
          for (final double axis in v) {
            expect(axis.abs(), lessThanOrEqualTo(180),
                reason: '${pose.id} $joint');
          }
        }
      }
      final Map<String, Object?> raw = (jsonDecode(
                  File('assets/content/poses3/poses3.json').readAsStringSync())
              as Map)
          .cast<String, Object?>();
      expect((raw['clamps'] as List<Object?>?)?.isNotEmpty, isTrue,
          reason: '限位夹取记录应随包产出（可追溯）');
    });

    test('标题不承诺 12 关节模型不具备的能力（手部/表情/双人）', () {
      for (final PoseEntry pose in poses) {
        for (final String bad in forbiddenTitles) {
          expect(pose.name.contains(bad), isFalse,
              reason: '「${pose.name}」超出 12 关节模型能力');
        }
      }
    });

    test('R20 可追溯：world3d → 12 关节（Dart 端上推导与构建期管线一致）', () {
      final File stateFile = File('../docs/pose-qa3/qa_photo_state.json');
      expect(stateFile.existsSync(), isTrue,
          reason: '缺接地校准证据 qa_photo_state.json（D68）');
      final Map<String, Object?> state =
          (jsonDecode(stateFile.readAsStringSync()) as Map)
              .cast<String, Object?>();
      final Map<String, Object?> photoState =
          (state['photo'] as Map? ?? <String, Object?>{})
              .cast<String, Object?>();
      final Map<String, dynamic> calibrations = <String, dynamic>{
        for (final Object? c
            in photoState['calibrations'] as List<Object?>? ?? <Object?>[])
          if (c is Map) '${c['id']}': c,
      };
      final Map<String, Object?> rawBounds =
          (photoState['bounds'] as Map? ?? <String, Object?>{})
              .cast<String, Object?>();
      for (final PoseEntry pose in poses) {
        final Map<String, Object?> skeleton =
            (jsonDecode(File(pose.skeleton).readAsStringSync()) as Map)
                .cast<String, Object?>();
        expect(skeleton['personDetected'], isTrue,
            reason: '${pose.id} 骨架未检出人体');
        final List<V3> world = (skeleton['world3d'] as List<Object?>)
            .whereType<List<Object?>>()
            .map((List<Object?> p) =>
                p.map((Object? v) => (v as num).toDouble()).toList())
            .toList();
        expect(world.length, 33, reason: '${pose.id} world3d 应为 33 点');
        final DerivedPose derived =
            deriveJoints(world, category: pose.category);
        for (final String joint in engineJoints) {
          final List<double> expected = (pose.joints[joint]! as List<Object?>)
              .map((Object? v) => (v as num).toDouble())
              .toList();
          final List<double> actual = derived.joints[joint]!;
          for (int i = 0; i < 3; i++) {
            expect((actual[i] - expected[i]).abs(), lessThan(1.0),
                reason: '${pose.id} $joint 轴 $i 与构建期不一致');
          }
        }
        expect((derived.rootPitch - pose.rootPitch).abs(), lessThan(1.0),
            reason: '${pose.id} rootPitch 与构建期不一致');
        // rootY：QA 接地校准后的值可追溯（校准记录精确匹配；未记录条目按
        // 渲染测量验证已贴地，且与原始推导值偏差在接地校正量级内）。
        final Object? measured = rawBounds[pose.id];
        expect(measured, isNotNull, reason: '${pose.id} 缺 QA 接地测量（bounds）');
        final double minY = ((measured! as Map)['minY'] as num).toDouble();
        final bool airborne = pose.category == '动态' ||
            pose.name.contains('跳') ||
            pose.name.contains('跃') ||
            pose.name.contains('腾空');
        if (airborne) {
          expect(minY, greaterThan(-0.02),
              reason: '${pose.id} 腾空姿势穿地（minY=$minY）');
          expect(pose.rootY, greaterThanOrEqualTo(0.19),
              reason: '${pose.id} 腾空姿势 rootY 未离地');
        } else {
          expect(minY.abs(), lessThan(0.08),
              reason: '${pose.id} 最终 rootY 未贴地（minY=$minY）');
        }
        final Object? calibrated = calibrations[pose.id];
        if (calibrated is Map && calibrated['after'] is num) {
          expect((pose.rootY - (calibrated['after'] as num).toDouble()).abs(),
              lessThan(0.005),
              reason: '${pose.id} rootY 与接地校准记录不一致');
        } else {
          // 未记录单轮校准：rootY = 推导值 + 接地校正（多轮 QA 累积）。
          expect((pose.rootY - derived.rootY).abs(), lessThan(1.4),
              reason: '${pose.id} rootY 偏离推导值过多（接地校正量级异常）');
        }
      }
      // bounds 映射应覆盖全部姿势（地面测量不被静默跳过）。
      expect(rawBounds.length, poses.length);
    });

    test('半身/特写照片标注 partialBody（D68 存疑清单）', () {
      int partial = 0;
      for (final PoseEntry pose in poses) {
        final Map<String, Object?> skeleton =
            (jsonDecode(File(pose.skeleton).readAsStringSync()) as Map)
                .cast<String, Object?>();
        final List<Object?> landmarks =
            skeleton['landmarks2d'] as List<Object?>? ?? <Object?>[];
        final List<double> ys = <double>[
          for (final Object? row in landmarks)
            if (row is List && row.length > 1) (row[1] as num).toDouble(),
        ];
        final double span =
            ys.isEmpty ? 0 : ys.reduce(math.max) - ys.reduce(math.min);
        final bool expected = span < 0.45 || span > 1.2;
        expect(pose.partialBody, expected,
            reason: '${pose.id} partialBody 标注与关键点跨度不一致');
        if (expected) {
          partial++;
          expect(pose.partialReason, isNotEmpty,
              reason: '${pose.id} 缺 partialReason');
        }
      }
      expect(partial, greaterThan(0), reason: '应存在半身/特写样本');
    });

    testWidgets('R23：端上识别不可用时给出可读提示且不阻塞（降级路径）', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPoseRecognizeNotice(context),
                child: const Text('open-notice'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open-notice'));
      await tester.pumpAndSettle();
      expect(find.text('端上照片识别暂不可用'), findsOneWidget);
      expect(find.textContaining('内置骨架'), findsWidgets);
      expect(find.textContaining('关节微调'), findsWidgets);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(find.text('端上照片识别暂不可用'), findsNothing);
    });
  });
}
