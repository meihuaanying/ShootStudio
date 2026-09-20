import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/planner/planner_controller.dart';
import 'package:shoot_studio/features/planner/planner_page.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/features/refs/refs_controller.dart';

import '../support/test_env.dart';

Future<void> settleUntil(
  WidgetTester tester,
  Finder finder, {
  int tries = 60,
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

  Future<void> settleUntilGone(
    WidgetTester tester,
    Finder finder, {
    int tries = 80,
  }) async {
    for (var i = 0; i < tries; i++) {
      if (finder.evaluate().isEmpty) return;
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// 测试收尾：让快照防抖与 SnackBar 计时器走完，避免 pending timer。
  Future<void> settleTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
  }

  Future<void> waitForState(
    WidgetTester tester,
    bool Function() condition, {
    int tries = 80,
  }) async {
    for (var i = 0; i < tries; i++) {
      if (condition()) return;
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(condition(), isTrue, reason: '状态等待超时');
  }

  late AppDatabase db;
  late Workspace workspace;
  late ProviderContainer container;

  setUp(() async {
    await TestEnv.install();
    workspace = await Workspace.initAt(p.join(TestEnv.root.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
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
    await TestEnv.dispose();
  });

  List<PlanModuleData> seedModules() => <PlanModuleData>[
    PlanModuleData(
      id: 'm1',
      type: PlanModuleType.theme,
      title: '拍摄主题',
      data: <String, Object?>{'text': '雨夜霓虹主基调'},
    ),
    PlanModuleData(
      id: 'm2',
      type: PlanModuleType.budget,
      title: '预算表',
      data: <String, Object?>{
        'rows': <Object?>[
          <String, Object?>{'item': '场地', 'price': 400, 'note': ''},
        ],
      },
    ),
    PlanModuleData(
      id: 'm3',
      type: PlanModuleType.sun,
      title: '日照时间',
      data: <String, Object?>{
        'place': '上海',
        'date': '2026-09-12',
        'lat': 31.23,
        'lon': 121.47,
      },
    ),
    PlanModuleData(
      id: 'm4',
      type: PlanModuleType.palette,
      title: '色卡',
      data: <String, Object?>{
        'colors': <String>['#c24e2a', '#2f3a4a'],
      },
    ),
    PlanModuleData(
      id: 'm5',
      type: PlanModuleType.poses,
      title: '姿势清单',
      data: <String, Object?>{
        'poses': <Object?>[
          <String, Object?>{
            'name': '侧身回眸',
            'lens': '35mm',
            'cameraPosition': '腰位',
            'joints': <String, Object?>{
              'spine': <double>[0, 20, 0],
            },
          },
        ],
      },
    ),
  ];

  Future<void> seedPlan() async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.plans)
        .insert(
          PlansCompanion.insert(
            id: 'p-f4',
            title: 'F4 编辑器测试',
            modulesJson: Value(
              jsonEncode(
                seedModules().map((PlanModuleData m) => m.toJson()).toList(),
              ),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> pumpPlanner(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1700, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PlannerPage())),
      ),
    );
    await settleUntil(tester, find.text('预算表'), required: true);
  }

  Future<void> selectModule(WidgetTester tester, String id) async {
    final Finder card = find.byKey(ValueKey<String>(id));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 100));
    await settleUntil(tester, find.textContaining('编辑 ·'), required: true);
  }

  PlanModuleData moduleById(String id) => container
      .read(plannerControllerProvider)
      .modules
      .firstWhere((PlanModuleData m) => m.id == id);

  testWidgets('预算编辑器：自动合计 + AI 估算（城市系数）', (WidgetTester tester) async {
    await seedPlan();
    await pumpPlanner(tester);
    await selectModule(tester, 'm2');
    await settleUntil(tester, find.text('自动合计'), required: true);
    expect(find.text('¥400'), findsOneWidget);

    await tester.tap(find.text('AI 估算'));
    await settleUntil(tester, find.text('生成估算'), required: true);
    await settleUntil(tester, find.text('上海 · 一线'), required: true);
    await tester.tap(find.text('生成估算'));
    await settleUntilGone(tester, find.text('生成估算'));
    await waitForState(
      tester,
      () => (moduleById('m2').data['rows'] as List<Object?>).length >= 10,
    );

    final PlanModuleData budget = moduleById('m2');
    final List<Object?> rows = budget.data['rows'] as List<Object?>;
    expect(
      rows.every((Object? r) => ((r as Map)['note'] as String).contains('估算值')),
      isTrue,
    );
    await settleTimers(tester);
  });

  testWidgets('日照编辑器：73 城搜索选中（离线可用）', (WidgetTester tester) async {
    await seedPlan();
    await pumpPlanner(tester);
    await selectModule(tester, 'm3');
    await settleUntil(
      tester,
      find.widgetWithText(TextField, '城市（内置城市库，输入即筛选）'),
      required: true,
    );
    await tester.enterText(
      find.widgetWithText(TextField, '城市（内置城市库，输入即筛选）'),
      '大连',
    );
    await settleUntil(tester, find.textContaining('大连 · 二线'), required: true);
    await tester.tap(find.textContaining('大连 · 二线'));
    await settleUntilGone(tester, find.textContaining('大连 · 二线'));
    await waitForState(tester, () => moduleById('m3').data['place'] == '大连');

    final PlanModuleData sun = moduleById('m3');
    expect(sun.data['place'], '大连');
    final double lat = (sun.data['lat'] as num).toDouble();
    expect(lat, closeTo(38.91, 0.5));
    await settleTimers(tester);
  });

  testWidgets('色卡编辑器：取色器添加颜色并进入模块数据', (WidgetTester tester) async {
    await seedPlan();
    await pumpPlanner(tester);
    await selectModule(tester, 'm4');
    await settleUntil(tester, find.text('添加颜色'), required: true);
    await tester.tap(find.text('添加颜色'));
    await settleUntil(tester, find.text('色值 #RRGGBB'), required: true);
    await tester.tap(find.text('添加'));
    await tester.pump(const Duration(milliseconds: 100));

    final PlanModuleData palette = moduleById('m4');
    final List<String> colors = (palette.data['colors'] as List? ?? <Object?>[])
        .cast<String>();
    expect(colors, hasLength(3));
    expect(colors.last, startsWith('#'));
    expect(colors.last.length, 7);
    await settleTimers(tester);
  });

  testWidgets('姿势编辑器：从内置姿势库替换', (WidgetTester tester) async {
    await seedPlan();
    await pumpPlanner(tester);
    await selectModule(tester, 'm5');
    await settleUntil(
      tester,
      find.byIcon(Icons.swap_horiz_rounded),
      required: true,
    );
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded).first);
    await settleUntil(tester, find.text('替换姿势'), required: true);
    await settleUntil(tester, find.text('站姿·展臂'), required: true);
    await tester.tap(find.text('站姿·展臂').first);
    await settleUntilGone(tester, find.text('替换姿势'));
    await waitForState(
      tester,
      () =>
          ((moduleById('m5').data['poses'] as List<Object?>).first
              as Map)['name'] ==
          '站姿·展臂',
    );

    final PlanModuleData poses = moduleById('m5');
    final List<Object?> list = poses.data['poses'] as List<Object?>;
    expect((list.first as Map)['name'], '站姿·展臂');
    expect(((list.first as Map)['joints'] as Map).isNotEmpty, isTrue);
    await settleTimers(tester);
  });

  testWidgets('富文本：工具栏加粗写入模块', (WidgetTester tester) async {
    await seedPlan();
    await pumpPlanner(tester);
    await selectModule(tester, 'm1');
    await settleUntil(
      tester,
      find.byIcon(Icons.format_bold_rounded),
      required: true,
    );
    await tester.tap(find.byIcon(Icons.format_bold_rounded));
    await tester.pump(const Duration(milliseconds: 100));

    final PlanModuleData theme = moduleById('m1');
    expect(theme.data['text'], contains('**加粗文字**'));
    await settleTimers(tester);
  });

  testWidgets('样片编辑：待插入帧带 imageRef 落入模块（导出可渲染真实图）', (
    WidgetTester tester,
  ) async {
    await seedPlan();
    await pumpPlanner(tester);
    container
        .read(pendingFramesProvider.notifier)
        .add(
          const PendingFrame(
            name: '本地上传样片',
            palette: <String>['#c24e2a', '#2f3a4a'],
            gradient: <String>['#c24e2a', '#2f3a4a'],
            sourceUrl: '',
            imagePath: 'uploaded-f4.jpg',
          ),
        );
    await tester.pump(const Duration(milliseconds: 50));

    await selectModule(tester, 'm1');
    await tester.pump(const Duration(milliseconds: 50));
    final PlanModuleData theme = moduleById('m1');
    container
        .read(plannerControllerProvider.notifier)
        .insertModule(
          PlanModuleData(
            id: 'm6',
            type: PlanModuleType.refs,
            title: '参考样片',
            data: <String, Object?>{'refs': <Object?>[]},
          ),
        );
    await tester.pump(const Duration(milliseconds: 100));
    final String refsId = container
        .read(plannerControllerProvider)
        .modules
        .last
        .id;
    await settleUntil(
      tester,
      find.byKey(ValueKey<String>(refsId)),
      required: true,
    );
    await selectModule(tester, refsId);
    await settleUntil(tester, find.text('插入待选（1）'), required: true);
    await tester.tap(find.text('插入待选（1）'));
    await waitForState(
      tester,
      () => (moduleById(refsId).data['refs'] as List<Object?>).isNotEmpty,
    );

    final PlanModuleData refs = moduleById(refsId);
    final List<Object?> list = refs.data['refs'] as List<Object?>;
    expect(list, hasLength(1));
    expect((list.first as Map)['imageRef'], 'uploaded-f4.jpg');
    expect(theme.data['text'], '雨夜霓虹主基调');
    await settleTimers(tester);
  });
}
