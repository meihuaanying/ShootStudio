// P2 · 可访问性（R82/R74 收尾）：为已实现的 Semantics 补断言。
//
// 背景：`lib` 里有 4 处 `Semantics(` 实现（语义按钮 + 可读标签），
// 但测试侧一条断言都没有 —— 「有实现、无覆盖」意味着这些标签会被
// 后续改动悄悄改掉而没有任何门禁会红。这份测试把它们钉住。
//
// 覆盖对象（`lib/` 全部 4 处，除 `refs_home.dart:149 _themeChip` 是私有内部件）：
//   - `RefsThemeCard`（refs_home.dart:268）   Semantics(button: true, label: '主题画报 X')
//   - `RefsPaletteStrip`（refs_palette.dart:29）Semantics(label: '五色色卡')
//   - `RefsHitCard._MiniAction`（refs_hit_card.dart:185）Semantics(button: true, label: …)
// `_themeChip` 所在的是 `RefsHomeHeader`，构造需要 controller/focusNode/status 等
// 十余个参数，且该私有件本身在 S5 的 UI 用例里已通过点击链路间接覆盖，故不单测。

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/refs/refs_hit_card.dart';
import 'package:shoot_studio/features/refs/refs_home.dart';
import 'package:shoot_studio/features/refs/refs_palette.dart';
import 'package:shoot_studio/services/search/search_models.dart';
import 'package:shoot_studio/services/search/theme_packs.dart';

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('P2 可访问性：语义标签与按钮角色', () {
    testWidgets('RefsThemeCard 暴露为按钮且标签含主题名', (tester) async {
      const pack = ThemePack(
        id: 'portrait',
        name: '人像',
        description: '人像主题',
        zhTerms: <String>['人像'],
        enQuery: 'portrait',
      );
      final SemanticsHandle handle = tester.ensureSemantics();
      // 不能只靠 addTearDown：tearDown 跑在断言之后，而 flutter_test 在
      // 「测试体结束、tearDown 之前」就会校验 SemanticsHandle 已释放
      // （WidgetTester._verifySemanticsHandlesWereDisposed）。
      // 实测报错：「A SemanticsHandle was active at the end of the test」。
      // 所以拿到语义节点后必须显式 dispose，再断言。

      await tester.pumpWidget(_wrap(RefsThemeCard(pack: pack, onTap: () {})));
      await tester.pumpAndSettle();

      // 同 test 2：不用 getSemantics(find.byType(...))，改用「带 label 的
      // Semantics 控件」收集，避免复合结构取不到语义节点。
      final Finder semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.trim().isNotEmpty,
      );
      final List<SemanticsNode> nodes = semanticsFinder
          .evaluate()
          .map((e) => tester.getSemantics(find.byWidget(e.widget)))
          .toList();
      handle.dispose();

      expect(nodes, isNotEmpty, reason: 'RefsThemeCard 应产生语义节点');
      final SemanticsNode node = nodes.first;
      // 新版把 flags 拆成具名布尔，「是不是按钮」直接读 flagsCollection.isButton。
      expect(node.flagsCollection.isButton, isTrue, reason: '主题画报卡应被辅助技术识别为按钮');
      expect(node.label, contains('主题画报'), reason: '标签应说明这是什么，而不只是露出一串色块');
      expect(node.label, contains('人像'), reason: '标签应带上具体主题名，否则多个卡片对读屏完全一样');
    });

    testWidgets('RefsPaletteStrip 有色卡语义标签', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      // 同 test 1：tearDown 之前 flutter_test 会先校验 handle 已释放，
      // 所以必须在这里显式 dispose，不能只挂 addTearDown。

      await tester.pumpWidget(
        _wrap(
          const RefsPaletteStrip(
            colors: <String>['#111111', '#222222', '#333333'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 不用 getSemantics(find.byType(...))：那要求控件本身在语义树里有对应
      // 节点，实测 RefsThemeCard 这种「Semantics 包 SizedBox+Column」的复合
      // 结构取不到（Bad state: Finder returned no matching elements）。
      // 改为按「带非空 label 的 Semantics 控件」收集语义节点，与 test 3 同法。
      final Finder semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.trim().isNotEmpty,
      );
      final List<SemanticsNode> nodes = semanticsFinder
          .evaluate()
          .map((e) => tester.getSemantics(find.byWidget(e.widget)))
          .toList();
      handle.dispose();

      expect(nodes, isNotEmpty, reason: 'RefsPaletteStrip 应产生语义节点');
      expect(
        nodes.any((n) => n.label.contains('五色色卡')),
        isTrue,
        reason: '色卡是纯视觉元素，必须给读屏用户一句可读说明',
      );
    });

    testWidgets('RefsHitCard 的悬停动作是带标签的按钮', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final hit = const SearchHit(
        id: 'h1',
        title: 'a photo',
        thumbUrl: 'https://example.invalid/a.jpg',
        fullUrl: 'https://example.invalid/full.jpg',
        sourceId: 'pexels',
        sourceLabel: 'Pexels',
        license: 'pexels',
        width: 1600,
        height: 900,
      );

      await tester.pumpWidget(
        _wrap(
          RefsHitCard(
            hit: hit,
            onOpen: () {},
            onAdd: () {},
            onSearchSimilar: () {},
            hovered: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // _MiniAction 是 RefsHitCard 内部的私有件，这里按「有语义标签」这一
      // 结果来断言，而不是按私有类型找控件。
      // 注意：Semantics widget 的 label 在 properties 里（SemanticsProperties），
      // 不在 widget 顶层；Semantics widget 的 properties 可为 null，需判空。
      final Finder semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.trim().isNotEmpty,
      );
      final List<SemanticsNode> nodes = semanticsFinder
          .evaluate()
          .map((e) => tester.getSemantics(find.byWidget(e.widget)))
          .toList();
      // 与前两条同理：tearDown 之前会校验 handle 已释放。
      handle.dispose();

      expect(semanticsFinder, findsWidgets, reason: '结果卡的悬停动作必须带可读语义标签');
      expect(
        nodes.any((n) => n.flagsCollection.isButton),
        isTrue,
        reason: '至少要有一个悬停动作被标记为按钮（收藏/以图搜图等）',
      );
      expect(
        nodes.where((n) => n.label.trim().isNotEmpty).isNotEmpty,
        isTrue,
        reason: '语义标签不能为空，否则读屏只读出「按钮」',
      );
    });
  });
}
