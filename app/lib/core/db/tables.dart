import 'package:drift/drift.dart';

/// 五大资源库（模特/场地/服装/道具/妆造）统一存一张表，type 区分。
class Resources extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // models|locations|clothing|props|makeup
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get fieldsJson =>
      text().withDefault(const Constant('{}'))(); // 各库专有字段
  TextColumn get coverImage => text().nullable()(); // 用户上传封面（D23）
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// 资源附图（用户自定义上传，关联到具体道具/场景等，D23）
class ResourceImages extends Table {
  TextColumn get id => text()();
  TextColumn get resourceId => text().customConstraint(
      'NOT NULL REFERENCES resources(id) ON DELETE CASCADE')();
  TextColumn get filePath => text()(); // 工作区内相对路径
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

/// 影片索引（FILMGRAB 转化，D4）
class Films extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get director => text().withDefault(const Constant(''))();
  IntColumn get year => integer().nullable()();
  TextColumn get coverGradient =>
      text().withDefault(const Constant(''))(); // 示意渐变
  TextColumn get sourceUrl => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {id};
}

/// 影片静帧
class FilmFrames extends Table {
  TextColumn get id => text()();
  TextColumn get filmId => text()
      .customConstraint('NOT NULL REFERENCES films(id) ON DELETE CASCADE')();
  TextColumn get name => text()();
  TextColumn get imageRef => text()(); // 本地路径或远程 URL
  TextColumn get paletteJson =>
      text().withDefault(const Constant('[]'))(); // 五色色卡
  TextColumn get sourceUrl => text().withDefault(const Constant(''))(); // 出处标注
  BoolColumn get inBoard =>
      boolean().withDefault(const Constant(false))(); // 是否入参考画板
  @override
  Set<Column> get primaryKey => {id};
}

/// 姿势库（人体模型姿势，D6）——姿势 = 关节角度集合
class Poses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()(); // 站姿|坐姿|蹲跪|动态|情绪
  TextColumn get difficulty => text().withDefault(const Constant('新手友好'))();
  TextColumn get jointsJson => text()(); // {joint: [rx,ry,rz]}
  TextColumn get tip => text().withDefault(const Constant(''))();
  TextColumn get lensAdvice => text().withDefault(const Constant(''))();
  BoolColumn get builtin => boolean().withDefault(const Constant(false))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

/// 布光场景（D5）——与引擎场景 JSON 一一对应
class LightingScenes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sceneJson => text()(); // 引擎场景完整 JSON（灯/道具/假人姿势/相机）
  TextColumn get linkedPoseId => text()
      .nullable()
      .customConstraint('REFERENCES poses(id) ON DELETE SET NULL')();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// 设备数据库（D19 D20）：相机机身 / 镜头 / 灯具
class GearItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // camera|lens|light
  TextColumn get brand => text()();
  TextColumn get model => text()();
  TextColumn get mount => text().withDefault(const Constant(''))();
  TextColumn get specsJson =>
      text().withDefault(const Constant('{}'))(); // 画幅/像素/功率/色温等
  RealColumn get priceRef => real().nullable()();
  BoolColumn get builtin => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

/// 策划案
class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get status =>
      text().withDefault(const Constant('draft'))(); // draft|final（定稿只是标签，D15）
  TextColumn get modulesJson =>
      text().withDefault(const Constant('[]'))(); // 有序模块数组
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// 策划案版本快照（D15–D17：无限历史 + 里程碑）
class PlanSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()
      .customConstraint('NOT NULL REFERENCES plans(id) ON DELETE CASCADE')();
  TextColumn get modulesJson => text()();
  TextColumn get label => text().nullable()(); // 手动里程碑名
  IntColumn get createdAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// AI 提供方配置（D8–D10）
class ProviderConfigs extends Table {
  TextColumn get id => text()(); // preset id 或自定义 uuid
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get protocol => text()
      .withDefault(const Constant('openai'))(); // openai|anthropic|responses
  TextColumn get encryptedKey =>
      text().withDefault(const Constant(''))(); // AES-256-GCM 密文（D9）
  TextColumn get defaultModel => text().withDefault(const Constant(''))();
  TextColumn get modelsJson =>
      text().withDefault(const Constant('[]'))(); // 模型发现缓存
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(0))(); // 路由优先级
  @override
  Set<Column> get primaryKey => {id};
}

/// 观测台调用日志（D10）
class CallLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get providerId => text()();
  TextColumn get model => text()();
  BoolColumn get success => boolean()();
  IntColumn get latencyMs => integer()();
  IntColumn get promptTokens => integer().withDefault(const Constant(0))();
  IntColumn get completionTokens => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  IntColumn get createdAt => integer()();
}

/// 键值设置（主题、开关、内容包版本、更新通道等）
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {key};
}
