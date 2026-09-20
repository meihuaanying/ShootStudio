import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/widgets.dart';
import '../../core/theme/tokens.dart';
import '../planner/planner_diff.dart';
import '../planner/planner_models.dart';
import 'ai_controller.dart';

/// AI 侧栏（F3）：对话式修订，携带策划案摘要与目标模块，diff 预览确认后应用。
class AiSidePanel extends ConsumerStatefulWidget {
  const AiSidePanel({
    super.key,
    required this.modules,
    required this.targetModuleId,
    required this.onApply,
  });

  final List<PlanModuleData> modules;
  final String? targetModuleId;
  final void Function(List<PlanModuleData> modules) onApply;

  @override
  ConsumerState<AiSidePanel> createState() => _AiSidePanelState();
}

class _AiSidePanelState extends ConsumerState<AiSidePanel> {
  final TextEditingController _input = TextEditingController();
  final List<({bool user, String text})> _chat = <({bool user, String text})>[];
  bool _busy = false;
  AiRevisionDraft? _draft;

  static const List<String> _quick = <String>[
    '让布光建议更具体（方位角与距离）',
    '预算压缩 20%',
    '色调换成夜景霓虹',
    '姿势换成动态抓拍',
    '补全时间轴与风险提示',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get _targetTitle {
    final String? id = widget.targetModuleId;
    if (id == null) return '整个策划案';
    for (final PlanModuleData m in widget.modules) {
      if (m.id == id) return m.title.isEmpty ? m.type.label : m.title;
    }
    return '整个策划案';
  }

  Future<void> _send([String? preset]) async {
    final String instruction = (preset ?? _input.text).trim();
    if (instruction.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _chat.add((user: true, text: instruction));
      _input.clear();
    });
    final AiController controller = ref.read(aiControllerProvider.notifier);
    final AiRevisionDraft? draft = await controller.revise(
      modules: widget.modules,
      instruction: instruction,
      targetModuleId: widget.targetModuleId,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _draft = draft;
      final String status = ref.read(aiControllerProvider).status;
      _chat.add((
        user: false,
        text: draft == null
            ? status
            : '已生成修订预览：${(draft.diff as PlanDiff).totalChanges} 处变更（确认后应用）',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PlanDiff? diff = _draft?.diff is PlanDiff
        ? _draft!.diff as PlanDiff
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsSectionTitle('AI 助手', subtitle: '目标：$_targetTitle'),
        const SizedBox(height: AppTokens.s8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final String q in _quick)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SsChip(
                    label: q,
                    selected: false,
                    onTap: _busy ? () {} : () => _send(q),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        Expanded(
          child: ListView(
            children: <Widget>[
              for (final ({bool user, String text}) line in _chat)
                Align(
                  alignment: line.user
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    constraints: const BoxConstraints(maxWidth: 260),
                    decoration: BoxDecoration(
                      color: line.user
                          ? AppTokens.accentSoft
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTokens.rSm),
                    ),
                    child: Text(
                      line.text,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              if (_draft != null && diff != null) _buildDiffCard(diff),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _input,
                decoration: InputDecoration(
                  hintText: '例如：主光再近一点 / 换夜景霓虹 / 预算减半',
                  isDense: true,
                  enabled: !_busy,
                ),
                onSubmitted: (String _) => _send(),
              ),
            ),
            const SizedBox(width: 6),
            SsButton(
              label: '发送',
              icon: Icons.send_rounded,
              dense: true,
              onPressed: _busy ? null : () => _send(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiffCard(PlanDiff diff) {
    final AiRevisionDraft draft = _draft!;
    return SsCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '修订预览 · 新增 ${diff.added.length} · 删除 ${diff.removed.length} · '
            '修改 ${diff.changed.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final PlanModuleData m in diff.added)
            _line(
              Icons.add_circle_outline_rounded,
              AppTokens.success,
              '新增：${m.title}',
            ),
          for (final PlanModuleData m in diff.removed)
            _line(
              Icons.remove_circle_outline_rounded,
              AppTokens.danger,
              '删除：${m.title}',
            ),
          for (final ModuleChange c in diff.changed)
            _line(
              Icons.change_circle_outlined,
              AppTokens.warning,
              '修改：${c.after.title} · ${c.changedKeys.join('、')}',
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              SsButton(
                label: '应用修订',
                icon: Icons.check_rounded,
                dense: true,
                onPressed: () {
                  widget.onApply(draft.modules);
                  ref.read(aiControllerProvider.notifier).clearRevision();
                  setState(() {
                    _draft = null;
                    _chat.add((user: false, text: '已应用修订'));
                  });
                },
              ),
              const SizedBox(width: 8),
              SsButton(
                label: '放弃',
                kind: SsButtonKind.ghost,
                dense: true,
                onPressed: () {
                  ref.read(aiControllerProvider.notifier).clearRevision();
                  setState(() => _draft = null);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5))),
        ],
      ),
    );
  }
}
