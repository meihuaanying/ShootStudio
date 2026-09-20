import 'dart:convert';

import 'planner_models.dart';

/// 模块级变更（D17：新增/删除/内容变更高亮）。
class ModuleChange {
  const ModuleChange({
    required this.before,
    required this.after,
    required this.changedKeys,
  });

  final PlanModuleData before;
  final PlanModuleData after;
  final List<String> changedKeys;
}

/// 两份模块列表的差异。
class PlanDiff {
  const PlanDiff({
    required this.added,
    required this.removed,
    required this.changed,
    required this.unchanged,
  });

  final List<PlanModuleData> added;
  final List<PlanModuleData> removed;
  final List<ModuleChange> changed;
  final int unchanged;

  int get totalChanges => added.length + removed.length + changed.length;
  bool get isEmpty => totalChanges == 0;
}

/// 计算 base（历史版本）→ current（当前）的模块级差异。
PlanDiff diffPlans(List<PlanModuleData> base, List<PlanModuleData> current) {
  final baseById = <String, PlanModuleData>{
    for (final PlanModuleData m in base) m.id: m,
  };
  final currentById = <String, PlanModuleData>{
    for (final PlanModuleData m in current) m.id: m,
  };

  final added = current
      .where((PlanModuleData m) => !baseById.containsKey(m.id))
      .toList();
  final removed = base
      .where((PlanModuleData m) => !currentById.containsKey(m.id))
      .toList();

  final changed = <ModuleChange>[];
  var unchanged = 0;
  for (final PlanModuleData before in base) {
    final after = currentById[before.id];
    if (after == null) continue;
    final keys = <String>[];
    if (before.title != after.title) keys.add('标题');
    final beforeData = jsonEncode(_normalize(before.data));
    final afterData = jsonEncode(_normalize(after.data));
    if (beforeData != afterData) {
      final union = <String>{...before.data.keys, ...after.data.keys};
      for (final String key in union) {
        final b = jsonEncode(before.data[key]);
        final a = jsonEncode(after.data[key]);
        if (b != a) keys.add(_label(key));
      }
      if (keys.isEmpty) keys.add('内容');
    }
    if (keys.isEmpty) {
      unchanged++;
    } else {
      changed.add(
        ModuleChange(before: before, after: after, changedKeys: keys),
      );
    }
  }
  return PlanDiff(
    added: added,
    removed: removed,
    changed: changed,
    unchanged: unchanged,
  );
}

/// 归一化（忽略折叠状态等展示字段）。
Map<String, Object?> _normalize(Map<String, Object?> data) {
  final copy = Map<String, Object?>.of(data)
    ..remove('folded')
    ..remove('placeholder');
  return copy;
}

String _label(String key) => switch (key) {
  'text' => '文本',
  'ids' => '绑定资源',
  'refs' => '样片',
  'poses' => '姿势',
  'colors' => '色卡',
  'rows' => '表格行',
  'sceneId' => '布光方案',
  'sceneName' => '布光方案名',
  'note' => '备注',
  _ => key,
};
