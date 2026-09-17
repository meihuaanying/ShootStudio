import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/db/database.dart';
import '../core/utils/json_utils.dart';

/// 内置内容包（D3：模板/姿势/布光预设/影片索引可云端增量更新；
/// 内置版本随安装包发布，云端包在 S5 更新通道合并）。
class ContentPacks {
  ContentPacks._();

  /// 内置内容包版本（与云端包版本比较决定增量拉取）。
  /// V4：姿势库切换到 poses3（120 条实拍照片姿势），版本升级触发重建。
  static const int builtinVersion = 2;

  static Map<String, Object?>? _cacheFilms;
  static Map<String, Object?>? _cachePoses;
  static Map<String, Object?>? _cachePosesLegacy;
  static Map<String, Object?>? _cachePresets;
  static Map<String, Object?>? _cacheTemplates;
  static Map<String, Object?>? _cacheGear;
  static Map<String, Object?>? _cacheClothing;
  static Map<String, Object?>? _cacheProps;
  static Map<String, Object?>? _cacheCities;
  static Map<String, Object?>? _cacheBudget;

  static Future<Map<String, Object?>> _load(String asset) async {
    final raw = await rootBundle.loadString(asset);
    return asMap(jsonDecode(raw));
  }

  static Future<List<FilmEntry>> films() async {
    _cacheFilms ??= await _load('assets/content/films/films.json');
    return asMapList(_cacheFilms!['films']).map(FilmEntry.fromJson).toList();
  }

  /// V4（D65–D70/R19/R20）：照片姿势库（120 条实拍 + MediaPipe 骨架 + 12 关节角）。
  static Future<Map<String, Object?>> poses3() async {
    _cachePoses ??= await _load('assets/content/poses3/poses3.json');
    return _cachePoses!;
  }

  /// 照片姿势库条目（poses 的 V4 实现）。
  static Future<List<PoseEntry>> poses() async {
    final raw = await poses3();
    return asMapList(raw['poses']).map(PoseEntry.fromJson).toList();
  }

  /// 归档：旧程序化姿势库（V4 起不再进入应用，仅保留数据与兼容加载能力）。
  static Future<List<PoseEntry>> posesLegacy() async {
    _cachePosesLegacy ??= await _load('assets/content/poses/poses.json');
    return asMapList(_cachePosesLegacy!['poses'])
        .map(PoseEntry.fromJson)
        .toList();
  }

  static Future<List<LightPresetEntry>> lightPresets() async {
    _cachePresets ??=
        await _load('assets/content/light_presets/light_presets.json');
    return asMapList(_cachePresets!['presets'])
        .map(LightPresetEntry.fromJson)
        .toList();
  }

  static Future<List<TemplateEntry>> templates() async {
    _cacheTemplates ??= await _load('assets/content/templates/templates.json');
    return asMapList(_cacheTemplates!['templates'])
        .map(TemplateEntry.fromJson)
        .toList();
  }

  static Future<List<GearEntry>> gear() async {
    _cacheGear ??= await _load('assets/content/gear/gear.json');
    return asMapList(_cacheGear!['items']).map(GearEntry.fromJson).toList();
  }

  static Future<List<ClothingCategoryEntry>> clothingCategories() async {
    _cacheClothing ??= await _load('assets/content/clothing/clothing.json');
    return asMapList(_cacheClothing!['categories'])
        .map(ClothingCategoryEntry.fromJson)
        .toList();
  }

  static Future<List<PropPresetEntry>> propPresets() async {
    _cacheProps ??= await _load('assets/content/props/props_presets.json');
    return asMapList(_cacheProps!['props'])
        .map(PropPresetEntry.fromJson)
        .toList();
  }

