import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import '../../core/theme/tokens.dart';
import '../planner/planner_models.dart';
import 'ai_controller.dart';

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
    final state = ref.watch(aiControllerProvider);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 920,
        height: 660,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: AppTokens.accent),
                  const SizedBox(width: 8),
                  const Text('AI 策划助手',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 16),
                  for (final (int index, String label) in <(int, String)>[
                    (0, '生成'),
                    (1, '提供方'),
                    (2, '观测台'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
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
                      fontSize: 10.5,
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
                1 => _buildProviders(state),
                _ => _buildObservatory(state),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 生成 ----------------
  Widget _buildGenerate(AiState state) {
    final controller = ref.read(aiControllerProvider.notifier);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(width: 300, child: _buildGenerateControls(state, controller)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildGenerateResult(state)),
      ],
    );
  }

  Widget _buildGenerateControls(AiState state, AiController controller) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SsSectionTitle('一句话开案', subtitle: '支持中文，可粘贴角色设定'),
          const SizedBox(height: AppTokens.s8),
          TextField(
            controller: _theme,
            maxLines: 3,
            decoration:
                const InputDecoration(hintText: '例：雨夜赛博朋克风初音正片，霓虹雨夜，未来感'),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTokens.accentSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      cmd.length > 14 ? '${cmd.substring(0, 14)}…' : cmd,
                      style: const TextStyle(
                          fontSize: 11, color: AppTokens.accent),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SsToggleRow(
            title: '本地引擎（离线降级）',
            subtitle: '无 Key / 断网时自动使用；不消耗任何额度',
            value: _forceLocal,
            onChanged: (bool v) => setState(() => _forceLocal = v),
          ),
          const SizedBox(height: 10),
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
                    await controller.generatePlan(_theme.text.trim(),
                        forceLocal: _forceLocal);
                  },
          ),
          const SizedBox(height: 8),
          Text(
            state.status,
            style: TextStyle(
              fontSize: 11.5,
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

  Widget _buildGenerateResult(AiState state) {
    if (state.generating) {
      return Padding(
        padding: const EdgeInsets.all(AppTokens.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('流式生成中…', style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    state.streamText.isEmpty ? '…' : state.streamText,
                    style: AppTokens.mono(context, size: 11, color: null),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final draft = state.draft;
    if (draft == null) {
      return const SsEmpty(
        icon: Icons.auto_awesome_outlined,
        title: '等待生成',
        hint: '输入主题后点击「生成策划案草稿」；也可以直接使用本地引擎离线生成',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SsBannerLite(
                text: draft.viaLocal
                    ? '来源：${draft.providerName}（离线降级）'
                    : '来源：${draft.providerName} · ${draft.latencyMs}ms · 入 ${draft.tokensIn} / 出 ${draft.tokensOut} tokens',
                success: !draft.viaLocal,
              ),
              const Spacer(),
              SsButton(
                label: '整体插入画布',
                dense: true,
                onPressed: () {
                  widget.onInsertAll(draft.modules);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '生成 ${draft.modules.length} 个模块（草稿态）',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: draft.modules.length,
              itemBuilder: (BuildContext context, int i) {
                final PlanModuleData module = draft.modules[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SsCard(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${module.title} · ${module.type.label}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                module.summary.isEmpty
                                    ? module.type.category
                                    : module.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SsButton(
                          label: '插入',
                          kind: SsButtonKind.ghost,
                          dense: true,
                          onPressed: () {
                            widget.onInsertModule(module);
                            ssToast(context, '已插入：${module.title}');
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 提供方 ----------------
  Widget _buildProviders(AiState state) {
    final selectedId = _selectedProvider ?? state.providers.first.preset.id;
    AiProviderView selected = state.providers.first;
    for (final AiProviderView p in state.providers) {
      if (p.preset.id == selectedId) selected = p;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: 300,
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.s12),
            children: <Widget>[
              const SsSectionTitle('提供方（13 家预设）', subtitle: '选中填 Key 即用'),
              const SizedBox(height: AppTokens.s8),
              for (final AiProviderView p in state.providers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SsCard(
                    selected: p.preset.id == selectedId,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    onTap: () =>
                        setState(() => _selectedProvider = p.preset.id),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.hasKey
                                ? AppTokens.success
                                : (p.enabled
                                    ? AppTokens.warning
                                    : Theme.of(context).colorScheme.outline),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(p.preset.name,
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                        if (p.enabled)
                          const Text('已启用',
                              style: TextStyle(
                                  fontSize: 9.5, color: AppTokens.accent)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _ProviderConfigCard(view: selected)),
      ],
    );
  }

  // ---------------- 观测台 ----------------
  Widget _buildObservatory(AiState state) {
    final summary = ref.read(aiControllerProvider.notifier).logSummary();
    return Padding(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SsSectionTitle('调用观测台',
              subtitle: '提供方 / 模型 / 延迟 / token / 成败（本地记录）'),
          const SizedBox(height: AppTokens.s12),
          Row(
            children: <Widget>[
              _stat('调用次数', '${summary.calls}'),
              _stat(
                  '成功率',
                  summary.calls == 0
                      ? '—'
                      : '${(summary.success * 100 / summary.calls).toStringAsFixed(0)}%'),
              _stat(
                  '平均延迟',
                  summary.calls == 0
                      ? '—'
                      : '${summary.avgLatency.toStringAsFixed(0)}ms'),
              _stat('输入 tokens', '${summary.tokensIn}'),
              _stat('输出 tokens', '${summary.tokensOut}'),
            ],
          ),
          const SizedBox(height: AppTokens.s12),
          Expanded(
            child: state.logs.isEmpty
                ? const SsEmpty(
                    icon: Icons.monitor_heart_outlined, title: '还没有调用记录')
                : ListView.builder(
                    itemCount: state.logs.length,
                    itemBuilder: (BuildContext context, int i) {
                      final log = state.logs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              log.success
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.error_outline_rounded,
                              size: 14,
                              color: log.success
                                  ? AppTokens.success
                                  : AppTokens.danger,
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 130,
                              child: Text(
                                '${log.providerId} · ${log.model}',
                                style: AppTokens.mono(context, size: 10.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text('${log.latencyMs}ms',
                                  style: AppTokens.mono(context, size: 10.5)),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                '↓${log.promptTokens} ↑${log.completionTokens}',
                                style: AppTokens.mono(context, size: 10.5),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                log.error ?? '',
                                style: const TextStyle(
                                    fontSize: 10.5, color: AppTokens.danger),
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

  Widget _stat(String label, String value) {
    return Expanded(
      child: SsCard(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(value, style: AppTokens.mono(context, size: 14)),
          ],
        ),
      ),
    );
  }
}

/// 提供方配置卡（D9 核心四件套：预设向导 / 加密 Key / 模型发现 / 连通测试）。
class _ProviderConfigCard extends ConsumerStatefulWidget {
  const _ProviderConfigCard({required this.view});

  final AiProviderView view;

  @override
  ConsumerState<_ProviderConfigCard> createState() =>
      _ProviderConfigCardState();
}

class _ProviderConfigCardState extends ConsumerState<_ProviderConfigCard> {
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _baseUrl;
  bool _obscure = true;
  bool _enabled = false;
  bool _testing = false;
  bool _discovering = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController();
    _model = TextEditingController();
    _baseUrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _syncFromView();
  }

  void _syncFromView() {
    _model.text = widget.view.model;
    _baseUrl.text = widget.view.preset.baseUrl;
    _enabled = widget.view.enabled;
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final controller = ref.read(aiControllerProvider.notifier);
    final provider = view.preset;
    return ListView(
      padding: const EdgeInsets.all(AppTokens.s16),
      children: <Widget>[
        SsSectionTitle(
          provider.name,
          subtitle: provider.isCustom
              ? '自定义 OpenAI 兼容端点'
              : '${provider.protocol.toUpperCase()} 协议 · 预设已填',
          trailing: SsToggleRow(
            title: '',
            value: _enabled,
            onChanged: (bool v) {
              setState(() => _enabled = v);
              controller.setEnabled(provider.id, v);
            },
          ),
        ),
        const SizedBox(height: AppTokens.s12),
        if (provider.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              provider.note,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        TextField(
          controller: _baseUrl,
          decoration:
              const InputDecoration(labelText: 'Base URL', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _key,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: provider.keyHint,
            hintText: view.hasKey
                ? '已保存：${view.maskedKey}（留空保持不变）'
                : '粘贴 API Key（AES-256-GCM 加密存储）',
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: view.models.isEmpty
                  ? TextField(
                      controller: _model,
                      decoration: const InputDecoration(
                          labelText: '模型名', isDense: true),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: view.models.contains(_model.text)
                          ? _model.text
                          : view.models.first,
                      decoration: const InputDecoration(
                          labelText: '模型（来自模型发现）', isDense: true),
                      items: <DropdownMenuItem<String>>[
                        for (final String m in view.models)
                          DropdownMenuItem<String>(value: m, child: Text(m)),
                      ],
                      onChanged: (String? v) => _model.text = v ?? '',
                    ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.s12),
        Row(
          children: <Widget>[
            SsButton(
              label: '保存配置',
              icon: Icons.save_outlined,
              dense: true,
              onPressed: () async {
                await controller.saveProvider(
                  provider,
                  apiKey: _key.text.trim(),
                  model: _model.text.trim().isEmpty
                      ? provider.defaultModel
                      : _model.text.trim(),
                  baseUrl: _baseUrl.text.trim(),
                  enabled: _enabled,
                );
                _key.clear();
                if (!context.mounted) return;
                ssToast(context, '已保存（Key 加密存储，不进日志与导出）');
              },
            ),
            const SizedBox(width: 8),
            SsButton(
              label: _testing ? '测试中…' : '连通性测试',
              icon: Icons.network_check_rounded,
              kind: SsButtonKind.ghost,
              dense: true,
              onPressed: _testing
                  ? null
                  : () async {
                      setState(() => _testing = true);
                      final result = await controller.testProvider(provider.id);
                      if (!context.mounted) return;
                      setState(() => _testing = false);
                      ssToast(
                        context,
                        result.success
                            ? '连通正常 · ${result.latencyMs}ms · ${result.content}'
                            : '失败：${result.error}',
                      );
                    },
            ),
            const SizedBox(width: 8),
            SsButton(
              label: _discovering ? '拉取中…' : '拉取模型列表',
              icon: Icons.download_for_offline_outlined,
              kind: SsButtonKind.ghost,
              dense: true,
              onPressed: _discovering
                  ? null
                  : () async {
                      setState(() => _discovering = true);
                      final models =
                          await controller.discoverModels(provider.id);
                      if (!context.mounted) return;
                      setState(() => _discovering = false);
                      ssToast(
                          context,
                          models.isEmpty
                              ? '未发现模型（可用手动输入）'
                              : '发现 ${models.length} 个模型');
                    },
            ),
            const Spacer(),
            if (provider.consoleUrl.isNotEmpty)
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(provider.consoleUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('获取 Key ↗', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.s16),
        const SsSectionTitle('智能路由优先级', subtitle: '失败自动按此顺序切换'),
        const SizedBox(height: AppTokens.s8),
        Row(
          children: <Widget>[
            SsButton(
              label: '上移',
              kind: SsButtonKind.ghost,
              dense: true,
              onPressed: () => controller.movePriority(provider.id, -1),
            ),
            const SizedBox(width: 6),
            SsButton(
              label: '下移',
              kind: SsButtonKind.ghost,
              dense: true,
              onPressed: () => controller.movePriority(provider.id, 1),
            ),
          ],
        ),
      ],
    );
  }
}
