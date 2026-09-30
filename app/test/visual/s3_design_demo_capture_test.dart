/// V8/R72 · S3 设计系统组件库 demo 视觉门禁（明暗 × 1280×800 / 1920×1080）。
///
/// 用法（app/ 下）：
///   ① 产出/更新：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub test/visual/s3_design_demo_capture_test.dart --update-goldens`
///   ② 回归比对：`$env:SS_V8_VISUAL='1'; flutter test --no-pub test/visual/s3_design_demo_capture_test.dart`
///   ③ 默认（CI）：只做渲染冒烟（含溢出/异常断言），不比对不落盘。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/dev/design_demo_page.dart';

const String _goldenDir = '../../../docs/screenshots/v8';
const String _shotDir = '../docs/screenshots/v8';
const String _indexFile = '../docs/qa/v8-s3-demo-screenshots.json';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  final List<Map<String, Object?>> shots = <Map<String, Object?>>[];

  for (final AppThemeVariant variant in AppThemeVariant.values) {
    for (final (double w, double h) size in _viewports) {
      final String name =
          's3-design-demo-${variant.name}-${size.$1.toInt()}x${size.$2.toInt()}';
      testWidgets('$name 渲染与视觉比对', (WidgetTester tester) async {
        tester.view
          ..physicalSize = Size(size.$1, size.$2)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('demo-root'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.of(variant),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(size: Size(size.$1, size.$2)),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: DesignDemoBoard(variant: variant),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        // CI 默认也执行本断言：布局溢出/渲染异常必须当场失败（R72 视觉门禁的快速护栏）。
        expect(tester.takeException(), isNull, reason: '$name 渲染异常');

        if (!_visual) return;
        await expectLater(
          find.byKey(const Key('demo-root')),
          matchesGoldenFile('$_goldenDir/$name.png'),
        );
        final File file = File('$_shotDir/$name.png');
        shots.add(<String, Object?>{
          'name': name,
          'page': 'design-demo',
          'theme': variant.name,
          'size': '${size.$1.toInt()}x${size.$2.toInt()}',
          'bytes': file.existsSync() ? file.lengthSync() : -1,
        });
      });
    }
  }

  test('S3 demo 截图索引', () async {
    if (!_capture) return;
    expect(shots.length, 4, reason: '2 主题 × 2 分辨率 = 4 张');
    final File file = File(_indexFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'note': 'V8/S3 设计系统组件库 demo 截图（R72：明暗双主题 × 1280×800 / 1920×1080）',
        'page': 'design-demo',
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
