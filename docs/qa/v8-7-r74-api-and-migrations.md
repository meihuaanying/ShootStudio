# V8.7 / R74 收口：sanctioned 弹层 API 增强 + 首批非布尔弹层迁移

> 承接 `docs/qa/v8-2-r74-dialogs.md`（V8.2 batch 1：3 处迁移到 `showSsConfirm`）。
> 那份文档给的结论是「先把 sanctioned API 增强到能装下 A/C 两类，再谈迁移」。
> 本阶段做的就是这件事，并顺带把审计口径改准。

## 1. 审计更正：v8.2 文档里两处论断不成立

重新按 `lib/` 全树（`core/design/` 自身除外）扫 `showDialog<...>(` 共 **23 处调用点**，
逐处量了「调用点行跨度 / 返回类型 / 是否 AlertDialog 外观 / 按钮数」。结论：

### 更正一：`SsDialog` 本来就是 widget，不是「只支持 bool 的函数」
v8.2 文档写「需要给 `SsDialog` 补一个返回任意类型 `T` 的泛型入口」。实测
`ss_dialog.dart:10` 的 `SsDialog` 是 **StatelessWidget**：

```dart
return Dialog(
  child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: ...),
);
```

`showDialog<String>(builder: (ctx) => SsDialog(...))` **今天就能**返回任意 `T`。
所以缺的从来不是「能力」，而是**便捷入口 + 统一动作按钮** —— 没有它们，
feature 侧想回传 `String`/`Map` 就只能自己拼 `AlertDialog` 与自己的按钮样式。

### 更正二：C 类 6 处里有 1 处不是 R74 对象
`plan_read_view.dart:32` 用的是 `Dialog.fullscreen`（全屏阅读器），**不是
AlertDialog 外观**，不在 R74「裸 AlertDialog」的收口范围内，应从计数中剔除。

### 更正后的口径
| 类别 | 处数 | 说明 |
|---|---|---|
| AlertDialog 外观调用点（R74 真正对象） | **11** | 见 §5 清单 |
| `showDialog` + 自定义弹层构造函数 | ~10 | 走 helper 返回自定义 Dialog，非 AlertDialog 外观 |
| `ss_dialog.dart` 自身 | 2 | 本 API 的实现，不算 site |

v8.2 文档的「48 → 42 / 剩 27」是粗数，**以本表为准**。

## 2. sanctioned API 增强（`app/lib/core/design/ss_dialog.dart`）

### 新增 `showSsDialog<T>(...)`
```dart
Future<T?> showSsDialog<T>({
  required BuildContext context,
  required String title,
  String? eyebrow,
  String? subtitle,
  Widget? child,
  List<Widget> Function(BuildContext ctx)? actions,
  bool barrierDismissible = true,
  double maxWidth = 560,
}) => showDialog<T>(...);
```

两个刻意的设计选择：

1. **`actions` 用 builder 形态**（`List<Widget> Function(BuildContext ctx)`），
   让调用方拿到**弹层自己的** `BuildContext` 去 `Navigator.of(ctx).pop(value)`。
   返回值在按下按钮那一刻才求值 —— 这正是 C 类要的东西（表单读控件、选择器读状态）。
2. **不做 `?? false` 兜底**：遮罩关闭就是 `null`，含义由调用方决定。
   这与 `showSsConfirm`（bool 语义，遮罩一律折算 `false`）**不同**，
   差异写进了 doc comment，避免迁移者以为两者可互换。

### 新增 `SsDialogAction`
```dart
class SsDialogAction extends StatelessWidget {
  const SsDialogAction({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = true,
    this.danger = false,
  });
}
```
`primary: true` → `FilledButton`（`danger: true` 时用 `p.danger`），否则 `TextButton`；
`onPressed` 留空 = 仅 `pop()`（取消/关闭）。

**刻意不做成泛型**，理由写在源码注释里：`void?` 之类的类型实参不合法，
做成泛型只会逼每个调用方写显式类型实参，反而更难读；要回传什么值
由调用方在 `onPressed` 里决定即可。

### `showSsConfirm` 改为复用 `SsDialogAction`
令牌单一来源（按钮形态不再有两套）。**语义完全保持**：
确认 → `true`，取消/遮罩 → `false`，`danger` 仍映射 `p.danger`。
这条行为由新增的回归用例钉住（见 §3 用例 ⑤）。

`SsSheet` / `showSsSheet` **未改**：它本就能装任意 `child`，
A 类「富内容」不需要新能力，只需要证明它装得下（见 §3 用例 ⑥）。

## 3. 新增测试 `app/test/core/ss_dialog_test.dart`（6 条，全绿）

放 `test/core/` 是为了镜像 `lib/core/` 的既有约定。

| # | 用例 | 守的是什么 |
|---|---|---|
| ① | `showSsDialog<String>` 点按钮回传 `'url'` | C 类的核心：返回值是调用方给的 `String`，不是 bool |
| ② | 点遮罩 → `null` | 「不做 `?? false` 兜底」这条设计承诺 |
| ③ | `barrierDismissible: false` 遮罩点不掉 | 导入/进度类弹层不能被误关（原裸 `showDialog` 的常用参数） |
| ④ | `SsDialogAction` 形态 | primary → `FilledButton`；次要 → `TextButton`；`danger` 色值 == `AppTokensV2.paletteOf(paper).danger` |
| ⑤ | `showSsConfirm` 回归 | 确认 → `true`；遮罩 → **`false`**（重构没改语义） |
| ⑥ | `SsSheet` 装富内容 | `TextField` 能输入、`ListView` 能滚动、嵌套滚动不抛异常 |

