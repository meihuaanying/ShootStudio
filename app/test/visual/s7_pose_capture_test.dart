/// V8/R72 · S7 动作摆姿视觉门禁（大图瀑布流 + 分类眉题 + 半屏抽屉 + 校正器 + 识别首屏）。
///
/// 用法（app/ 下）：
///   ① 产出/更新：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub --update-goldens test/visual/s7_pose_capture_test.dart`
///   ② 回归比对：`$env:SS_V8_VISUAL='1'; flutter test --no-pub test/visual/s7_pose_capture_test.dart`
///   ③ 默认（CI）：只做渲染冒烟（含溢出/异常断言），不比对不落盘。
///
/// 说明：检索管线需要联网，CI 不触网（R62），故用固定夹具渲染真实组件组合
/// （`PoseGalleryGrid` / `PoseCategoryEyebrow` / `showPoseDetailSheet` /
///  `PoseJointTuner` / `PoseTunerResetBar` / 真实 `PoseImportPage` 首屏）。
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
import 'package:shoot_studio/features/poses/pose_gallery.dart';
import 'package:shoot_studio/features/poses/pose_import_page.dart';
import 'package:shoot_studio/features/poses/pose_joint_tuner.dart';
import 'package:shoot_studio/features/poses/pose_skeleton.dart';
import 'package:shoot_studio/services/content_packs.dart';

const String _goldenDir = '../../../docs/screenshots/v8';
const String _shotDir = '../docs/screenshots/v8';
const String _indexFile = '../docs/qa/v8-s7-pose-screenshots.json';

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

/// 固定姿势夹具（R62：不联网）。
final List<PoseEntry> _poses = <PoseEntry>[
  for (final (String id, String name, String cat, String diff)
      in <(String, String, String, String)>[
        ('p001', '站姿·自然站立', '站姿', '进阶'),
        ('p002', '站姿·举手伸展', '站姿', '高难度'),
        ('p013', '坐姿·侧坐', '坐姿', '进阶'),
        ('p025', '蹲姿·半蹲', '蹲姿', '高难度'),
        ('p037', '靠姿·侧身倚靠', '靠姿', '高难度'),
        ('p085', '杂志大片·封面定格', '杂志大片', '高难度'),
        ('p099', '影视感·正面定妆', '影视感', '高难度'),
        ('p108', '道具互动·互动摆姿', '道具互动', '进阶'),
      ])
    PoseEntry(
      id: id,
      name: name,
      category: cat,
      difficulty: diff,
      photo: 'assets/content/poses3/photos/$id.jpg',
      skeleton: 'assets/content/poses3/photos/$id.skeleton.json',
      joints: <String, List<double>>{
        for (final String j in <String>[
          'spine',
          'neck',
          'shoulder_l',
          'elbow_l',
          'wrist_l',
          'shoulder_r',
          'elbow_r',
          'wrist_r',
          'hip_l',
          'knee_l',
          'hip_r',
          'knee_r',
        ])
          j: <double>[0, 0, 0],
      },
      rootY: 0,
      rootPitch: 0,
      weight: '重心落在髋部正下方',
      hands: '手臂自然下垂',
      mistake: '重心前移导致脚跟吃力',
      lens: '50mm 定焦（参考）',
      cameraPosition: '腰部高度平视',
    ),
];

/// 33 点固定骨架（校正器夹具）。
final List<PosePoint?> _points = <PosePoint?>[
  for (int i = 0; i < 33; i++)
    PosePoint(0.30 + (i % 6) * 0.08, 0.18 + (i ~/ 6) * 0.12, 1),
];

late Directory _temp;
late Workspace _ws;
late AppDatabase _db;

void _showSheetOnce(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((Duration _) {
    showPoseDetailSheet(
      context: context,
      pose: _poses.first,
      showSkeleton: true,
      favorite: false,
      onToggleSkeleton: () {},
      onToggleFavorite: () {},
      onInjectLighting: () {},
      onAddToPending: () {},
    );
  });
}

Widget _scene(String scene, AppThemeVariant variant) {
  final Widget content = switch (scene) {
    'gallery' => Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: PoseGalleryGrid(
        poses: _poses,
        showSkeleton: true,
        selectedId: 'p013',
        headerBuilder: (int i) => (i == 0 || i == 5)
            ? PoseCategoryEyebrow(
                category: _poses[i].category,
                count: _poses.length,
              )
            : null,
        onTap: (PoseEntry _) {},
      ),
    ),
    'tuner' => Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PoseTunerResetBar(
            joints: poseTunableJoints.keys.toList(),
            canReset: true,
            onResetJoint: (String _) {},
            onResetAll: () {},
          ),
          const SizedBox(height: AppSpace.s3),
          Expanded(
            child: PoseJointTuner(
              image: Container(color: const Color(0xFF15181D)),
              points: _points,
              imageSize: const Size(900, 1200),
              onPointMoved: (int _, double _, double _) {},
              onDragStart: (int _) {},
            ),
          ),
        ],
      ),
    ),
    'import' => const PoseImportPage(),
    _ => Builder(
      builder: (BuildContext context) {
        _showSheetOnce(context);
        return const SizedBox.shrink();
      },
    ),
  };
  return ProviderScope(
    overrides: <Override>[
      databaseProvider.overrideWithValue(_db),
      workspaceProvider.overrideWithValue(_ws),
    ],
    child: Scaffold(
      body: SafeArea(
        child: SsPage(title: '动作摆姿库', body: content),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    _temp = await Directory.systemTemp.createTemp('ss_s7_visual_');
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
        'gallery',
        'tuner',
        'sheet',
        'import',
      ]) {
        final String name =
            's7-pose-$scene-${variant.name}-${size.$1.toInt()}x${size.$2.toInt()}';
        testWidgets('$name 渲染与视觉比对', (WidgetTester tester) async {
          tester.view
            ..physicalSize = Size(size.$1, size.$2)
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('s7-root'),
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
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: '$name 渲染异常');

          if (!_visual) return;
          await expectLater(
            find.byKey(const Key('s7-root')),
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

  test('S7 动作摆姿截图索引', () async {
    if (!_capture) return;
    expect(shots.length, 16, reason: '4 场景 × 2 主题 × 2 分辨率 = 16 张');
    final File file = File(_indexFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'note': 'V8/S7 动作摆姿截图（D153：大图瀑布流 + 分类眉题 / 关节点校正器 + 复位条 / 详情半屏抽屉 / 识别首屏；明暗双主题 × 1280×800 与 1920×1080）',
        'pages': <String>['gallery', 'tuner', 'sheet', 'import'],
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
