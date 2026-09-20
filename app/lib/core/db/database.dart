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
    Resources,
    ResourceImages,
    Films,
    FilmFrames,
    Poses,
    LightingScenes,
    GearItems,
    Plans,
    PlanSnapshots,
    ProviderConfigs,
    CallLogs,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.e);

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // 版本升级时的迁移入口；保持所有历史表不丢数据
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );

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
