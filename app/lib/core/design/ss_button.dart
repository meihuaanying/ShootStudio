/// V8/D147 · S3：按钮四态（§3.5「主红 / 描边 / 文字 / 图标」）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 按钮四态：主红 / 描边 / 文字 / 图标。
enum SsButtonKind { primary, outline, text, icon }

/// 主按钮 / 描边按钮 / 文字按钮。
class SsButton extends StatelessWidget {
  const SsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = SsButtonKind.primary,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SsButtonKind kind;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final bool disabled = onPressed == null;
    final (Color bg, Color fg, Color? border) = switch (kind) {
      SsButtonKind.primary => (p.accent, p.surface, null),
      SsButtonKind.outline => (Colors.transparent, p.ink, p.rule),
      SsButtonKind.text => (Colors.transparent, p.accent, null),
      SsButtonKind.icon => (Colors.transparent, p.ink, null),
    };
    final TextStyle labelStyle = (dense ? AppType.small : AppType.body).style(
      fg,
      weight: AppFontWeight.medium,
    );
    return AnimatedOpacity(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      opacity: disabled ? 0.45 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.controlBorder,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? AppSpace.s3 : AppSpace.s4,
            vertical: dense ? AppSpace.s2 : AppSpace.s3,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.controlBorder,
            border: border == null ? null : Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: dense ? 15 : 17, color: fg),
                const SizedBox(width: AppSpace.s2),
              ],
              Flexible(
                child: Text(
                  label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图标按钮（选中态用 accentSoft 底 + 印相红图标）。
class SsIconButton extends StatelessWidget {
  const SsIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
    this.size = 20,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Widget button = InkWell(
      onTap: onPressed,
      borderRadius: AppRadius.controlBorder,
      child: Container(
        width: size + AppSpace.s4,
        height: size + AppSpace.s4,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : Colors.transparent,
          borderRadius: AppRadius.controlBorder,
          border: Border.all(color: selected ? p.accent : p.rule),
        ),
        child: Icon(icon, size: size, color: selected ? p.accent : p.inkSoft),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(
      message: tooltip!,
      waitDuration: AppMotion.fast,
      child: button,
    );
  }
}
