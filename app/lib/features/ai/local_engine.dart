import '../../services/content_packs.dart';
import '../planner/planner_models.dart';

/// 本地模板规则引擎（D11 / PRD 6.6）：无 Key / 断网时 100% 兜底产出基础策划案。
class LocalPlanEngine {
  const LocalPlanEngine();

  /// 主题关键词 → 模板类目。
  static const Map<String, String> _keywordCategory = <String, String>{
    'cos': 'Cos 正片',
    'cosplay': 'Cos 正片',
    '角色': 'Cos 正片',
    '二次元': 'Cos 正片',
    '汉服': '汉服',
    '古风': '汉服',
    '国风': '汉服',
    'jk': 'JK',
    '校园': 'JK',
    '婚纱': '婚纱',
    '新娘': '婚纱',
    '婚礼': '婚纱',
    '写真': '写真',
    '人像': '写真',
    '棚拍': '写真',
    '商拍': '商拍',
    '电商': '商拍',
    'lolita': 'Lo裙',
    'lo裙': 'Lo裙',
    '双人': '双人',
    '情侣': '双人',
  };

  /// 生成基础策划模块。
  Future<List<PlanModuleData>> generate({
    required String theme,
    required String Function() nextId,
    List<({String id, String name})> resourcesOfType = const <({
      String id,
      String name
    })>[],
    Map<String, List<String>> resourceNamesByType =
        const <String, List<String>>{},
    List<Map<String, Object?>> boardFrames = const <Map<String, Object?>>[],
    ({String id, String name})? lightingScene,
    List<Map<String, Object?>> favoritePoses = const <Map<String, Object?>>[],
    String? preferredCategory,
  }) async {
    final templates = await ContentPacks.templates();
    final lower = theme.toLowerCase();
    String category = preferredCategory ?? '';
    if (category.isEmpty) {
      for (final MapEntry<String, String> entry in _keywordCategory.entries) {
        if (lower.contains(entry.key)) {
          category = entry.value;
          break;
        }
      }
    }
    if (category.isEmpty) category = '写真';
    final template = templates.firstWhere(
      (TemplateEntry t) => t.category == category,
      orElse: () => templates.firstWhere(
          (TemplateEntry t) => t.category == '写真',
          orElse: () => templates.first),
    );

    final modules = modulesFromTemplate(template, nextId);
    // 用户主题与资源注入（F3：每个模块都给到可执行细节）。
    final CityEntry city = await _matchCity(lower);
    final List<BudgetItemEntry> budgetRefs = await ContentPacks.budgetRefs();
    final Map<String, double> multipliers =
        await ContentPacks.cityMultipliers();
    final double multiplier = multipliers[city.tier] ?? 1.0;
    for (final PlanModuleData module in modules) {
      switch (module.type) {
        case PlanModuleType.theme:
          final String raw = theme.trim().isEmpty ? '未命名主题' : theme.trim();
          module.data['text'] = raw.length >= 40
              ? raw
              : '$raw。\n画面方向：以参考画板的色调与构图为基调，突出人物神态与环境氛围的呼应；'
                  '整体低饱和中保留一处高亮色作为视觉锚点，服化道与场地质感统一。';
        case PlanModuleType.model:
        case PlanModuleType.location:
        case PlanModuleType.clothing:
        case PlanModuleType.props:
        case PlanModuleType.makeup:
          final typeKey = module.type.resourceKind!;
          final names = resourceNamesByType[typeKey] ?? const <String>[];
          module.data['ids'] = <String>[];
          module.data['placeholder'] = names.isEmpty;
          if (names.isNotEmpty) {
            module.data['note'] =
                '${module.data['note'] ?? ''}（建议优先复用：${names.take(3).join('、')}）'
                    .trim();
          } else if ((module.data['note'] as String? ?? '').length < 8) {
            module.data['note'] = switch (typeKey) {
              'models' => '按角色气质筛选模特，提前确认档期与妆造时间',
              'locations' => '外景需备案并预留转场时间；夜景确认照明条件',
              'clothing' => '按角色准备主服装与备用件，含安全裤与打底',
              'props' => '道具清单含采购负责人与到货时间，注意运输安全',
              _ => '妆造提前试妆，准备定妆参考与补妆包',
            };
          }
        case PlanModuleType.refs:
          module.data['refs'] = boardFrames.take(6).toList();
        case PlanModuleType.palette:
          final palette = boardFrames.isNotEmpty
              ? (boardFrames.first['palette'] as List?)?.take(5).toList()
              : null;
          module.data['colors'] = palette ??
              <String>['#2f3a4a', '#4d6bfe', '#c24e2a', '#e3dbcf', '#f6f3ee'];
        case PlanModuleType.lighting:
          module.data['sceneId'] = lightingScene?.id ?? '';
          module.data['sceneName'] = lightingScene?.name ?? '';
          module.data['note'] = lightingScene == null
              ? '三点布光起手：主光 45° 侧前 2.2m、高位，辅光对侧 2.6m 亮度 40%，'
                  '轮廓光侧后 2.8m 勾边；按环境色微调色温（夜景 5600K+，室内 3200K）'
              : '已绑定布光方案，导出时附带灯位图与参数清单';
          // D29：无已保存方案时给出可物化的三点灯位（生成后自动落库成可打开场景）。
          if (lightingScene == null) {
            final bool night = theme.contains('夜') ||
                theme.contains('霓虹') ||
                theme.contains('赛博');
            final int kelvin = night ? 4300 : 5600;
            module.data['lights'] = <Object?>[
              <String, Object?>{
                'name': night ? '冷调主光' : '主光',
                'type': 'soft',
                'x': -1.2,
                'y': -1.6,
                'height': 2.2,
                'intensity': 70,
                'kelvin': kelvin,
                'modifier': 'softbox-90',
              },
              <String, Object?>{
                'name': '辅光',
                'type': 'soft',
                'x': 1.6,
                'y': -1.2,
                'height': 1.8,
                'intensity': 40,
                'kelvin': kelvin,
                'modifier': 'umbrella-white',
              },
              <String, Object?>{
                'name': night ? '霓虹轮廓光' : '轮廓光',
                'type': 'hard',
                'x': 1.2,
                'y': 1.8,
                'height': 2.4,
                'intensity': 55,
                'kelvin': night ? 6000 : 5600,
                'modifier': 'barn',
              },
            ];
          }
        case PlanModuleType.poses:
          module.data['poses'] = favoritePoses.isNotEmpty
              ? favoritePoses.take(9).toList()
              : <Object?>[];
          if ((module.data['poses'] as List).isEmpty) {
            final poses = await ContentPacks.poses();
            module.data['poses'] = poses
                .take(3)
                .map((PoseEntry p) => <String, Object?>{
                      'name': p.name,
                      'joints': <String, Object?>{
                        ...p.joints,
                        'rootY': p.rootY,
                        'rootPitch': p.rootPitch,
                      },
                      'lens': p.lens,
                      'cameraPosition': p.cameraPosition,
                    })
                .toList();
          }
        case PlanModuleType.sun:
          module.data['place'] = city.name;
          module.data['lat'] = city.lat;
          module.data['lon'] = city.lon;
          if ((module.data['date'] as String? ?? '').isEmpty) {
            final now = DateTime.now();
            module.data['date'] =
                '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          }
        case PlanModuleType.crew:
          final List<Object?> rows = <Object?>[
            <String, Object?>{'role': '摄影师', 'who': '', 'time': '10:00'},
            <String, Object?>{'role': '妆造', 'who': '', 'time': '08:30'},
            <String, Object?>{'role': '后勤/道具', 'who': '', 'time': '09:30'},
          ];
          module.data['rows'] = rows;
        case PlanModuleType.budget:
          module.data['rows'] = budgetRefs.map((BudgetItemEntry item) {
            final double mid = (item.min + item.max) / 2 * multiplier;
            return <String, Object?>{
              'item': item.label,
              'price': mid.round(),
              'note':
                  '估算值（${item.min.round()}–${item.max.round()}，${city.tier}系数 ${multiplier.toStringAsFixed(2)}）',
            };
          }).toList();
        case PlanModuleType.storyboard:
          module.data['shots'] ??= <Object?>[];
        case PlanModuleType.richText:
          break;
      }
    }

    // 模板缺少布光模块时补齐（含可物化的三灯数值，D29）。
    if (!modules.any((PlanModuleData m) => m.type == PlanModuleType.lighting)) {
      final bool night =
          theme.contains('夜') || theme.contains('霓虹') || theme.contains('赛博');
      final int kelvin = night ? 4300 : 5600;
      final PlanModuleData lighting = PlanModuleData(
        id: nextId(),
        type: PlanModuleType.lighting,
        title: '布光图',
        data: <String, Object?>{
          'sceneId': '',
          'sceneName': '',
          'note': '三点布光起手（AI 已给出可执行灯位，可直接打开预演微调）',
          'lights': <Object?>[
            <String, Object?>{
              'name': night ? '冷调主光' : '主光',
              'type': 'soft',
              'x': -1.2,
              'y': -1.6,
              'height': 2.2,
              'intensity': 70,
              'kelvin': kelvin,
              'modifier': 'softbox-90',
            },
            <String, Object?>{
              'name': '辅光',
              'type': 'soft',
              'x': 1.6,
              'y': -1.2,
              'height': 1.8,
              'intensity': 40,
              'kelvin': kelvin,
              'modifier': 'umbrella-white',
            },
            <String, Object?>{
              'name': night ? '霓虹轮廓光' : '轮廓光',
              'type': 'hard',
              'x': 1.2,
              'y': 1.8,
              'height': 2.4,
              'intensity': 55,
              'kelvin': night ? 6000 : 5600,
              'modifier': 'barn',
            },
          ],
        },
      );
      final int themeIndex = modules
          .indexWhere((PlanModuleData m) => m.type == PlanModuleType.theme);
      modules.insert(themeIndex >= 0 ? themeIndex + 1 : 0, lighting);
    }

    // D30：基于姿势清单生成 8–12 镜分镜表（离线也达标）。
    final PlanModuleData? posesModule = modules
        .where((PlanModuleData m) => m.type == PlanModuleType.poses)
        .firstOrNull;
    PlanModuleData? storyboardModule = modules
        .where((PlanModuleData m) => m.type == PlanModuleType.storyboard)
        .firstOrNull;
    if (storyboardModule == null) {
      storyboardModule = PlanModuleData(
        id: nextId(),
        type: PlanModuleType.storyboard,
        title: '分镜表',
        data: <String, Object?>{'shots': <Object?>[]},
      );
      final int posesIndex = modules
          .indexWhere((PlanModuleData m) => m.type == PlanModuleType.poses);
      modules.insert(
          posesIndex >= 0 ? posesIndex + 1 : modules.length, storyboardModule);
    }
    {
      final List<String> poseNames =
          (posesModule?.data['poses'] as List? ?? <Object?>[])
              .whereType<Map>()
              .map((Map m) => '${m['name'] ?? ''}')
              .where((String n) => n.isNotEmpty)
              .toList();
      final PlanModuleData? lightingModule = modules
          .where((PlanModuleData m) => m.type == PlanModuleType.lighting)
          .firstOrNull;
      final String sceneName =
          lightingModule?.data['sceneName'] as String? ?? '';
      final String lightingText = sceneName.isNotEmpty ? sceneName : '三点布光';
      const List<String> sizes = <String>[
        '远景',
        '全身',
        '中景',
        '近景',
        '特写',
        '空镜',
      ];
      const Map<String, String> lensBySize = <String, String>{
        '远景': '24mm',
        '空镜': '35mm',
        '全身': '35mm',
        '中景': '50mm',
        '近景': '85mm',
        '特写': '135mm',
      };
      const List<String> cameras = <String>[
        '低机位',
        '腰位',
        '胸口',
        '眼位',
        '俯拍',
      ];
      final int count =
          poseNames.isEmpty ? 8 : (poseNames.length + 3).clamp(8, 12);
      final List<Object?> shots = <Object?>[];
      for (var i = 0; i < count; i++) {
        final String size = sizes[i % sizes.length];
        shots.add(<String, Object?>{
          'no': i + 1,
          'shotSize': size,
          'camera': cameras[i % cameras.length],
          'lens': lensBySize[size] ?? '50mm',
          'pose': poseNames.isEmpty ? '自然站姿' : poseNames[i % poseNames.length],
          'lighting': lightingText,
          'key': i == 0 || i == count - 1,
          'note': i == 0
              ? '开场建立环境与人物关系'
              : i == count - 1
                  ? '收尾情绪落幅'
                  : '',
        });
      }
      storyboardModule.data['shots'] = shots;
      storyboardModule.data['note'] = '按拍摄顺序排列；重点镜已标注，可拖拽微调';
    }
    return modules;
  }

  Future<CityEntry> _matchCity(String lowerTheme) async {
    final List<CityEntry> cities = await ContentPacks.cities();
    for (final CityEntry city in cities) {
      if (lowerTheme.contains(city.name)) return city;
    }
    for (final CityEntry city in cities) {
      if (city.name == '上海') return city;
    }
    return cities.first;
  }
}