  /// 云端模板包合并（S5 更新通道）。
  static void mergeCloudTemplates(Map<String, Object?> json) {
    final cloud =
        asMapList(json['templates']).map(TemplateEntry.fromJson).toList();
    if (cloud.isEmpty) return;
    final current = _cacheTemplates == null
        ? <TemplateEntry>[]
        : asMapList(_cacheTemplates!['templates'])
            .map(TemplateEntry.fromJson)
            .toList();
    final ids = current.map((TemplateEntry t) => t.id).toSet();
    final merged = <TemplateEntry>[
      ...current,
      ...cloud.where((TemplateEntry t) => !ids.contains(t.id)),
    ];
    _cacheTemplates = <String, Object?>{
      'version': 1,
      'templates': merged.map((TemplateEntry t) => t.toJson()).toList(),
    };
  }

  /// 云端姿势包合并（S5 更新通道）。
  static void mergeCloudPoses(Map<String, Object?> json) {
    final cloud = asMapList(json['poses']).map(PoseEntry.fromJson).toList();
    if (cloud.isEmpty) return;
    final current = _cachePoses == null
        ? <PoseEntry>[]
        : asMapList(_cachePoses!['poses']).map(PoseEntry.fromJson).toList();
    final ids = current.map((PoseEntry p) => p.id).toSet();
    final merged = <PoseEntry>[
      ...current,
      ...cloud.where((PoseEntry p) => !ids.contains(p.id)),
    ];
    _cachePoses = <String, Object?>{
      'version': 1,
      'poses': merged.map((PoseEntry p) => p.toJson()).toList(),
    };
  }

  static Future<List<CityEntry>> cities() async {
    _cacheCities ??= await _load('assets/content/cities/cities.json');
    return asMapList(_cacheCities!['cities']).map(CityEntry.fromJson).toList();
  }

  static Future<List<BudgetItemEntry>> budgetRefs() async {
    _cacheBudget ??= await _load('assets/content/budget/budget_refs.json');
    return asMapList(_cacheBudget!['items'])
        .map(BudgetItemEntry.fromJson)
        .toList();
  }

  /// 城市档位系数（一线/新一线/二线/三线）。
  static Future<Map<String, double>> cityMultipliers() async {
    _cacheCities ??= await _load('assets/content/cities/cities.json');
    return asMap(_cacheCities!['multipliers']).map(
      (String key, Object? value) => MapEntry(key, asDouble(value, 1)),
    );
  }

  /// 云端内容包注入/合并（S5 更新通道调用；按 id 去重，云端优先）。
  static void mergeCloud(
      {Map<String, Object?>? films, Map<String, Object?>? poses}) {
    if (films != null) _cacheFilms = films;
    if (poses != null) _cachePoses = poses;
  }

