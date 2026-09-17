import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 自研令牌组件库（D12/D13）——拒绝 Material 默认脸。
/// 全部组件只消费 [AppTokens]，明暗主题自动生效。

/// 卡片容器：细边框 + 低层级阴影 + 悬停轻抬（F7 动效体系）。
class SsCard extends StatefulWidget {
  const SsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.s16),
    this.onTap,
    this.selected = false,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry margin;

  @override
  State<SsCard> createState() => _SsCardState();
}

class _SsCardState extends State<SsCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rule = theme.colorScheme.outline;
    final card =
        theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;
    final content = Padding(padding: widget.padding, child: widget.child);
    final bool interactive = widget.onTap != null;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: interactive ? (_) => setState(() => _hover = true) : null,
      onExit: interactive ? (_) => setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: AppTokens.dFast,
        curve: AppTokens.cEmphasis,
        margin: widget.margin,
        transform: Matrix4.translationValues(0, _hover ? -1.5 : 0, 0),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          border: Border.all(
            color: widget.selected
                ? AppTokens.accent
                : _hover
                    ? AppTokens.accent.withValues(alpha: 0.45)
                    : rule,
            width: widget.selected ? 1.5 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark
                      ? (_hover ? 0.42 : 0.32)
                      : (_hover ? 0.10 : 0.04)),
              blurRadius: _hover ? 22 : 14,
              offset: Offset(0, _hover ? 9 : 6),
            ),
          ],
        ),
        child: interactive
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                  onTap: widget.onTap,
                  child: content,
                ),
              )
            : content,
      ),
    );
  }
}

/// 区块标题：小色块 + 标题 + 可选尾部。
class SsSectionTitle extends StatelessWidget {
  const SsSectionTitle(this.text, {super.key, this.trailing, this.subtitle});

  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTokens.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppTokens.s8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 空态（F7：可选程序绘制插画）。
enum SsArt { film, light, pose, compass }

class SsEmpty extends StatelessWidget {
  const SsEmpty(
      {super.key,
      required this.icon,
      required this.title,
      this.hint,
      this.action,
      this.art});

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;
  final SsArt? art;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (art != null)
              SizedBox(
                width: 132,
                height: 84,
                child: CustomPaint(
                  painter: _SsArtPainter(
                    art!,
                    muted.withValues(alpha: 0.35),
                    AppTokens.accent.withValues(alpha: 0.75),
                  ),
                ),
              )
            else
              Icon(icon, size: 44, color: muted.withValues(alpha: 0.5)),
            const SizedBox(height: AppTokens.s12),
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (hint != null) ...<Widget>[
              const SizedBox(height: AppTokens.s4),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: AppTokens.s16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 程序绘制空态插画（F7）：胶片框 / 灯位 / 姿态 / 罗盘。
class _SsArtPainter extends CustomPainter {
  _SsArtPainter(this.art, this.muted, this.accent);

  final SsArt art;
  final Color muted;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = muted
      ..strokeCap = StrokeCap.round;
    final Paint accentPaint = Paint()..color = accent;
    final Rect box = Rect.fromLTWH(0, 6, size.width, size.height - 12);

    switch (art) {
      case SsArt.film:
        final RRect frame = RRect.fromRectAndRadius(
            Rect.fromLTWH(box.left + 8, box.top, box.width - 16, box.height),
            const Radius.circular(6));
        canvas.drawRRect(frame, line);
        for (var i = 0; i < 5; i++) {
          final double x = frame.left + 8 + i * ((frame.width - 16) / 4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(x, frame.top + 6), width: 8, height: 5),
                const Radius.circular(1.5)),
            line,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(x, frame.bottom - 6), width: 8, height: 5),
                const Radius.circular(1.5)),
            line,
          );
        }
        canvas.drawCircle(box.center, 9, accentPaint);
      case SsArt.light:
        final Offset lamp = Offset(box.center.dx, box.top + 16);
        canvas.drawCircle(lamp, 7, accentPaint);
        canvas.drawLine(lamp, Offset(box.left + 16, box.bottom), line);
        canvas.drawLine(lamp, Offset(box.center.dx, box.bottom), line);
        canvas.drawLine(lamp, Offset(box.right - 16, box.bottom), line);
        final Path cone = Path()
          ..moveTo(lamp.dx, lamp.dy + 6)
          ..lineTo(box.left + 10, box.bottom)
          ..lineTo(box.right - 10, box.bottom)
          ..close();
        canvas.drawPath(
          cone,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = muted.withValues(alpha: 0.5),
        );
      case SsArt.pose:
        final Offset hip = Offset(box.center.dx, box.top + box.height * 0.52);
        final Offset neck = Offset(box.center.dx + 4, box.top + 14);
        final Paint body = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..color = muted;
        canvas.drawLine(hip, neck, body);
        canvas.drawCircle(neck - const Offset(0, 8), 7, accentPaint);
        canvas.drawLine(neck, Offset(box.left + 14, box.top + 30), body);
        canvas.drawLine(neck, Offset(box.right - 10, box.top + 22), body);
        canvas.drawLine(hip, Offset(box.left + 20, box.bottom - 4), body);
        canvas.drawLine(hip, Offset(box.right - 18, box.bottom - 4), body);
      case SsArt.compass:
        final Offset center = box.center;
        final double r = box.height / 2;
        canvas.drawCircle(center, r, line);
        canvas.drawCircle(center, r * 0.62, line);
        final Path needle = Path()
          ..moveTo(center.dx, center.dy - r * 0.62)
          ..lineTo(center.dx + 8, center.dy)
          ..lineTo(center.dx, center.dy + r * 0.62)
          ..lineTo(center.dx - 8, center.dy)
          ..close();
        canvas.drawPath(needle, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SsArtPainter oldDelegate) =>
      oldDelegate.art != art || oldDelegate.muted != muted;
}

