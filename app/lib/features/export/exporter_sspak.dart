// V8/S8 · D155：.sspak 打包（_exportSspak）与解包导入器（SspakImporter）。
// 从 exporter.dart 拆出；SspakImporter 留在 part 顶层，不进 extension。
part of 'exporter.dart';

extension _ExporterSspak on ExportService {
  Future<void> _exportSspak(
    File outFile,
    String title,
    PlanDocStatus status,
    List<PlanModuleData> modules,
    void Function(ExportProgress) onProgress,
    bool Function() isCancelled,
  ) async {
    final archive = Archive();

    void addBytes(String name, List<int> bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addBytes(
      'manifest.json',
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'format': 'sspak',
          // D150：v2 起 manifest 显式带版本与版式名，导入端据此迁移或明示拒绝。
          'version': kSspakFormatVersion,
          'layout': kSspakLayoutName,
          'app': 'ShootStudio',
          'appVersion': kAppVersion,
          'title': title,
          'exportedAt': DateTime.now().toIso8601String(),
        }),
      ),
    );
    addBytes(
      'plan.json',
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'version': kSspakFormatVersion,
          'title': title,
          'status': status.storageName,
          'modules': modules.map((PlanModuleData m) => m.toJson()).toList(),
        }),
      ),
    );

    // 关联资源与图片。
    final resources = await db.select(db.resources).get();
    final relatedIds = <String>{};
    for (final PlanModuleData module in modules) {
      relatedIds.addAll(
        (module.data['ids'] as List? ?? <Object?>[]).cast<String>(),
      );
    }
    final related = resources
        .where((Resource r) => relatedIds.contains(r.id))
        .toList();
    addBytes(
      'resources.json',
      utf8.encode(
        jsonEncode(<String, Object?>{
          'resources': related
              .map(
                (Resource r) => <String, Object?>{
                  'id': r.id,
                  'type': r.type,
                  'name': r.name,
                  'fields': asMap(jsonDecode(r.fieldsJson)),
                  'cover': r.coverImage,
                },
              )
              .toList(),
        }),
      ),
    );

    // 布光方案。
    final sceneIds = modules
        .where((PlanModuleData m) => m.type == PlanModuleType.lighting)
        .map((PlanModuleData m) => m.data['sceneId'] as String? ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();
    final scenes = await db.select(db.lightingScenes).get();
    addBytes(
      'lighting.json',
      utf8.encode(
        jsonEncode(<String, Object?>{
          'scenes': scenes
              .where((LightingScene s) => sceneIds.contains(s.id))
              .map(
                (LightingScene s) => <String, Object?>{
                  'id': s.id,
                  'name': s.name,
                  'scene': asMap(jsonDecode(s.sceneJson)),
                },
              )
              .toList(),
        }),
      ),
    );

    // 收藏姿势。
    final poses = await db.select(db.poses).get();
    addBytes(
      'poses.json',
      utf8.encode(
        jsonEncode(<String, Object?>{
          'poses': poses
              .where((Pose pose) => pose.favorite)
              .map(
                (Pose pose) => <String, Object?>{
                  'id': pose.id,
                  'name': pose.name,
                  'category': pose.category,
                  'difficulty': pose.difficulty,
                  'joints': asMap(jsonDecode(pose.jointsJson)),
                  'tip': pose.tip,
                  'lens': pose.lensAdvice,
                },
              )
              .toList(),
        }),
      ),
    );

    // 参考帧（画板）。
    final frames = await (db.select(
      db.filmFrames,
    )..where((t) => t.inBoard.equals(true))).get();
    addBytes(
      'refs.json',
      utf8.encode(
        jsonEncode(<String, Object?>{
          'refs': frames
              .map(
                (FilmFrame frame) => <String, Object?>{
                  'id': frame.id,
                  'name': frame.name,
                  'imageRef': frame.imageRef,
                  'palette': frame.paletteJson,
                  'sourceUrl': frame.sourceUrl,
                },
              )
              .toList(),
        }),
      ),
    );

    // 图片文件：资源封面与参考图。
    var count = 0;
    for (final Resource resource in related) {
      final cover = resource.coverImage;
      if (cover == null || cover.isEmpty) continue;
      final file = File(
        path.join(workspace.root.path, 'images', resource.type, cover),
      );
      if (await file.exists()) {
        addBytes('images/${resource.type}/$cover', await file.readAsBytes());
        count++;
      }
    }
    for (final FilmFrame frame in frames) {
      if (frame.imageRef.isEmpty) continue;
      final file = File(
        path.join(workspace.root.path, 'images', 'refs', frame.imageRef),
      );
      if (await file.exists()) {
        addBytes('images/refs/${frame.imageRef}', await file.readAsBytes());
        count++;
      }
    }
    onProgress(ExportProgress('已打包 $count 张图片', 0.6));
    if (isCancelled()) throw const ExportCancelled();
    final encoded = ZipEncoder().encode(archive);
    await outFile.writeAsBytes(encoded!);
  }
}