  /// 把内置内容同步进工作区数据库（幂等；保留用户收藏与画板状态）。
  static Future<void> syncToDatabase(AppDatabase db) async {
    final version = await db.getSetting('content_version');
    if (version == '$builtinVersion') return;

    final filmList = await films();
    for (final film in filmList) {
      await db.into(db.films).insertOnConflictUpdate(
            FilmsCompanion.insert(
              id: film.id,
              title: film.title,
              director: Value(film.director),
              year: Value(film.year),
              sourceUrl: Value(film.sourceUrl),
              coverGradient: Value(jsonEncode(film.frames.first.gradient)),
            ),
          );
      for (final frame in film.frames) {
        await db.into(db.filmFrames).insertOnConflictUpdate(
              FilmFramesCompanion.insert(
                id: '${film.id}:${frame.name}',
                filmId: film.id,
                name: frame.name,
                imageRef: '',
                paletteJson: Value(jsonEncode(frame.palette)),
                sourceUrl: Value(frame.sourceUrl),
              ),
            );
      }
    }

    final poseList = await poses();
    for (final pose in poseList) {
      final existing = await (db.select(db.poses)
            ..where((t) => t.id.equals(pose.id)))
          .getSingleOrNull();
      await db.into(db.poses).insertOnConflictUpdate(
            PosesCompanion.insert(
              id: pose.id,
              name: pose.name,
              category: pose.category,
              difficulty: Value(pose.difficulty),
              jointsJson: jsonEncode(<String, Object?>{
                ...pose.joints,
                'rootY': pose.rootY,
                'rootPitch': pose.rootPitch,
              }),
              tip: Value(pose.weight),
              lensAdvice: Value(pose.lens),
              builtin: const Value(true),
              favorite: Value(existing?.favorite ?? false),
            ),
          );
    }

    // 设备数据库（D19/D20）：内置条目重建（用户自定义保留，kind 以 builtin 区分）。
    final gearItems = await gear();
    await (db.delete(db.gearItems)..where((t) => t.builtin.equals(true))).go();
    for (final GearEntry item in gearItems) {
      await db.into(db.gearItems).insertOnConflictUpdate(
            GearItemsCompanion.insert(
              id: item.id,
              kind: item.kind,
              brand: item.brand,
              model: item.model,
              mount: Value(item.mount),
              specsJson: Value(jsonEncode(item.specs)),
              priceRef: Value(item.priceRef),
              builtin: const Value(true),
            ),
          );
    }

    // 道具预设（D22）：仅在库中尚无预设条目时播种（幂等，不覆盖用户编辑）。
    final presetCount = await db
        .customSelect(
            "SELECT COUNT(*) c FROM resources WHERE id LIKE 'preset-%'")
        .getSingle();
    if (((presetCount.data['c'] as num?)?.toInt() ?? 0) == 0) {
      final presets = await propPresets();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final PropPresetEntry prop in presets) {
        await db.into(db.resources).insertOnConflictUpdate(
              ResourcesCompanion.insert(
                id: 'preset-${prop.id}',
                type: 'props',
                name: prop.name,
                fieldsJson: Value(jsonEncode(<String, Object?>{
                  'price': '¥${prop.price}',
                  'note': prop.note,
                  'owner': prop.owner,
                  'tags': <String>[prop.category],
                })),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    }

    await db.setSetting('content_version', '$builtinVersion');
  }

  // ---------------- V3：真实素材与人物（D46–D56） ----------------

  static Map<String, Object?>? _cacheStills;
  static Map<String, Object?>? _cacheImageSources;
  static Map<String, Object?>? _cacheGearPhotos;
  static Map<String, Object?>? _cacheClothingPhotos;
  static Map<String, Object?>? _cacheCharacters;

  /// PD 静帧包（assets/content/stills/stills.json）。
  static Future<Map<String, Object?>> pdStills() async {
    _cacheStills ??= await _load('assets/content/stills/stills.json');
    return _cacheStills!;
  }

  /// 内置图片源凭据（Pexels/TMDB/代理默认值；设置页可覆盖/清空）。
  static Future<Map<String, Object?>> imageSourcesConfig() async {
    _cacheImageSources ??= await _load('assets/config/image_sources.json');
    return _cacheImageSources!;
  }

  /// 器材实拍（Pexels 缓存，gear/gear_photos.json）。
  static Future<Map<String, Object?>> gearPhotos() async {
    _cacheGearPhotos ??= await _load('assets/content/gear/gear_photos.json');
    return _cacheGearPhotos!;
  }

  /// 服装参考实拍（clothing/clothing_photos.json）。
  static Future<Map<String, Object?>> clothingPhotos() async {
    _cacheClothingPhotos ??=
        await _load('assets/content/clothing/clothing_photos.json');
    return _cacheClothingPhotos!;
  }

  /// 人物 GLB 清单（models/characters/manifest.json）。
  static Future<Map<String, Object?>> charactersManifest() async {
    _cacheCharacters ??= await _load('assets/models/characters/manifest.json');
    return _cacheCharacters!;
  }
}

/// 设备条目（相机/镜头/灯具）。
class GearEntry {
  const GearEntry({
    required this.id,
    required this.kind,
    required this.brand,
    required this.model,
    required this.mount,
    required this.specs,
    required this.priceRef,
    this.tags = const <String>[],
    this.aliases = const <String>[],
    this.image = '',
    this.imageSource = '',
  });

  final String id;

  /// camera | lens | light
  final String kind;
  final String brand;
  final String model;
  final String mount;
  final Map<String, Object?> specs;
  final double priceRef;

  final List<String> tags;
  final List<String> aliases;
  final String image;
  final String imageSource;

  String get displayName => '$brand $model';

  /// 规格搜索文本（规格词/别名/标签/卡口全部参与关键词匹配）。
  String get searchText => <String>[
        displayName,
        model,
        brand,
        mount,
        imageSource,
        ...tags,
        ...aliases,
        ...specs.values.map((Object? v) => '$v'),
      ].join(' ').toLowerCase();

  String get specSummary => switch (kind) {
        'camera' =>
          '${specs['sensor'] ?? ''} · ${specs['megapixel'] ?? ''}MP · ${specs['weight_g'] ?? ''}g',
        'lens' =>
          '${specs['focal'] ?? ''} ${specs['aperture'] ?? ''} · ${specs['mount'] ?? mount}',
        _ =>
          '${specs['power_w'] ?? ''}W · ${specs['cct'] ?? ''} · CRI ${specs['cri'] ?? ''}',
      };

  static GearEntry fromJson(Map<String, Object?> json) => GearEntry(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? 'camera',
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String? ?? '',
        mount: json['mount'] as String? ?? '',
        specs: asMap(json['specs']),
        priceRef: asDouble(json['priceRef']),
        tags: asStringList(json['tags']),
        aliases: asStringList(json['aliases']),
        image: json['image'] as String? ?? '',
        imageSource: json['imageSource'] as String? ?? '',
      );
}

/// 服装目录分类（D21）。
class ClothingCategoryEntry {
  const ClothingCategoryEntry({
    required this.id,
    required this.category,
    required this.gradient,
    required this.examples,
    required this.description,
  });

  final String id;
  final String category;
  final List<String> gradient;
  final List<String> examples;
  final String description;

  static ClothingCategoryEntry fromJson(Map<String, Object?> json) =>
      ClothingCategoryEntry(
        id: json['id'] as String? ?? '',
        category: json['category'] as String? ?? '',
        gradient: asStringList(json['gradient']),
        examples: asStringList(json['examples']),
        description: json['description'] as String? ?? '',
      );
}

/// 道具预设（D22）。
class PropPresetEntry {
  const PropPresetEntry({
    required this.id,
    required this.name,
    required this.price,
    required this.note,
    required this.owner,
    required this.category,
  });

  final String id;
  final String name;
  final num price;
  final String note;
  final String owner;
  final String category;

  static PropPresetEntry fromJson(Map<String, Object?> json) => PropPresetEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?) ?? 0,
        note: json['note'] as String? ?? '',
        owner: json['owner'] as String? ?? '',
        category: json['category'] as String? ?? '常用道具',
      );
}

