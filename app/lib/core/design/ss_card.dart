/// V8/D147 · S3：卡片（文卡 / 图卡 / 数据卡）+ 模块页骨架（§3.5）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'ss_image_frame.dart';
import 'tokens.dart';

/// 文卡：hairline 边框 + 一级纸感阴影 + 悬停轻抬。
class SsCard extends StatefulWidget {
  const SsCard({
    super.key,
    required this.child,
    this.padding = AppSpace.card,
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
    final AppPalette p = context.palette;
    final bool interactive = widget.onTap != null;
    final Widget content = Padding(
      padding: widget.padding,
      child: widget.child,
    );
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: interactive ? (_) => setState(() => _hover = true) : null,
      onExit: interactive ? (_) => setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        margin: widget.margin,
        transform: Matrix4.translationValues(0, _hover ? -1.5 : 0, 0),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.controlBorder,
          border: Border.all(
            color: widget.selected
                ? p.accent
                : _hover
                ? p.accent.withValues(alpha: 0.45)
                : p.rule,
          ),
          boxShadow: appShadowPaper(p.ink),
        ),
        child: interactive
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: AppRadius.controlBorder,
                  onTap: widget.onTap,
                  child: content,
                ),
              )
            : content,
      ),
    );
  }
}

/// 图卡：图片帧（比例锁）+ 衬线标题 + mono 元信息。
class SsImageCard extends StatelessWidget {
  const SsImageCard({
    super.key,
    required this.title,
    this.subtitle,
    this.image,
    this.ratio = SsFrameRatio.threeTwo,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final Widget? image;
  final SsFrameRatio ratio;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return SsCard(
      onTap: onTap,
      selected: selected,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (image != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.control),
              ),
              child: image!,
            ),
          Padding(
            padding: AppSpace.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.h3.style(p.ink),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.style(p.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 数据卡：eyebrow 眉题 + 大号 mono 读数 + 单位/说明。
class SsDataCard extends StatelessWidget {
  const SsDataCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.hint,
  });

  final String label;
  final String value;
  final String? unit;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label.toUpperCase(), style: appEyebrow(p.muted)),
          const SizedBox(height: AppSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(child: Text(value, style: appMono(p.ink, size: 20))),
              if (unit != null) ...<Widget>[
                const SizedBox(width: AppSpace.s1),
                Text(unit!, style: appMono(p.muted, size: 11)),
              ],
            ],
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: AppSpace.s1),
            Text(hint!, style: AppType.caption.style(p.muted)),
          ],
        ],
      ),
    );
  }
}

/// 模块页统一骨架：眉题 + 衬线标题 + hairline + 主体。
class SsPage extends StatelessWidget {
  const SsPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.eyebrow,
    this.actions = const <Widget>[],
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.s4,
      AppSpace.s3,
      AppSpace.s4,
      AppSpace.s3,
    ),
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final List<Widget> actions;
  final Widget body;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s4,
            AppSpace.s4,
            AppSpace.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (eyebrow != null)
                      Text(eyebrow!, style: appEyebrow(p.accent)),
                    Text(title, style: AppType.h1.style(p.ink)),
                    if (subtitle != null)
                      Text(subtitle!, style: AppType.small.style(p.muted)),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Divider(height: 1, color: p.rule),
        Expanded(
          child: Padding(padding: padding, child: body),
        ),
      ],
    );
  }
}
