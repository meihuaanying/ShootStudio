/// V8/D147 · S3：文字与分隔件（眉题 Eyebrow / 区块标题 / KV 读数行 / hairline）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Eyebrow 眉题：mono 11pt + 字距 1.5 + 可选尾部 hairline（§3.2 画册风标志性元素）。
class SsEyebrow extends StatelessWidget {
  const SsEyebrow(this.text, {super.key, this.trailingRule = true, this.color});

  final String text;
  final bool trailingRule;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Widget label = Text(text, style: appEyebrow(color ?? p.accent));
    if (!trailingRule) return label;
    return Row(
      children: <Widget>[
        label,
        const SizedBox(width: AppSpace.s2),
        Expanded(child: Container(height: 1, color: p.rule)),
      ],
    );
  }
}

/// 区块标题：衬线 H3 + 可选副标题 + 尾部动作。
class SsSectionTitle extends StatelessWidget {
  const SsSectionTitle(this.text, {super.key, this.trailing, this.subtitle});

  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(text, style: AppType.h3.style(p.ink)),
              if (subtitle != null)
                Text(subtitle!, style: AppType.caption.style(p.muted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// KV 读数行：muted 标签 + mono 数值（坐标/距离/角度/F 值等）。
class SsKvRow extends StatelessWidget {
  const SsKvRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.dense = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: dense ? AppSpaceFine.n2 : AppSpace.s1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(child: Text(label, style: AppType.caption.style(p.muted))),
          const SizedBox(width: AppSpace.s2),
          Text(value, style: appMono(valueColor ?? p.ink, size: 12.5)),
        ],
      ),
    );
  }
}

/// 等宽读数徽标（坐标/距离/角度等）。
class SsMonoBadge extends StatelessWidget {
  const SsMonoBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s2,
        vertical: AppSpaceFine.n2,
      ),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: AppRadius.chipBorder,
        border: Border.all(color: p.rule),
      ),
      child: Text(text, style: appMono(p.inkSoft, size: 11)),
    );
  }
}

/// hairline 分割线（1px；§3.3 禁止 2px+）。
class SsDivider extends StatelessWidget {
  const SsDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 1, color: p.rule),
    );
  }
}
