import '../../core/utils/json_utils.dart';
import '../../services/content_packs.dart';

/// 15 种模块类型（PRD 6.5 + D30 分镜）。
enum PlanModuleType {
  theme('拍摄主题', '内容'),
  model('模特绑定', '绑定'),
  location('场地绑定', '绑定'),
  sun('日照时间', '内容'),
  refs('参考样片', '内容'),
  palette('色调色卡', '内容'),
  lighting('布光图', '绑定'),
  poses('姿势清单', '绑定'),
  storyboard('分镜表', '内容'),
  clothing('服装清单', '绑定'),
  props('道具清单', '绑定'),
  makeup('妆面造型', '绑定'),
  crew('人员分工', '内容'),
  budget('预算表', '内容'),
  richText('自定义富文本', '内容');

  const PlanModuleType(this.label, this.category);
  final String label;
  final String category;

  static PlanModuleType fromName(String name) =>
      PlanModuleType.values.firstWhere(
        (PlanModuleType t) => t.name == name,
        orElse: () => PlanModuleType.theme,
      );

  /// 绑定类模块对应的资源库 type（model/location/clothing/props/makeup）。
  String? get resourceKind => switch (this) {
    PlanModuleType.model => 'models',
    PlanModuleType.location => 'locations',
    PlanModuleType.clothing => 'clothing',
    PlanModuleType.props => 'props',
    PlanModuleType.makeup => 'makeup',
    _ => null,
  };
}

/// 策划案模块。
class PlanModuleData {
  PlanModuleData({
    required this.id,
    required this.type,
    required this.title,
    Map<String, Object?>? data,
    this.folded = false,
  }) : data = data ?? <String, Object?>{};

  final String id;
  final PlanModuleType type;
  String title;
  Map<String, Object?> data;
  bool folded;

  String get summary => switch (type) {
    PlanModuleType.theme || PlanModuleType.richText =>
      (data['text'] as String? ?? '').replaceAll('\n', ' ').trim(),
    PlanModuleType.sun => '${data['place'] ?? ''} · ${data['date'] ?? ''}',
    PlanModuleType.refs => '${(data['refs'] as List?)?.length ?? 0} 张样片',
    PlanModuleType.palette =>
      ((data['colors'] as List?) ?? const <Object?>[]).join(' '),
    PlanModuleType.lighting => data['sceneName'] as String? ?? '未绑定布光方案',
    PlanModuleType.poses => '${(data['poses'] as List?)?.length ?? 0} 个姿势',
    PlanModuleType.storyboard => '${(data['shots'] as List?)?.length ?? 0} 个镜头',
    PlanModuleType.crew => '${(data['rows'] as List?)?.length ?? 0} 条分工',
    PlanModuleType.budget => '${(data['rows'] as List?)?.length ?? 0} 条预算',
    _ => '${(data['ids'] as List?)?.length ?? 0} 项绑定',
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.name,
    'title': title,
    'data': data,
    'folded': folded,
  };

  static PlanModuleData fromJson(Map<String, Object?> json) => PlanModuleData(
    id: json['id'] as String? ?? '',
    type: PlanModuleType.fromName(json['type'] as String? ?? 'theme'),
    title: json['title'] as String? ?? '',
    data: asMap(json['data']),
    folded: json['folded'] as bool? ?? false,
  );

  /// 应用模板预设（保留 type/title，注入预设数据）。
  static PlanModuleData fromTemplate(Map<String, Object?> raw, String id) {
    final type = PlanModuleType.fromName(raw['type'] as String? ?? 'theme');
    final preset = asMap(raw['preset']);
    final data = deepCopy(preset);
    switch (type) {
      case PlanModuleType.model:
      case PlanModuleType.location:
      case PlanModuleType.clothing:
      case PlanModuleType.props:
      case PlanModuleType.makeup:
        data['ids'] ??= <String>[];
        data['placeholder'] = (data['ids'] as List).isEmpty;
      case PlanModuleType.refs:
        data['refs'] ??= <Object?>[];
      case PlanModuleType.poses:
        data['poses'] ??= <Object?>[];
      case PlanModuleType.storyboard:
        data['shots'] ??= <Object?>[];
      case PlanModuleType.lighting:
        data['sceneId'] ??= '';
        data['sceneName'] ??= '';
      case PlanModuleType.palette:
        data['colors'] ??= <String>[];
      case PlanModuleType.sun:
        data['place'] ??= '';
        data['date'] ??= '';
        data['lat'] ??= 31.23;
        data['lon'] ??= 121.47;
      case PlanModuleType.crew:
        data['rows'] ??= <Object?>[];
      case PlanModuleType.budget:
        data['rows'] ??= <Object?>[];
      case PlanModuleType.theme:
      case PlanModuleType.richText:
        data['text'] ??= '';
    }
    return PlanModuleData(
      id: id,
      type: type,
      title: raw['title'] as String? ?? type.label,
      data: data,
    );
  }
}

/// 策划案状态。
enum PlanDocStatus {
  draft('草稿'),
  final_('已定稿'),
  done('已完成');

  const PlanDocStatus(this.label);
  final String label;

  static PlanDocStatus fromName(String name) => switch (name) {
    'final' => PlanDocStatus.final_,
    'done' => PlanDocStatus.done,
    _ => PlanDocStatus.draft,
  };

  String get storageName => this == PlanDocStatus.final_ ? 'final' : name;
}

/// 版本快照记录。
class PlanSnapshotInfo {
  const PlanSnapshotInfo({
    required this.id,
    required this.createdAt,
    required this.label,
    required this.moduleCount,
  });

  final String id;
  final DateTime createdAt;
  final String? label;
  final int moduleCount;
}

/// 从模板创建模块序列。
List<PlanModuleData> modulesFromTemplate(
  TemplateEntry template,
  String Function() nextId,
) {
  return template.modules
      .map(
        (Map<String, Object?> raw) =>
            PlanModuleData.fromTemplate(raw, nextId()),
      )
      .toList();
}

/// 模块 JSON Schema 校验（AI 输出与导入数据用，PRD 6.6）。
class ModuleSchemaValidator {
  ModuleSchemaValidator._();

  static List<String> validate(List<Object?> modules) {
    final errors = <String>[];
    if (modules.isEmpty) {
      errors.add('模块列表为空');
      return errors;
    }
    for (var i = 0; i < modules.length; i++) {
      final raw = modules[i];
      if (raw is! Map) {
        errors.add('模块 #${i + 1} 不是对象');
        continue;
      }
      final map = raw.cast<String, Object?>();
      final typeName = map['type'];
      if (typeName is! String ||
          !PlanModuleType.values.any(
            (PlanModuleType t) => t.name == typeName,
          )) {
        errors.add('模块 #${i + 1} type 非法：$typeName');
        continue;
      }
      final type = PlanModuleType.fromName(typeName);
      if (map['title'] is! String || (map['title'] as String).isEmpty) {
        errors.add('模块 #${i + 1}（${type.label}）缺少标题');
      }
      if (map['data'] is! Map) {
        errors.add('模块 #${i + 1}（${type.label}）缺少 data');
      }
    }
    return errors;
  }
}
