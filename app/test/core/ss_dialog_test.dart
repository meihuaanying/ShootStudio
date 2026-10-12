// V8.7 / R74：sanctioned 弹层 API 的通用入口与动作按钮。
//
// 背景：`showSsConfirm` 只覆盖「确认/取消 → bool」。R74 §3 C 类 6 处弹层要把
// `String` / `Map` / record 交回调用方，此前只能在 feature 里裸写
// `showDialog<T> + AlertDialog`。本次补 `showSsDialog<T>`（返回值类型由调用方
// 决定）与 `SsDialogAction`（弹层动作按钮，令牌单一来源），本文件把它们钉住。
//
// 同时给 `showSsConfirm` 加回归保护：它内部的动作按钮已改为复用
// `SsDialogAction`，必须证明「遮罩关闭 → false」「确认 → true」没变。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/design/widgets.dart';

/// 触发弹层的宿主：把 `open` 拿到的 Future 记在调用方变量上，便于断言返回值。
class _Host extends StatelessWidget {
  const _Host({required this.open});

  final Future<void> Function(BuildContext ctx) open;

  static const String _label = '打开';

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Builder(
      builder: (BuildContext ctx) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => open(ctx),
            child: const Text(_label),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('V8.7 弹层 API：通用入口 showSsDialog<T>', () {
    testWidgets('按钮可回传任意类型（String）', (tester) async {
      late Future<String?> result;
      Future<void> open(BuildContext ctx) async {
        result = showSsDialog<String>(
          context: ctx,
          title: '补图 · 相机',
          child: const Text('选择本地图片，或粘贴图片链接。'),
          actions: (BuildContext c) => <Widget>[
            SsDialogAction(label: '取消', primary: false),
            SsDialogAction(
              label: '选择本地图片',
              primary: false,
              onPressed: () => Navigator.pop(c, 'file'),
            ),
            SsDialogAction(
              label: '粘贴图片链接',
              primary: false,
              onPressed: () => Navigator.pop(c, 'url'),
            ),
          ],
        );
      }

      await tester.pumpWidget(_Host(open: open));
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(
        find.text('补图 · 相机'),
        findsOneWidget,
        reason: '弹层标题应由 SsDialog 渲染',
      );
      expect(
        find.text('选择本地图片，或粘贴图片链接。'),
        findsOneWidget,
        reason: '富内容应原样落在 child 里',
      );

      await tester.tap(find.text('粘贴图片链接'));
      await tester.pumpAndSettle();

      expect(find.text('补图 · 相机'), findsNothing, reason: '点按钮后弹层应关闭');
      expect(await result, 'url', reason: 'C 类的关键：返回值必须是调用方给的 String，而不是 bool');
    });

    testWidgets('点遮罩关闭时返回 null（与 bool 版不同，文档已写明）', (tester) async {
      late Future<String?> result;
      await tester.pumpWidget(
        _Host(
          open: (BuildContext ctx) async {
            result = showSsDialog<String>(
              context: ctx,
              title: '选择来源',
              child: const Text('正文'),
              actions: (BuildContext c) => <Widget>[
                SsDialogAction(label: '取消', primary: false),
                SsDialogAction(
                  label: '文件',
                  onPressed: () => Navigator.pop(c, 'file'),
                ),
              ],
            );
          },
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('选择来源'), findsOneWidget);

      // 屏幕左上角必然在弹层之外（默认 insetPadding = AppSpace.block）。
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.text('选择来源'), findsNothing, reason: '默认允许点遮罩关闭');
      expect(
        await result,
        isNull,
        reason: '通用入口不做 ?? false 兜底，遮罩关闭即 null，由调用方决定含义',
      );
    });

    testWidgets('barrierDismissible: false 时遮罩点不掉', (tester) async {
      late Future<void> result;
      await tester.pumpWidget(
        _Host(
          open: (BuildContext ctx) async {
            result = showSsDialog<void>(
              context: ctx,
              title: '导入中',
              barrierDismissible: false,
              child: const Text('请稍候'),
              actions: (BuildContext c) => <Widget>[
                SsDialogAction(label: '关闭', primary: false),
              ],
            );
          },
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(
        find.text('导入中'),
        findsOneWidget,
        reason: '导入/进度类弹层不能被误点遮罩关掉（原裸 showDialog 的常用参数）',
      );

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('导入中'), findsNothing);
      await result; // void 型入口不产生业务返回值，等它收尾即可
    });
  });

  group('V8.7 弹层 API：SsDialogAction 形态', () {
    testWidgets('primary 用实心、次要动作用文字按钮', (tester) async {
      await tester.pumpWidget(
        _Host(
          open: (BuildContext ctx) async {
            unawaited(
              showSsDialog<void>(
                context: ctx,
                title: '确认覆盖',
                actions: (BuildContext c) => <Widget>[
                  SsDialogAction(label: '取消', primary: false),
                  SsDialogAction(label: '删除', danger: true),
                ],
              ),
            );
          },
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '删除'), findsOneWidget);

      // danger 用告警色：与 showSsConfirm 的 danger 同一令牌来源。
      final AppPalette paper = AppTokensV2.paletteOf(AppThemeVariant.paper);
      final FilledButton dangerBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '删除'),
      );
      expect(
        dangerBtn.style?.backgroundColor?.resolve(<WidgetState>{}),
        paper.danger,
      );
    });
  });

