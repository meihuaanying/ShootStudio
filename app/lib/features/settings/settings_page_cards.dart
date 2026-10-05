// V8/S9 · D158：AI 渠道卡片（提供方开关 / 优先级 / 余额）。
// 从 settings_page.dart 拆出（R73 行数门禁）；part 同库，私有成员无需公开化。
part of 'settings_page.dart';

class _AiChannelsCard extends ConsumerStatefulWidget {
  const _AiChannelsCard();

  @override
  ConsumerState<_AiChannelsCard> createState() => _AiChannelsCardState();
}

class _AiChannelsCardState extends ConsumerState<_AiChannelsCard> {
  final Set<String> _expanded = <String>{};
  final Map<String, TextEditingController> _keys =
      <String, TextEditingController>{};
  final Set<String> _fetching = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      ref.read(aiControllerProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    for (final TextEditingController c in _keys.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetch(String id) async {
    setState(() => _fetching.add(id));
    final List<String> models = await ref
        .read(aiControllerProvider.notifier)
        .fetchModels(id);
    if (!mounted) return;
    setState(() => _fetching.remove(id));
    final AiProviderView? view = ref
        .read(aiControllerProvider)
        .providers
        .where((AiProviderView view) => view.preset.id == id)
        .firstOrNull;
    ssToast(
      context,
      models.isEmpty
          ? '拉取失败：检查 Key 与网络（已保留手动模型）'
          : '已拉取 ${models.length} 个模型，自动选模：${view?.model ?? ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AiState ai = ref.watch(aiControllerProvider);
    final ThemeData theme = Theme.of(context);
    final List<AiProviderView> providers = <AiProviderView>[...ai.providers]
      ..sort(
        (AiProviderView a, AiProviderView b) =>
            a.priority.compareTo(b.priority),
      );
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SsSectionTitle(
            'AI 通道',
            subtitle: 'D40：自动拉取模型列表 · 自动选可用模型 · 失败自动换模型/换商',
          ),
          const SizedBox(height: AppSpace.s3),
          for (final AiProviderView view in providers.take(8)) ...<Widget>[
            _row(context, theme, view),
            const Divider(height: 14),
          ],
          Text(
            'Key 仅保存在本机工作区（AES-256-GCM 加密）；未配置时自动使用本地引擎。',
            style: TextStyle(
              fontSize: AppFontSize.caption,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ThemeData theme, AiProviderView view) {
    final AppPalette p = context.palette;

    final bool expanded = _expanded.contains(view.preset.id);
    final TextEditingController key = _keys.putIfAbsent(
      view.preset.id,
      () => TextEditingController(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: view.hasKey
                    ? (view.enabled ? p.film : p.gold)
                    : theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${view.preset.name}'
                    '${view.hasKey ? ' · ${view.maskedKey}' : ''}',
                    style: const TextStyle(
                      fontSize: AppFontSize.smallLg,
                      fontWeight: AppFontWeight.medium,
                    ),
                  ),
                  Text(
                    view.models.isEmpty
                        ? '模型：${view.model.isEmpty ? '未选择（生成时自动探测）' : view.model}'
                        : '模型：${view.model} · 已发现 ${view.models.length} 个',
                    style: TextStyle(
                      fontSize: AppFontSize.caption,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '上移优先级',
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
              onPressed: () => ref
                  .read(aiControllerProvider.notifier)
                  .movePriority(view.preset.id, -1),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '下移优先级',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              onPressed: () => ref
                  .read(aiControllerProvider.notifier)
                  .movePriority(view.preset.id, 1),
            ),
            SsButton(
              label: _fetching.contains(view.preset.id) ? '拉取中…' : '拉模型',
              dense: true,
              kind: SsButtonKind.text,
              onPressed: view.hasKey && !_fetching.contains(view.preset.id)
                  ? () => _fetch(view.preset.id)
                  : null,
            ),
            const SizedBox(width: 4),
            SsButton(
              label: expanded ? '收起' : '配置',
              dense: true,
              kind: SsButtonKind.text,
              onPressed: () => setState(() {
                if (!_expanded.remove(view.preset.id)) {
                  _expanded.add(view.preset.id);
                }
              }),
            ),
          ],
        ),
        if (expanded) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: key,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: view.hasKey
                        ? '已保存（重新输入可覆盖）'
                        : view.preset.keyHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SsButton(
                label: '保存',
                dense: true,
                onPressed: () async {
                  await ref
                      .read(aiControllerProvider.notifier)
                      .saveProvider(
                        view.preset,
                        apiKey: key.text.trim(),
                        model: view.model,
                        baseUrl: view.preset.baseUrl,
                        enabled: true,
                      );
                  key.clear();
                  if (mounted) {
                    // 保存动作已触发一次 encrypt，此时才问得出钥匙串是否可用。
                    final bool ok = ref
                        .read(aiControllerProvider.notifier)
                        .keyStorageAvailable;
                    if (!ok) {
                      ssToast(this.context, '系统钥匙串不可用：Key 仅本次会话有效，重启后需重填');
                    } else {
                      ssToast(this.context, '已保存并启用 ${view.preset.name}');
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// G6：图片素材通道（Pexels/TMDB Key）+ 开源素材许可页。