/// 流光进度条（F7：生成中动效）。
class SsShimmer extends StatefulWidget {
  const SsShimmer({super.key, this.height = 4, this.label});

  final double height;
  final String? label;

  @override
  State<SsShimmer> createState() => _SsShimmerState();
}

class _SsShimmerState extends State<SsShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppTokens.dSlow,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(widget.label!,
              style: const TextStyle(fontSize: 12, color: AppTokens.accent)),
          const SizedBox(height: 6),
        ],
        AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = _controller.value;
            return Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height / 2),
                gradient: LinearGradient(
                  begin: Alignment(-1.6 + 3.2 * t, 0),
                  end: Alignment(-0.6 + 3.2 * t, 0),
                  colors: <Color>[
                    AppTokens.accentSoft,
                    AppTokens.accent.withValues(alpha: 0.75),
                    AppTokens.accent2.withValues(alpha: 0.6),
                    AppTokens.accentSoft,
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 页签切换淡入（F7：保持子页面状态，仅重放透明度/位移）。
class SsFadeSwitch extends StatefulWidget {
  const SsFadeSwitch({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<SsFadeSwitch> createState() => _SsFadeSwitchState();
}

class _SsFadeSwitchState extends State<SsFadeSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppTokens.dFast,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant SsFadeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved =
        CurvedAnimation(parent: _controller, curve: AppTokens.cEmphasis);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// 筛选胶囊。
class SsChip extends StatelessWidget {
  const SsChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: AppTokens.dFast,
        curve: AppTokens.cEmphasis,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.accentSoft
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppTokens.accent : theme.colorScheme.outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? AppTokens.accent : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 主按钮 / 次按钮 / 幽灵按钮。
enum SsButtonKind { primary, soft, ghost }

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
    final theme = Theme.of(context);
    final disabled = onPressed == null;
    final Color bg = switch (kind) {
      SsButtonKind.primary => AppTokens.accent,
      SsButtonKind.soft => AppTokens.accentSoft,
      SsButtonKind.ghost => Colors.transparent,
    };
    final Color fg = switch (kind) {
      SsButtonKind.primary => Colors.white,
      SsButtonKind.soft => AppTokens.accent,
      SsButtonKind.ghost => theme.colorScheme.onSurface,
    };
    return AnimatedOpacity(
      duration: AppTokens.dFast,
      opacity: disabled ? 0.45 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 16,
            vertical: dense ? 7 : 10,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTokens.rSm),
            border: kind == SsButtonKind.ghost
                ? Border.all(color: theme.colorScheme.outline)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: dense ? 15 : 17, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: dense ? 12.5 : 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 表单行：标签 + 控件。
class SsField extends StatelessWidget {
  const SsField(
      {super.key,
      required this.label,
      required this.child,
      this.hint,
      this.copy});

  final String label;
  final Widget child;
  final String? hint;
  final VoidCallback? copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (copy != null)
                    InkWell(
                      onTap: copy,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 10),
              child: Text(
                hint!,
                style: TextStyle(
                    fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// 设置开关行。
class SsToggleRow extends StatelessWidget {
  const SsToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 13.5)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 消息条（内联提示）。
enum SsBannerKind { info, success, warning, danger }

class SsBanner extends StatelessWidget {
  const SsBanner(
      {super.key, required this.text, this.kind = SsBannerKind.info});

  final String text;
  final SsBannerKind kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      SsBannerKind.info => AppTokens.accent,
      SsBannerKind.success => AppTokens.success,
      SsBannerKind.warning => AppTokens.warning,
      SsBannerKind.danger => AppTokens.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            switch (kind) {
              SsBannerKind.info => Icons.info_outline_rounded,
              SsBannerKind.success => Icons.check_circle_outline_rounded,
              SsBannerKind.warning => Icons.warning_amber_rounded,
              SsBannerKind.danger => Icons.error_outline_rounded,
            },
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(text, style: TextStyle(fontSize: 12.5, color: color))),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        text,
        style: AppTokens.mono(
          context,
          size: 11,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 轻提示。
void ssToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// 轻量横幅（成功/提示）。
class SsBannerLite extends StatelessWidget {
  const SsBannerLite({super.key, required this.text, this.success = false});

  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? AppTokens.success : AppTokens.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11.5, color: color)),
    );
  }
}

/// 模块页统一骨架：标题栏 + 分隔线 + 主体。
class SsPage extends StatelessWidget {
  const SsPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const <Widget>[],
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 12),
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outline),
        Expanded(child: Padding(padding: padding, child: body)),
      ],
    );
  }
}
