import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../ai/ai_controller.dart';
import '../ai/plan_read_view.dart';
import '../planner/planner_controller.dart';
import '../planner/planner_models.dart';
import '../shell/app_shell.dart';

/// 最近策划案（开案页与编辑器共用，创建后失效刷新）。
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

/// 灵感卡片（极简首屏：默认收起，「换一批灵感」展开）。
const List<({String title, String prompt})> _inspirations =
    <({String title, String prompt})>[
      (title: '雨夜赛博', prompt: '雨夜赛博朋克风正片，霓虹与湿地反光，冷主光加品红点缀'),
      (title: '汉服晨雾', prompt: '汉服园林晨雾，柔光与衣料质感，轻叙事'),
      (title: '棚拍情绪', prompt: '棚拍情绪人像，伦勃朗光与低饱和色调'),
      (title: 'JK 放学后', prompt: '双人校园 JK，放学后教室与天台，自然光生活化抓拍'),
      (title: '婚纱旅拍', prompt: '婚纱旅拍，海边黄金时刻，仪式感叙事'),
      (title: '商拍产品人像', prompt: '商拍人像，品牌概念片，干净留白与统一色温'),
    ];

/// F1 开案页：极简首屏（输入框 + 可展开灵感区 + 最近策划案）。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _theme = TextEditingController();
  bool _showInspiration = false;
  int _inspirationStart = 0;
  bool _generating = false;

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  List<({String title, String prompt})> get _sliced =>
      List<({String title, String prompt})>.generate(
        _inspirations.length,
        (int i) =>
            _inspirations[(_inspirationStart + i) % _inspirations.length],
      );

  Future<void> _generate() async {
    final theme = _theme.text.trim();
    if (theme.length < 4) {
      ssToast(context, '先描述一下你的想法（至少 5 个字）');
      return;
    }
    setState(() => _generating = true);
    final AiController controller = ref.read(aiControllerProvider.notifier);
    await controller.init();
    AiDraftResult draft = await controller.generatePlan(theme);
    while (mounted) {
      setState(() => _generating = false);
      if (!mounted) return;
      final String? action = await PlanReadView.show(
        context,
        draft,
        idea: theme,
      );
      if (!mounted) return;
      if (action == 'accept') {
        await ref
            .read(plannerControllerProvider.notifier)
            .createFromDraft(
              title: theme.length > 18 ? '${theme.substring(0, 18)}…' : theme,
              modules: draft.modules,
            );
        ref.read(shellTabProvider.notifier).state = 5; // 策划案页
        ref.invalidate(recentPlansProvider);
        if (mounted) ssToast(context, '已写入画布，开始微调吧');
        return;
      }
      if (action != 'retry') return;
      setState(() => _generating = true);
      draft = await controller.generatePlan(theme);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SsPage(
      title: '开案',
      subtitle: '一句话描述你的想法，三十秒得到可执行的策划案',
      actions: <Widget>[
        SsChip(
          label: _showInspiration ? '收起灵感' : '换一批灵感',
          selected: _showInspiration,
          onTap: () => setState(() {
            _showInspiration = !_showInspiration;
            _inspirationStart++;
          }),
        ),
      ],
      body: ListView(
        children: <Widget>[
          const SizedBox(height: AppTokens.s24),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    '说说你想拍什么',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '例：雨夜赛博朋克风初音正片，霓虹雨夜，未来感；或直接粘贴角色设定。',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _theme,
                          maxLines: 3,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: '输入主题想法（支持中文）…',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.s12),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SsButton(
                          label: _generating ? '生成中…' : '生成策划案',
                          icon: Icons.auto_awesome_rounded,
                          onPressed: _generating ? null : _generate,
                        ),
                      ),
                    ],
                  ),
                  if (_generating) ...<Widget>[
                    const SizedBox(height: AppTokens.s8),
                    const SsShimmer(label: '正在生成：推理策划思路 → 结构化输出 → 品质自检…'),
                    _LiveReasoning(),
                  ],
                  if (_showInspiration) ...<Widget>[
                    const SizedBox(height: AppTokens.s12),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _sliced.length,
                        separatorBuilder: (_, int index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (BuildContext context, int i) {
                          final item = _sliced[i];
                          return SsCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            onTap: () => _theme.text = item.prompt,
                            child: SizedBox(
                              width: 150,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.prompt,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTokens.s24),
                  Row(
                    children: <Widget>[
                      const Expanded(child: SsSectionTitle('最近的策划案')),
                      Text(
                        '数据都在本地工作区',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.s8),
                  _RecentPlans(
                    onOpen: (Plan plan) async {
                      await ref
                          .read(plannerControllerProvider.notifier)
                          .openPlan(plan);
                      ref.read(shellTabProvider.notifier).state = 5;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.s32),
        ],
      ),
    );
  }
}

int _moduleCount(Plan plan) {
  try {
    final Object? decoded = jsonDecode(plan.modulesJson);
    if (decoded is List) return decoded.length;
  } catch (_) {}
  return 0;
}

class _RecentPlans extends ConsumerWidget {
  const _RecentPlans({required this.onOpen});

  final Future<void> Function(Plan plan) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Plan>> plans = ref.watch(recentPlansProvider);
    final ThemeData theme = Theme.of(context);
    return plans.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (Object e, _) =>
          SsBanner(text: '读取失败：$e', kind: SsBannerKind.danger),
      data: (List<Plan> list) {
        if (list.isEmpty) {
          return SsCard(
            padding: const EdgeInsets.all(AppTokens.s16),
            child: Text(
              '还没有策划案 —— 在上面输入想法，或从模板库开始。',
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (final Plan plan in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SsCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_moduleCount(plan)} 个模块 · '
                              '${PlanDocStatus.fromName(plan.status).label}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
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

/// 生成过程实时推理流 + 尝试链（D28/D40）。
class _LiveReasoning extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AiState ai = ref.watch(aiControllerProvider);
    final String attempt = ai.attempts.isEmpty ? '' : ai.attempts.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (attempt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              attempt,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (ai.reasoningText.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTokens.rSm),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                ai.reasoningText,
                style: const TextStyle(fontSize: 12, height: 1.55),
              ),
            ),
          ),
      ],
    );
  }
}