/// 影片条目。
class FilmEntry {
  const FilmEntry({
    required this.id,
    required this.title,
    required this.director,
    required this.year,
    required this.tags,
    required this.sourceUrl,
    required this.frames,
  });

  final String id;
  final String title;
  final String director;
  final int? year;
  final List<String> tags;
  final String sourceUrl;
  final List<FrameEntry> frames;

  static FilmEntry fromJson(Map<String, Object?> json) => FilmEntry(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        director: json['director'] as String? ?? '',
        year: (json['year'] as num?)?.toInt(),
        tags: asStringList(json['tags']),
        sourceUrl: json['sourceUrl'] as String? ?? '',
        frames: asMapList(json['frames']).map(FrameEntry.fromJson).toList(),
      );
}

class FrameEntry {
  const FrameEntry({
    required this.name,
    required this.palette,
    required this.gradient,
    required this.description,
    required this.sourceUrl,
    required this.tags,
  });

  final String name;
  final List<String> palette;
  final List<String> gradient;
  final String description;
  final String sourceUrl;
  final List<String> tags;

  static FrameEntry fromJson(Map<String, Object?> json) => FrameEntry(
        name: json['name'] as String? ?? '',
        palette: asStringList(json['palette']),
        gradient: asStringList(json['gradient']),
        description: json['description'] as String? ?? '',
        sourceUrl: json['sourceUrl'] as String? ?? '',
        tags: asStringList(json['tags']),
      );
}

