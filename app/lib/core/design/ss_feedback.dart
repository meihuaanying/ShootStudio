/// V8/D147 · S3：消息条 / Toast / Tooltip（§3.5）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 内联消息条语气。
enum SsBannerKind { info, success, warning, danger }

/// 内联消息条（hairline 边框 + 语义色底纹）。
class SsBanner extends StatelessWidget {
  const SsBanner({
    super.key,
    required this.text,
    this.kind = SsBannerKind.info,
  });

  final String text;
  final SsBannerKind kind;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Color color = _colorOf(p, kind);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.chipBorder,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(_iconOf(kind), size: 16, color: color),
          const SizedBox(width: AppSpace.s2),
          Expanded(child: Text(text, style: AppType.small.style(color))),
        ],
      ),
    );
  }
}

/// 轻量横幅（成功/提示，行内小字）。
class SsBannerLite extends StatelessWidget {
  const SsBannerLite({super.key, required this.text, this.success = false});

  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Color color = success ? p.film : p.gold;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s2,
        vertical: AppSpace.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.chipBorder,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: AppType.caption.style(color)),
    );
  }
}

Color _colorOf(AppPalette p, SsBannerKind kind) => switch (kind) {
  SsBannerKind.info => p.accent,
  SsBannerKind.success => p.film,
  SsBannerKind.warning => p.gold,
  SsBannerKind.danger => p.danger,
};

IconData _iconOf(SsBannerKind kind) => switch (kind) {
  SsBannerKind.info => Icons.info_outline_rounded,
  SsBannerKind.success => Icons.check_circle_outline_rounded,
  SsBannerKind.warning => Icons.warning_amber_rounded,
  SsBannerKind.danger => Icons.error_outline_rounded,
};

/// 轻提示（Toast）：ink 底 + bg 文字（§3.5）。
void ssToast(
  BuildContext context,
  String message, {
  SsBannerKind kind = SsBannerKind.info,
  Duration duration = AppMotion.slow,
}) {
  final AppPalette p = context.palette;
  final Color color = _colorOf(p, kind);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: p.ink,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.controlBorder,
        ),
        content: Row(
          children: <Widget>[
            Icon(_iconOf(kind), size: 15, color: color),
            const SizedBox(width: AppSpace.s2),
            Expanded(child: Text(message, style: AppType.small.style(p.bg))),
          ],
        ),
      ),
    );
}

/// Tooltip 包装（§3.5）：ink 底 + bg 文字 + 160ms 延迟。
class SsTooltip extends StatelessWidget {
  const SsTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Tooltip(message: message, waitDuration: AppMotion.fast, child: child);
}
