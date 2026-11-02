import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../lighting/lighting_models.dart';
import '../planner/planner_models.dart';
import '../projects/project_controller.dart';

class FieldTask {
  const FieldTask({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  final bool done;

  FieldTask copyWith({bool? done}) =>
      FieldTask(id: id, title: title, done: done ?? this.done);

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'done': done,
  };

  static FieldTask? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final String id = '${raw['id'] ?? ''}'.trim();
    final String title = '${raw['title'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) return null;
    return FieldTask(id: id, title: title, done: raw['done'] == true);
  }
}

class FieldState {
  const FieldState({
    this.loaded = false,
    this.plans = const <Plan>[],
    this.selectedPlanId = '',
    this.modules = const <PlanModuleData>[],
    this.lightingById = const <String, LightingSceneData>{},
    this.tasks = const <FieldTask>[],
    this.notes = '',
    this.status = '',
  });

  final bool loaded;
  final List<Plan> plans;
  final String selectedPlanId;
  final List<PlanModuleData> modules;

  /// 策划模块关联的布光场景，键为 sceneId。
  final Map<String, LightingSceneData> lightingById;
  final List<FieldTask> tasks;
  final String notes;
  final String status;

  Plan? get selectedPlan {
    for (final Plan plan in plans) {
      if (plan.id == selectedPlanId) return plan;
    }
    return null;
  }

  int get doneCount => tasks.where((FieldTask task) => task.done).length;

