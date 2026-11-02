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
import 'package:shoot_studio/features/field/field_controller.dart';
import 'package:shoot_studio/features/field/field_exposure_brief.dart';
import 'package:shoot_studio/features/field/field_page.dart';
import 'package:shoot_studio/features/lighting/light_meter.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/features/projects/project_controller.dart';
import 'package:shoot_studio/features/shell/app_shell.dart';
import 'package:shoot_studio/features/shell/shell_nav.dart';

import '../support/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Workspace workspace;
  late ProviderContainer container;

  setUp(() async {
    await TestEnv.install();
    workspace = await Workspace.initAt(p.join(TestEnv.root.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').getSingle();
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        workspaceProvider.overrideWithValue(workspace),
      ],
    );
    await _seedPlan(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await TestEnv.dispose();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  test('现场清单与备注按项目和策划案保存并恢复', () async {
    final field = container.read(fieldControllerProvider.notifier);
    await field.init();
    expect(container.read(fieldControllerProvider).tasks, isNotEmpty);
    final LightingSceneData? linkedScene = container
        .read(fieldControllerProvider)
        .lightingById['scene-field'];
    expect(linkedScene, isNotNull);
    expect(linkedScene!.mode, LightingMode.calibrated);
    expect(linkedScene.exposure.isCalibrated, isTrue);
    await field.toggleTask('module:light-1');
    await field.addTask('联系场务确认退场时间');
    field.setNotes('主灯左移 0.5m');
    await field.saveNotes();

    final ShootFieldState saved = await db
        .select(db.shootFieldStates)
        .getSingle();
    expect(saved.notes, '主灯左移 0.5m');
    final List<Object?> tasks =
        jsonDecode(saved.checklistJson) as List<Object?>;
    expect(
      tasks.any(
        (Object? item) =>
            item is Map &&
            item['id'] == 'module:light-1' &&
            item['done'] == true,
      ),
      isTrue,
    );

    final projects = container.read(projectsProvider.notifier);
    await projects.createProject('空项目');
    container.read(fieldControllerProvider);
    await field.init();
    expect(container.read(fieldControllerProvider).selectedPlan, isNull);

    await projects.switchProject(AppDatabase.legacyProjectId);
    container.read(fieldControllerProvider);
    await field.init();
    final FieldState restored = container.read(fieldControllerProvider);
    expect(restored.notes, '主灯左移 0.5m');
    expect(restored.tasks.last.title, '联系场务确认退场时间');
    expect(
      restored.tasks.firstWhere((FieldTask t) => t.id == 'module:light-1').done,
      isTrue,
    );
  });

  testWidgets('390×844 现场页可勾选清单并保存备注', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FieldPage())),
      ),
    );
    await settle(tester);
    expect(find.text('拍摄现场'), findsOneWidget);
    expect(find.text('拍摄清单'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await settle(tester);
    ShootFieldState saved = await db.select(db.shootFieldStates).getSingle();
    expect(saved.checklistJson, contains('"done":true'));

    await tester.ensureVisible(find.text('现场备注'));
    final Finder notes = find.byType(TextField).last;
    await tester.enterText(notes, '现场增加一块反光板');
    await tester.tap(find.text('保存备注'));
    await settle(tester);
    saved = await db.select(db.shootFieldStates).getSingle();
    expect(saved.notes, '现场增加一块反光板');

    await tester.scrollUntilVisible(
      find.byType(FieldExposureBrief),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('校准曝光 · 现场参数'), findsOneWidget);
    expect(find.textContaining('ISO 400'), findsOneWidget);
    expect(find.textContaining('总照度 800 lux'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏外壳使用底部导航并可进入现场和更多', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await settle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(ShellSideNav), findsNothing);

    await tester.tap(find.text('现场').last);
    await settle(tester);
    expect(find.text('拍摄清单'), findsOneWidget);
    await tester.tap(find.text('更多'));
    await settle(tester);
    expect(find.text('完整编辑与项目资源'), findsOneWidget);
    expect(find.text('资源库'), findsOneWidget);
  });
}

Future<void> _seedPlan(AppDatabase db) async {
  final int now = DateTime.now().millisecondsSinceEpoch;
  final List<PlanModuleData> modules = <PlanModuleData>[
    PlanModuleData(
      id: 'light-1',
      type: PlanModuleType.lighting,
      title: '布光图',
      data: <String, Object?>{
        'sceneId': 'scene-field',
        'sceneName': '三点布光',
        'lights': <Object?>[
          <String, Object?>{'name': '主灯', 'x': 1, 'y': -1},
        ],
      },
    ),
    PlanModuleData(
      id: 'pose-1',
      type: PlanModuleType.poses,
      title: '姿势清单',
      data: <String, Object?>{
        'poses': <Object?>[
          <String, Object?>{
            'name': '站姿·展臂',
            'photo': 'assets/content/poses3/photos/p001.jpg',
          },
        ],
      },
    ),
    PlanModuleData(
      id: 'shot-1',
      type: PlanModuleType.storyboard,
      title: '分镜表',
      data: <String, Object?>{
        'shots': <Object?>[
          <String, Object?>{'no': 1, 'shotSize': '中景', 'lens': '50mm'},
        ],
      },
    ),
  ];
  final LightingSceneData scene = LightingSceneData(
    id: 'scene-field',
    name: '现场三点布光',
    devices: <DeviceSpec>[
      DeviceSpec(
        id: 'key',
        kind: 'light',
        name: '主灯',
        type: 'soft',
        x: -1.2,
        y: -1.6,
        intensity: 70,
        modifier: 'softbox-large',
      ),
    ],
  )..mode = LightingMode.calibrated;
  scene.exposure
    ..iso = 400
    ..shutterSeconds = 1 / 125
    ..measuredLux = 800
    ..calibrationFactor = LightMeter.calibrationFactorFor(scene, 800)
    ..calibrationSignature = LightMeter.signatureOf(scene);
  await db
      .into(db.lightingScenes)
      .insert(
        LightingScenesCompanion.insert(
          id: scene.id,
          projectId: const Value(AppDatabase.legacyProjectId),
          name: scene.name,
          sceneJson: jsonEncode(scene.toJson()),
          updatedAt: now,
        ),
      );
  await db
      .into(db.plans)
      .insert(
        PlansCompanion.insert(
          id: 'field-plan',
          projectId: const Value(AppDatabase.legacyProjectId),
          title: '现场测试策划',
          modulesJson: Value(
            jsonEncode(modules.map((PlanModuleData m) => m.toJson()).toList()),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );
}
