/// V8/S8 · D155：成案阅读视图 —— 按杂志内页排版重排。
///
/// 版式约定（对齐设计合同 §3 / D155）：
/// - 刊头：Display 衬线大标题（一句话成案）+ 眉题元信息行（通道 / 模块数 / 耗时）；
/// - 桌面宽栏双栏：左侧目录（可点，按当前分节高亮），右侧正文；
/// - 正文：眉题分节 + 图卡分镜（复用只读渲染器）+ KV 读数预算表（hairline 表格）；
/// - 附录：推理链、不足与风险、原始文本。
///
/// 契约不变：`show()` 仍返回 `'accept'`（写入画布）/ `'retry'`（重新生成）/ `null`（关闭），
/// 唯一外部调用点是 `lib/features/home/home_page.dart`。
library;

import 'package:flutter/material.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/features/ai/ai_controller.dart';
import 'package:shoot_studio/features/planner/module_content_view.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';

part 'plan_read_view_spread.dart';

class PlanReadView extends StatefulWidget {
  const PlanReadView({super.key, required this.draft, required this.idea});

  final AiDraftResult draft;
  final String idea;

  static Future<String?> show(
    BuildContext context,
    AiDraftResult draft, {
    required String idea,
  }) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => Dialog.fullscreen(
        child: PlanReadView(draft: draft, idea: idea),
      ),
    );
  }

  @override
  State<PlanReadView> createState() => _PlanReadViewState();
}

class _PlanReadViewState extends State<PlanReadView> {
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _keys = <GlobalKey>[];
  int _section = 0;
  int _nextKey = 0;

  /// extension 里不能直接调 protected setState，统一走这层薄封装。
  void refresh(void Function() fn) => setState(fn);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyAt(int index) {
    while (_keys.length <= index) {
      _keys.add(GlobalKey());
    }
    return _keys[index];
  }

  /// 目录条目：与 [_body] 的分节顺序严格一一对应（索引即 key 下标）。
  List<String> get _tocTitles {
    final List<String> titles = <String>['刊头', '读数'];
    for (final PlanModuleData m in widget.draft.modules) {
      titles.add(m.title.trim().isEmpty ? m.type.label : m.title.trim());
    }
    titles.add('推理链');
    if (_hasRisks) titles.add('不足与风险');
    titles.add('附录 · 原始文本');
    return titles;
  }

  bool get _hasRisks {
    final AiDraftResult d = widget.draft;
    return d.shortcomings.isNotEmpty || d.schemaErrors.isNotEmpty;
  }

  void _jumpTo(int index) {
    refresh(() => _section = index);
    final BuildContext? target = _keyAt(index).currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: AppWait.planReveal,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _topBar(context),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final Widget body = _body(context);
              if (c.maxWidth < 1040) return body;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(width: 236, child: _toc(context)),
                  Container(width: 1, color: context.palette.rule),
                  Expanded(child: body),
                ],
              );
            },
          ),
        ),
        _actions(context),
      ],
    );
  }

  /// 刊头：关闭 + 眉题 + 通道标签。
  Widget _topBar(BuildContext context) {
    final AiDraftResult d = widget.draft;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s5,
        vertical: AppSpace.s2,
      ),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(bottom: BorderSide(color: context.palette.rule)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: '关闭',
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text('AI 成案 · 阅读', style: appEyebrow(context.palette.muted)),
          ),
          _tag(
            context,
            d.cancelled ? '已取消' : (d.viaLocal ? '本地引擎' : d.providerName),
            d.cancelled ? context.palette.danger : context.palette.accent,
          ),
        ],
      ),
    );
  }

  /// 左栏目录（宽栏双栏布局）。
  Widget _toc(BuildContext context) {
    final List<String> titles = _tocTitles;
    return ColoredBox(
      color: context.palette.surfaceSunken,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s4,
          AppSpace.s3,
          AppSpace.s6,
        ),
        itemCount: titles.length,
        itemBuilder: (BuildContext context, int i) {
          final bool active = i == _section;
          return InkWell(
            onTap: () => _jumpTo(i),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpace.s1,
                horizontal: AppSpace.s2,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: active ? context.palette.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                titles[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.small.style(
                  active ? context.palette.ink : context.palette.muted,
                  weight: active ? AppFontWeight.medium : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 右栏正文（单栏布局时整宽）。
  Widget _body(BuildContext context) {
    _nextKey = 0;
    final List<Widget> sections = <Widget>[
      _hero(context),
      _readout(context),
      for (int i = 0; i < widget.draft.modules.length; i++)
        _moduleSpread(context, widget.draft.modules[i], i + 1),
      _reasoning(context),
      if (_hasRisks) _risks(context),
      _appendix(context),
    ];
    return Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s5,
          vertical: AppSpace.s5,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final Widget s in sections)
                  KeyedSubtree(key: _keyAt(_nextKey++), child: s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 底栏行动区（保持旧契约：retry / 关闭 / accept）。
  Widget _actions(BuildContext context) {
    final bool cancelled = widget.draft.cancelled;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s5,
        vertical: AppSpace.s3,
      ),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(top: BorderSide(color: context.palette.rule)),
      ),
      child: Row(
        children: <Widget>[
          if (cancelled)
            Expanded(
              child: Text(
                '本次生成已被取消，仅供复核，不可写入画布。',
                style: AppType.small.style(context.palette.danger),
              ),
            )
          else
            const Spacer(),
          SsButton(
            label: '重新生成',
            icon: Icons.refresh_rounded,
            kind: SsButtonKind.text,
            dense: true,
            onPressed: () => Navigator.pop(context, 'retry'),
          ),
          const SizedBox(width: AppSpace.s2),
          SsButton(
            label: '稍后（关闭）',
            kind: SsButtonKind.text,
            dense: true,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: AppSpace.s2),
          SsButton(
            label: cancelled ? '已取消' : '写入画布并编辑',
            icon: cancelled ? Icons.block_rounded : Icons.check_rounded,
            dense: true,
            onPressed: cancelled
                ? null
                : () => Navigator.pop(context, 'accept'),
          ),
        ],
      ),
    );
  }
}
