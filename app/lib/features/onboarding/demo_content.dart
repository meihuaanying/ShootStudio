import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/database.dart';
import '../../core/utils/json_utils.dart';
import '../../services/content_packs.dart';
import '../planner/planner_models.dart';

/// 示例内容（F6）：首次引导「载入示例内容」写入，设置页可一键移除。
/// 所有新建行使用 `demo-` 前缀；对内容包既有行（参考帧/姿势）通过设置键记录以便还原。
class DemoContentService {
  DemoContentService._();

  static const String planId = 'demo-plan-1';
  static const String sceneId = 'demo-scene-1';
  static const List<String> resourceIds = <String>[
    'demo-res-model',
    'demo-res-location',
    'demo-res-prop',
  ];
  static const String _keySeeded = 'demo_content';
  static const String _keyFrames = 'demo_frames';
  static const String _keyPoses = 'demo_poses';

  static Future<bool> isSeeded(AppDatabase db) async =>
      await db.getSetting(_keySeeded) == 'true';

  static Future<int> seed(AppDatabase db) async {
    if (await isSeeded(db)) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    var seeded = 0;

    // 1) 收藏 3 个姿势（内容包既有行）。
    final poses = await ContentPacks.poses();
    final chosenPoses = poses.take(3).toList();
    for (final PoseEntry pose in chosenPoses) {
      await db.into(db.poses).insertOnConflictUpdate(
            PosesCompanion.insert(
              id: pose.id,
              name: pose.name,
              category: pose.category,
              difficulty: Value(pose.difficulty),
              jointsJson: jsonEncode(pose.joints),
              tip: Value(pose.weight),
              lensAdvice: Value(pose.lens),
              builtin: const Value(true),
              favorite: const Value(true),
            ),
          );
      seeded++;
    }

    // 2) 布光方案（三点布光预设）。
    final presets = await ContentPacks.lightPresets();
    final threePoint = presets.firstWhere(
      (LightPresetEntry p) => p.id == 'three-point',
      orElse: () => presets.first,
    );
    await db.into(db.lightingScenes).insertOnConflictUpdate(
          LightingScenesCompanion.insert(
            id: sceneId,
            name: '示例 · 三点布光方案',
            sceneJson: jsonEncode(<String, Object?>{
              'id': sceneId,
              'name': '示例 · 三点布光方案',
              'width': 6,
              'depth': 8,
              'height': 3.2,
              'devices': threePoint.devices,
            }),
            linkedPoseId: const Value(null),
            updatedAt: now,
          ),
        );
    seeded++;

    // 3) 资源条目（模特 / 场地 / 道具）。
    final resources = <(String, String, String, Map<String, Object?>)>[
      (
        'demo-res-model',
        'models',
        '示例模特 · 小满',
        <String, Object?>{
          'region': '杭州',
          'price': '300/小时',
          'note': '示例数据：擅长夜景与古风，可自由修改或删除',
          'tags': <String>['示例', '夜景'],
        },
      ),
      (
        'demo-res-location',
        'locations',
        '示例场地 · 废弃泳池',
        <String, Object?>{
          'region': '上海',
          'price': '200/小时',
          'note': '示例数据：夜拍需备案，含基础电源',
          'tags': <String>['示例', '夜景'],
        },
      ),
      (
        'demo-res-prop',
        'props',
        '示例道具 · 透明伞',
        <String, Object?>{
          'price': '¥35',
          'owner': '道具组买',
          'note': '示例数据：夜景反光利器',
          'tags': <String>['示例'],
        },
      ),
    ];
    for (final (
          String id,
          String type,
          String name,
          Map<String, Object?> fields
        ) in resources) {
      await db.into(db.resources).insertOnConflictUpdate(
            ResourcesCompanion.insert(
              id: id,
              type: type,
              name: name,
              fieldsJson: Value(jsonEncode(fields)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      seeded++;
    }

    // 4) 参考画板 6 帧（内容包影片索引，记录 inBoard 以便还原）。
    final films = await ContentPacks.films();
    final frames = films.first.frames.take(6).toList();
    final frameIds = <String>[];
    for (final FrameEntry frame in frames) {
      final id = '${films.first.id}:${frame.name}';
      frameIds.add(id);
      await db.into(db.filmFrames).insertOnConflictUpdate(
            FilmFramesCompanion.insert(
              id: id,
              filmId: films.first.id,
              name: frame.name,
              imageRef: '',
              paletteJson: Value(jsonEncode(frame.palette)),
              sourceUrl: Value(frame.sourceUrl),
              inBoard: const Value(true),
            ),
          );
      seeded++;
    }

    // 5) 示例策划案（Cos 模板 + 已填细节）。
    final templates = await ContentPacks.templates();
    final cos = templates.firstWhere(
      (TemplateEntry t) => t.id == 'tpl-cos',
      orElse: () => templates.first,
    );
    var seq = 0;
    final modules = modulesFromTemplate(cos, () => 'demo-mod-${seq++}');
    final firstPalette = frames.isNotEmpty ? frames.first.palette : <String>[];
    for (final PlanModuleData module in modules) {
      switch (module.type) {
        case PlanModuleType.theme:
          module.data['text'] = '示例：雨夜霓虹 · Cosplay 正片。\n'
              '以冷主光塑造角色轮廓，用霓虹色点缀环境；服化道对齐角色设定，突出神态与配色。';
        case PlanModuleType.model:
          module.data['ids'] = <String>['demo-res-model'];
          module.data['placeholder'] = false;
          module.data['note'] = '示例模特档案已绑定，可替换为自己的资源';
        case PlanModuleType.location:
          module.data['ids'] = <String>['demo-res-location'];
          module.data['placeholder'] = false;
        case PlanModuleType.props:
          module.data['ids'] = <String>['demo-res-prop'];
          module.data['placeholder'] = false;
        case PlanModuleType.refs:
          module.data['refs'] = frames
              .map((FrameEntry f) => <String, Object?>{
                    'name': f.name,
                    'palette': f.palette,
                    'gradient': f.gradient,
                    'sourceUrl': f.sourceUrl,
                  })
              .toList();
        case PlanModuleType.palette:
          module.data['colors'] = firstPalette;
        case PlanModuleType.lighting:
          module.data['sceneId'] = sceneId;
          module.data['sceneName'] = '示例 · 三点布光方案';
          module.data['placeholder'] = false;
        case PlanModuleType.poses:
          module.data['poses'] = chosenPoses
              .map((PoseEntry p) => <String, Object?>{
                    'name': p.name,
                    'joints': <String, Object?>{
                      ...p.joints,
                      'rootY': p.rootY,
                      'rootPitch': p.rootPitch,
                    },
                    'lens': p.lens,
                    'cameraPosition': p.cameraPosition,
                    'photo': p.photo,
                    'author': p.author,
                    'license': p.license,
                    'source': p.source,
                  })
              .toList();
        case PlanModuleType.storyboard:
          module.data['shots'] = <Object?>[];
        case PlanModuleType.sun:
          module.data['place'] = '上海';
          module.data['lat'] = 31.23;
          module.data['lon'] = 121.47;
          module.data['date'] =
              DateTime.now().toIso8601String().substring(0, 10);
        default:
          break;
      }
    }
    // 示例补齐分镜模块（旗舰功能：8 镜，绑定姿势与灯位）。
    if (!modules
        .any((PlanModuleData m) => m.type == PlanModuleType.storyboard)) {
      const List<String> sizes = <String>['远景', '全身', '中景', '近景', '特写', '空镜'];
      const Map<String, String> lensBySize = <String, String>{
        '远景': '24mm',
        '空镜': '35mm',
        '全身': '35mm',
        '中景': '50mm',
        '近景': '85mm',
        '特写': '135mm',
      };
      const List<String> cameras = <String>['低机位', '腰位', '胸口', '眼位', '俯拍'];
      final List<Object?> shots = <Object?>[
        for (var i = 0; i < 8; i++)
          <String, Object?>{
            'no': i + 1,
            'shotSize': sizes[i % sizes.length],
            'camera': cameras[i % cameras.length],
            'lens': lensBySize[sizes[i % sizes.length]] ?? '50mm',
            'pose': chosenPoses.isEmpty
                ? '自然站姿'
                : chosenPoses[i % chosenPoses.length].name,
            'lighting': '示例 · 三点布光方案',
            'key': i == 0 || i == 7,
            'note': i == 0 ? '开场建立环境与人物关系' : (i == 7 ? '收尾情绪落幅' : ''),
          },
      ];
      final PlanModuleData storyboard = PlanModuleData(
        id: 'demo-mod-${seq++}',
        type: PlanModuleType.storyboard,
        title: '分镜表',
        data: <String, Object?>{'shots': shots},
      );
      final int posesIndex = modules
          .indexWhere((PlanModuleData m) => m.type == PlanModuleType.poses);
      modules.insert(
          posesIndex >= 0 ? posesIndex + 1 : modules.length, storyboard);
    }

    await db.into(db.plans).insertOnConflictUpdate(
          PlansCompanion.insert(
            id: planId,
            title: '示例 · 雨夜霓虹 Cosplay 正片',
            status: const Value('draft'),
            modulesJson: Value(jsonEncode(
                modules.map((PlanModuleData m) => m.toJson()).toList())),
            createdAt: now,
            updatedAt: now,
          ),
        );
    seeded++;

    await db.setSetting(_keySeeded, 'true');
    await db.setSetting(_keyFrames, jsonEncode(frameIds));
    await db.setSetting(
        _keyPoses, jsonEncode(chosenPoses.map((PoseEntry p) => p.id).toList()));
    return seeded;
  }

  /// 一键移除示例内容（保留用户自己创建的数据）。
  static Future<void> remove(AppDatabase db) async {
    // 还原画板帧。
    final frameIds =
        asStringList(jsonDecode(await db.getSetting(_keyFrames) ?? '[]'));
    for (final String id in frameIds) {
      await (db.update(db.filmFrames)..where((t) => t.id.equals(id)))
          .write(const FilmFramesCompanion(inBoard: Value(false)));
    }
    // 还原姿势收藏。
    final poseIds =
        asStringList(jsonDecode(await db.getSetting(_keyPoses) ?? '[]'));
    for (final String id in poseIds) {
      await (db.update(db.poses)..where((t) => t.id.equals(id)))
          .write(const PosesCompanion(favorite: Value(false)));
    }
    // 删除示例新建行。
    await (db.delete(db.plans)..where((t) => t.id.equals(planId))).go();
    await (db.delete(db.lightingScenes)..where((t) => t.id.equals(sceneId)))
        .go();
    for (final String id in resourceIds) {
      await (db.delete(db.resources)..where((t) => t.id.equals(id))).go();
    }
    await db.setSetting(_keySeeded, 'false');
    await db.setSetting(_keyFrames, '[]');
    await db.setSetting(_keyPoses, '[]');
  }
}