/// V5/D86：单手姿态（预设 id 或自定义每指弯曲；spread 张开；wrist 腕部附加旋转）。
class HandPoseState {
  const HandPoseState({
    this.preset = 'relax',
    this.curls = const <String, double>{},
    this.spread = 0,
    this.wrist,
  });

  final String preset;

  /// thumb/index/middle/ring/pinky → 弯曲 0..1。
  final Map<String, double> curls;
  final double spread;
  final List<double>? wrist;

  bool get isCustom => preset == 'custom';

  HandPoseState copyWith({
    String? preset,
    Map<String, double>? curls,
    double? spread,
    Object? wrist = _sentinel,
  }) =>
      HandPoseState(
        preset: preset ?? this.preset,
        curls: curls ?? this.curls,
        spread: spread ?? this.spread,
        wrist: wrist == _sentinel ? this.wrist : wrist as List<double>?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'preset': preset,
        if (curls.isNotEmpty) 'curls': curls,
        'spread': spread,
        if (wrist != null) 'wrist': wrist,
      };

  static HandPoseState fromJson(Map<String, Object?> json) {
    final Map<String, Object?> rawCurls = asMap(json['curls']);
    final List<Object?> rawWrist = asList(json['wrist']);
    return HandPoseState(
      preset: json['preset'] as String? ?? 'relax',
      curls: rawCurls.map(
          (String k, Object? v) => MapEntry<String, double>(k, asDouble(v))),
      spread: asDouble(json['spread']),
      wrist: rawWrist.isEmpty
          ? null
          : rawWrist.map((Object? v) => asDouble(v)).toList(),
    );
  }

  static const Object _sentinel = Object();
}

/// V5：手部 JSON（供 scene/pose 往返；缺失时为 null）。
Map<String, Object?>? handsToJson(HandPoseState? l, HandPoseState? r) {
  if (l == null && r == null) return null;
  return <String, Object?>{
    if (l != null) 'l': l.toJson(),
    if (r != null) 'r': r.toJson(),
  };
}

/// V5：从 pose/scene JSON 解析手部（无字段返回 (null, null)，R36 兼容）。
(HandPoseState?, HandPoseState?) handsFromJson(Object? raw) {
  final Map<String, Object?> map = asMap(raw);
  if (map.isEmpty) return (null, null);
  HandPoseState? parse(Object? v) {
    final Map<String, Object?> m = asMap(v);
    return m.isEmpty ? null : HandPoseState.fromJson(m);
  }

  return (parse(map['l']), parse(map['r']));
}

