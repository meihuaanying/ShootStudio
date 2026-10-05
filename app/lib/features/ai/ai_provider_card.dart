import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import 'ai_controller.dart';
/// 提供方配置卡（D9 核心四件套：预设向导 / 加密 Key / 模型发现 / 连通测试）。
class ProviderConfigCard extends ConsumerStatefulWidget {
  const ProviderConfigCard({super.key, required this.view});

  final AiProviderView view;

  @override
  ConsumerState<ProviderConfigCard> createState() =>
      ProviderConfigCardState();
}

class ProviderConfigCardState extends ConsumerState<ProviderConfigCard> {
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
      padding: const EdgeInsets.all(AppSpace.s4),
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
        const SizedBox(height: AppSpace.s3),
        if (provider.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: Text(
              provider.note,
              style: TextStyle(
                fontSize: AppFontSize.captionLg,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        TextField(
          controller: _baseUrl,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            isDense: true,
          ),
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
                size: 16,
              ),
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
                        labelText: '模型名',
                        isDense: true,
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: view.models.contains(_model.text)
                          ? _model.text
                          : view.models.first,
                      decoration: const InputDecoration(
                        labelText: '模型（来自模型发现）',
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final String m in view.models)
                          DropdownMenuItem<String>(value: m, child: Text(m)),
                      ],
                      onChanged: (String? v) => _model.text = v ?? '',
                    ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
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
              kind: SsButtonKind.text,
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
              kind: SsButtonKind.text,
              dense: true,
              onPressed: _discovering
                  ? null
                  : () async {
                      setState(() => _discovering = true);
                      final models = await controller.discoverModels(
                        provider.id,
                      );
                      if (!context.mounted) return;
                      setState(() => _discovering = false);
                      ssToast(
                        context,
                        models.isEmpty
                            ? '未发现模型（可用手动输入）'
                            : '发现 ${models.length} 个模型',
                      );
                    },
            ),
            const Spacer(),
            if (provider.consoleUrl.isNotEmpty)
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(provider.consoleUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text(
                  '获取 Key ↗',
                  style: TextStyle(fontSize: AppFontSize.smallSm),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        const SsSectionTitle('智能路由优先级', subtitle: '失败自动按此顺序切换'),
        const SizedBox(height: AppSpace.s2),
        Row(
          children: <Widget>[
            SsButton(
              label: '上移',
              kind: SsButtonKind.text,
              dense: true,
              onPressed: () => controller.movePriority(provider.id, -1),
            ),
            const SizedBox(width: 6),
            SsButton(
              label: '下移',
              kind: SsButtonKind.text,
              dense: true,
              onPressed: () => controller.movePriority(provider.id, 1),
            ),
          ],
        ),
      ],
    );
  }
}
