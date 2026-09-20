import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../services/content_packs.dart';
import 'planner_models.dart';

/// 策划编辑器状态。
class PlannerState {
  const PlannerState({
    this.planId = '',
    this.title = '未命名策划案',
    this.status = PlanDocStatus.draft,
    this.modules = const <PlanModuleData>[],
    this.loaded = false,
    this.dirty = false,
    this.statusText = '',
    this.snapshots = const <PlanSnapshotInfo>[],
    this.lastSnapshotKey = '',
  });

  final String planId;
  final String title;
  final PlanDocStatus status;
  final List<PlanModuleData> modules;
  final bool loaded;
  final bool dirty;
  final String statusText;
  final List<PlanSnapshotInfo> snapshots;
  final String lastSnapshotKey;

  int get moduleCount => modules.length;

  PlannerState copyWith({
    String? planId,
    String? title,
    PlanDocStatus? status,
    List<PlanModuleData>? modules,
    bool? loaded,
    bool? dirty,
    String? statusText,
    List<PlanSnapshotInfo>? snapshots,
    String? lastSnapshotKey,
  }) {
    return PlannerState(
      planId: planId ?? this.planId,
      title: title ?? this.title,
      status: status ?? this.status,
      modules: modules ?? this.modules,
      loaded: loaded ?? this.loaded,
      dirty: dirty ?? this.dirty,
      statusText: statusText ?? this.statusText,
      snapshots: snapshots ?? this.snapshots,
      lastSnapshotKey: lastSnapshotKey ?? this.lastSnapshotKey,
    );
  }
}

final plannerControllerProvider =
    NotifierProvider<PlannerController, PlannerState>(PlannerController.new);

class PlannerController extends Notifier<PlannerState> {
  static const Uuid _uuid = Uuid();
  late final AppDatabase _db = ref.read(databaseProvider);
  Timer? _snapshotDebounce;

  @override
  PlannerState build() {
    ref.onDispose(() => _snapshotDebounce?.cancel());
    return const PlannerState();
  }