/// 姿势条目（V4：照片 + 骨架 + 12 关节；joints 含 rootY/rootPitch 可选键）。
class PoseEntry {
  const PoseEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.joints,
    required this.rootY,
    required this.rootPitch,
    required this.weight,
    required this.hands,
    required this.mistake,
    required this.lens,
    this.cameraPosition = '',
    this.photo = '',
    this.overlay = '',
    this.skeleton = '',
    this.confidence = 0,
    this.referenceOnly = false,
    this.partialBody = false,
    this.partialReason = '',
    this.source = '',
    this.license = '',
    this.author = '',
    this.origin = '',
    this.handsL,
    this.handsR,
  });

  final String id;
  final String name;
  final String category;
  final String difficulty;
  final Map<String, Object?> joints;
  final double rootY;
  final double rootPitch;
  final String weight;
  final String hands;
  final String mistake;
  final String lens;
  final String cameraPosition;

  /// 实拍照片资源路径（`assets/content/poses3/photos/<id>.jpg`）。
  final String photo;

  /// 骨架叠加图（QA 证据，`docs/pose-qa3/overlay-<id>.png` 或照片目录同 id）。
  final String overlay;

  /// MediaPipe BlazePose 骨架 JSON（33 关键点 2D/3D）。
  final String skeleton;

  /// 桩级置信度（0..1）；<0.6 时 referenceOnly。
  final double confidence;

  /// 置信度过低：仅供构图参考，不可宣称可复现（D68/R20）。
  final bool referenceOnly;

  /// 半身/特写照片：关键点跨度异常，3D 关节复现仅供构图参考。
  final bool partialBody;
  final String partialReason;

  final String source;
  final String license;
  final String author;
  final String origin;

  /// V5/D88：手部姿态（可选；自定义姿势/云端包可携带）。
  final HandPoseState? handsL;
  final HandPoseState? handsR;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'category': category,
        'difficulty': difficulty,
        'joints': joints,
        'rootY': rootY,
        'rootPitch': rootPitch,
        'weight': weight,
        'hands': hands,
        'commonMistake': mistake,
        'lens': lens,
        'cameraPosition': cameraPosition,
        'photo': photo,
        'overlay': overlay,
        'skeleton': skeleton,
        'confidence': confidence,
        'referenceOnly': referenceOnly,
        'partialBody': partialBody,
        'partialReason': partialReason,
        'source': source,
        'license': license,
        'author': author,
        'origin': origin,
        if (handsL != null || handsR != null)
          'hands': handsToJson(handsL, handsR),
      };

  static PoseEntry fromJson(Map<String, Object?> json) {
    final joints = asMap(json['joints']);
    final (HandPoseState?, HandPoseState?) hands = handsFromJson(json['hands']);
    return PoseEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '站姿',
      difficulty: json['difficulty'] as String? ?? '新手友好',
      joints: joints,
      rootY: asDouble(json['rootY']),
      rootPitch: asDouble(json['rootPitch']),
      weight: json['weight'] as String? ?? '',
      hands: json['hands'] as String? ?? '',
      mistake: json['commonMistake'] as String? ?? '',
      lens: json['lens'] as String? ?? '',
      cameraPosition: json['cameraPosition'] as String? ?? '',
      photo: json['photo'] as String? ?? '',
      overlay: json['overlay'] as String? ?? '',
      skeleton: json['skeleton'] as String? ?? '',
      confidence: asDouble(json['confidence']),
      referenceOnly: json['referenceOnly'] == true,
      partialBody: json['partialBody'] == true,
      partialReason: json['partialReason'] as String? ?? '',
      source: json['source'] as String? ?? '',
      license: json['license'] as String? ?? '',
      author: json['author'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      handsL: hands.$1,
      handsR: hands.$2,
    );
  }
}

/// 布光预设条目。
class LightPresetEntry {
  const LightPresetEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.note,
    required this.devices,
  });

  final String id;
  final String name;
  final String category;
  final String note;
  final List<Map<String, Object?>> devices;

  static LightPresetEntry fromJson(Map<String, Object?> json) =>
      LightPresetEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '基础',
        note: json['note'] as String? ?? '',
        devices: asMapList(json['devices']),
      );
}

/// 城市条目（F10）。
class CityEntry {
  const CityEntry({
    required this.name,
    required this.lat,
    required this.lon,
    required this.tier,
  });

  final String name;
  final double lat;
  final double lon;
  final String tier;

  static CityEntry fromJson(Map<String, Object?> json) => CityEntry(
        name: json['name'] as String? ?? '',
        lat: asDouble(json['lat']),
        lon: asDouble(json['lon']),
        tier: json['tier'] as String? ?? '二线',
      );
}

/// 预算参考条目（F9）。
class BudgetItemEntry {
  const BudgetItemEntry({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.note,
  });

  final String key;
  final String label;
  final double min;
  final double max;
  final String note;

  static BudgetItemEntry fromJson(Map<String, Object?> json) => BudgetItemEntry(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        min: asDouble(json['min']),
        max: asDouble(json['max']),
        note: json['note'] as String? ?? '',
      );
}

/// 策划模板条目。
class TemplateEntry {
  const TemplateEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.modules,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final List<Map<String, Object?>> modules;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'modules': modules,
      };

  static TemplateEntry fromJson(Map<String, Object?> json) => TemplateEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        modules: asMapList(json['modules']),
      );
}
