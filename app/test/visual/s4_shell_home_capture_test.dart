/// V8/R72 · S4 App 外壳 + 首页视觉门禁（明暗 × 1280×800 / 1920×1080）。
///
/// 用法（app/ 下）：
///   ① 产出/更新：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub test/visual/s4_shell_home_capture_test.dart --update-goldens`
///   ② 回归比对：`$env:SS_V8_VISUAL='1'; flutter test --no-pub test/visual/s4_shell_home_capture_test.dart`
///   ③ 默认（CI）：只做渲染冒烟（含溢出/异常断言），不比对不落盘。
///
/// 说明：截图渲染的是 `AppShell` 的真实组件组合（`ShellSideNav` + `VerticalHairline` +
/// `ShellUpdateBanner` + 真实 `HomePage`）；`AppShell` 本身只是 40 行的组装层，且其
/// `initState` 会触发联网的 `silentCheck()`，故按真实布局组合渲染以保证截图可复现。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/features/home/home_page.dart';
import 'package:shoot_studio/features/home/home_recent.dart';
import 'package:shoot_studio/features/shell/app_shell.dart';
import 'package:shoot_studio/features/shell/shell_nav.dart';
import 'package:shoot_studio/features/shell/shell_update_banner.dart';
import 'package:shoot_studio/features/updater/updater.dart';

const String _goldenDir = '../../../docs/screenshots/v8';
const String _shotDir = '../docs/screenshots/v8';
const String _indexFile = '../docs/qa/v8-s4-shell-home-screenshots.json';

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

/// 截图用公告（有新版时的横幅形态）。
final Announcement _banner = Announcement(
  version: '2.0.0',
  notes: <String>[
    '杂志画册风设计系统落地：令牌唯一来源 + 组件库 16 项',
    '外壳与首页重构：三段式导航 · 衬线大标题 · 最近策划案',
  ],
  publishedAt: '2026-09-30',
  downloads: <String, DownloadEntry>{
    'windows': const DownloadEntry(
      mirror: 'https://example.com/win.zip',
      github: 'https://github.com/o/r/releases/download/v2.0.0/win.zip',
      sha256: 'aa',
    ),
  },
  contentPacks: const <ContentPackEntry>[],
  ops: const <({String title, String date})>[],
);

Widget _shell(AppThemeVariant variant, {required bool banner}) {
  return ProviderScope(
    overrides: <Override>[
      recentPlansProvider.overrideWith((Ref ref) async => <Plan>[]),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(variant),
      home: Scaffold(
        body: Column(
          children: <Widget>[
            if (banner)
              ShellUpdateBanner(
                updater: UpdaterState(
                  announcement: _banner,
                  lastState: UpdateState.hasUpdate,
                ),
              ),
            Expanded(
              child: Row(
                children: <Widget>[
                  ShellSideNav(index: 0, onSelect: (int _) {}),
                  const VerticalHairline(),
                  const Expanded(child: HomePage()),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  final List<Map<String, Object?>> shots = <Map<String, Object?>>[];

  for (final AppThemeVariant variant in AppThemeVariant.values) {
    for (final (double w, double h) size in _viewports) {
      for (final bool banner in <bool>[false, true]) {
        final String scene = banner ? 'shell-banner' : 'shell-home';
        final String name =
            's4-$scene-${variant.name}-${size.$1.toInt()}x${size.$2.toInt()}';
        testWidgets('$name 渲染与视觉比对', (WidgetTester tester) async {
          tester.view
            ..physicalSize = Size(size.$1, size.$2)
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('s4-root'),
              child: MediaQuery(
                data: MediaQueryData(size: Size(size.$1, size.$2)),
                child: _shell(variant, banner: banner),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull, reason: '$name 渲染异常');

          if (!_visual) return;
          await expectLater(
            find.byKey(const Key('s4-root')),
            matchesGoldenFile('$_goldenDir/$name.png'),
          );
          final File file = File('$_shotDir/$name.png');
          shots.add(<String, Object?>{
            'name': name,
            'page': scene,
            'theme': variant.name,
            'size': '${size.$1.toInt()}x${size.$2.toInt()}',
            'banner': banner,
            'bytes': file.existsSync() ? file.lengthSync() : -1,
          });
        });
      }
    }
  }

  test('S4 外壳 + 首页截图索引', () async {
    if (!_capture) return;
    expect(shots.length, 8, reason: '2 主题 × 2 分辨率 × 2 场景 = 8 张');
    final File file = File(_indexFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'note': 'V8/S4 App 外壳 + 首页截图（R72：明暗双主题 × 1280×800 / 1920×1080；含更新横幅场景）',
        'pages': <String>['shell-home', 'shell-banner'],
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
