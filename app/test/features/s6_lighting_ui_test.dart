import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'package:shoot_studio/features/lighting/camera_helpers.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_canvas_view.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_device_list.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_effect_widgets.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_inspector.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_left_column.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_pose_widgets.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_rig_widgets.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_workbench.dart';

/// V8/S6 · D152 布光预演重构的 UI 测试。
///
/// 纪律（R79/R66）：只新增，不改既有 44 个 q6_* 用例；覆盖三栏信息架构、
/// 顶部工具条（机位/构图/画质/出片 ≤3 步）、画中画灯位图、撤销重做按钮态与 ≥20 步。
/// 引擎视口在 flutter_test 下走 EngineView 的测试占位（F16），不创建平台视图。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late Workspace workspace;
  late AppDatabase db;
  late ProviderContainer container;
  late LightingController controller;

  LightingState state() => container.read(lightingControllerProvider);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ss_s6_lighting_');
    workspace = await Workspace.initAt(p.join(temp.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        workspaceProvider.overrideWithValue(workspace),
      ],
    );
    controller = container.read(lightingControllerProvider.notifier);
    await controller.init();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Widget host(Widget child) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(AppThemeVariant.darkroom),
      home: Scaffold(body: SizedBox(width: 1600, height: 900, child: child)),
    );
  }

  Widget toolbar({
    String viewMode = 'scene3d',
    bool cameraView = false,
    bool guidesOn = false,
    bool skeleton = false,
    bool pip = true,
    bool listCollapsed = false,
    bool canUndo = false,
    bool canRedo = false,
    String status = '',
    bool abReady = false,
    ValueChanged<String>? onView,
    VoidCallback? onUndo,
    VoidCallback? onRedo,
    VoidCallback? onToggleList,
    VoidCallback? onOpenStill,
  }) {
    return host(
      SafeArea(
        child: LightingToolbar(
          viewMode: viewMode,
          cameraView: cameraView,
          guides: CameraGuideSettings(
            thirds: guidesOn,
            safeArea: guidesOn,
            info: guidesOn,
          ),
          skeleton: skeleton,
          characterName: '默认人物',
          characterSelected: false,
          stillRunning: false,
          abReady: abReady,
          canUndo: canUndo,
          canRedo: canRedo,
          listCollapsed: listCollapsed,
          pip: pip,
          status: status,
          onView: onView ?? (_) {},
          onToggleSkeleton: () {},
          onPickCharacter: () {},
          onToggleCameraView: () {},
          onToggleGuides: () {},
          onToggleList: onToggleList ?? () {},
          onTogglePip: () {},
          onOpenStill: onOpenStill ?? () {},
          onOpenAb: () {},
          onUndo: onUndo ?? () {},
          onRedo: onRedo ?? () {},
        ),
      ),
    );
  }

  Widget inspector(LightingState s) {
    return host(
      SafeArea(
        child: LightingInspector(
          state: s,
          controller: controller,
          bridge: null,
          guides: const CameraGuideSettings(),
          onGuides: (_) {},
          assistDistance: 3.2,
          assistDofAvailable: true,
          legacyCharacter: false,
          onSavePose: (_, _, _) async {},
          onResetPose: () {},
          onUploadTexture: () async {},
          onChanged: () {},
          onNotify: (_) {},
        ),
      ),
    );
  }

  /// 桌面窗口可缩放：测试里先给足视口，避免 tap 落到视口外 + ListView 懒建子项。
  Future<void> useWide(
    WidgetTester tester, {
    Size size = const Size(1600, 1400),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('S6 顶部工具条（D152：机位/构图/画质 + 出片 ≤3 步）', () {
    testWidgets('视图三档 + 机位/构图/画质/画中画/清单 + 撤销重做 + 出片', (
      WidgetTester tester,
    ) async {
      await useWide(tester);
      final List<String> views = <String>[];
      var undos = 0;
      var redos = 0;
      var stills = 0;
      await tester.pumpWidget(
        toolbar(
          onView: views.add,
          canUndo: true,
          canRedo: true,
          onUndo: () => undos++,
          onRedo: () => redos++,
          onOpenStill: () => stills++,
        ),
      );
      await tester.pump();
      expect(find.text('俯视图'), findsOneWidget);
      expect(find.text('3D 预览'), findsOneWidget);
      expect(find.text('分屏'), findsOneWidget);
      expect(find.text('机位'), findsOneWidget);
      expect(find.text('构图'), findsOneWidget);
      expect(find.text('画质'), findsOneWidget);
      expect(find.text('灯位图·画中画'), findsOneWidget);
      expect(find.text('收起清单'), findsOneWidget);
      expect(find.text('撤销'), findsOneWidget);
      expect(find.text('重做'), findsOneWidget);
      expect(find.text('A/B 对比'), findsOneWidget);
      // 出片 = 第 2 步入口（点开效果预览对话框后保存即第 3 步）。
      expect(find.text('出片'), findsOneWidget);

      await tester.tap(find.text('俯视图'));
      await tester.tap(find.text('分屏'));
      expect(views, <String>['top', 'split']);
      await tester.tap(find.text('撤销'));
      await tester.tap(find.text('重做'));
      await tester.tap(find.text('出片'));
      expect(undos, 1);
      expect(redos, 1);
      expect(stills, 1);
    });

    testWidgets('状态栏展示 controller status（引擎/撤销结果可见）', (
      WidgetTester tester,
    ) async {
      await useWide(tester);
      await tester.pumpWidget(toolbar(status: '已撤销：加灯'));
      await tester.pump();
      expect(find.text('已撤销：加灯'), findsOneWidget);
    });

    testWidgets('清单折叠态切换按钮文案 + 无可撤销时按钮为空操作', (WidgetTester tester) async {
      await useWide(tester);
      var toggled = 0;
      var undos = 0;
      await tester.pumpWidget(
        toolbar(
          listCollapsed: true,
          onToggleList: () => toggled++,
          canUndo: false,
          onUndo: () => undos++,
        ),
      );
      await tester.pump();
      expect(find.text('展开清单'), findsOneWidget);
      await tester.tap(find.text('展开清单'));
      expect(toggled, 1);
      await tester.tap(find.text('撤销'));
      expect(undos, 0);
    });
  });

  group('S6 撤销/重做（D152：≥20 步 + 按钮态）', () {
    test('连续 24 次加灯可逐步撤销到空影棚', () {
      final int before = state().scene.devices.length;
      for (int i = 0; i < 24; i++) {
        controller.addLight();
      }
      final int added = state().scene.devices.length - before;
      expect(added, greaterThanOrEqualTo(20));
      for (int i = 0; i < added; i++) {
        expect(state().canUndo, isTrue);
        controller.undo();
      }
      expect(state().scene.devices.length, before);
      expect(state().canUndo, isFalse);
      expect(state().canRedo, isTrue);
    });

    testWidgets('工具条撤销按钮在有栈时触发页面回调', (WidgetTester tester) async {
      await useWide(tester);
      controller.addLight();
      expect(state().canUndo, isTrue);
      var undos = 0;
      await tester.pumpWidget(toolbar(canUndo: true, onUndo: () => undos++));
      await tester.pump();
      await tester.tap(find.text('撤销'));
      expect(undos, 1);
    });
  });

  group('S6 左栏（预设 + 设备清单，可折叠）', () {
    testWidgets('LightingLeftColumn 同时给出预设组与设备清单', (WidgetTester tester) async {
      await useWide(tester);
      controller.addLight();
      await tester.pumpWidget(
        host(
          Row(
            children: <Widget>[
              LightingLeftColumn(
                state: state(),
                controller: controller,
                presets: const <LightPresetEntry>[],
              ),
              const Expanded(
                child: LightingDeviceList(
                  devices: <DeviceSpec>[],
                  selectedId: null,
                  onSelect: _ignore,
                  onCapture: _noop,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LightingPresetPanel), findsOneWidget);
      expect(find.text('布光预设'), findsOneWidget);
      expect(find.byType(LightingDeviceList), findsWidgets);
      expect(find.text('设备与道具'), findsNWidgets(2));
      expect(find.text('空影棚 · 未布置任何灯光'), findsOneWidget);
    });

    testWidgets('设备清单点击选中并高亮', (WidgetTester tester) async {
      await useWide(tester);
      controller.addLight();
      final DeviceSpec device = state().scene.devices.first;
      String? picked;
      await tester.pumpWidget(
        host(
          LightingDeviceList(
            devices: state().scene.devices,
            selectedId: device.id,
            onSelect: (String id) => picked = id,
            onCapture: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text(device.name), findsOneWidget);
      expect(find.textContaining('方位'), findsWidgets);
      await tester.tap(find.text(device.name));
      await tester.pump();
      expect(picked, device.id);
    });

    testWidgets('灯具类型标签与 LightType 对齐', (WidgetTester tester) async {
      await useWide(tester);
      controller.addLight();
      await tester.pumpWidget(
        host(
          LightingDeviceList(
            devices: state().scene.devices,
            selectedId: null,
            onSelect: (_) {},
            onCapture: () {},
          ),
        ),
      );
      await tester.pump();
      // 设备行显示 LightType 中文标签（不是英文 id，也不是 emoji）。
      final String label = lightingTypeLabel(state().scene.devices.first.type);
      expect(find.textContaining(label), findsWidgets);
    });
  });

  group('S6 右栏属性检查器（上下文切换）', () {
    testWidgets('未选中：机位 + 测光表 + 公共面板', (WidgetTester tester) async {
      await useWide(tester);
      await tester.pumpWidget(inspector(state()));
      await tester.pump();
      expect(find.text('参数面板'), findsOneWidget);
      expect(find.text('未选中对象'), findsOneWidget);
      expect(find.byType(CameraRigPanel), findsOneWidget);
      expect(find.byType(LightingMeterCard), findsOneWidget);
      expect(find.byType(JointTunePanel), findsOneWidget);
      expect(find.byType(HandPosePanel), findsOneWidget);
      expect(find.byType(QualityPanel), findsOneWidget);
      expect(find.byType(LightingEffectPreview), findsOneWidget);
    });

    testWidgets('选中灯具：光型/灯具/控光件 + 删除，且公共面板仍各一份', (WidgetTester tester) async {
      await useWide(tester);
      controller.addLight();
      controller.select(state().selectedId);
      await tester.pumpWidget(inspector(state()));
      await tester.pump();
      expect(find.text('光型'), findsOneWidget);
      expect(find.text('灯具'), findsOneWidget);
      expect(find.text('控光件'), findsOneWidget);
      expect(find.text('亮度'), findsOneWidget);
      expect(find.text('色温'), findsOneWidget);
      expect(find.text('删除该对象'), findsOneWidget);
      expect(find.byType(CameraRigPanel), findsNothing);
      expect(find.byType(JointTunePanel), findsOneWidget);
      expect(find.byType(HandPosePanel), findsOneWidget);
      expect(find.byType(QualityPanel), findsOneWidget);
      expect(find.byType(LightingEffectPreview), findsOneWidget);
    });

    testWidgets('亮度滑杆改选中灯 → 控制器更新且可撤销', (WidgetTester tester) async {
      await useWide(tester);
      controller.addLight();
      controller.select(state().selectedId);
      final int before = state().selected!.intensity;
      await tester.pumpWidget(inspector(state()));
      await tester.pump();
      await tester.drag(find.byType(Slider).first, const Offset(60, 0));
      await tester.pump();
      expect(state().selected!.intensity, isNot(before));
      controller.undo();
      expect(state().selected!.intensity, before);
    });
  });

  group('S6 中栏（3D 视口 + 画中画灯位图）', () {
    Widget stage({String viewMode = 'scene3d', bool pip = true}) {
      return host(
        LightingStageView(
          scene: state().scene,
          selectedId: state().selectedId,
          viewMode: viewMode,
          cameraView: false,
          guides: const CameraGuideSettings(),
          assistDistance: 3.2,
          pip: pip,
          linkage: true,
          onSelect: (_) {},
          onMove: (_, _, _) {},
          onMoveEnd: () {},
          onCameraMove: (_, _) {},
          onCameraMoveEnd: () {},
          onExportDiagnostics: () async {},
          onBridgeReady: (_) {},
          onEvent: (_) {},
        ),
      );
    }

    testWidgets('3D 模式叠加灯位图画中画（可切全屏）', (WidgetTester tester) async {
      await useWide(tester);
      await tester.pumpWidget(stage());
      await tester.pump();
      expect(find.byType(LightingCanvasView), findsOneWidget);
      expect(find.text('灯位图 · 联动'), findsOneWidget);
    });

    testWidgets('pip=false 时不叠画中画；俯视图模式独占灯位图', (WidgetTester tester) async {
      await useWide(tester);
      await tester.pumpWidget(stage(pip: false));
      await tester.pump();
      expect(find.text('灯位图 · 联动'), findsNothing);
      await tester.pumpWidget(stage(viewMode: 'top'));
      await tester.pump();
      expect(find.text('灯位图 · 联动'), findsNothing);
      expect(find.byType(LightingCanvasView), findsOneWidget);
    });
  });
}

void _noop() {}

void _ignore(String _) {}
