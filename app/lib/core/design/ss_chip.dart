/// V8/D147 · S3：Chip / 标签 / Tabs（§3.5）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 筛选胶囊（圆角 2；选中 accentSoft 底 + 印相红字）。
class SsChip extends StatelessWidget {
  const SsChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.chipBorder,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s1,
        ),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: AppRadius.chipBorder,
          border: Border.all(color: selected ? p.accent : p.rule),
        ),
        child: Text(
          label,
          style: AppType.small.style(
            selected ? p.accent : p.inkSoft,
            weight: selected ? AppFontWeight.medium : AppFontWeight.regular,
          ),
        ),
      ),
    );
  }
}

/// 静态标签（eyebrow 风格：mono + 字距 1.5 + hairline 边框）。
class SsTag extends StatelessWidget {
  const SsTag({super.key, required this.label, this.tone = SsTagTone.neutral});

  final String label;
  final SsTagTone tone;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final (Color color, Color bg) = switch (tone) {
      SsTagTone.neutral => (p.inkSoft, p.surfaceSunken),
      SsTagTone.accent => (p.accent, p.accentSoft),
      SsTagTone.positive => (p.film, p.film.withValues(alpha: 0.12)),
      SsTagTone.warning => (p.gold, p.gold.withValues(alpha: 0.12)),
      SsTagTone.danger => (p.danger, p.danger.withValues(alpha: 0.12)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.chipBorder,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: appEyebrow(color)),
    );
  }
}

/// 标签语气。
enum SsTagTone { neutral, accent, positive, warning, danger }

/// Tabs：hairline 底线 + 印相红指示（§3.3 禁用 2px+ 边框 → 指示线 1px）。
class SsTabs extends StatelessWidget {
  const SsTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s2,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == index ? p.accent : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: AppType.small.style(
                    i == index ? p.accent : p.muted,
                    weight: i == index
                        ? AppFontWeight.medium
                        : AppFontWeight.regular,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
