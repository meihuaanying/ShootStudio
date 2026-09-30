/// V8/R72 · S5 画面参考视觉门禁（首屏画报 / 瀑布流结果 / 详情抽屉 / 我的画板）。
///
/// 用法（app/ 下）：
///   ① 产出/更新：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub test/visual/s5_refs_capture_test.dart --update-goldens`
///   ② 回归比对：`$env:SS_V8_VISUAL='1'; flutter test --no-pub test/visual/s5_refs_capture_test.dart`
///   ③ 默认（CI）：只做渲染冒烟（含溢出/异常断言），不比对不落盘。
///
/// 说明：截图用**真实组件组合**渲染（`RefsHomeHeader` / `RefsMasonryGrid` +
/// `RefsHitCard` / `RefsHitDrawer` / `RefsBoardView` + `SsPage` 外框），与
/// `RefsPage._searchPane/_results/_boardPane` 的版面组装一致；结果条目与画板帧
/// 用固定夹具注入（检索管线需要联网，CI 不触网，R62）。检索文本/状态/色卡均来自真实控件。
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
import 'package:shoot_studio/features/refs/refs_board.dart';
import 'package:shoot_studio/features/refs/refs_controller.dart';
import 'package:shoot_studio/features/refs/refs_hit_card.dart';
import 'package:shoot_studio/features/refs/refs_hit_drawer.dart';
import 'package:shoot_studio/features/refs/refs_home.dart';
import 'package:shoot_studio/features/refs/refs_masonry.dart';
import 'package:shoot_studio/features/refs/refs_palette.dart';
import 'package:shoot_studio/features/refs/refs_page.dart' show kRefsDisclaimer;
import 'package:shoot_studio/services/search/search_models.dart';

const String _goldenDir = '../../../docs/screenshots/v8';
const String _shotDir = '../docs/screenshots/v8';
const String _indexFile = '../docs/qa/v8-s5-refs-screenshots.json';

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

/// 固定检索夹具（R62：不联网；逐条带来源/许可，R63）。
final List<SearchHit> _hits = <SearchHit>[
  for (final (
        String id,
        String title,
        String source,
        String license,
        bool commercial,
        int w,
        int h,
      )
      in <(String, String, String, String, bool, int, int)>[
        ('tmdb-1', '银翼杀手 · 街景霓虹', 'TMDB', 'TMDB 版权素材', false, 1920, 1080),
        ('wm-2', '梦旅人 · 黄昏海岸', 'Wikimedia', 'CC BY 4.0', true, 1200, 1600),
        ('pex-3', '夜城 · 雨面反光', 'Pexels', 'Pexels License', true, 1600, 1067),
        ('ov-4', '摩根 · 冷调侧光', 'Openverse', 'CC0 1.0', true, 1400, 1400),
        ('tmdb-5', '花样年华 · 旗袍背影', 'TMDB', 'TMDB 版权素材', false, 1080, 1350),
        ('wm-6', '玻璃温室 · 晨光', 'Wikimedia', 'CC BY-SA 4.0', false, 1600, 900),
        ('pex-7', '港口 · 长曝雾气', 'Pexels', 'Pexels License', true, 1280, 853),
        ('ov-8', '山脊 · 高对比黑白', 'Openverse', 'PD', true, 2000, 1125),
        ('tmdb-9', '教父 · 暖调书房', 'TMDB', 'TMDB 版权素材', false, 1200, 1575),
      ])
    SearchHit(
      id: id,
      title: title,
      thumbUrl: 'https://example.invalid/$id-thumb.jpg',
      fullUrl: 'https://example.invalid/$id.jpg',
      sourceId: source.toLowerCase(),
      sourceLabel: source,
      license: license,
      commercialOk: commercial,
      attribution: '$source / $license',
      sourcePageUrl: 'https://example.invalid/page/$id',
      width: w,
      height: h,
      group: id.contains('-1') ? 'blade-runner' : 'misc',
    ),
];

final List<RefFrame> _board = <RefFrame>[
  for (final (String id, String name, String film, String url)
      in <(String, String, String, String)>[
        ('f1', '街景霓虹 · 远景', '银翼杀手', 'https://example.invalid/a'),
        ('f2', '雨面反光 · 中景', '银翼杀手', 'https://example.invalid/b'),
        ('f3', '旗袍背影 · 特写', '花样年华', 'https://example.invalid/c'),
        ('f4', '晨光温室 · 广角', '玻璃温室', ''),
        ('f5', '暖调书房 · 过肩', '教父', 'https://example.invalid/e'),
      ])
    RefFrame(
      id: id,
      name: name,
      palette: const <String>['#2f5d50', '#a97e2f', '#b43a2b', '#101010'],
      gradient: const <String>['#101010', '#f0ebe3'],
      sourceUrl: url,
      description: '内置索引帧',
      inBoard: true,
      filmTitle: film,
    ),
];

Widget _homeHeader({
  required TextEditingController controller,
  required FocusNode focus,
  required String status,
  required String vision,
  bool compact = false,
}) {
  return RefsHomeHeader(
    controller: controller,
    focusNode: focus,
    searching: false,
    status: status,
    vision: vision,
    compact: compact,
    onSearch: () {},
    onPickTheme: (_) {},
    onAllThemes: () {},
    onSearchByImage: () {},
    onPaste: () {},
    onImport: () {},
  );
}

