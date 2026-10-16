// V8.14 / C2 · sanctioned 输入件 `SsTextInput` 的 API 扩展与一个真缺陷的回归。
//
// 背景：`lib/features` 里有 60 处裸 `TextField(`（组件门禁 `check_components.mjs`
// 计数），要迁到 sanctioned 输入件，就得先让 `SsTextInput` 能表达它们实际用到的
// 参数（`onSubmitted` / `maxLines` / `minLines` / `maxLength` / `keyboardType` /
// `textInputAction` / `focusNode` / `dense`）。本文件钉住这些透传。
//
// 同时钉住一个此前**静默失效**的参数：`initialValue` 曾被声明但 `build()` 从未
// 使用（`TextField` 本身没有 `initialValue`），于是
// `SsTextInput(label: '项目名', initialValue: 'CITY-NIGHT')`
// 会渲染成一个空框。要让它生效必须有个 controller，故该组件由 StatelessWidget
// 改为 StatefulWidget（仅在调用方未提供 controller 时自建并释放）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/design/widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('SsTextInput · sanctioned 输入件', () {
    testWidgets('initialValue 生效（回归：此前被 build() 静默忽略）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SsTextInput(label: '项目名', initialValue: 'CITY-NIGHT')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('CITY-NIGHT'),
        findsOneWidget,
        reason: 'initialValue 应真的渲染进输入框，而不是被忽略',
      );
    });

    testWidgets('调用方提供的 controller 优先于 initialValue', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController(
        text: '来自 controller',
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _wrap(SsTextInput(label: '项目名', controller: c, initialValue: '不应出现')),
      );
      await tester.pumpAndSettle();
      expect(find.text('来自 controller'), findsOneWidget);
      expect(
        find.text('不应出现'),
        findsNothing,
        reason: '外部 controller 存在时不应被 initialValue 覆盖',
      );
    });

    testWidgets('maxLines / minLines / maxLength 透传到 TextField', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SsTextInput(
            label: '备注',
            maxLines: 3,
            minLines: 2,
            maxLength: 30,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final TextField f = tester.widget<TextField>(find.byType(TextField));
      expect(f.maxLines, 3);
      expect(f.minLines, 2);
      expect(f.maxLength, 30);
    });

    testWidgets('onSubmitted / keyboardType / textInputAction 透传', (
      WidgetTester tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        _wrap(
          SsTextInput(
            label: '标签',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (String v) => submitted = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final TextField f = tester.widget<TextField>(find.byType(TextField));
      expect(f.keyboardType, TextInputType.number);
      expect(f.textInputAction, TextInputAction.done);
      f.onSubmitted?.call('回眸');
      expect(submitted, '回眸', reason: 'onSubmitted 未透传');
    });

    testWidgets('obscure / dense 透传，且 label 可省略', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const SsTextInput(hint: '搜索姿势名', obscure: true, dense: true)),
      );
      await tester.pumpAndSettle();
      final TextField f = tester.widget<TextField>(find.byType(TextField));
      expect(f.obscureText, isTrue);
      expect(f.decoration?.isDense, isTrue);
      expect(f.decoration?.labelText, isNull, reason: 'label 应可省略');
      expect(f.decoration?.hintText, '搜索姿势名');
    });
  });
}
