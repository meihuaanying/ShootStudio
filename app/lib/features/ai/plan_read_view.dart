import 'package:flutter/material.dart';

import '../../core/design/widgets.dart';
import '../../core/theme/tokens.dart';
import '../planner/module_content_view.dart';
import '../planner/planner_models.dart';
import 'ai_controller.dart';

/// D28/D43：生成完成后的全案阅读模式（完整正文 + 评分 + 推理 + 短板 + 尝试链）。
/// 返回：'accept'（写入画布并编辑）/ 'retry'（重新生成）/ null（关闭）。
class PlanReadView extends StatelessWidget {
  const PlanReadView({super.key, required this.draft, required this.idea});

  final AiDraftResult draft;
  final String idea;

  static Future<String?> show(BuildContext context, AiDraftResult draft,
          {required String idea}) =>
      showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PlanReadView(draft: draft, idea: idea),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool local = draft.viaLocal;
    return Dialog.fullscreen(
      child: Column(
        children: <Widget>[
          _header(context, theme, local),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: <Widget>[
                if (draft.shortcomings.isNotEmpty) _shortcomings(context),
                if (draft.reasoning.trim().isNotEmpty) _reasoning(context),
                for (var i = 0; i < draft.modules.length; i++)
                  _moduleCard(context, draft.modules[i], i + 1),
              ],
            ),
          ),
          _actions(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ThemeData theme, bool local) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.menu_book_rounded, color: AppTokens.accent),
              const SizedBox(width: 8),
              const Text('全案阅读',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              if (local)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTokens.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('本地引擎兜底',
                      style: TextStyle(fontSize: 11, color: AppTokens.warning)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('想法：$idea',
              style: TextStyle(
                  fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _chip('质量分 ${draft.totalScore.toStringAsFixed(0)}',
                  good: draft.totalScore >= 90),
              _chip('细节 ${draft.detailScore.toStringAsFixed(0)}'),
              _chip('一致性 ${draft.consistencyScore.toStringAsFixed(0)}'),
              _chip(draft.providerName),
              if (draft.latencyMs > 0) _chip('${draft.latencyMs}ms'),
              if (draft.tokensIn + draft.tokensOut > 0)
                _chip('tokens ${draft.tokensIn}+${draft.tokensOut}'),
            ],
          ),
          if (draft.attempts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text('生成尝试链（${draft.attempts.length}）',
                    style: const TextStyle(fontSize: 12)),
                children: <Widget>[
                  for (final String attempt in draft.attempts)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('· $attempt',
                            style: const TextStyle(fontSize: 11.5)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, {bool good = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: good
              ? AppTokens.success.withValues(alpha: 0.12)
              : AppTokens.accentSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                color: good ? AppTokens.success : AppTokens.accent,
                fontWeight: FontWeight.w600)),
      );

  Widget _shortcomings(BuildContext context) {
    return SsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('待改进（可一键让 AI 重试修正）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final String item in draft.shortcomings)
            Text('· $item', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _reasoning(BuildContext context) {
    return SsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text('AI 策划思路（推理原文）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: <Widget>[
            SelectableText(draft.reasoning,
                style: const TextStyle(fontSize: 12.5, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard(BuildContext context, PlanModuleData module, int index) {
    return SsCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          initiallyExpanded: index <= 2,
          title: Text(
              '$index. ${module.title.isEmpty ? module.type.label : module.title}',
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          subtitle:
              Text(module.type.label, style: const TextStyle(fontSize: 11)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: ModuleContentView(module: module),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: <Widget>[
          SsButton(
            label: '重新生成',
            kind: SsButtonKind.ghost,
            onPressed: () => Navigator.pop(context, 'retry'),
          ),
          const Spacer(),
          SsButton(
            label: '稍后（关闭）',
            kind: SsButtonKind.ghost,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          SsButton(
            label: '写入画布并编辑',
            onPressed: () => Navigator.pop(context, 'accept'),
          ),
        ],
      ),
    );
  }
}
