/// V8/S8 · D155 AI 成案与导出视觉门禁（成案阅读视图 + AI 三态 + 导出面板）。
///
/// 用法（app/ 下）：
///   ① 产出/更新：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub --update-goldens test/visual/s8_plan_capture_test.dart`
///   ② 回归比对：`$env:SS_V8_VISUAL='1'; flutter test --no-pub test/visual/s8_plan_capture_test.dart`
///   ③ 默认（CI）：只做渲染冒烟（含溢出/异常断言），不比对不落盘。
///
/// 检索管线需要联网，CI 不触网（R62），故用固定夹具渲染真实组件组合：
/// `PlanReadView`（杂志内页排版）、`AiStageBar` / `AiGeneratingPanel` /
/// `AiReadingPanel`（AI 三态）、`ExportPanel`（导出面板）。
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
import 'package:shoot_studio/features/ai/ai_controller.dart';
import 'package:shoot_studio/features/ai/ai_stage.dart';
import 'package:shoot_studio/features/ai/plan_read_view.dart';
import 'package:shoot_studio/features/export/export_panel.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';

const String _goldenDir = '../../../docs/screenshots/v8';
const String _shotDir = '../docs/screenshots/v8';
const String _indexFile = '../docs/qa/v8-s8-plan-screenshots.json';

bool get _capture => Platform.environment['SS_V8_CAPTURE'] == '1';
bool get _visual => Platform.environment['SS_V8_VISUAL'] == '1' || _capture;

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

const String _idea = '雨夜赛博朋克风初音正片，霓虹雨夜，未来感';

List<PlanModuleData> _modules() => <PlanModuleData>[
  PlanModuleData(
    id: 'm1',
    type: PlanModuleType.theme,
    title: '主题基调',
    data: <String, Object?>{'text': '雨夜 · 霓虹 · 湿润反光地面'},
  ),
  PlanModuleData(
    id: 'm2',
    type: PlanModuleType.sun,
    title: '日落时刻',
    data: <String, Object?>{'place': '外滩', 'date': '19:40'},
  ),
  PlanModuleData(
    id: 'm3',
    type: PlanModuleType.refs,
    title: '样片参考',
    data: <String, Object?>{
      'refs': <Object?>[
        <String, Object?>{
          'name': '雨夜霓虹参考帧',
          'palette': <Object?>[
            '#2B6CFF',
            '#FF4D6D',
            '#14E0A0',
            '#F2C14E',
            '#8A919E',
          ],
          'gradient': <Object?>['#2B6CFF', '#8A919E'],
          'sourceUrl': 'https://film-grab.com/?s=test',
        },
      ],
    },
  ),
  PlanModuleData(
    id: 'm4',
    type: PlanModuleType.poses,
    title: '姿势序列',
    data: <String, Object?>{
      'poses': <Object?>[
        <String, Object?>{'name': '站姿·自然站立', 'author': '内建', 'license': 'CC0'},
        <String, Object?>{'name': '站姿·举手伸展', 'author': '内建', 'license': 'CC0'},
      ],
    },
  ),
  PlanModuleData(
    id: 'm5',
    type: PlanModuleType.storyboard,
    title: '分镜',
    data: <String, Object?>{
      'shots': <Object?>[
        <String, Object?>{'no': '01', 'desc': '远景：霓虹街口推入'},
        <String, Object?>{'no': '02', 'desc': '中景：侧身回眸'},
      ],
    },
  ),
];

AiDraftResult _draft({bool cancelled = false}) => AiDraftResult(
  modules: _modules(),
  viaLocal: false,
  providerName: '云端 A',
  rawText: '{"modules":[{"id":"m1","type":"theme"}]}',
  reasoning: '先定主题与时刻，再取样片色板；姿势优先选站姿以匹配远景推入的镜头语言。',
  totalScore: 86,
  detailScore: 88,
  consistencyScore: 82,
  tokensIn: 412,
  tokensOut: 968,
  latencyMs: 4260,
  attempts: const <String>['云端 A · 连通', '云端 A · 一次重试后成功'],
  cancelled: cancelled,
);

Widget _scene(String scene) {
  switch (scene) {
    case 'reading':
      return Scaffold(
        body: PlanReadView(draft: _draft(), idea: _idea),
      );
    case 'reading-cancelled':
      return Scaffold(
        body: PlanReadView(draft: _draft(cancelled: true), idea: _idea),
      );
    case 'stage-generating':
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: AppSpace.s3),
              AiStageBar(stage: AiStage.generating),
              const SizedBox(height: AppSpace.s3),
              Expanded(
                child: AiGeneratingPanel(
                  state: AiState(
                    generating: true,
                    status: '正在生成（第 2 次尝试）…',
                    streamText: '正在写主题与时刻…\n正在检索样片色板…\n正在编排姿势序列…',
                    reasoningText: '先定主题与时刻，再取样片色板。',
                    attempts: const <String>['云端 A · 402 额度不足', '云端 B · 连通'],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    case 'stage-reading':
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: AppSpace.s3),
              AiStageBar(stage: AiStage.reading),
              const SizedBox(height: AppSpace.s3),
              Expanded(
                child: AiReadingPanel(
                  state: AiState(draft: _draft()),
                  idea: _idea,
                  onInsertAll: (List<PlanModuleData> _) {},
                  onInsertModule: (PlanModuleData _) {},
                ),
              ),
            ],
          ),
        ),
      );
    default:
      return Scaffold(
        body: ExportPanel(
          title: _idea,
          status: PlanDocStatus.draft,
          modules: _modules(),
        ),
      );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Workspace ws;
  late AppDatabase db;

  setUpAll(() async {
    await _loadFonts();
    tempDir = await Directory.systemTemp.createTemp('ss_s8_visual_');
    ws = await Workspace.initAt(p.join(tempDir.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDownAll(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  final List<Map<String, Object?>> shots = <Map<String, Object?>>[];

  for (final AppThemeVariant variant in AppThemeVariant.values) {
    for (final (double w, double h) size in _viewports) {
      for (final String scene in <String>[
        'reading',
        'reading-cancelled',
        'stage-generating',
        'stage-reading',
        'export',
      ]) {
        final String name =
            's8-plan-$scene-${variant.name}-${size.$1.toInt()}x${size.$2.toInt()}';
        testWidgets('$name 渲染与视觉比对', (WidgetTester tester) async {
          tester.view
            ..physicalSize = Size(size.$1, size.$2)
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('s8-root'),
              child: MediaQuery(
                data: MediaQueryData(size: Size(size.$1, size.$2)),
                child: ProviderScope(
                  overrides: <Override>[
                    databaseProvider.overrideWithValue(db),
                    workspaceProvider.overrideWithValue(ws),
                  ],
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.of(variant),
                    home: _scene(scene),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: '$name 渲染异常');

          if (!_visual) return;
          await expectLater(
            find.byKey(const Key('s8-root')),
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

  test('S8 策划案/AI/导出截图索引', () async {
    if (!_capture) return;
    expect(shots.length, 20, reason: '5 场景 × 2 主题 × 2 分辨率 = 20 张');
    final File file = File(_indexFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'note': 'V8/S8 D155 截图（成案阅读视图双栏 / 已取消态 / AI 三态生成中 / AI 三态阅读 / 导出面板；明暗双主题 × 1280×800 与 1920×1080）',
        'scenes': <String>['reading', 'reading-cancelled', 'stage-generating', 'stage-reading', 'export'],
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