用例 ⑥ 顺带覆盖了一个真实风险：`SsSheet` 的 child 外层已有
`SingleChildScrollView`，内层再放 `ListView` 属于嵌套滚动 —— 实测
`tester.takeException()` 为 `null`，说明不会炸。

## 4. 本阶段迁移的 4 处（全部保持原返回值语义）

| 文件 | 原返回 | 关键点 |
|---|---|---|
| `gear_browser.dart` `_showRephotoDialog` | `String?` | 三个动作 pop `'file'` / `'url'` / `null`；**不做** `?? false` 折算 |
| `gear_browser.dart` 粘贴链接 | `bool?` | 调用方判 `ok != true`，故遮罩 `null` 与取消 `false` 等价；取消仍显式 pop `false` 保持逐字语义 |
| `refs_page.dart` `_showAllThemes` | `void` | 见下方两条注意点 |
| `planner_page_layout.dart` `_askLabel` | `String?` | 里程碑命名，`TextField` 读 `ctl.text` 后 pop |

### 迁移 `refs_page.dart` 时踩到的两个点（写在这里省得后人再撞）
1. **嵌套 Navigator**：`showDialog` 默认 `useRootNavigator: true`，弹层被推到
   **根** Navigator；而弹层内色块原本用 dialog 的 `ctx` 去 pop。改用
   `showSsDialog` 后，`child` 是**构造期**参数，拿不到弹层 ctx，若直接用页面级
   `context`，在存在嵌套 Navigator 的场景下会 pop 到另一个 Navigator。
   解法：在 `child` 里套一层 `Builder` 取弹层子树的 ctx。
2. **不要套两层滚动**：原 `AlertDialog` 的 content 自带
   `SingleChildScrollView`；`SsDialog` 已经把 `child` 包进
   `Flexible(SingleChildScrollView)`。故迁移时**去掉**原那层，
   只留 `SizedBox(width: 520)`，否则内外两个可滚动区。

### 宽度对齐
`SsDialog` = `Dialog` + `ConstrainedBox(maxWidth)` + `padding: AppSpace.block`（24 两侧）。
原 `AlertDialog` content 的固定宽度 `SizedBox(width: N)` 要配上
`maxWidth: N + 48` 才能保持观感，故：`SizedBox(520)` → `maxWidth: 570`；
`SizedBox(380)` → `maxWidth: 430`。

### 如实登记的视觉差异
R74 收口的目的就是让弹层外观归一，因此**标题样式必然变化**：
原本手写的 `TextStyle(fontSize: AppFontSize.bodyLg)` 标题，现在统一走
`AppType.h2`（衬线，`SsDialog` 的标题样式）。这是**预期内的改变**，不是回归。
另外 affirmative 动作从 `TextButton` 变为 `FilledButton`（`SsDialogAction`
的 `primary` 默认值），与 `showSsConfirm` 的确认键一致。

## 5. 剩余未迁移清单（**没有做完，如实列出**）

11 处 AlertDialog 外观调用点中，本阶段迁了 4 处，**还剩 7 处**：

| 文件 | 行跨度 | 返回 | 按钮 | 未迁原因 |
|---|---|---|---|---|
| `refs_page_chrome.dart:85` | 44 | `void` | 3 | 需逐个确认按钮语义，预算外 |
| `planner_page_layout.dart:362` | 46 | `void` | 1 | 同上 |
| `updater_download_sheets.dart:47` | 48 | `void` | 0 | 无按钮，需确认是否纯展示 |
| `pose_import_page_layout.dart:54` | 52 | `(String?,String?)` | 1 | `StatefulBuilder`，状态在弹层内，迁移需重构 |
| `planner_page_layout.dart:188` | 56 | `void` | 1 | 预算外 |
| `gear_browser_add.dart:11` | 104 | `bool` | 1 | 富内容，需逐段核对 |
| `gear_browser_card.dart:259` | 203 | `void` | 3 | 富内容+图片链，最长的一处 |

> R82 明令禁止虚报覆盖率。本阶段**没有**把 R74 做到 100%。
> 已落地的部分：sanctioned API 从「只覆盖 bool」扩到「任意 `T` + 统一动作按钮」，
> 且 7 处剩余站点用的都是同一套 `showSsDialog` / `SsDialogAction`，
> 后续迁移是**机械替换**，不再需要发明 API。

## 6. 门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 256 files，**0 changed** |
| `flutter analyze --no-pub --fatal-infos` | **No issues found** |
| `flutter test --no-pub` | 见 §7 |
| `check_file_size.mjs` | PASS |
| `check_tokens.mjs` | PASS（四类全 0） |

## 7. 测试计数

基线（V8.5 / V8.6）：**535 passed + 34 skipped**。
本阶段新增 `test/core/ss_dialog_test.dart` 6 条 → 预期 **541 passed + 34 skipped**。
