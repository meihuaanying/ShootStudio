part of 'lighting_controller.dart';

/// V8/D152 撤销/重做栈。
///
/// 拆成 mixin 而不是 extension：riverpod 的 `Notifier.state` 标了
/// `@protected`，`--fatal-infos` 下 extension 访问会报
/// `invalid_use_of_protected_member`；mixin 位于类的继承链上，访问合法，
/// 且方法仍归属 LightingController，所有调用点与测试零改动。
mixin _LightingUndo on Notifier<LightingState> {

/// V8/D152：撤销/重做栈（64 步；拖拽按交互区间折叠为一步）。
final LightingUndoStack undoStack = LightingUndoStack();

/// 正在进行的连续交互（拖灯/拖机位/滑杆）；非空时不再重复记撤销点。
String? _interactionId;

// ---------------- V8/D152 撤销 / 重做 ----------------

/// 记一步撤销点（在真正修改之前调用）。
///
/// [merge] 语义同 `LightingUndoStack.record`：拖拽/滑杆类连续变更传 true
/// （靠合并窗口折叠成一步）；加灯/删除/应用预设等离散操作传 false（每步独立）。
void _pushUndo(String label, {bool merge = false}) {
  if (_interactionId != null) return;
  undoStack.record(
    LightingSnapshot.of(state.scene, state.selectedId, label),
    merge: merge,
  );
  _syncUndoFlags();
}

void _syncUndoFlags() {
  if (state.canUndo == undoStack.canUndo && !state.canRedo) return;
  state = state.copyWith(canUndo: undoStack.canUndo, canRedo: false);
}

/// 开始一次连续交互（拖拽）：只在起点记一次撤销点。
void beginInteraction(String id) {
  if (_interactionId == id) return;
  final DeviceSpec? d = _deviceOf(id);
  final String label = switch (d?.kind) {
    'light' => '移动灯具 ${d?.name ?? ''}',
    'prop' => '移动道具 ${d?.name ?? ''}',
    _ => id.startsWith('camera') ? '调整机位' : '调整 $id',
  };
  undoStack.record(LightingSnapshot.of(state.scene, state.selectedId, label));
  _interactionId = id;
  _syncUndoFlags();
}

/// 结束连续交互。
void endInteraction() {
  _interactionId = null;
}

DeviceSpec? _deviceOf(String id) {
  for (final DeviceSpec d in state.scene.devices) {
    if (d.id == id) return d;
  }
  return null;
}

/// 撤销一步（返回 true 表示有可撤销内容）。
bool undo() {
  final LightingSnapshot? next = undoStack.undo(_snapshot());
  if (next == null) {
    state = state.copyWith(status: '没有可撤销的操作');
    return false;
  }
  _interactionId = null;
  state = state.copyWith(
    scene: next.scene,
    selectedId: next.selectedId,
    dirty: true,
    undoSeq: state.undoSeq + 1,
    cameraSeq: state.cameraSeq + 1,
    canUndo: undoStack.canUndo,
    canRedo: undoStack.canRedo,
    status: '已撤销：${next.label}',
  );
  return true;
}

/// 重做一步。
bool redo() {
  final LightingSnapshot? next = undoStack.redo(_snapshot());
  if (next == null) {
    state = state.copyWith(status: '没有可重做的操作');
    return false;
  }
  _interactionId = null;
  state = state.copyWith(
    scene: next.scene,
    selectedId: next.selectedId,
    dirty: true,
    undoSeq: state.undoSeq + 1,
    cameraSeq: state.cameraSeq + 1,
    canUndo: undoStack.canUndo,
    canRedo: undoStack.canRedo,
    status: '已重做：${next.label}',
  );
  return true;
}

LightingSnapshot _snapshot() =>
    LightingSnapshot.of(state.scene, state.selectedId, '当前状态');

}