  group('V8.7 弹层 API：showSsConfirm 重构后行为不变', () {
    testWidgets('确认返回 true，遮罩关闭返回 false', (tester) async {
      late Future<bool> confirmResult;
      Future<void> openConfirm(BuildContext ctx) async {
        confirmResult = showSsConfirm(
          ctx,
          title: '删除姿势？',
          message: '不可撤销。',
          confirmLabel: '删除',
          danger: true,
        );
      }

      await tester.pumpWidget(_Host(open: openConfirm));
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('删除姿势？'), findsOneWidget);
      expect(find.text('不可撤销。'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(await confirmResult, isTrue);

      // 第二次：点遮罩 → 必须仍是 false（原来就是 `result ?? false`）。
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(
        await confirmResult,
        isFalse,
        reason: '遮罩关闭在 bool 版里一律折算成 false，迁移方靠的就是这条',
      );
    });
  });

  group('V8.7 弹层 API：SsSheet 装富内容', () {
    testWidgets('表单与可滚动列表都能放进底部抽屉', (tester) async {
      await tester.pumpWidget(
        _Host(
          open: (BuildContext ctx) async {
            unawaited(
              showSsSheet<void>(
                context: ctx,
                title: '编辑条目',
                eyebrow: '库',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const TextField(
                      decoration: InputDecoration(labelText: '名称'),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        children: const <Widget>[
                          ListTile(title: Text('条目 A')),
                          ListTile(title: Text('条目 B')),
                          ListTile(title: Text('条目 C')),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: <Widget>[SsDialogAction(label: '取消', primary: false)],
              ),
            );
          },
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('编辑条目'), findsOneWidget);
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'A 类「带 TextField 表单」必须真的能装进来',
      );
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('条目 A'), findsOneWidget);

      // 能输入 = 抽屉没有把输入焦点吃掉。
      await tester.enterText(find.byType(TextField), '新名称');
      await tester.pumpAndSettle();
      expect(find.text('新名称'), findsOneWidget);

      // 滚动列表不抛异常（SingleChildScrollView + 内层 ListView 嵌套的边界）。
      await tester.drag(find.byType(ListView), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // V8.8 补：这条是迁移时最容易踩的坑 ——
    // `SsDialogAction(label: '关闭', primary: false)` 不写 onPressed 时，
    // 若实现把 null 直接透给 TextButton，按钮会**变成禁用态、点不动**，
    // 弹层关不掉。实现里是 `onPressed ?? () => Navigator.of(context).pop()`，
    // 这里把「不写 onPressed 也能关掉」钉住。
    testWidgets('SsDialogAction 无 onPressed 时点一下就能关掉弹层', (tester) async {
      await tester.pumpWidget(
        _Host(
          open: (BuildContext ctx) async {
            await showSsDialog<void>(
              context: ctx,
              title: '关闭动作回归',
              actions: (BuildContext actx) => <Widget>[
                SsDialogAction(label: '关闭', primary: false),
              ],
            );
          },
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('关闭动作回归'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(
        find.text('关闭动作回归'),
        findsNothing,
        reason: '不写 onPressed 的动作必须仍能 pop（否则弹层关不掉）',
      );
    });
  });
}
