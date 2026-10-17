/// V8/D147 · S3：底部抽屉（§3.5）—— 与对话框同族，V8.21 自 ss_dialog.dart 拆分。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 底部抽屉：顶部 hairline + 8 圆角 + 弹层阴影。
///
/// V8.21 补 `subtitle` / `trailing` 两个可选位（默认 null = 不渲染，对既有调用方
/// 零变更），以便把 feature 侧自拼的「标题 + 副标题 + 右侧操作」整段收口进来。
class SsSheet extends StatelessWidget {
  const SsSheet({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? eyebrow;

  /// 标题下的次级说明（V8.21 补；默认 null = 不渲染，对既有调用方零变更）。
  final String? subtitle;

  /// 标题下方的右侧操作位（V8.21 补；默认 null = 不渲染，对既有调用方零变更）。
  final Widget? trailing;

  final Widget? child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.rule)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.frame),
        ),
        boxShadow: appShadowOverlay(p.ink),
      ),
      padding: AppSpace.block,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (eyebrow != null) Text(eyebrow!, style: appEyebrow(p.accent)),
          Text(title, style: AppType.h2.style(p.ink)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s1),
              child: Text(subtitle!, style: AppType.small.style(p.muted)),
            ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing!),
          if (child != null) ...<Widget>[
            const SizedBox(height: AppSpace.s3),
            Flexible(child: SingleChildScrollView(child: child!)),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpace.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                for (final Widget action in actions)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpace.s2),
                    child: action,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 底部抽屉入口。
Future<T?> showSsSheet<T>({
  required BuildContext context,
  required String title,
  String? eyebrow,
  String? subtitle,
  Widget? trailing,
  Widget? child,
  List<Widget> actions = const <Widget>[],
  double? maxWidth,
}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  barrierColor: AppScrim.sheet,
  constraints: maxWidth == null ? null : BoxConstraints(maxWidth: maxWidth),
  builder: (BuildContext ctx) => Padding(
    padding: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + AppSpace.s5),
    child: SsSheet(
      title: title,
      eyebrow: eyebrow,
      subtitle: subtitle,
      trailing: trailing,
      actions: actions,
      child: child,
    ),
  ),
);
