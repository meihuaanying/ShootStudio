/// V8/R72 · S6 布光预演视觉门禁（左栏 / 工具条 / 视口+画中画 / 右栏检查器）。
///
/// 用法（app/ 下）：
///   ① 产出/更新：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub --update-goldens test/visual/s6_lighting_capture_test.dart`
///   ② 回归比对：`$env:SS_V8_VISUAL='1'; flutter test --no-pub test/visual/s6_lighting_capture_test.dart`
///   ③ 默认（CI）：只做渲染冒烟（含溢出/异常断言），不比对不落盘。
///
/// 说明：渲染的是真实组件组合（`LightingLeftColumn` + `LightingToolbar` +
/// `LightingStageView` + `LightingInspector`），与 `LightingPage.build` 的三栏
/// 版面组装一致；设备/机位用固定夹具注入（检索与引擎都需外部资源，CI 不触网，R62）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/lighting/camera_helpers.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_inspector.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_left_column.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_workbench.dart';
import 'package:shoot_studio/services/content_packs.dart';

const String _goldenDir = '../../../docs/screenshots/v8';
const String _shotDir = '../docs/screenshots/v8';
const String _indexFile = '../docs/qa/v8-s6-lighting-screenshots.json';

bool get _capture => Platform.environment['SS_V8_CAPTURE'] == '1';
bool get _visual => Platform.environment['SS_V8_VISUAL'] == '1' || _capture;

/// 本机系统字体（不入仓，仅让截图渲染真实字形）。
const Map<String, String> _systemFonts = <String, String>{
  AppFonts.body: r'C:\Windows\Fonts\NotoSansSC-VF.ttf',
  AppFonts.mono: r'C:\Windows\Fonts\consola.ttf',
  'MaterialIcons':
      r'C:\dev\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
};

Future<void> _loadFonts() async {
  final FontLoader display = FontLoader(AppFonts.display)
    ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-ShootStudio.otf'));
  await display.load();
  for (final MapEntry<String, String> entry in _systemFonts.entries) {
    final File file = File(entry.value);
    if (!file.existsSync()) continue;
    final Uint8List bytes = await file.readAsBytes();
    final FontLoader loader = FontLoader(entry.key)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

const List<(double, double)> _viewports = <(double, double)>[
  (1280, 800),
  (1920, 1080),
];

/// 截图用固定夹具：三点布光 + 一个道具（逐条带来源，不触网）。
LightingSceneData _scene() => LightingSceneData(
  id: 'qa',
  name: '视觉门禁夹具',
  devices: <DeviceSpec>[
    for (final (
          String id,
          String kind,
          String name,
          String type,
          double x,
          double y,
          double height,
          int intensity,
          int kelvin,
        )
        in <(String, String, String, String, double, double, double, int, int)>[
          ('L1', 'light', '主光 · 柔光箱', 'soft', -1.6, 1.8, 2.1, 70, 5200),
          ('L2', 'light', '辅光 · 反光罩', 'hard', 1.8, 1.4, 1.6, 30, 5600),
          ('L3', 'light', '轮廓光 · 束光筒', 'hard', 0.2, -2.2, 2.3, 85, 4200),
          ('P1', 'prop', '道具 · 木箱', 'crate', 1.1, -0.4, 0.5, 0, 0),
        ])
      DeviceSpec(
        id: id,
        kind: kind,
        name: name,
        type: type,
        x: x,
        y: y,
        height: height,
        intensity: intensity,
        kelvin: kelvin,
        beamAngle: 45,
        softness: 0.4,
        fixture: 'cob-600d',
        modifier: 'softbox-medium',
      ),
  ],
  width: 6,
  depth: 8,
  height: 3.2,
  ambientEnabled: true,
  camera: CameraRigData(x: 0, y: 5.5, height: 1.35, focal: 85),
);

Widget _host(AppThemeVariant variant, Widget child) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(variant),
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Expanded(child: child),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
  );
}

Widget _toolbarRow(
  LightingState state, {
  required String viewMode,
  required bool cameraView,
  required CameraGuideSettings guides,
  required bool listCollapsed,
  required bool pip,
  required bool canUndo,
  required bool canRedo,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
    child: LightingToolbar(
      viewMode: viewMode,
      cameraView: cameraView,
      guides: guides,
      skeleton: false,
      characterName: '默认人物',
      characterSelected: true,
      stillRunning: false,
      abReady: false,
      canUndo: canUndo,
      canRedo: canRedo,
      listCollapsed: listCollapsed,
      pip: pip,
      status: state.status.isEmpty ? '就绪 · 拖动灯位实时预览' : state.status,
      onView: (_) {},
      onToggleSkeleton: () {},
      onPickCharacter: () {},
      onToggleCameraView: () {},
      onToggleGuides: () {},
      onToggleList: () {},
      onTogglePip: () {},
      onOpenStill: () {},
      onOpenAb: () {},
      onUndo: () {},
      onRedo: () {},
    ),
  );
}