  FieldState copyWith({
    bool? loaded,
    List<Plan>? plans,
    String? selectedPlanId,
    List<PlanModuleData>? modules,
    Map<String, LightingSceneData>? lightingById,
    List<FieldTask>? tasks,
    String? notes,
    String? status,
  }) {
    return FieldState(
      loaded: loaded ?? this.loaded,
      plans: plans ?? this.plans,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      modules: modules ?? this.modules,
      lightingById: lightingById ?? this.lightingById,
      tasks: tasks ?? this.tasks,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

final fieldControllerProvider = NotifierProvider<FieldController, FieldState>(
  FieldController.new,
);

class FieldController extends Notifier<FieldState> {
  static const Uuid _uuid = Uuid();
  late final AppDatabase _db = ref.read(databaseProvider);
  late String _projectId;
  bool _loading = false;
  bool _disposed = false;

  @override
  FieldState build() {
    _projectId = ref.watch(currentProjectIdProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const FieldState();
  }

  Future<void> init() async {
    if (_loading || _disposed) return;
    _loading = true;
    try {
      final String projectId = _projectId;
      final List<Plan> plans =
          await (_db.select(_db.plans)
                ..where((t) => t.projectId.equals(projectId))
                ..orderBy(<OrderClauseGenerator<$PlansTable>>[
                  (t) => OrderingTerm(
                    expression: t.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();
      if (_disposed || projectId != _projectId) return;
      if (plans.isEmpty) {
        state = const FieldState(loaded: true);
        return;
      }
      final String selected =
          plans.any((Plan plan) => plan.id == state.selectedPlanId)
          ? state.selectedPlanId
          : plans.first.id;
      state = state.copyWith(
        plans: plans,
        selectedPlanId: selected,
        loaded: true,
      );
      await _loadSelectedPlan();
    } finally {
      _loading = false;
    }
  }

  Future<void> selectPlan(String planId) async {
    if (!state.plans.any((Plan plan) => plan.id == planId)) return;
    state = state.copyWith(selectedPlanId: planId);
    await _loadSelectedPlan();
  }

  Future<void> _loadSelectedPlan() async {
    final Plan? plan = state.selectedPlan;
    if (plan == null) return;
    final String projectId = _projectId;
    final ShootFieldState? saved =
        await (_db.select(_db.shootFieldStates)..where(
              (t) => t.projectId.equals(projectId) & t.planId.equals(plan.id),
            ))
            .getSingleOrNull();
    if (_disposed ||
        projectId != _projectId ||
        state.selectedPlanId != plan.id) {
      return;
    }
    final List<PlanModuleData> modules = _decodeModules(plan.modulesJson);
    final Map<String, LightingSceneData> lightingById =
        await _loadLightingScenes(modules, projectId);
    if (_disposed ||
        projectId != _projectId ||
        state.selectedPlanId != plan.id) {
      return;
    }
    final List<FieldTask> defaults = _defaultTasks(plan);
    final List<FieldTask> stored = _decodeTasks(saved?.checklistJson ?? '[]');
    state = state.copyWith(
      modules: modules,
      lightingById: lightingById,
      tasks: _mergeTasks(defaults, stored),
      notes: saved?.notes ?? '',
      status: '',
    );
  }

  /// 从布光页返回现场页后刷新已关联场景。
  Future<void> refreshSelectedPlan() => _loadSelectedPlan();

  Future<Map<String, LightingSceneData>> _loadLightingScenes(
    List<PlanModuleData> modules,
    String projectId,
  ) async {
    final Set<String> sceneIds = <String>{
      for (final PlanModuleData module in modules)
        if (module.type == PlanModuleType.lighting)
          if ('${module.data['sceneId'] ?? ''}'.trim().isNotEmpty)
            '${module.data['sceneId']}'.trim(),
    };
    if (sceneIds.isEmpty) return const <String, LightingSceneData>{};
    try {
      final List<LightingScene> rows = await (_db.select(
        _db.lightingScenes,
      )..where((t) => t.projectId.equals(projectId))).get();
      final Map<String, LightingSceneData> scenes =
          <String, LightingSceneData>{};
      for (final LightingScene row in rows) {
        if (!sceneIds.contains(row.id)) continue;
        try {
          final Object? decoded = jsonDecode(row.sceneJson);
          if (decoded is Map) {
            scenes[row.id] = LightingSceneData.fromJson(decoded.cast());
          }
        } catch (_) {
          // 损坏场景不阻断现场清单与备注。
        }
      }
      return scenes;
    } catch (_) {
      return const <String, LightingSceneData>{};
    }
  }

  List<PlanModuleData> _decodeModules(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <PlanModuleData>[];
      return decoded
          .whereType<Map>()
          .map((Map item) => PlanModuleData.fromJson(item.cast()))
          .toList();
    } catch (_) {
      return const <PlanModuleData>[];
    }
  }

  List<FieldTask> _decodeTasks(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <FieldTask>[];
      return decoded.map(FieldTask.fromJson).whereType<FieldTask>().toList();
    } catch (_) {
      return const <FieldTask>[];
    }
  }

  List<FieldTask> _defaultTasks(Plan plan) {
    final List<FieldTask> tasks = <FieldTask>[];
    for (final PlanModuleData module in _decodeModules(plan.modulesJson)) {
      if (const <PlanModuleType>{
        PlanModuleType.model,
        PlanModuleType.location,
        PlanModuleType.lighting,
        PlanModuleType.poses,
        PlanModuleType.storyboard,
        PlanModuleType.clothing,
        PlanModuleType.props,
        PlanModuleType.makeup,
        PlanModuleType.crew,
      }.contains(module.type)) {
        tasks.add(
          FieldTask(id: 'module:${module.id}', title: '核对并完成：${module.title}'),
        );
      }
    }
    tasks.addAll(const <FieldTask>[
      FieldTask(id: 'field:adjustments', title: '记录现场调整并与团队确认'),
      FieldTask(id: 'field:backup', title: '素材双备份并核对文件完整性'),
    ]);
    return tasks;
  }

  List<FieldTask> _mergeTasks(
    List<FieldTask> defaults,
    List<FieldTask> stored,
  ) {
    final Map<String, FieldTask> storedById = <String, FieldTask>{
      for (final FieldTask task in stored) task.id: task,
    };
    final Set<String> defaultIds = defaults.map((FieldTask t) => t.id).toSet();
    return <FieldTask>[
      for (final FieldTask task in defaults) storedById[task.id] ?? task,
      for (final FieldTask task in stored)
        if (!defaultIds.contains(task.id)) task,
    ];
  }

  Future<void> toggleTask(String taskId) async {
    state = state.copyWith(
      tasks: <FieldTask>[
        for (final FieldTask task in state.tasks)
          if (task.id == taskId) task.copyWith(done: !task.done) else task,
      ],
    );
    await _persist('清单已保存');
  }

  Future<void> addTask(String rawTitle) async {
    final String title = rawTitle.trim();
    if (title.isEmpty || state.selectedPlan == null) return;
    state = state.copyWith(
      tasks: <FieldTask>[
        ...state.tasks,
        FieldTask(id: 'custom:${_uuid.v4()}', title: title),
      ],
    );
    await _persist('已添加现场事项');
  }

  void setNotes(String value) {
    state = state.copyWith(notes: value);
  }

  Future<void> saveNotes() => _persist('现场备注已保存');

  Future<void> _persist(String message) async {
    final Plan? plan = state.selectedPlan;
    if (plan == null) return;
    try {
      await _db
          .into(_db.shootFieldStates)
          .insertOnConflictUpdate(
            ShootFieldStatesCompanion.insert(
              projectId: _projectId,
              planId: plan.id,
              checklistJson: Value(
                jsonEncode(
                  state.tasks.map((FieldTask task) => task.toJson()).toList(),
                ),
              ),
              notes: Value(state.notes),
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      state = state.copyWith(status: message);
    } catch (_) {
      state = state.copyWith(status: '保存失败，请重试');
    }
  }
}
