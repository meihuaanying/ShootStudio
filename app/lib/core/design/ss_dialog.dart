/// V8/D147 · S3：对话框与底部抽屉（§3.5）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 对话框：eyebrow 眉题 + 衬线标题 + hairline 底 + 弹层阴影（§3.3）。
class SsDialog extends StatelessWidget {
  const SsDialog({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.child,
    this.actions = const <Widget>[],
    this.maxWidth = 560,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? child;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: AppSpace.block,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.frameBorder,
            border: Border.all(color: p.rule),
            boxShadow: appShadowOverlay(p.ink),
          ),
          padding: AppSpace.block,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (eyebrow != null) Text(eyebrow!, style: appEyebrow(p.accent)),
              Text(title, style: AppType.h2.style(p.ink)),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpace.s1),
                Text(subtitle!, style: AppType.small.style(p.muted)),
              ],
              if (child != null) ...<Widget>[
                const SizedBox(height: AppSpace.s3),
                Divider(height: 1, color: p.rule),
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
        ),
      ),
    );
  }
}

/// 底部抽屉：顶部 hairline + 8 圆角 + 弹层阴影。
class SsSheet extends StatelessWidget {
  const SsSheet({
    super.key,
    required this.title,
    this.eyebrow,
    this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? eyebrow;
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

/// 确认对话框（§3.5「对话框」+ R76 迁移/重置类决策必须走它）。
Future<bool> showSsConfirm(
  BuildContext context, {
  required String title,
  String? eyebrow,
  String? message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool danger = false,
}) async {
  final AppPalette p = context.palette;
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => SsDialog(
      eyebrow: eyebrow,
      title: title,
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? p.danger : p.accent,
            foregroundColor: p.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.controlBorder,
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      child: message == null
          ? null
          : Text(message, style: AppType.body.style(p.inkSoft)),
    ),
  );
  return result ?? false;
}

/// 底部抽屉入口。
Future<T?> showSsSheet<T>({
  required BuildContext context,
  required String title,
  String? eyebrow,
  Widget? child,
  List<Widget> actions = const <Widget>[],
}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  barrierColor: const Color(0x99000000),
  builder: (BuildContext ctx) => Padding(
    padding: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + AppSpace.s5),
    child: SsSheet(
      title: title,
      eyebrow: eyebrow,
      actions: actions,
      child: child,
    ),
  ),
);
