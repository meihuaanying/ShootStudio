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
          // 内容区垫一层透明 Material：ListTile 的背景与墨迹、按钮的水波都要画在
          // 「最近的 Material 祖先」上。原 `AlertDialog` 自带 Material，而本组件
          // 把底色画在 Container(DecoratedBox) 上却没有 Material —— 于是 Dialog 里
          // 的 ListTile 会触发 “background color or ink splashes may be invisible”
          // 断言（实测 test/features/f4_editors_test.dart 报 15 条）。
          // 用 `MaterialType.transparency`：它不往中间插 ColoredBox/DecoratedBox，
          // 底色与描边仍由外层 Container 独占，视觉不变。
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (eyebrow != null)
                  Text(eyebrow!, style: appEyebrow(p.accent)),
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

/// 通用弹层入口：返回值类型由调用方决定（V8.7 补，覆盖 R74 C 类）。
///
/// `showSsConfirm` 只覆盖「确认/取消 → bool」。表单、选择器、粘贴链接这类
/// 弹层必须把 `String` / `Map` / record 交回调用方，此前只能在 feature 里
/// 裸写 `showDialog<T> + AlertDialog`（R74 §3 C 类）。这里补上同一条路子，
/// 视觉仍全部来自 [SsDialog]，不让 feature 自己拼弹层外观。
///
/// `actions` 用 builder 形态，是为了让调用方能拿到弹层自己的 `BuildContext`
/// 去 `Navigator.of(ctx).pop(value)` —— 返回值在按下按钮那一刻才求值，
/// 所以选择器类弹层应先在回调里读控件状态、再 pop。
Future<T?> showSsDialog<T>({
  required BuildContext context,
  required String title,
  String? eyebrow,
  String? subtitle,
  Widget? child,
  List<Widget> Function(BuildContext ctx)? actions,
  bool barrierDismissible = true,
  double maxWidth = 560,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: (BuildContext ctx) => SsDialog(
    eyebrow: eyebrow,
    title: title,
    subtitle: subtitle,
    maxWidth: maxWidth,
    actions: actions == null ? const <Widget>[] : actions(ctx),
    child: child,
  ),
);

/// 弹层动作按钮：`primary` 形态与 [showSsConfirm] 的确认键同一套令牌
/// （单一来源），`primary: false` 为次要形态（取消 / 关闭）。
///
/// `onPressed` 留空表示「仅关闭」。需要回传值的弹层在按下那一刻
/// `Navigator.of(context).pop(value)` —— 值是 `T` 还是别的类型由调用方决定，
/// 故本件不做成泛型（`void?` 之类的类型实参不合法，泛型只会逼调用方写
/// 显式类型实参，反而更难读）。
class SsDialogAction extends StatelessWidget {
  const SsDialogAction({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = true,
    this.danger = false,
  });

  final String label;

  /// 留空 = 仅关闭弹层（等同 `pop()`）。
  final VoidCallback? onPressed;

  /// 主按钮（实心 + 强调色）还是次要按钮（文字）。
  final bool primary;

  /// 主按钮是否用告警色（删除 / 覆盖类决策）。
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final VoidCallback handle = onPressed ?? () => Navigator.of(context).pop();
    if (!primary) {
      return TextButton(onPressed: handle, child: Text(label));
    }
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: danger ? p.danger : p.accent,
        foregroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.controlBorder,
        ),
      ),
      onPressed: handle,
      child: Text(label),
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
        SsDialogAction(
          label: cancelLabel,
          primary: false,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        SsDialogAction(
          label: confirmLabel,
          danger: danger,
          onPressed: () => Navigator.of(ctx).pop(true),
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
  barrierColor: AppScrim.sheet,
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
