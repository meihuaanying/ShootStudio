import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/widgets.dart';
import '../planner/planner_models.dart';
import 'ai_controller.dart';
import 'ai_stage.dart';
import 'ai_provider_card.dart';

/// AI 策划助手面板（D8–D11 / PRD 6.6）：生成 / 提供方 / 观测台三视图。
class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({
    super.key,
    required this.onInsertAll,
    required this.onInsertModule,
  });

  final void Function(List<PlanModuleData> modules) onInsertAll;
  final void Function(PlanModuleData module) onInsertModule;

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final TextEditingController _theme = TextEditingController();
  int _tab = 0;
  bool _forceLocal = false;
  String? _selectedProvider;

  static const List<String> _quickCommands = <String>[
    '雨夜赛博朋克风正片，霓虹与湿地反光',
    '汉服园林晨雾，柔光与衣料质感',
    '棚拍情绪人像，伦勃朗光与低饱和色调',
    '双人校园 JK，自然光生活化抓拍',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      ref.read(aiControllerProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final state = ref.watch(aiControllerProvider);
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpace.s5),
      child: SizedBox(
        width: 920,
        height: 660,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s3,
                AppSpaceFine.n10,
                AppSpace.s2,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.auto_awesome_rounded, size: 18, color: p.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'AI 策划助手',
                    style: TextStyle(
                      fontSize: AppFontSize.bodyLg,
                      fontWeight: AppFontWeight.heavy,
                    ),
                  ),
                  const SizedBox(width: 16),
                  for (final (int index, String label) in <(int, String)>[
                    (0, '生成'),
                    (1, '提供方'),
                    (2, '观测台'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpaceFine.n6),
                      child: SsChip(
                        label: label,
                        selected: _tab == index,
                        onTap: () => setState(() => _tab = index),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '本月免费额度使用 $kOfficialMonthlyQuota 次上限 · 已用 ${state.monthlyFreeUsed}',
                    style: TextStyle(
                      fontSize: AppFontSize.tinyLg,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (_tab) {
                0 => _buildGenerate(state),
                1 => _buildProviders(context, state),
                _ => _buildObservatory(state),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 生成（三态：描述 → 生成中 → 阅读成案）----------------
  Widget _buildGenerate(AiState state) {
    final controller = ref.read(aiControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s3,
            AppSpace.s4,
            0,
          ),
          child: AiStageBar(stage: resolveAiStage(state)),
        ),
        const SizedBox(height: AppSpace.s3),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 300,
                child: _buildGenerateControls(context, state, controller),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildGenerateResult(state)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateControls(
    BuildContext context,
    AiState state,
    AiController controller,
  ) {
    final AppPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SsSectionTitle('一句话开案', subtitle: '支持中文，可粘贴角色设定'),
          const SizedBox(height: AppSpace.s2),
          TextField(
            controller: _theme,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '例：雨夜赛博朋克风初音正片，霓虹雨夜，未来感',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String cmd in _quickCommands)
                InkWell(
                  onTap: () => _theme.text = cmd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s2,
                      vertical: AppSpace.s1,
                    ),
                    decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      cmd.length > 14 ? '${cmd.substring(0, 14)}…' : cmd,
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        color: p.accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // D155：输入态收敛为「一句话 + 高级选项折叠」，默认只暴露一句话。
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('ai-advanced'),
              dense: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              collapsedIconColor: p.muted,
              iconColor: p.accent,
              title: Text('高级选项', style: AppType.small.style(p.muted)),
              children: <Widget>[
                SsToggleRow(
                  title: '本地引擎（离线降级）',
                  subtitle: '无 Key / 断网时自动使用；不消耗任何额度',
                  value: _forceLocal,
                  onChanged: (bool v) => setState(() => _forceLocal = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SsButton(
            label: state.generating ? '生成中…' : '生成策划案草稿',
            icon: Icons.bolt_rounded,
            onPressed: state.generating
                ? null
                : () async {
                    if (_theme.text.trim().length < 4) {
                      ssToast(context, '请先输入主题描述（至少 5 个字）');
                      return;
                    }
                    await controller.generatePlan(
                      _theme.text.trim(),
                      forceLocal: _forceLocal,
                    );
                  },
          ),
          const SizedBox(height: 8),
          Text(
            state.status,
            style: TextStyle(
              fontSize: AppFontSize.captionLg,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          const SsBanner(
            text: '生成内容一律进入草稿态，需你确认后才写入策划案；未配置 Key 时自动使用本地规则引擎。',
            kind: SsBannerKind.info,
          ),
        ],
      ),
    );
  }

  /// D155：三态分发。生成中 → 流式 + 可取消；有草稿 → 阅读成案；否则等待生成。
  Widget _buildGenerateResult(AiState state) {
    switch (resolveAiStage(state)) {
      case AiStage.generating:
        return Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: AiGeneratingPanel(state: state),
        );
      case AiStage.reading:
        return Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: AiReadingPanel(
            state: state,
            idea: _theme.text,
            onInsertAll: (List<PlanModuleData> modules) {
              widget.onInsertAll(modules);
              Navigator.pop(context);
            },
            onInsertModule: (PlanModuleData m) {
              widget.onInsertModule(m);
              ssToast(context, '已插入：${m.title}');
            },
          ),
        );
      case AiStage.input:
        return const SsEmpty(
          icon: Icons.auto_awesome_outlined,
          title: '等待生成',
          hint: '输入主题后点击「生成策划案草稿」；也可以直接使用本地引擎离线生成',
        );
    }
  }

  // ---------------- 提供方 ----------------
  Widget _buildProviders(BuildContext context, AiState state) {
    final AppPalette p = context.palette;
    final selectedId = _selectedProvider ?? state.providers.first.preset.id;
    AiProviderView selected = state.providers.first;
    for (final AiProviderView view in state.providers) {
      if (view.preset.id == selectedId) selected = view;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: 300,
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s3),
            children: <Widget>[
              const SsSectionTitle('提供方（13 家预设）', subtitle: '选中填 Key 即用'),
              const SizedBox(height: AppSpace.s2),
              for (final AiProviderView view in state.providers)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s1),
                  child: SsCard(
                    selected: view.preset.id == selectedId,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpaceFine.n10,
                      vertical: AppSpace.s2,
                    ),
                    onTap: () =>
                        setState(() => _selectedProvider = view.preset.id),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: view.hasKey
                                ? p.film
                                : (view.enabled
                                      ? p.gold
                                      : Theme.of(context).colorScheme.outline),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            view.preset.name,
                            style: const TextStyle(fontSize: AppFontSize.small),
                          ),
                        ),
                        if (view.enabled)
                          Text(
                            '已启用',
                            style: TextStyle(
                              fontSize: AppFontSize.microLg,
                              color: p.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: ProviderConfigCard(view: selected)),
      ],
    );
  }

  // ---------------- 观测台 ----------------
  Widget _buildObservatory(AiState state) {
    final summary = ref.read(aiControllerProvider.notifier).logSummary();
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SsSectionTitle(
            '调用观测台',
            subtitle: '提供方 / 模型 / 延迟 / token / 成败（本地记录）',
          ),
          const SizedBox(height: AppSpace.s3),
          Row(
            children: <Widget>[
              _stat(context, '调用次数', '${summary.calls}'),
              _stat(
                context,
                '成功率',
                summary.calls == 0
                    ? '—'
                    : '${(summary.success * 100 / summary.calls).toStringAsFixed(0)}%',
              ),
              _stat(
                context,
                '平均延迟',
                summary.calls == 0
                    ? '—'
                    : '${summary.avgLatency.toStringAsFixed(0)}ms',
              ),
              _stat(context, '输入 tokens', '${summary.tokensIn}'),
              _stat(context, '输出 tokens', '${summary.tokensOut}'),
            ],
          ),
          const SizedBox(height: AppSpace.s3),
          Expanded(
            child: state.logs.isEmpty
                ? const SsEmpty(
                    icon: Icons.monitor_heart_outlined,
                    title: '还没有调用记录',
                  )
                : ListView.builder(
                    itemCount: state.logs.length,
                    itemBuilder: (BuildContext context, int i) {
                      final AppPalette p = context.palette;

                      final log = state.logs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s1),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              log.success
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.error_outline_rounded,
                              size: 14,
                              color: log.success ? p.film : p.danger,
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 130,
                              child: Text(
                                '${log.providerId} · ${log.model}',
                                style: appMono(p.inkSoft),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                '${log.latencyMs}ms',
                                style: appMono(p.inkSoft),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                '↓${log.promptTokens} ↑${log.completionTokens}',
                                style: appMono(p.inkSoft),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                log.error ?? '',
                                style: TextStyle(
                                  fontSize: AppFontSize.tinyLg,
                                  color: p.danger,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final AppPalette p = context.palette;
    return Expanded(
      child: SsCard(
        padding: const EdgeInsets.all(AppSpaceFine.n10),
        margin: const EdgeInsets.only(right: AppSpace.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.caption,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(value, style: appMono(p.inkSoft)),
          ],
        ),
      ),
    );
  }
}

