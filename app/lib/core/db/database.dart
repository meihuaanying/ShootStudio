import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../workspace/workspace.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ShootProjects,
    Resources,
    ResourceImages,
    Films,
    FilmFrames,
    ProjectReferences,
    Poses,
    ProjectPoses,
    LightingScenes,
    GearItems,
    Plans,
    ShootFieldStates,
    PlanSnapshots,
    ProviderConfigs,
    CallLogs,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.e);

  static const String legacyProjectId = 'project-default';
  static const String currentProjectSetting = 'current_project_id';

  static AppDatabase? _instance;
  static AppDatabase get I => _instance ??= throw StateError('数据库未初始化');

  /// 测试专用：注入自定义执行器（如 NativeDatabase.memory()）。
  static AppDatabase forTesting(QueryExecutor executor) =>
      AppDatabase._(executor);

  /// 在 Workspace.init() 之后调用（D2 本地优先）
  static Future<AppDatabase> init() async {
    if (_instance != null) return _instance!;
    final ws = Workspace.I;
    // 测试守卫（F16）：flutter_test 的 FakeAsync 与 drift 后台 isolate 会死锁，
    // 测试环境改用前台内存库；测试通过 bootstrapPathOverrideProvider 注入临时工作区。
    final bool isTestEnv =
        !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';
    _instance = isTestEnv
        ? AppDatabase._(NativeDatabase.memory())
        : AppDatabase._(
            driftDatabase(
              name: 'database',
              native: DriftNativeOptions(databasePath: () async => ws.dbPath),
            ),
          );
    await _instance!.customSelect('SELECT 1').getSingle(); // 触发建库
    return _instance!;
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(shootProjects);
        await m.createTable(projectReferences);
        await m.createTable(projectPoses);
        await m.addColumn(plans, plans.projectId);
        await m.addColumn(lightingScenes, lightingScenes.projectId);
      }
      if (from < 3) {
        await m.createTable(shootFieldStates);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await _initializeProjects();
    },
  );

  /// 所有旧数据只回填一次；可复用素材本身仍保持全局。
  Future<void> _initializeProjects() async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await into(shootProjects).insert(
      ShootProjectsCompanion.insert(
        id: legacyProjectId,
        name: '默认拍摄项目',
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await customStatement(
      'UPDATE plans SET project_id = ? WHERE project_id IS NULL',
      <Object?>[legacyProjectId],
    );
    await customStatement(
      'UPDATE lighting_scenes SET project_id = ? WHERE project_id IS NULL',
      <Object?>[legacyProjectId],
    );
    if (await getSetting('project_refs_migrated') != '1') {
      await customStatement(
        'INSERT OR IGNORE INTO project_references (project_id, frame_id, added_at) '
        'SELECT ?, id, ? FROM film_frames WHERE in_board = 1',
        <Object?>[legacyProjectId, now],
      );
      await customStatement(
        'UPDATE film_frames SET in_board = 0 WHERE in_board = 1',
      );
      await setSetting('project_refs_migrated', '1');
    }
    final String? legacyOrder = await getSetting('refs_board_order');
    final String projectOrderKey = 'refs_board_order:$legacyProjectId';
    if (legacyOrder != null && await getSetting(projectOrderKey) == null) {
      await setSetting(projectOrderKey, legacyOrder);
    }
    final String? current = await getSetting(currentProjectSetting);
    final ShootProject? existing = current == null
        ? null
        : await (select(
            shootProjects,
          )..where((p) => p.id.equals(current))).getSingleOrNull();
    if (existing == null) {
      await setSetting(currentProjectSetting, legacyProjectId);
    }
  }

  // ---------- 通用读写 ----------
  Future<String?> getSetting(String key) async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(
      settings,
    ).insertOnConflictUpdate(Setting(key: key, value: value));
  }
}
