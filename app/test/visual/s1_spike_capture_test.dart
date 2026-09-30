/// V8/R72 · S1 设计 spike 视觉门禁：样板页渲染冒烟 + 截图（golden）产出
///
/// 用法（app/ 下）：
///   ① 产出/更新截图：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub test/visual/s1_spike_capture_test.dart --update-goldens`
///      → 2 样板页 × 明暗双主题 × 1280×800 / 1920×1080，PNG 写入 `docs/screenshots/v8/`
///   ② 视觉回归比对：`$env:SS_V8_VISUAL='1'; flutter test --no-pub test/visual/s1_spike_capture_test.dart`
///      → 与已落盘 PNG 逐张比对（不一致即失败）
///   ③ 默认（CI）：只做渲染冒烟，不比对不落盘 → 保证 CI 干净、字体光栅化差异不误报。
///
/// 说明：`RenderRepaintBoundary.toImage` 的 Future 在 testWidgets 的 FakeAsync 中需真实事件循环，
/// 故截图走 `matchesGoldenFile`（由框架内部 runAsync 驱动），并用 `--update-goldens` 写文件。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/design_spike/spike_pages.dart';
import 'package:shoot_studio/design_spike/spike_tokens.dart';

/// golden 路径相对测试文件所在目录（`app/test/visual/`）
const String kSpikeGoldenDir = '../../../docs/screenshots/v8';

/// 文件 IO 路径相对测试进程 cwd（`app/`）
const String kSpikeShotDir = '../docs/screenshots/v8';
const String kSpikeIndexFile = '../docs/qa/v8-s1-screenshots.json';

bool get _capture => Platform.environment['SS_V8_CAPTURE'] == '1';
bool get _visual => Platform.environment['SS_V8_VISUAL'] == '1' || _capture;

/// 本机系统字体（不入仓，仅让截图渲染真实字形；CI 无此文件时回退默认测试字体）
const Map<String, String> _systemFonts = <String, String>{
  SpikeFonts.body: r'C:\Windows\Fonts\NotoSansSC-VF.ttf',
  SpikeFonts.mono: r'C:\Windows\Fonts\consola.ttf',
  'MaterialIcons':
      r'C:\dev\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
};

Future<void> _loadFonts() async {
  final FontLoader display = FontLoader(SpikeFonts.display)
    ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-ShootStudio.otf'));
  await display.load();
  for (final MapEntry<String, String> entry in _systemFonts.entries) {
    final File file = File(entry.value);
    if (!file.existsSync()) {
      continue;
    }
    final Uint8List bytes = await file.readAsBytes();
    final FontLoader loader = FontLoader(entry.key)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  final List<Map<String, Object?>> shots = <Map<String, Object?>>[];

  for (final SpikeThemeMode mode in SpikeThemeMode.values) {
    for (final SpikeViewport viewport in SpikeViewport.values) {
      final String sizeName =
          '${viewport.width.toInt()}x${viewport.height.toInt()}';
      for (final (
            String page,
            Widget Function(SpikeThemeMode, SpikeViewport) build,
          )
          in <(String, Widget Function(SpikeThemeMode, SpikeViewport))>[
            (
              'home',
              (SpikeThemeMode m, SpikeViewport v) =>
                  spikeHomePage(m, viewport: v),
            ),
            (
              'lighting',
              (SpikeThemeMode m, SpikeViewport v) =>
                  spikeLightingPage(m, viewport: v),
            ),
          ]) {
        final String name = 's1-$page-${mode.name}-$sizeName';
        testWidgets('$name 渲染与视觉比对', (WidgetTester tester) async {
          tester.view
            ..physicalSize = Size(viewport.width, viewport.height)
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('spike-root'),
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(viewport.width, viewport.height),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: build(mode, viewport),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: '$name 渲染异常');

          if (!_visual) {
            return;
          }
          await expectLater(
            find.byKey(const Key('spike-root')),
            matchesGoldenFile('$kSpikeGoldenDir/$name.png'),
          );
          final File file = File('$kSpikeShotDir/$name.png');
          shots.add(<String, Object?>{
            'name': name,
            'page': page,
            'theme': mode.name,
            'size': sizeName,
            'bytes': file.existsSync() ? file.lengthSync() : -1,
          });
        }, skip: !_visual);
      }
    }
  }

  test('S1 spike 截图索引', () async {
    final File file = File(kSpikeIndexFile);
    if (!_capture) {
      return;
    }
    expect(
      shots.length,
      8,
      reason: '2 页 × 2 主题 × 2 分辨率 = 8 张（官网首屏另 4 张，见 web 截图工具）',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'note': 'V8/S1 设计 spike 样板页截图（R72：明暗双主题 × 1280×800 / 1920×1080）',
        'pages': <String>['home', 'lighting'],
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
