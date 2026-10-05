import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';

/// 首页首屏（S4 画册风）：眉题 + 衬线 Display 大标题 + 导语 + 输入区。
/// 交互回调全部由 `home_page.dart` 注入，便于单测与视觉门禁复用。
class HomeIdeaHero extends StatelessWidget {
  const HomeIdeaHero({
    super.key,
    required this.controller,
    required this.generating,
    required this.onGenerate,
    this.trailing,
  });

  final TextEditingController controller;
  final bool generating;
  final VoidCallback onGenerate;

  /// 顶部动作（换一批灵感 chip）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: SsEyebrow('OPENING · 开案')),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        // 保留既有文案锚点「说说你想拍什么」（golden/flow 测试依赖）。
        Text(
          '说说你想拍什么',
          style: AppType.display.style(p.ink, font: AppFonts.display),
        ),
        const SizedBox(height: AppSpace.s2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            '一句话描述你的想法，三十秒得到可执行的策划案：'
            '画面参考、布光预演、动作摆姿与预算表一次成案。',
            style: AppType.body.style(p.inkSoft),
          ),
        ),
        const SizedBox(height: AppSpace.s5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: AppType.body.style(p.ink),
                decoration: InputDecoration(
                  hintText: '输入主题想法（支持中文）…',
                  hintStyle: AppType.body.style(p.muted),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s3),
            SsButton(
              label: generating ? '生成中…' : '生成策划案',
              icon: Icons.auto_awesome_rounded,
              onPressed: generating ? null : onGenerate,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        Row(
          children: <Widget>[
            const Icon(Icons.lock_outline_rounded, size: 14),
            const SizedBox(width: AppSpace.s2),
            Text(
              '数据都在本地工作区 · 模型随包 · 无需联网',
              style: AppType.caption.style(p.muted),
            ),
          ],
        ),
      ],
    );
  }
}

/// 灵感卡片条（S4）：横向卡片，点击回填输入框。
class HomeInspirationStrip extends StatelessWidget {
  const HomeInspirationStrip({
    super.key,
    required this.items,
    required this.onPick,
  });

  final List<({String title, String prompt})> items;
  final ValueChanged<({String title, String prompt})> onPick;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, int _) => const SizedBox(width: AppSpace.s2),
        itemBuilder: (BuildContext context, int i) {
          final ({String title, String prompt}) item = items[i];
          return SizedBox(
            width: 208,
            child: SsCard(
              margin: EdgeInsets.zero,
              onTap: () => onPick(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.title, style: AppType.h3.style(p.ink)),
                  const SizedBox(height: AppSpace.s1),
                  Expanded(
                    child: Text(
                      item.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.style(p.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 生成过程实时推理流（D28/D40）。
class HomeLiveReasoning extends StatelessWidget {
  const HomeLiveReasoning({
    super.key,
    required this.attempt,
    required this.text,
  });

  final String attempt;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (attempt.isNotEmpty)
          Text(attempt, style: appMono(p.muted, size: AppFontSize.caption)),
        if (text.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSpace.s2),
            padding: const EdgeInsets.all(AppSpace.s3),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: AppRadius.controlBorder,
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(text, style: AppType.body.style(p.inkSoft)),
            ),
          ),
      ],
    );
  }
}
