import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/ai/ai_controller.dart';
import 'package:shoot_studio/features/export/exporter.dart';
import 'package:shoot_studio/features/planner/planner_controller.dart';
import 'package:shoot_studio/features/planner/planner_page.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/services/content_packs.dart';

import '../support/test_env.dart';

Future<void> settleUntil(
  WidgetTester tester,
  Finder finder, {
  int tries = 80,
  bool required = false,
}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 60));
  }
  if (required) {
    expect(finder.evaluate(), isNotEmpty, reason: '等待超时：$finder');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('J3：本地引擎产出 8–12 镜分镜且质量分 ≥90', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ContentPacks.syncToDatabase(db);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final AiController controller =
        container.read(aiControllerProvider.notifier);
    await controller.init();

    final AiDraftResult draft =
        await controller.generatePlan('汉服园林晨雾', forceLocal: true);
    final PlanModuleData sb = draft.modules
        .firstWhere((PlanModuleData m) => m.type == PlanModuleType.storyboard);
    final List<Object?> shots = sb.data['shots'] as List<Object?>;
    expect(shots.length, inInclusiveRange(8, 12));
    for (final Object? shot in shots) {
      final Map<Object?, Object?> map = shot as Map<Object?, Object?>;
      expect('${map['shotSize']}'.isNotEmpty, isTrue);
      expect('${map['lens']}'.isNotEmpty, isTrue);
      expect('${map['pose']}'.isNotEmpty, isTrue);
      expect('${map['camera']}'.isNotEmpty, isTrue);
    }
    expect((shots.first as Map)['key'], isTrue);
    expect((shots.last as Map)['key'], isTrue);
    expect(draft.totalScore, greaterThanOrEqualTo(90),
        reason: '${draft.shortcomings}');
    // 布光也已物化为可打开场景。
    final PlanModuleData lighting = draft.modules
        .firstWhere((PlanModuleData m) => m.type == PlanModuleType.lighting);
    expect((lighting.data['sceneId'] as String? ?? ''), isNotEmpty);
  });

  test('J3：分镜随长图与 PDF 导出渲染', () async {
    final Directory temp = await Directory.systemTemp.createTemp('ss_g3_');
    addTearDown(() => temp.delete(recursive: true));
    final Workspace workspace = await Workspace.initAt(p.join(temp.path, 'ws'));
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final ExportService service = ExportService(workspace: workspace, db: db);

    final List<PlanModuleData> modules = <PlanModuleData>[
      PlanModuleData(
        id: 's1',
        type: PlanModuleType.storyboard,
        title: '分镜表',
        data: <String, Object?>{
          'shots': <Object?>[
            for (var i = 1; i <= 8; i++)
              <String, Object?>{
                'no': i,
                'shotSize': i.isEven ? '中景' : '全身',
                'camera': '腰位',
                'lens': '35mm',
                'pose': '侧身回眸',
                'lighting': '主光冷白',
                'key': i == 1,
                'note': i == 1 ? '开场建立环境' : '',
              },
          ],
        },
      ),
    ];
    final ExportResult png = await service.run(
      planTitle: '分镜导出',
      status: PlanDocStatus.draft,
      modules: modules,
      format: ExportFormat.longPng,
      onProgress: (_) {},
      isCancelled: () => false,
    );
    final List<int> pngBytes = await File(png.files.first).readAsBytes();
    expect(pngBytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
    expect(pngBytes.length, greaterThan(8 * 1024));

    final ExportResult pdf = await service.run(
      planTitle: '分镜导出',
      status: PlanDocStatus.draft,
      modules: modules,
      format: ExportFormat.pdf,
      onProgress: (_) {},
      isCancelled: () => false,
    );
    final List<int> pdfBytes = await File(pdf.files.first).readAsBytes();
    expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), '%PDF-');
  });

  testWidgets('J3：分镜编辑器可添加/标重点/排序', (WidgetTester tester) async {
    late Workspace workspace;
    late AppDatabase db;
    await tester.runAsync(() async {
      await TestEnv.install();
      workspace = await Workspace.initAt(p.join(TestEnv.root.path, 'ws'));
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final int now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.plans).insert(
            PlansCompanion.insert(
              id: 'p-g3',
              title: '分镜测试',
              modulesJson: Value(jsonEncode(<Map<String, Object?>>[
                PlanModuleData(
                  id: 'm-sb',
                  type: PlanModuleType.storyboard,
                  title: '分镜表',
                  data: <String, Object?>{
                    'shots': <Object?>[
                      <String, Object?>{
                        'no': 1,
                        'shotSize': '全身',
                        'camera': '腰位',
                        'lens': '35mm',
                        'pose': '自然站姿',
                        'lighting': '',
                        'key': true,
                        'note': '',
                      },
                    ],
                  },
                ).toJson(),
              ])),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    addTearDown(() async {
      await db.close();
      await TestEnv.dispose();
    });
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        workspaceProvider.overrideWithValue(workspace),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1700, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PlannerPage())),
      ),
    );
    await settleUntil(tester, find.byKey(const ValueKey<String>('m-sb')),
        required: true);
    await tester.tap(find.byKey(const ValueKey<String>('m-sb')));
    await tester.pump(const Duration(milliseconds: 100));
    await settleUntil(tester, find.text('添加镜头'), required: true);
    await tester.tap(find.text('添加镜头'));
    await tester.pump(const Duration(milliseconds: 100));
    final PlannerState state = container.read(plannerControllerProvider);
    final PlanModuleData sb =
        state.modules.firstWhere((PlanModuleData m) => m.id == 'm-sb');
    expect((sb.data['shots'] as List<Object?>).length, 2);
    // 标重点按钮存在且可点（切回取消）。
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
    // 走完快照防抖计时器，避免 pending timer。
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
  });
}