/// 固定色卡（截图可复现；真实运行时由 PaletteExtractor 提取，R70）。
List<String> _paletteOf(SearchHit hit) {
  const List<List<String>> sets = <List<String>>[
    <String>['#1b2a3a', '#2f5d50', '#a97e2f', '#b43a2b', '#f0ebe3'],
    <String>['#d8c3a5', '#8a9b6e', '#3f5b78', '#2a2622', '#f4efe6'],
    <String>['#0b1d26', '#123c4a', '#2b7a78', '#7fb6a8', '#cfe3dc'],
    <String>['#101010', '#3c3c3c', '#7a7a7a', '#c9c9c9', '#f5f5f5'],
    <String>['#5a1f1f', '#8c3b2f', '#c07a52', '#d9b48f', '#f2e3cf'],
    <String>['#e8f0e8', '#a8c8b0', '#6f9a7d', '#3f6152', '#21332a'],
    <String>['#1a1f2b', '#3f5a78', '#88a2b8', '#c4d3de', '#eef3f7'],
    <String>['#000000', '#1c1c1c', '#4d4d4d', '#a6a6a6', '#ffffff'],
    <String>['#3b2a1f', '#7a5a3a', '#c9a97a', '#e8d9bf', '#fbf3e6'],
  ];
  final int index = hit.id.codeUnits.fold<int>(0, (int a, int b) => a + b);
  return sets[index % sets.length];
}

Widget _scene(String scene, AppThemeVariant variant) {
  final TextEditingController search = TextEditingController(
    text: scene == 'home' ? '' : '夜城 霓虹',
  );
  final FocusNode focus = FocusNode();
  return ProviderScope(
    overrides: <Override>[
      databaseProvider.overrideWithValue(_db),
      workspaceProvider.overrideWithValue(_ws),
      // 固定色卡提取器：截图不触网、色卡可复现（R62）。
      refsPaletteServiceProvider.overrideWithValue(
        RefsPaletteService(
          db: _db,
          workspaceRoot: _ws.root.path,
          extract: (SearchHit hit) async => _paletteOf(hit),
        ),
      ),
    ],
    child: Scaffold(
      body: SsPage(
        title: '画面参考',
        subtitle: '中英文搜影视/画作/摄影参考 · 主题画报 · 我的画板',
        body: switch (scene) {
          'home' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _homeHeader(
                controller: search,
                focus: focus,
                status: '',
                vision: '',
              ),
              const SizedBox(height: AppSpace.s4),
              const Expanded(
                child: SsEmpty(
                  icon: Icons.travel_explore_rounded,
                  title: '选一张画报，或直接搜关键词',
                  hint: '支持影片/导演/演员/画作/摄影主题；也可以用「以图搜图」把一张图变成检索词',
                ),
              ),
              Text(
                kRefsDisclaimer,
                style: AppType.caption.style(
                  ssPaletteOf(context: variant).muted,
                ),
              ),
            ],
          ),
          'results' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _homeHeader(
                controller: search,
                focus: focus,
                status: '共 ${_hits.length} 条 · 4 源',
                vision: 'neon rain city night',
                compact: true,
              ),
              const SizedBox(height: AppSpace.s3),
              Expanded(
                child: RefsMasonryGrid(
                  itemCount: _hits.length,
                  itemBuilder: (BuildContext context, int i) => RefsHitCard(
                    hit: _hits[i],
                    hovered: i == 1,
                    onOpen: () {},
                    onAdd: () {},
                    onSearchSimilar: () {},
                  ),
                ),
              ),
              Text(
                kRefsDisclaimer,
                style: AppType.caption.style(
                  ssPaletteOf(context: variant).muted,
                ),
              ),
            ],
          ),
          'detail' => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: RefsHitDrawer(
              hit: _hits.first,
              similar: _hits.skip(1).take(5).toList(),
              onAdd: () {},
              onOpenSource: () {},
            ),
          ),
          _ => RefsBoardView(
            board: _board,
            imagePathOf: (RefFrame _) => null,
            exporting: false,
            onOpen: (_) {},
            onRemove: (_) {},
            onReorder: (_, _) {},
            onExport: () {},
            onPaste: () {},
            onImport: () {},
          ),
        },
      ),
    ),
  );
}

/// 无需 BuildContext 拿调色板（截图只需要文本样式）。
AppPalette ssPaletteOf({required AppThemeVariant context}) =>
    AppTheme.of(context).brightness == Brightness.light
    ? AppPalette.paper
    : AppPalette.darkroom;

/// 截图用的空工作区与内存库（色卡槽位要读设置/工作区，故必须提供，R62 不触网）。
late Directory _temp;
late Workspace _ws;
late AppDatabase _db;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    _temp = await Directory.systemTemp.createTemp('ss_s5_visual_');
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
        'home',
        'results',
        'detail',
        'board',
      ]) {
        final String name =
            's5-refs-$scene-${variant.name}-${size.$1.toInt()}x${size.$2.toInt()}';
        testWidgets('$name 渲染与视觉比对', (WidgetTester tester) async {
          tester.view
            ..physicalSize = Size(size.$1, size.$2)
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('s5-root'),
              child: MediaQuery(
                data: MediaQueryData(size: Size(size.$1, size.$2)),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.of(variant),
                  home: _scene(scene, variant),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull, reason: '$name 渲染异常');

          if (!_visual) return;
          await expectLater(
            find.byKey(const Key('s5-root')),
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

  test('S5 画面参考截图索引', () async {
    if (!_capture) return;
    expect(shots.length, 16, reason: '4 场景 × 2 主题 × 2 分辨率 = 16 张');
    final File file = File(_indexFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'note': 'V8/S5 画面参考截图（D154：首屏画报 / 瀑布流结果 + 悬停浮层 / 详情抽屉 + 五色色卡 / 我的画板编排；明暗双主题 × 1280×800 与 1920×1080）',
        'pages': <String>['home', 'results', 'detail', 'board'],
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
