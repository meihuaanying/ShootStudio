// V8/S8 · D155：成案阅读视图的版面组件（刊头 / 眉题分节 / 图卡分镜 / KV 读数预算表 /
// 附录）。与 plan_read_view.dart 同一库，私有互访关系不变。
part of 'plan_read_view.dart';

/// 评分读数格式化：0 视为「未评分」，给破折号而不是 0.0（避免读成满分 0）。
String _readoutScore(double v) => v <= 0 ? '—' : v.toStringAsFixed(1);

extension _PlanReadSpread on _PlanReadViewState {
  /// 小标签（通道 / 状态）。
  Widget _tag(BuildContext context, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.s2,
      vertical: AppSpaceFine.n3,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.42)),
      borderRadius: BorderRadius.circular(AppRadius.chip),
    ),
    child: Text(text, style: appMono(color)),
  );

  /// 眉题分节头：`01 / 标题` + hairline。
  Widget _eyebrow(BuildContext context, String index, String label) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(index, style: appEyebrow(context.palette.accent)),
        const SizedBox(width: AppSpace.s2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appEyebrow(context.palette.muted),
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        Expanded(child: Container(height: 1, color: context.palette.rule)),
      ],
    ),
  );

  /// 刊头：Display 衬线大标题（一句话成案）+ 副题 + 元信息行。
  Widget _hero(BuildContext context) {
    final AiDraftResult d = widget.draft;
    final List<String> meta = <String>[
      if (d.viaLocal) '本地引擎' else d.providerName,
      '${d.modules.length} 个模块',
      if (d.latencyMs > 0) '${d.latencyMs} ms',
      if (d.attempts.isNotEmpty) '尝试 ${d.attempts.length} 次',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('成案阅读视图', style: appEyebrow(context.palette.muted)),
          const SizedBox(height: AppSpace.s2),
          Text(
            widget.idea.trim().isEmpty ? '未命名成案' : widget.idea.trim(),
            style: Theme.of(context).textTheme.displayLarge,
          ),
          if (d.cancelled) ...<Widget>[
            const SizedBox(height: AppSpace.s3),
            _tag(context, '已取消', context.palette.danger),
          ],
          const SizedBox(height: AppSpace.s3),
          Text(
            '按一句描述生成的完整策划案草稿，可逐节复核后写入画布继续编辑。',
            style: AppType.body.style(context.palette.inkSoft),
          ),
          const SizedBox(height: AppSpace.s3),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s1,
            children: <Widget>[
              for (final String m in meta)
                _tag(context, m, context.palette.muted),
            ],
          ),
          const SizedBox(height: AppSpace.s5),
          Container(height: 2, color: context.palette.ink),
        ],
      ),
    );
  }

  /// KV 读数预算表：hairline 表格（无竖线）。
  Widget _readout(BuildContext context) {
    final AiDraftResult d = widget.draft;
    final List<(String, String)> rows = <(String, String)>[
      ('模块数', '${d.modules.length}'),
      ('总分', _readoutScore(d.totalScore)),
      ('细节分', _readoutScore(d.detailScore)),
      ('一致分', _readoutScore(d.consistencyScore)),
      ('输入 tokens', '${d.tokensIn}'),
      ('输出 tokens', '${d.tokensOut}'),
      ('耗时', d.latencyMs > 0 ? '${d.latencyMs} ms' : '—'),
      ('通道', d.viaLocal ? '本地引擎' : d.providerName),
      ('尝试链', d.attempts.isEmpty ? '—' : d.attempts.join(' → ')),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _eyebrow(context, '01', '读数 · 预算与一致性'),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              border: Border.all(color: context.palette.rule),
            ),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < rows.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.palette.rule,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s3,
                      vertical: AppSpace.s2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 132,
                          child: Text(
                            rows[i].$1,
                            style: appMono(context.palette.muted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rows[i].$2,
                            style: appMono(context.palette.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单个模块分镜：眉题（序号 / 分类 / 标题）+ 建议 + 只读图卡。
  Widget _moduleSpread(BuildContext context, PlanModuleData m, int ordinal) {
    final String title = m.title.trim().isEmpty ? m.type.label : m.title.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _eyebrow(
            context,
            '${ordinal.toString().padLeft(2, '0')} / ${m.type.category}',
            title,
          ),
          Text(title, style: AppType.h3.style(context.palette.ink)),
          const SizedBox(height: AppSpace.s1),
          Text(
            '${m.type.label}｜${m.id}',
            style: appMono(context.palette.muted),
          ),
          if (m.summary.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpace.s2),
            Text(
              m.summary.trim(),
              style: AppType.small.style(context.palette.inkSoft),
            ),
          ],
          const SizedBox(height: AppSpace.s3),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              border: Border.all(color: context.palette.rule),
            ),
            padding: const EdgeInsets.all(AppSpace.s4),
            child: ModuleContentView(module: m, compact: true),
          ),
        ],
      ),
    );
  }

  /// 附录：推理链。
  Widget _reasoning(BuildContext context) {
    final String text = widget.draft.reasoning.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _eyebrow(context, 'R1', '推理链'),
          if (text.isEmpty)
            Text(
              '（本次生成未回传推理链）',
              style: AppType.small.style(context.palette.muted),
            )
          else
            Text(text, style: appMono(context.palette.inkSoft, size: 12)),
        ],
      ),
    );
  }

  /// 附录：不足与风险（schemaErrors + shortcomings）。
  Widget _risks(BuildContext context) {
    final AiDraftResult d = widget.draft;
    final List<String> items = <String>[...d.shortcomings, ...d.schemaErrors];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _eyebrow(context, 'R2', '不足与风险'),
          for (final String s in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('· ', style: appMono(context.palette.danger)),
                  Expanded(
                    child: Text(
                      s,
                      style: AppType.small.style(context.palette.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 附录：原始文本。
  Widget _appendix(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _eyebrow(context, 'A1', '附录 · 原始文本'),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: context.palette.surfaceSunken,
              border: Border.all(color: context.palette.rule),
            ),
            padding: const EdgeInsets.all(AppSpace.s3),
            child: SingleChildScrollView(
              child: Text(
                widget.draft.rawText,
                style: appMono(context.palette.inkSoft, size: 11.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
