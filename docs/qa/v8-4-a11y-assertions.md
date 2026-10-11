# V8.4 / P2-2 可访问性断言（为已实现的 Semantics 补门禁）

> 合同依据：R82 反模式（「低清充数 / 虚报覆盖率 / 跳过门禁」出现即返工）与
> R74 组件收尾的验收口径 ——「有实现、无覆盖」与「没实现」在门禁上等价。

## 1. 问题

`lib/` 里共有 **4 处 `Semantics(`** 实现（语义按钮角色 + 可读标签），但测试侧
**一条断言都没有**。后果不是「读屏用户现在用不了」，而是：**这些标签会被后续
改动悄悄改掉、甚至整段删掉，而没有任何门禁会红**。本次把它们钉住。

| 位置 | 内容 | 是否单测 |
|---|---|---|
| `refs_hit_card.dart:185` `_MiniAction` | `button: true, label: …` | ✅（经 test 3） |
| `refs_home.dart:150` `_themeChip` | `button: true, label: '主题画报 X'` | ❌ 私有件，见 §4 |
| `refs_home.dart:268` `RefsThemeCard` | `button: true, label: '主题画报 X'` | ✅（test 1） |
| `refs_palette.dart:29` `RefsPaletteStrip` | `label: '五色色卡'` | ✅（test 2） |

## 2. 交付物

`app/test/features/p2_a11y_test.dart`（新，3 条 `testWidgets`，全绿）。

## 3. 调通过程中定位到的 4 个真实问题

### ① `SemanticsHandle` 不能只挂 `addTearDown`
实测报错：
```
A SemanticsHandle was active at the end of the test.
All SemanticsHandle instances must be disposed by calling dispose().
```
原因：`tearDown` 跑在**断言之后**，而 `flutter_test` 在「测试体结束、tearDown
之前」就执行 `WidgetTester._verifySemanticsHandlesWereDisposed`。
**修法**：`getSemantics(...)` 拿到节点后**立即显式 `handle.dispose()`**，再断言。
（这也是三条用例最初全挂在第一个断言的原因 —— 脚手架问题，不是断言问题。）

### ② `getSemantics(find.byType(X))` 对复合结构取不到节点
实测报错：
```
Bad state: Finder returned no matching elements.
  at SemanticsController.find (controller.dart:98)
  at WidgetController.getSemantics (controller.dart:2364)
```
`RefsThemeCard` 是 `Semantics(button: true, label: …, child: InkWell(SizedBox(Column(...))))`
这种嵌套结构，`find.byType` 命中的控件在语义树里没有直接对应节点。
**修法**：改为按「带非空 `properties.label` 的 `Semantics` 控件」用
`find.byWidgetPredicate` 收集，再逐个人工 `getSemantics(find.byWidget(...))`。
三条用例统一用这一手法，避免同文件里两种取节点方式。

### ③ 合并后的语义 label 带尾随换行
`RefsPaletteStrip` 的等值断言实测：
```
Expected: '五色色卡'
  Actual: '五色色卡\n'
```
尾随 `\n` 来自色块子节点语义的合并。**产品 label 本身是对的**，属断言口径
过严。改为 `contains('五色色卡')` + `label.trim().isNotEmpty`，
守的是「有这句可读说明」而不是合并细节。

### ④ `SemanticsFlags` 没有 `contains`，且 `hasFlag` 已弃用
`analyze --fatal-infos` 报：
```
info - 'hasFlag' is deprecated ... Use flagsCollection instead (3.32+)
```
按提示改成 `flagsCollection.contains(...)` 又报 `undefined_method` ——
新版把 flags 拆成**具名布尔**（`isButton` / `isLink` / `isHidden` …），
不是集合。最终写法 `node.flagsCollection.isButton`。
（读 Flutter 源码 `semantics.dart` 确认：`SemanticsFlags get flagsCollection`
+ `data.flagsCollection.isSelected` 这类用法。）

## 4. 刻意不测的一处

`refs_home.dart:149 _themeChip` 是**私有**内部件，宿主 `RefsHomeHeader`
构造需要 controller / focusNode / status 等十余个参数，单独构造意义有限；
它所在链路已由 S5 的 UI 用例（`s5_refs_ui_test.dart`）通过点击间接覆盖。
故不单测，理由写死在测试文件头注释里，避免后人以为漏了。

## 5. 门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 255 files（1 changed → 复跑归零） |
| `flutter analyze --no-pub --fatal-infos` | No issues found |
| `flutter test --no-pub` | **535 passed + 34 skipped**（532 基线 + 3） |
| `check_file_size.mjs` | PASS |
| `check_tokens.mjs` | PASS（四类全 0） |

临时探针 `test/features/_a11y_probe_test.dart` 已删除（它是用来把
「脚手架问题」与「断言问题」分开定位的，不进仓库）。

## 6. 一句话总结

补的是「已存在但没人守」的可访问性语义标签；真正的收获是 4 个可直接复用的
`flutter_test` 语义测试写法（handle 显式释放、`byWidgetPredicate` 收节点、
合并 label 用 contains、`flagsCollection.isXxx`）。