/// .sspak 导入还原（PRD 6.7 边界：校验包内版本号）。
class SspakImporter {
  SspakImporter({required this.workspace, required this.db});

  final Workspace workspace;
  final AppDatabase db;

  Future<({String planId, String title, int moduleCount, int? migratedFrom})>
  import(String sspakPath) async {
    final bytes = await File(sspakPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    Map<String, Object?> readJson(String name) {
      for (final ArchiveFile file in archive) {
        if (file.name == name) {
          return asMap(jsonDecode(utf8.decode(file.content!)));
        }
      }
      throw StateError('.sspak 缺少 $name');
    }

    // D150：版本分档明示 —— v2 直接读；v1 / 无版本 → 迁移并回报；更高版本 → 拒绝。
    final manifest = readJson('manifest.json');
    if (manifest['format'] != 'sspak') {
      throw const FormatException('不是 .sspak 数据包（manifest.format 不匹配）');
    }
    final int? pkgVersion = (manifest['version'] as num?)?.toInt();
    int? migratedFrom;
    if (pkgVersion == null || pkgVersion < kSspakFormatVersion) {
      // v1 结构与 v2 相同（manifest/plan/poses/… 清单字段一致），只缺版本标记，
      // 迁移 = 读同一批清单 + 补默认字段，这里显式回报来源版本。
      migratedFrom = pkgVersion ?? 1;
    } else if (pkgVersion > kSspakFormatVersion) {
      throw FormatException(
        '该 .sspak 由 ShootStudio v$kSspakFormatVersion 之后的版本生成'
        '（包内 v$pkgVersion），请先升级 App 再导入。',
      );
    }

    // 图片落盘（R84 安全：Zip Slip 防护）。
    //
    // 归档里的条目名是**不可信输入**：一个 `images/../../evil.png` 就能让
    // path.join 越出 workspace，把任意文件写到用户能写的地方（Zip Slip）。
    //
    // 两段式：先**全量校验**再**统一落盘**。边校验边写会让排在恶意条目之前的
    // 正常图片先落盘，抛异常时工作区已处于半导入状态 —— 那种"中止"名不副实。
    //
    // 每条目两道互补的校验：
    //   1) 名称规范化 —— 拒绝 `..`、绝对路径、反斜杠（Windows 盘符/UNC）。
    //   2) path.join 之后断言最终路径确实位于 images 目录内。
    // 第 2 道不是冗余：第 1 道只挡字面量形态，规范化与解析的边界差异仍可能
    // 让落点跑出 images（跨平台 path 实现对 `C:` 之类前缀的处理并不一致）。
    final imagesRoot = path.normalize(
      path.absolute(path.join(workspace.root.path, 'images')),
    );
    final List<(File, List<int>)> pending = <(File, List<int>)>[];
    for (final ArchiveFile file in archive) {
      // 全包级名称卫生：任何条目都不该带前导斜杠或反斜杠。合法 .sspak 的
      // 条目名一律是 `images/x.png` / `manifest.json` 这种相对 POSIX 形态；
      // `/images/evil.png` 形制的条目只可能来自畸形或恶意构造，且若只按
      // startsWith('images/') 过滤会被静默忽略 —— 用户会拿到一个悄悄少了
      // 图片的数据包还不知道，所以显式拒绝。
      if (file.name.startsWith('/') || file.name.contains(r'\')) {
        throw FormatException('.sspak 条目名含绝对路径或反斜杠：${file.name}');
      }
      if (!file.name.startsWith('images/')) continue;
      final relative = file.name.substring('images/'.length);
      if (relative.isEmpty) {
        throw const FormatException('.sspak 图片条目名为空');
      }
      if (path.isAbsolute(relative)) {
        throw FormatException('.sspak 图片条目名是绝对路径：${file.name}');
      }
      if (relative.split('/').any((String seg) => seg == '..')) {
        throw FormatException('.sspak 图片条目名含 `..` 上跳：${file.name}');
      }
      final targetPath = path.normalize(
        path.absolute(path.join(imagesRoot, relative)),
      );
      if (!path.isWithin(imagesRoot, targetPath)) {
        throw FormatException('.sspak 图片条目越出 images 目录：${file.name}');
      }
      pending.add((File(targetPath), file.content!));
    }
    for (final (File target, List<int> bytes) in pending) {
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes);
    }

    // 资源还原（新 id 防冲突）。
    final resourceIdMap = <String, String>{};
    final resourcesJson = readJson('resources.json');
    final list = resourcesJson['resources'] as List? ?? <Object?>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final Object? raw in list) {
      if (raw is! Map) continue;
      final map = raw.cast<String, Object?>();
      final newId = 'imported-${map['id']}';
      resourceIdMap[map['id'] as String? ?? ''] = newId;
      await db
          .into(db.resources)
          .insertOnConflictUpdate(
            ResourcesCompanion.insert(
              id: newId,
              type: map['type'] as String? ?? 'props',
              name: map['name'] as String? ?? '导入资源',
              fieldsJson: Value(
                jsonEncode(map['fields'] ?? <String, Object?>{}),
              ),
              coverImage: Value(map['cover'] as String?),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    // 布光方案还原。
    final lightingJson = readJson('lighting.json');
    final sceneIdMap = <String, String>{};
    for (final Object? raw in lightingJson['scenes'] as List? ?? <Object?>[]) {
      if (raw is! Map) continue;
      final map = raw.cast<String, Object?>();
      final newId = 'imported-${map['id']}';
      sceneIdMap[map['id'] as String? ?? ''] = newId;
      await db
          .into(db.lightingScenes)
          .insertOnConflictUpdate(
            LightingScenesCompanion.insert(
              id: newId,
              name: map['name'] as String? ?? '导入布光方案',
              sceneJson: jsonEncode(map['scene'] ?? <String, Object?>{}),
              linkedPoseId: const Value(null),
              updatedAt: now,
            ),
          );
    }

    // 姿势还原。
    final posesJson = readJson('poses.json');
    for (final Object? raw in posesJson['poses'] as List? ?? <Object?>[]) {
      if (raw is! Map) continue;
      final map = raw.cast<String, Object?>();
      await db
          .into(db.poses)
          .insertOnConflictUpdate(
            PosesCompanion.insert(
              id: 'imported-${map['id']}',
              name: map['name'] as String? ?? '导入姿势',
              category: map['category'] as String? ?? '站姿',
              difficulty: Value(map['difficulty'] as String? ?? '进阶'),
              jointsJson: jsonEncode(map['joints'] ?? <String, Object?>{}),
              tip: Value(map['tip'] as String? ?? ''),
              lensAdvice: Value(map['lens'] as String? ?? ''),
              builtin: const Value(false),
              favorite: const Value(true),
            ),
          );
    }

    // 策划案还原（重映射引用）。
    final planJson = readJson('plan.json');
    final modules = (planJson['modules'] as List? ?? <Object?>[])
        .whereType<Map>()
        .map((Map m) => PlanModuleData.fromJson(m.cast<String, Object?>()))
        .toList();
    for (final PlanModuleData module in modules) {
      final ids = (module.data['ids'] as List? ?? <Object?>[]).cast<String>();
      if (ids.isNotEmpty) {
        module.data['ids'] = ids
            .map((String id) => resourceIdMap[id] ?? id)
            .toList();
      }
      if (module.type == PlanModuleType.lighting) {
        final sceneId = module.data['sceneId'] as String? ?? '';
        module.data['sceneId'] = sceneIdMap[sceneId] ?? sceneId;
      }
    }
    final nextId = DateTime.now().microsecondsSinceEpoch;
    final planId = 'imported-$nextId';
    await db
        .into(db.plans)
        .insertOnConflictUpdate(
          PlansCompanion.insert(
            id: planId,
            title: '${planJson['title'] ?? '导入策划案'}（导入）',
            status: Value(planJson['status'] as String? ?? 'draft'),
            modulesJson: Value(
              jsonEncode(
                modules.map((PlanModuleData m) => m.toJson()).toList(),
              ),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (
      planId: planId,
      title: planJson['title'] as String? ?? '导入策划案',
      moduleCount: modules.length,
      migratedFrom: migratedFrom,
    );
  }
}
