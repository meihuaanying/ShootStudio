import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/export/exporter.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';

Uint8List _pngBytes(img.Image image) =>
    Uint8List.fromList(img.encodePng(image));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late Workspace workspace;
  late AppDatabase db;
  final List<String> requestedRefs = <String>[];

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ss_f4_export_');
    workspace = await Workspace.initAt(p.join(temp.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    requestedRefs.clear();
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Uint8List redImage() {
    final img.Image image = img.Image(width: 240, height: 160);
    for (final img.Pixel pixel in image) {
      pixel
        ..r = 194
        ..g = 78
        ..b = 42;
    }
    return _pngBytes(image);
  }

  ExportService serviceWithRefs() => ExportService(
    workspace: workspace,
    db: db,
    refBytesLoader: (String ref) async {
      requestedRefs.add(ref);
      return ref == 'up-1.jpg' ? redImage() : null;
    },
  );

  List<PlanModuleData> buildModules() => <PlanModuleData>[
    PlanModuleData(
      id: 'm1',
      type: PlanModuleType.theme,
      title: '拍摄主题',
      data: <String, Object?>{
        'text':
            '**雨夜霓虹**主基调\n- 主光 45° 侧前 2.2m\n- 品红点缀 90°\n'
            '服装与角色设定保持一致，突出神态。',
      },
    ),
    PlanModuleData(
      id: 'm2',
      type: PlanModuleType.refs,
      title: '参考样片',
      data: <String, Object?>{
        'refs': <Object?>[
          <String, Object?>{
            'name': '本地上传样片',
            'palette': <String>['#c24e2a', '#2f3a4a'],
            'gradient': <String>['#c24e2a', '#2f3a4a'],
            'sourceUrl': '',
            'imageRef': 'up-1.jpg',
          },
          <String, Object?>{
            'name': '画板参考帧',
            'palette': <String>['#224466', '#113355'],
            'gradient': <String>['#224466', '#113355'],
            'sourceUrl': 'https://example.com',
            'imageRef': '',
          },
        ],
      },
    ),
    PlanModuleData(
      id: 'm3',
      type: PlanModuleType.lighting,
      title: '布光图',
      data: <String, Object?>{
        'sceneId': 'scene-f4',
        'sceneName': 'F4 双灯方案',
        'note': '主光 45° 2.2m，轮廓光侧后 2.8m',
      },
    ),
  ];

  Future<void> seedScene() async {
    await db
        .into(db.lightingScenes)
        .insert(
          LightingScenesCompanion.insert(
            id: 'scene-f4',
            name: 'F4 双灯方案',
            sceneJson: jsonEncode(<String, Object?>{
              'devices': <Object?>[
                <String, Object?>{
                  'id': 'l1',
                  'kind': 'light',
                  'name': '主光',
                  'type': 'soft',
                  'x': -1.4,
                  'y': -1.6,
                  'height': 2.0,
                  'intensity': 70,
                  'kelvin': 5600,
                  'color': '#fff3e0',
                  'on': true,
                },
                <String, Object?>{
                  'id': 'l2',
                  'kind': 'light',
                  'name': '轮廓光',
                  'type': 'hard',
                  'x': 1.8,
                  'y': 1.4,
                  'height': 2.2,
                  'intensity': 45,
                  'kelvin': 6000,
                  'color': '#ffd54f',
                  'on': true,
                },
              ],
            }),
            linkedPoseId: const Value(null),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  test('长图：真实上传图片参与渲染（loader 命中 + 合法大图 PNG）', () async {
    await seedScene();
    final ExportResult result = await serviceWithRefs().run(
      planTitle: 'F4 导出测试',
      status: PlanDocStatus.draft,
      modules: buildModules(),
      format: ExportFormat.longPng,
      onProgress: (_) {},
      isCancelled: () => false,
    );
    expect(requestedRefs, contains('up-1.jpg'));
    expect(result.files, hasLength(1));
    final File file = File(result.files.first);
    final Uint8List bytes = await file.readAsBytes();
    expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
    // 含真实图片后体积应明显大于纯色卡版本。
    expect(bytes.length, greaterThan(15 * 1024));
  });

  test('PDF：含矢量灯位图（真实图片与灯位场景均被读取）', () async {
    await seedScene();
    final ExportResult result = await serviceWithRefs().run(
      planTitle: 'F4 PDF 测试',
      status: PlanDocStatus.final_,
      modules: buildModules(),
      format: ExportFormat.pdf,
      onProgress: (_) {},
      isCancelled: () => false,
    );
    expect(result.files, hasLength(1));
    final Uint8List bytes = await File(result.files.first).readAsBytes();
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(4 * 1024));
    // 参考图字节被 PDF 内嵌读取。
    expect(requestedRefs, contains('up-1.jpg'));
  });

  test('清理：无 imageRef 时不触发 loader（纯占位不回退）', () async {
    await seedScene();
    final List<PlanModuleData> modules = buildModules();
    modules[1].data['refs'] = <Object?>[
      <String, Object?>{
        'name': '画板帧',
        'palette': <String>['#224466', '#113355'],
        'gradient': <String>['#224466', '#113355'],
        'sourceUrl': '',
        'imageRef': '',
      },
    ];
    await serviceWithRefs().run(
      planTitle: '无真实图',
      status: PlanDocStatus.draft,
      modules: modules,
      format: ExportFormat.longPng,
      onProgress: (_) {},
      isCancelled: () => false,
    );
    expect(requestedRefs, isEmpty);
  });
}
