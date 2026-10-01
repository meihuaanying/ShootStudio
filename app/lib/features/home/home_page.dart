import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import '../ai/ai_controller.dart';
import '../ai/plan_read_view.dart';
import '../planner/planner_controller.dart';
import '../shell/app_shell.dart';
import 'home_hero.dart';
import 'home_recent.dart';

/// 灵感卡片（极简首屏：默认收起，「换一批灵感」展开）。
const List<({String title, String prompt})> kHomeInspirations =
    <({String title, String prompt})>[
      (title: '雨夜赛博', prompt: '雨夜赛博朋克风正片，霓虹与湿地反光，冷主光加品红点缀'),
      (title: '汉服晨雾', prompt: '汉服园林晨雾，柔光与衣料质感，轻叙事'),
      (title: '棚拍情绪', prompt: '棚拍情绪人像，伦勃朗光与低饱和色调'),
      (title: 'JK 放学后', prompt: '双人校园 JK，放学后教室与天台，自然光生活化抓拍'),
      (title: '婚纱旅拍', prompt: '婚纱旅拍，海边黄金时刻，仪式感叙事'),
      (title: '商拍产品人像', prompt: '商拍人像，品牌概念片，干净留白与统一色温'),
    ];

/// 策划案 tab 下标（`shellTabProvider` 语义固定，见 shell_nav.dart）。
const int kShellTabPlanner = 5;

/// F1 开案页（S4 画册风重构）：衬线大标题首屏 + 灵感条 + 最近策划案。
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
        kHomeInspirations.length,
        (int i) =>
            kHomeInspirations[(_inspirationStart + i) %
                kHomeInspirations.length],
      );

  Future<void> _generate() async {
    final String theme = _theme.text.trim();
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
      // D155：被取消的草稿只是占位，不可写入画布（阅读视图里按钮已是灰的，这里兜底）。
      if (draft.cancelled) {
        ssToast(context, '本次生成已被取消，请调整描述后重试');
        return;
      }
      if (action == 'accept') {
        await ref
            .read(plannerControllerProvider.notifier)
            .createFromDraft(
              title: theme.length > 18 ? '${theme.substring(0, 18)}…' : theme,
              modules: draft.modules,
            );
        ref.read(shellTabProvider.notifier).state = kShellTabPlanner;
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
    final AppPalette p = context.palette;
    final AiState ai = ref.watch(aiControllerProvider);
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
          const SizedBox(height: AppSpace.s5),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  HomeIdeaHero(
                    controller: _theme,
                    generating: _generating,
                    onGenerate: _generate,
                    trailing: Text(
                      'SS · V8',
                      style: appMono(
                        p.muted,
                        size: AppType.caption.size,
                      ).copyWith(letterSpacing: 1.5),
                    ),
                  ),
                  if (_generating) ...<Widget>[
                    const SizedBox(height: AppSpace.s3),
                    const SsShimmer(label: '正在生成：推理策划思路 → 结构化输出 → 品质自检…'),
                    const SizedBox(height: AppSpace.s2),
                    HomeLiveReasoning(
                      attempt: ai.attempts.isEmpty ? '' : ai.attempts.last,
                      text: ai.reasoningText,
                    ),
                  ],
                  if (_showInspiration) ...<Widget>[
                    const SizedBox(height: AppSpace.s5),
                    const SsSectionTitle('灵感样片', subtitle: '点击回填到上方输入框'),
                    const SizedBox(height: AppSpace.s3),
                    HomeInspirationStrip(
                      items: _sliced,
                      onPick: (({String title, String prompt}) item) =>
                          _theme.text = item.prompt,
                    ),
                  ],
                  const SizedBox(height: AppSpace.s6),
                  const SsSectionTitle('最近的策划案'),
                  const SizedBox(height: AppSpace.s3),
                  HomeRecentPlans(
                    onOpen: (Plan plan) async {
                      await ref
                          .read(plannerControllerProvider.notifier)
                          .openPlan(plan);
                      ref.read(shellTabProvider.notifier).state =
                          kShellTabPlanner;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s6),
        ],
      ),
    );
  }
}
