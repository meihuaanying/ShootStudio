import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/features/planner/planner_controller.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/features/planner/planner_pending.dart';
import 'package:shoot_studio/features/projects/project_controller.dart';
import 'package:shoot_studio/features/refs/refs_controller.dart';

import '../support/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Workspace workspace;
  late ProviderContainer container;

  setUp(() async {
    await TestEnv.install();
    workspace = await Workspace.initAt(p.join(TestEnv.root.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').getSingle();
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        workspaceProvider.overrideWithValue(workspace),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await TestEnv.dispose();
  });

  List<PlanModuleData> modules(String text) => <PlanModuleData>[
    PlanModuleData(
      id: 'theme-1',
      type: PlanModuleType.theme,
      title: '拍摄主题',
      data: <String, Object?>{'text': text},
    ),
  ];

  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 50; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(condition(), isTrue, reason: '等待项目状态加载超时');
  }

  test('策划案按项目隔离，创建时间保留且自动快照去重', () async {
    final projects = container.read(projectsProvider.notifier);
    await container.read(projectsProvider.future);
    final planner = container.read(plannerControllerProvider.notifier);
    await planner.init();
    await planner.createFromDraft(title: '项目 A 策划', modules: modules('雨夜'));
    final String planA = container.read(plannerControllerProvider).planId;
    final Plan before = await (db.select(
      db.plans,
    )..where((t) => t.id.equals(planA))).getSingle();

    await planner.saveNow();
    await planner.saveNow();
    final Plan after = await (db.select(
      db.plans,
    )..where((t) => t.id.equals(planA))).getSingle();
    final List<PlanSnapshot> snapshots = await (db.select(
      db.planSnapshots,
    )..where((t) => t.planId.equals(planA))).get();
    expect(after.createdAt, before.createdAt);
    expect(snapshots, hasLength(1));

    await projects.createProject('项目 B');
    container.read(plannerControllerProvider);
    await planner.init();
    expect(container.read(plannerControllerProvider).modules, isEmpty);
    await planner.newBlank();
    planner.setTitle('项目 B 策划');
    await planner.saveNow();

    final List<Plan> all = await db.select(db.plans).get();
    expect(all, hasLength(2));
    expect(all.map((Plan row) => row.projectId).toSet(), hasLength(2));
    await projects.switchProject(AppDatabase.legacyProjectId);
    container.read(plannerControllerProvider);
    await planner.init();
    expect(container.read(plannerControllerProvider).title, '项目 A 策划');
  });

  test('损坏策划案进入只读保护，保存不会覆盖原始 JSON', () async {
    const String raw = '{broken';
    await db
        .into(db.plans)
        .insert(
          PlansCompanion.insert(
            id: 'broken-plan',
            projectId: const Value(AppDatabase.legacyProjectId),
            title: '损坏记录',
            modulesJson: const Value(raw),
            createdAt: 1,
            updatedAt: 9999999999999,
          ),
        );
    final planner = container.read(plannerControllerProvider.notifier);
    await planner.init();
    expect(container.read(plannerControllerProvider).readOnly, isTrue);
    await planner.saveNow();
    final Plan row = await (db.select(
      db.plans,
    )..where((t) => t.id.equals('broken-plan'))).getSingle();
    expect(row.modulesJson, raw);
  });

  test('同一参考帧可属于多个项目，移除只影响当前项目', () async {
    final refs = container.read(refsControllerProvider.notifier);
    await refs.init();
    final films = container.read(refsControllerProvider).films;
    expect(films, isNotEmpty);
    final film = films.first;
    expect(film.frames, isNotEmpty);
    final frame = film.frames.first;
    final String frameId = '${film.id}:${frame.name}';
    await refs.toggleBoard(film, frame);

    final projects = container.read(projectsProvider.notifier);
    await projects.createProject('参考项目 B');
    container.read(refsControllerProvider);
    await refs.init();
    expect(container.read(refsControllerProvider).board, isEmpty);
    await refs.toggleBoard(film, frame);
    expect(await db.select(db.projectReferences).get(), hasLength(2));

    final RefFrame current = container
        .read(refsControllerProvider)
        .board
        .firstWhere((RefFrame item) => item.id == frameId);
    await refs.removeBoardItem(current);
    final List<ProjectReference> remaining = await db
        .select(db.projectReferences)
        .get();
    expect(remaining, hasLength(1));
    expect(remaining.single.projectId, AppDatabase.legacyProjectId);
  });

  test('项目姿势清单持久化并随项目切换', () async {
    final pending = container.read(pendingPosesProvider.notifier);
    await pending.add(
      const PendingPose(name: '姿势 A', joints: <String, Object?>{}),
    );
    final projects = container.read(projectsProvider.notifier);
    await projects.createProject('姿势项目 B');
    container.read(pendingPosesProvider);
    await pending.init();
    await waitFor(() => container.read(pendingPosesProvider).isEmpty);
    await pending.add(
      const PendingPose(name: '姿势 B', joints: <String, Object?>{}),
    );

    await projects.switchProject(AppDatabase.legacyProjectId);
    container.read(pendingPosesProvider);
    await pending.init();
    await waitFor(
      () => container
          .read(pendingPosesProvider)
          .any((PendingPose pose) => pose.name == '姿势 A'),
    );
    expect(container.read(pendingPosesProvider).single.name, '姿势 A');
  });

  test('布光场景按项目保存和重新载入', () async {
    final lighting = container.read(lightingControllerProvider.notifier);
    await lighting.init();
    final String sceneA = container.read(lightingControllerProvider).scene.id;
    await lighting.save();

    final projects = container.read(projectsProvider.notifier);
    await projects.createProject('布光项目 B');
    container.read(lightingControllerProvider);
    await lighting.init();
    final String sceneB = container.read(lightingControllerProvider).scene.id;
    expect(sceneB, isNot(sceneA));
    await lighting.save();

    await projects.switchProject(AppDatabase.legacyProjectId);
    container.read(lightingControllerProvider);
    await lighting.init();
    expect(container.read(lightingControllerProvider).scene.id, sceneA);
  });

  test('schema v1 升级保留旧策划、布光和画板', () async {
    final File file = File(p.join(TestEnv.root.path, 'legacy.db'));
    final sqlite.Database raw = sqlite.sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE plans (
        id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft', modules_json TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE lighting_scenes (
        id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
        scene_json TEXT NOT NULL, linked_pose_id TEXT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE film_frames (
        id TEXT NOT NULL PRIMARY KEY, film_id TEXT NOT NULL, name TEXT NOT NULL,
        image_ref TEXT NOT NULL, palette_json TEXT NOT NULL DEFAULT '[]',
        source_url TEXT NOT NULL DEFAULT '', in_board INTEGER NOT NULL DEFAULT 0
      )
    ''');
    raw.execute(
      'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
    );
    raw.execute(
      "INSERT INTO plans VALUES ('old-plan', '旧策划', 'draft', '[]', 10, 20)",
    );
    raw.execute(
      "INSERT INTO lighting_scenes VALUES ('old-scene', '旧布光', '{}', NULL, 20)",
    );
    raw.execute(
      "INSERT INTO film_frames VALUES ('old-frame', 'old-film', '旧帧', '', '[]', '', 1)",
    );
    raw.execute(
      'INSERT INTO settings VALUES (\'refs_board_order\', \'["old-frame"]\')',
    );
    raw.execute('PRAGMA user_version = 1');
    raw.dispose();

    final AppDatabase migrated = AppDatabase.forTesting(NativeDatabase(file));
    await migrated.customSelect('SELECT 1').getSingle();
    final QueryRow fieldTable = await migrated
        .customSelect(
          'SELECT name FROM sqlite_master '
          'WHERE type = \'table\' AND name = \'shoot_field_states\'',
        )
        .getSingle();
    expect(fieldTable.data['name'], 'shoot_field_states');
    final Plan plan = await migrated.select(migrated.plans).getSingle();
    final LightingScene scene = await migrated
        .select(migrated.lightingScenes)
        .getSingle();
    final ProjectReference reference = await migrated
        .select(migrated.projectReferences)
        .getSingle();
    expect(plan.projectId, AppDatabase.legacyProjectId);
    expect(scene.projectId, AppDatabase.legacyProjectId);
    expect(reference.frameId, 'old-frame');
    expect(reference.projectId, AppDatabase.legacyProjectId);
    final FilmFrame frame = await migrated
        .select(migrated.filmFrames)
        .getSingle();
    expect(frame.inBoard, isFalse);
    expect(
      await migrated.getSetting(
        'refs_board_order:${AppDatabase.legacyProjectId}',
      ),
      '["old-frame"]',
    );
    expect(jsonDecode(plan.modulesJson), isEmpty);
    await migrated.close();
  });
}
