import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../planner/planner_models.dart';

/// 最近策划案（S4：列表 + 杂志化空态）。
final recentPlansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  final AppDatabase db = ref.watch(databaseProvider);
  final rows =
      await (db.select(db.plans)
            ..orderBy(<OrderClauseGenerator<$PlansTable>>[
              (t) => OrderingTerm(
                expression: t.updatedAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(6))
          .get();
  return rows;
});

/// 读取模块数（modulesJson 解析失败时按 0 计，不抛）。
int homeModuleCount(Plan plan) {
  try {
    final Object? decoded = jsonDecode(plan.modulesJson);
    if (decoded is List) return decoded.length;
  } catch (_) {}
  return 0;
}

class HomeRecentPlans extends ConsumerWidget {
  const HomeRecentPlans({super.key, required this.onOpen});

  final Future<void> Function(Plan plan) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;
    final AsyncValue<List<Plan>> plans = ref.watch(recentPlansProvider);
    return plans.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpace.s4),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (Object e, _) =>
          SsBanner(text: '读取失败：$e', kind: SsBannerKind.danger),
      data: (List<Plan> list) {
        if (list.isEmpty) {
          return SsCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('还没有策划案', style: AppType.h3.style(p.ink)),
                      const SizedBox(height: AppSpace.s1),
                      Text(
                        '在上面输入想法，或从模板库开始。',
                        style: AppType.body.style(p.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (final Plan plan in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s2),
                child: SsCard(
                  onTap: () => onOpen(plan),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              plan.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.h3.style(p.ink),
                            ),
                            const SizedBox(height: AppSpace.s1),
                            Text(
                              '${homeModuleCount(plan)} 个模块 · '
                              '${PlanDocStatus.fromName(plan.status).label}',
                              style: AppType.caption.style(p.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: AppFontSize.h3,
                        color: p.muted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