  Future<void> init() async {
    if (state.loaded) return;
    final rows =
        await (_db.select(_db.plans)
              ..orderBy(<OrderClauseGenerator<$PlansTable>>[
                (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .get();
    if (rows.isNotEmpty) {
      final Plan row = rows.first;
      final modules = _decodeModules(row.modulesJson);
      state = state.copyWith(
        planId: row.id,
        title: row.title,
        status: PlanDocStatus.fromName(row.status),
        modules: modules,
        loaded: true,
        statusText: '已载入「${row.title}」',
      );
      await _reloadSnapshots();
      return;
    }
    state = state.copyWith(
      planId: _uuid.v4(),
      loaded: true,
      modules: <PlanModuleData>[],
      statusText: '空策划案 · 可从模板开始或添加模块',
    );
  }

  List<PlanModuleData> _decodeModules(String raw) {
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((Map m) => PlanModuleData.fromJson(m.cast<String, Object?>()))
          .toList();
    } catch (_) {
      return <PlanModuleData>[];
    }
  }

  /// 新建：从模板注入。
  Future<void> newFromTemplate(TemplateEntry template) async {
    state = state.copyWith(
      planId: _uuid.v4(),
      title: template.name,
      status: PlanDocStatus.draft,
      modules: modulesFromTemplate(template, () => _uuid.v4()),
      dirty: true,
      statusText: '已应用模板：${template.name}',
    );
    await _persist();
    _scheduleSnapshot();
  }

  Future<void> newBlank() async {
    state = state.copyWith(
      planId: _uuid.v4(),
      title: '未命名策划案',
      status: PlanDocStatus.draft,
      modules: <PlanModuleData>[],
      dirty: true,
      statusText: '空策划案 · 从左侧添加模块',
    );
    await _persist();
    _scheduleSnapshot();
  }

  void setTitle(String title) {
    state = state.copyWith(
      title: title.trim().isEmpty ? '未命名策划案' : title.trim(),
      dirty: true,
    );
    _scheduleSnapshot();
  }

  void setStatus(PlanDocStatus status) {
    state = state.copyWith(
      status: status,
      dirty: true,
      statusText: '状态：${status.label}',
    );
    _scheduleSnapshot();
  }

  /// 用开案页草稿创建新策划案并进入编辑态（F1）。
  Future<void> createFromDraft({
    required String title,
    required List<PlanModuleData> modules,
  }) async {
    final copies = modules
        .map(
          (PlanModuleData m) => PlanModuleData(
            id: _uuid.v4(),
            type: m.type,
            title: m.title,
            data: Map<String, Object?>.of(m.data),
          ),
        )
        .toList();
    state = state.copyWith(
      planId: _uuid.v4(),
      title: title.trim().isEmpty ? '未命名策划案' : title.trim(),
      status: PlanDocStatus.draft,
      modules: copies,
      dirty: true,
      statusText: '来自开案页 · 可逐模块微调',
    );
    await _persist();
    await _recordSnapshot(label: '开案初稿');
  }

  /// 从首页/最近列表打开指定策划案（传入 plans 表行）。
  Future<void> openPlan(Plan row) async {
    state = state.copyWith(
      planId: row.id,
      title: row.title,
      status: PlanDocStatus.fromName(row.status),
      modules: _decodeModules(row.modulesJson),
      loaded: true,
      dirty: false,
      statusText: '已打开「${row.title}」',
    );
    await _reloadSnapshots();
  }

  /// 应用 AI 修订（F3）：整体替换模块列表、落库并记录快照。
  Future<void> replaceModules(List<PlanModuleData> modules) async {
    state = state.copyWith(
      modules: modules
          .map((PlanModuleData m) => PlanModuleData.fromJson(m.toJson()))
          .toList(),
      dirty: true,
      statusText: '已应用 AI 修订（${modules.length} 个模块）',
    );
    await _persist();
    await _recordSnapshot(label: 'AI 修订');
  }

  /// 插入 AI 生成的模块（新 id；草稿态由调用方提示）。
  void insertModules(List<PlanModuleData> modules) {
    final copies = modules
        .map(
          (PlanModuleData m) => PlanModuleData(
            id: _uuid.v4(),
            type: m.type,
            title: m.title,
            data: Map<String, Object?>.of(m.data),
          ),
        )
        .toList();
    state = state.copyWith(
      modules: <PlanModuleData>[...state.modules, ...copies],
      dirty: true,
      statusText: '已插入 ${copies.length} 个 AI 模块（草稿态确认）',
    );
    _scheduleSnapshot();
  }

  void insertModule(PlanModuleData module) =>
      insertModules(<PlanModuleData>[module]);

  /// 导入 .sspak 后重新载入最新策划案。
  Future<void> reloadLatest() async {
    state = state.copyWith(loaded: false);
    await init();
  }

  PlanModuleData addModule(PlanModuleType type) {
    final module = PlanModuleData.fromTemplate(<String, Object?>{
      'type': type.name,
      'title': type.label,
      'preset': <String, Object?>{},
    }, _uuid.v4());
    state = state.copyWith(
      modules: <PlanModuleData>[...state.modules, module],
      dirty: true,
      statusText: '已添加模块：${type.label}',
    );
    _scheduleSnapshot();
    return module;
  }

  void removeModule(String id) {
    state = state.copyWith(
      modules: state.modules.where((PlanModuleData m) => m.id != id).toList(),
      dirty: true,
    );
    _scheduleSnapshot();
  }

  void duplicateModule(String id) {
    final index = state.modules.indexWhere((PlanModuleData m) => m.id == id);
    if (index < 0) return;
    final copy = PlanModuleData.fromJson(<String, Object?>{
      ...state.modules[index].toJson(),
      'id': _uuid.v4(),
      'folded': false,
    });
    final modules = <PlanModuleData>[...state.modules]..insert(index + 1, copy);
    state = state.copyWith(modules: modules, dirty: true);
    _scheduleSnapshot();
  }

  void reorder(int oldIndex, int newIndex) {
    final modules = <PlanModuleData>[...state.modules];
    final moved = modules.removeAt(oldIndex);
    modules.insert(newIndex.clamp(0, modules.length), moved);
    state = state.copyWith(modules: modules, dirty: true);
    _scheduleSnapshot();
  }

  void toggleFold(String id) {
    for (final PlanModuleData m in state.modules) {
      if (m.id == id) m.folded = !m.folded;
    }
    state = state.copyWith(modules: <PlanModuleData>[...state.modules]);
  }

  void updateModule(String id, void Function(PlanModuleData m) mutate) {
    for (final PlanModuleData m in state.modules) {
      if (m.id == id) {
        mutate(m);
        break;
      }
    }
    state = state.copyWith(
      modules: <PlanModuleData>[...state.modules],
      dirty: true,
    );
    _scheduleSnapshot();
  }

  /// 编辑停顿 3 秒自动快照（D15）。
  void _scheduleSnapshot() {
    _snapshotDebounce?.cancel();
    _snapshotDebounce = Timer(const Duration(seconds: 3), () {
      _persist().then((_) => _recordSnapshot());
    });
  }

  /// 立即持久化（保存按钮/离开页面）。
  Future<void> saveNow() async {
    _snapshotDebounce?.cancel();
    await _persist();
    await _recordSnapshot();
    state = state.copyWith(dirty: false, statusText: '已保存');
  }

  Future<void> _persist() async {
    await _db
        .into(_db.plans)
        .insertOnConflictUpdate(
          PlansCompanion.insert(
            id: state.planId,
            title: state.title,
            status: Value(state.status.storageName),
            modulesJson: Value(
              jsonEncode(
                state.modules.map((PlanModuleData m) => m.toJson()).toList(),
              ),
            ),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    state = state.copyWith(dirty: false);
  }

  Future<void> _recordSnapshot({String? label}) async {
    final key = jsonEncode(
      state.modules.map((PlanModuleData m) => m.toJson()).toList(),
    );
    await _db
        .into(_db.planSnapshots)
        .insert(
          PlanSnapshotsCompanion.insert(
            id: _uuid.v4(),
            planId: state.planId,
            modulesJson: key,
            label: Value(label),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    state = state.copyWith(lastSnapshotKey: key);
    await _reloadSnapshots();
  }

  /// 手动里程碑命名（D16）。
  Future<void> milestoneNow(String label) async {
    await _persist();
    await _recordSnapshot(label: label.trim().isEmpty ? '里程碑' : label.trim());
    state = state.copyWith(statusText: '已创建里程碑：$_labelOrEmpty');
  }

  String get _labelOrEmpty =>
      state.snapshots.isEmpty ? '' : (state.snapshots.first.label ?? '');

  Future<void> _reloadSnapshots() async {
    final rows =
        await (_db.select(_db.planSnapshots)
              ..where((t) => t.planId.equals(state.planId))
              ..orderBy(<OrderClauseGenerator<$PlanSnapshotsTable>>[
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    final snapshots = rows
        .map(
          (PlanSnapshot row) => PlanSnapshotInfo(
            id: row.id,
            createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
            label: row.label,
            moduleCount: _decodeModules(row.modulesJson).length,
          ),
        )
        .toList();
    state = state.copyWith(snapshots: snapshots);
  }

  /// 读取指定快照的模块列表（版本对比用，D17）。
  Future<List<PlanModuleData>> modulesOfSnapshot(String snapshotId) async {
    final row = await (_db.select(
      _db.planSnapshots,
    )..where((t) => t.id.equals(snapshotId))).getSingleOrNull();
    if (row == null) return const <PlanModuleData>[];
    return _decodeModules(row.modulesJson);
  }

  /// 回滚到快照（回滚也产生新快照，永不丢历史，D17）。
  Future<void> restoreSnapshot(String snapshotId) async {
    final row = await (_db.select(
      _db.planSnapshots,
    )..where((t) => t.id.equals(snapshotId))).getSingleOrNull();
    if (row == null) return;
    await _recordSnapshot(label: '回滚前自动备份');
    final modules = _decodeModules(row.modulesJson);
    state = state.copyWith(
      modules: modules,
      dirty: true,
      statusText: '已回滚到 ${DateTime.fromMillisecondsSinceEpoch(row.createdAt)}',
    );
    await _persist();
    await _recordSnapshot(label: '回滚目标');
  }
}
