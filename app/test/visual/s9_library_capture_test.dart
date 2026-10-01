/// V8/R72 · S9 资源库 + 设置 + 引导页视觉门禁。
///
/// 用法（app/ 下）：
///   ① 产出/更新：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub --update-goldens test/visual/s9_library_capture_test.dart`
///   ② 回归比对：`$env:SS_V8_VISUAL='1'; flutter test --no-pub test/visual/s9_library_capture_test.dart`
///   ③ 默认（CI）：只做渲染冒烟（含溢出/异常断言），不比对不落盘。
///
/// 覆盖率守门由 `tool/gear_coverage.py` 负责（CI line 67 直接跑它），
/// 本文件只守「页面版式在明暗 × 2 分辨率下都不溢出、不破版」。
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
import 'package:shoot_studio/features/libraries/gear_browser.dart';
import 'package:shoot_studio/features/libraries/libraries_page.dart';
import 'package:shoot_studio/features/onboarding/onboarding_page.dart';
import 'package:shoot_studio/features/settings/settings_page.dart';

const String _goldenDir = '../../../docs/screenshots/v8';
const String _shotDir = '../docs/screenshots/v8';
const String _indexFile = '../docs/qa/v8-s9-library-screenshots.json';

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

late Directory tempDir;
late Workspace ws;
late AppDatabase db;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    tempDir = await Directory.systemTemp.createTemp('ss_s9_visual_');
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
        'libraries',
        'gear',
        'settings',
        'onboarding',
      ]) {
        final String name =
            's9-$scene-${variant.name}-${size.$1.toInt()}x${size.$2.toInt()}';
        testWidgets('$name 渲染与视觉比对', (WidgetTester tester) async {
          tester.view
            ..physicalSize = Size(size.$1, size.$2)
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final Widget body = switch (scene) {
            'libraries' => const LibrariesPage(),
            'gear' => const GearBrowser(),
            'settings' => const SettingsPage(),
            _ => const OnboardingPage(),
          };

          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('s9-root'),
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
                    // Scaffold 提供 Material 祖先（SsButton 的 InkWell 需要）。
                    home: Scaffold(body: body),
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
            find.byKey(const Key('s9-root')),
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

  test('S9 资源库/设置/引导截图索引', () async {
    if (!_capture) return;
    expect(shots.length, 16, reason: '4 场景 × 2 主题 × 2 分辨率 = 16 张');
    final File file = File(_indexFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'note': 'V8/S9 资源库 + 设置 + 引导页截图（明暗双主题 × 1280×800 与 1920×1080；覆盖率六类 100% 由 CI 的 tool/gear_coverage.py 守门）',
        'scenes': <String>['libraries', 'gear', 'settings', 'onboarding'],
        'themes': <String>['paper', 'darkroom'],
        'viewports': <String>['1280x800', '1920x1080'],
        'coverageGate': 'app/tool/gear_coverage.py（camera/lens/light/accessory/clothing/props 六类 100%）',
        'count': shots.length,
        'shots': shots,
      })}\n',
      flush: true,
    );
    expect(file.existsSync(), isTrue);
  }, skip: !_capture);
}
