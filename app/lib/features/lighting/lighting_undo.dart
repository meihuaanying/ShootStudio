import 'lighting_models.dart';

/// V8/D152 · S6：布光场景的撤销/重做（契约要求 ≥20 步；这里给 64 步余量）。
///
/// 设计要点：
///   1. 快照 = `LightingSceneData.copy()` 深拷贝（灯/道具/机位全含），所以撤销后
///      引擎 `applyScene` 能按 id 增量 reconcile 回原状，不需要额外序列化。
///   2. 拖拽类操作按「同标签 + 合并窗口」折叠成一步（拖 60 帧只占 1 步），
///      窗口由调用方用 `beginInteraction`/`endInteraction` 精确圈定（滑杆则靠窗口兜底）。
///   3. 纯逻辑无 Flutter 依赖（可单测），时间源可注入（测试里用假时钟）。
/// 一次可撤销的快照。
class LightingSnapshot {
  LightingSnapshot({
    required this.scene,
    required this.selectedId,
    required this.label,
  });

  /// 从当前场景取一份深拷贝快照。
  factory LightingSnapshot.of(
    LightingSceneData scene,
    String? selectedId,
    String label,
  ) {
    return LightingSnapshot(
      scene: scene.copy(),
      selectedId: selectedId,
      label: label,
    );
  }

  final LightingSceneData scene;
  final String? selectedId;

  /// 人读标签（状态栏提示「已撤销：移动 主灯」）。
  final String label;
}

/// 撤销栈：容量 [capacity]，同标签在 [mergeWindowMs] 内合并。
class LightingUndoStack {
  LightingUndoStack({
    this.capacity = 64,
    this.mergeWindowMs = 600,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// 契约要求 ≥20 步；留到 64 步避免长会话丢失。
  final int capacity;

  /// 合并窗口：拖拽/滑杆连续变更折叠为一步。
  final int mergeWindowMs;

  final DateTime Function() _clock;

  final List<LightingSnapshot> _undo = <LightingSnapshot>[];
  final List<LightingSnapshot> _redo = <LightingSnapshot>[];
  String? _lastLabel;
  int? _lastAtMs;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoCount => _undo.length;
  int get redoCount => _redo.length;

  /// 最近一步可撤销/重做的标签（无则 null）。
  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;
  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;

  /// 记录一步「变更前」的状态。
  ///
  /// [merge] 为 true 时（拖拽 / 滑杆等连续变更）同标签在合并窗口内折叠为一步；
  /// 为 false 时（加灯、删道具、应用预设等离散点击）每步独立成一条，
  /// 否则连点 24 次会被折成 1 步，达不到契约要求的 ≥20 步。
  void record(LightingSnapshot before, {bool merge = true}) {
    final int now = _clock().millisecondsSinceEpoch;
    final bool fold =
        merge &&
        _lastLabel == before.label &&
        _lastAtMs != null &&
        now - _lastAtMs! <= mergeWindowMs &&
        _undo.isNotEmpty;
    if (fold) {
      // 保留更早的基准（拖拽起点），只刷新时间窗。
      _lastAtMs = now;
    } else {
      _undo.add(before);
      while (_undo.length > capacity) {
        _undo.removeAt(0);
      }
      _lastLabel = before.label;
      _lastAtMs = now;
    }
    _redo.clear();
  }

  /// 撤销：返回上一个快照（无则 null）；[current] 压入重做栈。
  LightingSnapshot? undo(LightingSnapshot current) {
    if (_undo.isEmpty) return null;
    _redo.add(current);
    final LightingSnapshot next = _undo.removeLast();
    _lastLabel = _undo.isEmpty ? null : _undo.last.label;
    _lastAtMs = null;
    return next;
  }

  /// 重做：返回下一个快照（无则 null）；[current] 压回撤销栈。
  LightingSnapshot? redo(LightingSnapshot current) {
    if (_redo.isEmpty) return null;
    _undo.add(current);
    final LightingSnapshot next = _redo.removeLast();
    _lastLabel = next.label;
    _lastAtMs = _clock().millisecondsSinceEpoch;
    return next;
  }

  /// 清空（例如打开另一个方案）。
  void clear() {
    _undo.clear();
    _redo.clear();
    _lastLabel = null;
    _lastAtMs = null;
  }
}