Widget _stage(
  LightingState state, {
  required String viewMode,
  required bool cameraView,
  required bool pip,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: LightingStageView(
      scene: state.scene,
      selectedId: state.selectedId,
      viewMode: viewMode,
      cameraView: cameraView,
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

Widget _inspectorColumn(LightingState state, LightingController controller) {
  return SizedBox(
    width: 300,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: LightingInspector(
        state: state,
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

late Directory _temp;
late Workspace _ws;
late AppDatabase _db;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    _temp = await Directory.systemTemp.createTemp('ss_s6_visual_');
    _ws = await Workspace.initAt(p.join(_temp.path, 'ws'));
    _db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDownAll(() async {
    await _db.close();
    if (await _temp.exists()) await _temp.delete(recursive: true);
  });

  final List<Map<String, Object?>> shots = <Map<String, Object?>>[];

  for (final AppThemeVariant variant in AppThemeVariant.values) {
    for (final (double w, double h) size in _viewports) {
      for (final String scene in <String>[
        'workspace',
        'stage-pip',
        'inspector-selected',
        'left-list',
      ]) {
        final String name =
            's6-lighting-$scene-${variant.name}-${size.$1.toInt()}x${size.$2.toInt()}';
        testWidgets('$name 渲染与视觉比对', (WidgetTester tester) async {
          tester.view
            ..physicalSize = Size(size.$1, size.$2)
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final ProviderContainer container = ProviderContainer(
            overrides: <Override>[
              databaseProvider.overrideWithValue(_db),
              workspaceProvider.overrideWithValue(_ws),
            ],
          );
          addTearDown(container.dispose);
          final LightingController controller = container.read(
            lightingControllerProvider.notifier,
          );
          final LightingState base = container.read(lightingControllerProvider);
          final LightingState state = base.copyWith(
            scene: _scene(),
            selectedId: scene == 'inspector-selected' ? 'L1' : null,
            status: '就绪 · 拖动灯位实时预览',
            canUndo: true,
          );

          Widget body;
          switch (scene) {
            case 'stage-pip':
              body = Column(
                children: <Widget>[
                  _toolbarRow(
                    state,
                    viewMode: 'scene3d',
                    cameraView: true,
                    guides: const CameraGuideSettings(
                      thirds: true,
                      safeArea: true,
                    ),
                    listCollapsed: false,
                    pip: true,
                    canUndo: true,
                    canRedo: false,
                  ),
                  Expanded(
                    child: _stage(
                      state,
                      viewMode: 'scene3d',
                      cameraView: true,
                      pip: true,
                    ),
                  ),
                ],
              );
            case 'inspector-selected':
              body = Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        _toolbarRow(
                          state,
                          viewMode: 'split',
                          cameraView: false,
                          guides: const CameraGuideSettings(),
                          listCollapsed: true,
                          pip: false,
                          canUndo: true,
                          canRedo: false,
                        ),
                        Expanded(
                          child: _stage(
                            state,
                            viewMode: 'split',
                            cameraView: false,
                            pip: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _inspectorColumn(state, controller),
                ],
              );
            case 'left-list':
              body = Row(
                children: <Widget>[
                  SizedBox(
                    width: 232,
                    child: LightingLeftColumn(
                      state: state,
                      controller: controller,
                      presets: const <LightPresetEntry>[],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        _toolbarRow(
                          state,
                          viewMode: 'top',
                          cameraView: false,
                          guides: const CameraGuideSettings(),
                          listCollapsed: false,
                          pip: false,
                          canUndo: false,
                          canRedo: false,
                        ),
                        Expanded(
                          child: _stage(
                            state,
                            viewMode: 'top',
                            cameraView: false,
                            pip: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            default:
              body = Column(
                children: <Widget>[
                  _toolbarRow(
                    state,
                    viewMode: 'split',
                    cameraView: false,
                    guides: const CameraGuideSettings(),
                    listCollapsed: false,
                    pip: true,
                    canUndo: true,
                    canRedo: false,
                  ),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _stage(
                            state,
                            viewMode: 'split',
                            cameraView: false,
                            pip: true,
                          ),
                        ),
                        _inspectorColumn(state, controller),
                      ],
                    ),
                  ),
                ],
              );
          }

          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('s6-root'),
              child: MediaQuery(
                data: MediaQueryData(size: Size(size.$1, size.$2)),
                child: _host(variant, body),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull, reason: '$name 渲染异常');

          if (!_visual) return;
          await expectLater(
            find.byKey(const Key('s6-root')),
            matchesGoldenFile('$_goldenDir/$name.png'),
          );
          final File file = File('$_shotDir/$name.png');
          shots.add(<String, Object?>{
            'name': name,
            'scene': scene,
            'theme': variant.name,
            'size': '${size.$1.toInt()}x${size.$2.toInt()}',
            'bytes': file.existsSync() ? file.lengthSync() : -1,
          });
        });
      }
    }
  }

  test('S6 布光预演截图索引', () async {
    if (!_capture) return;
    expect(shots.length, 16, reason: '4 场景 × 2 主题 × 2 分辨率 = 16 张');
    final File file = File(_indexFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'note': 'V8/S6 布光预演截图（D152：左栏清单可折叠 / 顶部工具条 / 3D 视口 + 画中画灯位图 / 右栏属性检查器；明暗双主题 × 1280×800 与 1920×1080）',
        'pages': <String>['workspace', 'stage-pip', 'inspector-selected', 'left-list'],
        'themes': <String>['paper', 'darkroom'],
        'viewports': <String>['1280x800', '1920x1080'],
        'count': shots.length,
        'shots': shots,
      })}\n',
      flush: true,
    );
    expect(file.existsSync(), isTrue);
  }, skip: !_capture);
}
