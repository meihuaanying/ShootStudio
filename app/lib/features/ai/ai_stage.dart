/// V8/S8 · D155：AI 面板收敛为「描述 → 生成中 → 阅读成案」三态。
///
/// 合同要求（§4.4）：
/// - 输入态：一句话 + 高级选项折叠（输入控件仍由 `AiPanel` 持有）；
/// - 生成态：流式输出 + 可取消 + 失败自动换商提示；
/// - 阅读态：直接进入成案阅读视图（`PlanReadView`），再决定是否写入画布。
///
/// 本文件只放三态的判定与两个面板组件，不动 `AiController` 的生成逻辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';

import 'ai_controller.dart';
import 'plan_read_view.dart';

/// AI 面板三态。D155：生成 → 阅读 → 修订收敛为「描述 / 生成中 / 阅读成案」。
enum AiStage {
  /// 一句话描述 + 高级选项（尚未生成，或上次生成已被取消）。
  input('01', '描述'),

  /// 流式生成中：可取消；失败会自动换商，尝试链在面板里明示。
  generating('02', '生成中'),

  /// 阅读成案：杂志内页阅读视图 → 写入画布 / 重新生成。
  reading('03', '阅读成案');

  const AiStage(this.ordinal, this.label);

  /// 眉题编号（mono，两位）。
  final String ordinal;

  /// 眉题文案。
  final String label;
}

/// 由 `AiState` 解析当前态：生成中 > 已取消回到描述 > 有草稿为阅读。
AiStage resolveAiStage(AiState state) {
  if (state.generating) return AiStage.generating;
  final AiDraftResult? draft = state.draft;
  if (draft == null || draft.cancelled) return AiStage.input;
  return AiStage.reading;
}

/// 三态眉题条：编号 + 文案 + hairline 连接线（D155 的「可见进度」）。
class AiStageBar extends StatelessWidget {
  const AiStageBar({super.key, required this.stage});

  final AiStage stage;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final List<AiStage> all = AiStage.values;
    return Row(
      children: <Widget>[
        for (final AiStage s in all) ...<Widget>[
          _StageDot(stage: s, done: s.index < stage.index, active: s == stage),
          if (s.index < all.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
                child: Container(
                  height: 1,
                  color: s.index < stage.index ? p.accent : p.rule,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({
    required this.stage,
    required this.done,
    required this.active,
  });

  final AiStage stage;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Color fg = active
        ? p.bg
        : done
        ? p.accent
        : p.muted;
    final Color bg = active
        ? p.accent
        : done
        ? p.accentSoft
        : p.surfaceSunken;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: active ? p.accent : p.rule),
          ),
          child: Text(
            stage.ordinal,
            style: appMono(fg, size: 9.5, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: AppSpace.s1 + 2),
        Text(
          stage.label,
          style: AppType.small.style(
            active ? p.ink : p.muted,
            weight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// 生成态面板：流式正文 + 推理链 + 尝试链（自动换商明示）+ 取消。
class AiGeneratingPanel extends ConsumerWidget {
  const AiGeneratingPanel({super.key, required this.state, this.onCancel});

  final AiState state;

  /// 留空则回落到 `AiController.cancelGenerate()`。
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;
    final bool hasReasoning = state.reasoningText.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                state.status.isEmpty ? '正在生成…' : state.status,
                style: AppType.small.style(p.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SsButton(
              label: '取消生成',
              icon: Icons.stop_circle_outlined,
              kind: SsButtonKind.text,
              dense: true,
              onPressed:
                  onCancel ??
                  () =>
                      ref.read(aiControllerProvider.notifier).cancelGenerate(),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s2),
        if (state.attempts.isNotEmpty) _attemptBanner(context, p),
        if (state.attempts.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: SsBanner(
              text: '本次已自动换商：${state.attempts.join(' → ')}（D40 同商换模型 → 换商）',
              kind: SsBannerKind.warning,
            ),
          ),
        Text('流式输出', style: appEyebrow(p.muted)),
        const SizedBox(height: AppSpace.s1 + 2),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.s3),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: p.rule),
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Text(
                  state.streamText.trim().isEmpty
                      ? '正在向上游取回第一段文本…'
                      : state.streamText,
                  style: appMono(p.inkSoft, size: 11),
                ),
              ),
            ),
          ),
        ),
        if (hasReasoning) ...<Widget>[
          const SizedBox(height: AppSpace.s3),
          Text('推理链', style: appEyebrow(p.muted)),
          const SizedBox(height: AppSpace.s1 + 2),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 132),
            padding: const EdgeInsets.all(AppSpace.s2),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: SingleChildScrollView(
              child: Text(
                state.reasoningText,
                style: appMono(p.muted, size: 10.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 尝试链 chip 行：每个上游一次。
  Widget _attemptBanner(BuildContext context, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Wrap(
        spacing: AppSpace.s1 + 2,
        runSpacing: AppSpace.s1,
        children: <Widget>[
          for (int i = 0; i < state.attempts.length; i++)
            _AttemptChip(ordinal: i + 1, text: state.attempts[i]),
        ],
      ),
    );
  }
}

class _AttemptChip extends StatelessWidget {
  const _AttemptChip({required this.ordinal, required this.text});

  final int ordinal;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2, vertical: 3),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text('$ordinal · $text', style: appMono(p.accent, size: 10)),
    );
  }
}

/// 阅读态面板：先读成案（杂志内页），再决定写入画布。
class AiReadingPanel extends ConsumerWidget {
  const AiReadingPanel({
    super.key,
    required this.state,
    required this.idea,
    required this.onInsertAll,
    required this.onInsertModule,
    this.onRegenerate,
  });

