import '../planner/planner_models.dart';

/// 生成质量评分（F3）：结构合法性（必须 100%）+ 细节完整度 + 引用一致性。
class PlanScore {
  const PlanScore({
    required this.structureOk,
    required this.detailScore,
    required this.consistencyScore,
    required this.shortcomings,
  });

  final bool structureOk;
  final double detailScore;
  final double consistencyScore;
  final List<String> shortcomings;

  /// 总分：结构不合格直接 0；否则细节 60% + 一致性 40%。
  double get total =>
      structureOk ? detailScore * 0.6 + consistencyScore * 0.4 : 0;

  bool get needsRetry => total < 80;
}

/// 评分器：纯函数式，便于单测。
class PlanScorer {
  PlanScorer._();

  static PlanScore score(
    List<PlanModuleData> modules, {
    Set<String> knownResourceIds = const <String>{},
    Set<String> knownSceneIds = const <String>{},
  }) {
    if (modules.isEmpty) {
      return const PlanScore(
        structureOk: false,
        detailScore: 0,
        consistencyScore: 0,
        shortcomings: <String>['模块列表为空'],
      );
    }

    final shortcomings = <String>[];
    var detailPass = 0;

    void detail(bool ok, String moduleTitle, String reason) {
      if (ok) {
        detailPass++;
      } else {
        shortcomings.add('$moduleTitle：$reason');
      }
    }

    for (final PlanModuleData module in modules) {
      final String title =
          module.title.isEmpty ? module.type.label : module.title;
      switch (module.type) {
        case PlanModuleType.theme:
          final String text = module.data['text'] as String? ?? '';
          detail(text.length >= 40, title, '主题描述过短（需含氛围/风格/目标，≥40 字）');
        case PlanModuleType.richText:
          final String text = module.data['text'] as String? ?? '';
          detail(text.trim().isNotEmpty, title, '内容为空');
        case PlanModuleType.model:
        case PlanModuleType.location:
        case PlanModuleType.clothing:
        case PlanModuleType.props:
        case PlanModuleType.makeup:
          final List<String> ids =
              (module.data['ids'] as List? ?? <Object?>[]).cast<String>();
          final String note = module.data['note'] as String? ?? '';
          detail(ids.isNotEmpty || note.length >= 8, title, '未绑定资源且缺少建议说明');
        case PlanModuleType.sun:
          final String place = module.data['place'] as String? ?? '';
          final String date = module.data['date'] as String? ?? '';
          final bool dateOk = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date);
          detail(place.isNotEmpty && dateOk, title, '缺少城市或合法日期');
        case PlanModuleType.refs:
          final int count =
              (module.data['refs'] as List? ?? <Object?>[]).length;
          detail(count >= 1, title, '未插入任何参考样片');
        case PlanModuleType.storyboard:
          final List<Object?> shots =
              module.data['shots'] as List? ?? <Object?>[];
          detail(shots.length >= 8, title, '分镜不足 8 个镜头（需 8–12 镜）');
          final bool fieldsOk = shots.whereType<Map>().every((Map m) =>
              '${m['shotSize'] ?? ''}'.isNotEmpty &&
              '${m['lens'] ?? ''}'.isNotEmpty &&
              '${m['pose'] ?? ''}'.isNotEmpty);
          detail(fieldsOk && shots.isNotEmpty, title, '存在缺少景别/焦段/姿势的分镜');
        case PlanModuleType.palette:
          final int count =
              (module.data['colors'] as List? ?? <Object?>[]).length;
          detail(count >= 3, title, '色卡不足 3 色');
        case PlanModuleType.lighting:
          final String sceneId = module.data['sceneId'] as String? ?? '';
          final String note = module.data['note'] as String? ?? '';
          detail(sceneId.isNotEmpty || note.length >= 10, title,
              '未绑定布光方案且缺少参数化建议');
        case PlanModuleType.poses:
          final List<Object?> poses =
              module.data['poses'] as List? ?? <Object?>[];
          final bool detailed = poses.length >= 3 &&
              poses
                  .whereType<Map>()
                  .every((Map m) => (m['lens'] as String? ?? '').isNotEmpty);
          detail(detailed, title, '姿势不足 3 个或缺少镜头建议');
        case PlanModuleType.crew:
          final List<Map<String, Object?>> rows =
              (module.data['rows'] as List? ?? <Object?>[])
                  .whereType<Map>()
                  .map((Map m) => m.cast<String, Object?>())
                  .toList();
          final bool ok = rows.length >= 2 &&
              rows.every((Map<String, Object?> r) =>
                  (r['role'] as String? ?? '').isNotEmpty &&
                  (r['time'] as String? ?? '').isNotEmpty);
          detail(ok, title, '分工不足 2 条或缺少成员时间');
        case PlanModuleType.budget:
          final List<Map<String, Object?>> rows =
              (module.data['rows'] as List? ?? <Object?>[])
                  .whereType<Map>()
                  .map((Map m) => m.cast<String, Object?>())
                  .toList();
          final double sum = rows.fold(
              0,
              (double a, Map<String, Object?> r) =>
                  a + ((r['price'] as num?)?.toDouble() ?? 0));
          final bool ok = rows.length >= 2 &&
              rows.every((Map<String, Object?> r) =>
                  (r['item'] as String? ?? '').isNotEmpty) &&
              sum > 0;
          detail(ok, title, '预算不足 2 条或金额为 0');
      }
    }
    final double detailScore = detailPass / modules.length * 100;

    // 引用一致性。
    var refTotal = 0;
    var refPass = 0;
    for (final PlanModuleData module in modules) {
      final String title =
          module.title.isEmpty ? module.type.label : module.title;
      switch (module.type) {
        case PlanModuleType.model:
        case PlanModuleType.location:
        case PlanModuleType.clothing:
        case PlanModuleType.props:
        case PlanModuleType.makeup:
          for (final String id
              in (module.data['ids'] as List? ?? <Object?>[]).cast<String>()) {
            refTotal++;
            if (knownResourceIds.contains(id)) {
              refPass++;
            } else {
              shortcomings.add('$title：绑定资源不存在（$id），请重新绑定');
            }
          }
        case PlanModuleType.lighting:
          final String sceneId = module.data['sceneId'] as String? ?? '';
          if (sceneId.isNotEmpty) {
            refTotal++;
            if (knownSceneIds.contains(sceneId)) {
              refPass++;
            } else {
              shortcomings.add('$title：布光方案不存在（$sceneId），请重新绑定');
            }
          }
        default:
          break;
      }
    }
    final double consistencyScore =
        refTotal == 0 ? 100 : refPass / refTotal * 100;

    // 结构合法性：复用模块 Schema 校验（模块 JSON 往返）。
    final List<String> structureErrors = ModuleSchemaValidator.validate(
      modules.map((PlanModuleData m) => m.toJson()).toList(),
    );

    return PlanScore(
      structureOk: structureErrors.isEmpty,
      detailScore: detailScore,
      consistencyScore: consistencyScore,
      shortcomings: <String>[...shortcomings, ...structureErrors],
    );
  }
}
