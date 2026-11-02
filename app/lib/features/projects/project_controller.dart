import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

/// 当前工作上下文。默认项目由数据库 v2 初始化保证存在。
final currentProjectIdProvider = StateProvider<String>(
  (ref) => AppDatabase.legacyProjectId,
);

final projectsProvider =
    AsyncNotifierProvider<ProjectsController, List<ShootProject>>(
      ProjectsController.new,
    );

class ProjectsController extends AsyncNotifier<List<ShootProject>> {
  static const Uuid _uuid = Uuid();
  late final AppDatabase _db = ref.read(databaseProvider);

  @override
  Future<List<ShootProject>> build() async {
    final List<ShootProject> projects = await _sortedProjects();
    final String saved =
        await _db.getSetting(AppDatabase.currentProjectSetting) ??
        AppDatabase.legacyProjectId;
    final String current = projects.any((ShootProject p) => p.id == saved)
        ? saved
        : AppDatabase.legacyProjectId;
    if (ref.read(currentProjectIdProvider) != current) {
      ref.read(currentProjectIdProvider.notifier).state = current;
    }
    return projects;
  }

  Future<List<ShootProject>> _sortedProjects() {
    return (_db.select(_db.shootProjects)
          ..orderBy(<OrderClauseGenerator<$ShootProjectsTable>>[
            (p) =>
                OrderingTerm(expression: p.updatedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<ShootProject> createProject(String rawName) async {
    final String name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(rawName, 'rawName', '项目名称不能为空');
    }
    final int now = DateTime.now().millisecondsSinceEpoch;
    final ShootProjectsCompanion entry = ShootProjectsCompanion.insert(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.shootProjects).insert(entry);
    final List<ShootProject> projects = await _sortedProjects();
    state = AsyncData<List<ShootProject>>(projects);
    final ShootProject created = projects.firstWhere(
      (ShootProject p) => p.id == entry.id.value,
    );
    await switchProject(created.id);
    return created;
  }

  Future<void> switchProject(String projectId) async {
    final ShootProject? project = await (_db.select(
      _db.shootProjects,
    )..where((p) => p.id.equals(projectId))).getSingleOrNull();
    if (project == null) {
      throw StateError('拍摄项目不存在：$projectId');
    }
    await _db.setSetting(AppDatabase.currentProjectSetting, projectId);
    ref.read(currentProjectIdProvider.notifier).state = projectId;
  }
}