  final AiState state;

  /// 一句话描述（传给阅读视图作副题）。
  final String idea;

  /// 整体写入画布。
  final void Function(List<PlanModuleData> modules) onInsertAll;

  /// 单个模块写入画布。
  final void Function(PlanModuleData module) onInsertModule;

  /// 重新生成（留空则调用 `AiController.generatePlan`）。
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;
    final AiDraftResult draft = state.draft!;
    final bool cancelled = draft.cancelled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (cancelled)
          const SsBanner(
            text: '本次生成已被取消，仅供复核，不可写入画布。',
            kind: SsBannerKind.danger,
          )
        else
          SsBannerLite(
            text: draft.viaLocal
                ? '来源：${draft.providerName}（离线降级）'
                : '来源：${draft.providerName} · ${draft.latencyMs}ms · 入 ${draft.tokensIn} / 出 ${draft.tokensOut} tokens',
            success: !draft.viaLocal,
          ),
        const SizedBox(height: AppSpace.s2),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: <Widget>[
            SsButton(
              label: '阅读成案',
              icon: Icons.menu_book_outlined,
              dense: true,
              onPressed: () => _openRead(context, draft),
            ),
            SsButton(
              label: cancelled ? '已取消' : '写入画布',
              icon: cancelled
                  ? Icons.block_rounded
                  : Icons.download_done_rounded,
              kind: SsButtonKind.text,
              dense: true,
              onPressed: cancelled ? null : () => onInsertAll(draft.modules),
            ),
            SsButton(
              label: '重新生成',
              icon: Icons.refresh_rounded,
              kind: SsButtonKind.text,
              dense: true,
              onPressed:
                  onRegenerate ??
                  () => ref
                      .read(aiControllerProvider.notifier)
                      .generatePlan(idea.trim()),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        Text(
          cancelled
              ? '已取消（${draft.modules.length} 个模块占位）'
              : '生成 ${draft.modules.length} 个模块（草稿态）',
          style: appEyebrow(p.muted),
        ),
        const SizedBox(height: AppSpace.s1 + 2),
        Expanded(
          child: ListView.builder(
            itemCount: draft.modules.length,
            itemBuilder: (BuildContext context, int i) {
              final PlanModuleData m = draft.modules[i];
              return SsCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${m.title} · ${m.type.label}',
                            style: AppType.body.style(p.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.summary.isEmpty ? m.type.category : m.summary,
                            style: AppType.small.style(p.muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    SsButton(
                      label: '插入',
                      kind: SsButtonKind.text,
                      dense: true,
                      onPressed: () => onInsertModule(m),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 打开杂志内页阅读视图；用户在阅读视图里确认写入后按 `accept` 回写。
  Future<void> _openRead(BuildContext context, AiDraftResult draft) async {
    final String? action = await PlanReadView.show(context, draft, idea: idea);
    if (action == 'accept' && !draft.cancelled && context.mounted) {
      onInsertAll(draft.modules);
    }
  }
}
