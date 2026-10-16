# V8.13 / 批次 C：R74 最后 5 处 `AlertDialog` 迁移 + `SsDialog` 缺 `Material` 的真缺陷修复

> 本阶段把 `lib/features` 里**最后 5 处活着的 `AlertDialog`** 迁到 sanctioned
> `SsDialog`，并修掉迁移过程中暴露出的一个**组件自身缺陷**。
> 门禁实测 `AlertDialog(` 字面量从 **5 → 0**，并已把这个 0 写进组件基线锁定。

## 0. 为什么会有这一阶段：上一轮的「归零」是假阴性

`V8.10` 曾宣称「`lib` 内 `AlertDialog` 归零」，并在偏差登记里把 R74 标为
**已消除**。那个结论是**错的**。当时的扫描判据是：

```
showDialog<...>( 的调用点 + 其后 ±1500 字符窗口内含 'AlertDialog'
```

而下面这 5 处的形态是「**独立 widget 类的 `build()` 里 `return AlertDialog(`**」，
调用点在**另一个文件**（`builder: (_) => const _XxxDialog()`）——
那个窗口里**永远看不到** `AlertDialog` 字面量，于是扫描报 0。

**假阴性不是「少报了一点」，而是把「还剩 5 处」说成了「一处不剩」。**
本阶段既修这 5 处，也把这个判据错误公开登记（见 §4）。

## 1. 5 处迁移清单

| # | 宿主类 | 文件 | 原 `AlertDialog` 行 | `maxWidth` | 动作钮处理 |
|---|---|---|---|---|---|
| 1 | `ResourceEditorDialog` | `libraries/library_resource_editor.dart` | 97 | **568** | 取消→`SsDialogAction(primary:false)`；删除/保存**保留裸控件** |
| 2 | `_ColorPickerDialog` | `planner/planner_page_dialogs.dart` | 220 | **368** | 取消/添加→`SsDialogAction` |
| 3 | `_PoseInfoDialog` | `planner/planner_page_pose_dialogs.dart` | 22 | 默认 560 | 关闭→`SsDialogAction(primary:false)` |
| 4 | `_PoseReplaceDialog` | `planner/planner_page_pose_dialogs.dart` | 117 | **408** | 取消→`SsDialogAction(primary:false)` |
| 5 | `_BudgetEstimateDialog` | `planner/planner_page_pose_dialogs.dart` | 217 | **368** | 取消→`SsDialogAction`；生成估算**保留 `SsButton`** |

改法统一：`return AlertDialog(...)` → `return SsDialog(...)`，外层
`showDialog(builder: (_) => X())` 不动（这 5 处是**类**，不是函数调用）。

### 1.1 宽度公式
`maxWidth = 原 SizedBox.width + 48`。`SsDialog` 左右 padding 各
`AppSpace.block`（24），两侧共 48，故加 48 才是「内容宽度不变」。

### 1.2 删掉内层滚动
原 `content: SizedBox(width: N, child: SingleChildScrollView(child: Column(...)))`
里的 `SingleChildScrollView` 已由 `SsDialog` 自带的
`Flexible(child: SingleChildScrollView(child: child!))` 承担。
**保留内层会变成嵌套滚动**（V8.8 已踩过一次），故删掉，只留 `Column`。

### 1.3 `_PoseReplaceDialog` 刻意**保留**固定高度
它的内容是 `SizedBox(width: 360, height: 380, child: Column(children: [TextField, ..., Expanded(ListView)]))`。
`Expanded` 需要有界高度，而 `SsDialog` 会把 `child` 包进
`SingleChildScrollView`（高度无界）→ 去掉这个 `height: 380` 会直接报
`RenderFlex ... unbounded` 错误。故保留整个 `SizedBox`，只换外壳。

### 1.4 禁用态按钮**不换** `SsDialogAction`（关键语义陷阱）
`SsDialogAction` 的实现是：

```dart
final VoidCallback handle = onPressed ?? () => Navigator.of(context).pop();
```

即 **`onPressed == null` 不是「禁用」，而是「仅关闭弹层」**。
所以凡是 `onPressed` 可能为 null 的按钮，换成 `SsDialogAction` 会把
「不可点」变成「点一下就关弹层」：

- `ResourceEditorDialog` 的**删除**（`onPressed: _busy ? null : …`）
  与**保存**（`onPressed: !_valid || _busy ? null : …`）→ 保留裸 `TextButton` / `FilledButton`；
- `_BudgetEstimateDialog` 的**生成估算**（`onPressed: _city == null ? null : …`）→ 保留 `SsButton`。

`SsDialog.actions` 的类型是 `List<Widget>`，允许混用，所以这条不牺牲任何东西。

## 2. ★ 顺带修掉的真缺陷：`SsDialog` 缺 `Material`

### 2.1 现象
迁移后 `test/features/f4_editors_test.dart` 的「姿势编辑器：从内置姿势库替换」
从 `+5` 变成 `+5 -1`，抛 **15 条**同一断言：

```
ListTile background color or ink splashes may be invisible.
The ListTile is wrapped in a DecoratedBox that has a background color. ...
ListTile: ListTile(dense: true, onTap: Closure: () => void)
DecoratedBox: DecoratedBox(bg: BoxDecoration(color: Color(1,1,1,1), ...))
```

那个白色 `DecoratedBox` 就是 `SsDialog` 的 `Container(color: p.surface, ...)`。

### 2.2 根因（直接读 SDK 源码确认）
`C:\dev\flutter\packages\flutter\lib\src\material\list_tile.dart` 的
`_findIntermediateWidget`：从 `ListTile` 往上走祖先，
**遇到第一个 `Material` 就停止**；若在此之前遇到有非透明色的
`ColoredBox` / `DecoratedBox`（`BoxDecoration` 或 `ShapeDecoration` 的 `color`）则报错。

`AlertDialog` 内部**本来就有一个 `Material`**，`SsDialog` 没有 —— 所以
ListTile 的墨迹与背景色会画到弹层外面去。**这是组件自身的缺陷**，
前 11 处迁移的弹层里没有 `ListTile`，所以一直没暴露。

### 2.3 修法
`SsDialog.build` 里 `Container(decoration: …, padding: AppSpace.block, child: …)`
的 child 包一层：

```dart
Material(
  type: MaterialType.transparency,
  child: Column(...),
)
```

选 `MaterialType.transparency` 而不是默认的 `canvas`：
读 `material.dart` 的 `Material.build`（:540-546），transparency 分支返回
`ClipPath(clipper: ShapeBorderClipper(shape: RoundedRectangleBorder()), child: _ShapeBorderPaint(...))`
—— **不会往中间插 `ColoredBox`/`DecoratedBox`**，所以 ListTile 的祖先走查会
直接在 `Material` 处停，断言不再触发。

### 2.4 为什么不担心它改变文字排版
`Material.build`（:474-481）**无条件**把 child 包进
`AnimatedDefaultTextStyle(style: widget.textStyle ?? Theme.of(context).textTheme.bodyMedium!)`，
所以加 `Material` 确实会给子树强加 `bodyMedium`。

但这不是「新增变化」而是「**恢复对齐**」：原 `AlertDialog` 走的是
**同一条** `AnimatedDefaultTextStyle` 代码路径。也就是说，迁移到 `SsDialog`
时丢掉 `Material`，本来就已经让文字排版与 `AlertDialog` 不一致了；
补上 `Material` 是把这份不一致修回去。

## 3. 另一个只有本批才会遇到的坑：`child:` 必须放最后

`--fatal-infos` 下 `sort_child_properties_last` 是**致命**的。

- 前 11 处迁移用的是 **函数** `showSsDialog(child: ..., actions: ...)` —— 函数调用不受这条 lint 管；
- 本批用的是 **widget 构造** `SsDialog(child: ..., actions: ...)` —— 受管，`child:` 必须在末尾。

写了脚本 `%TEMP%opencode\reorder_child.py`（字符串感知的括号匹配 + 顶层逗号切分具名参数）
把 `child:` 挪到末尾，再用 `dart format` 收尾缩进。
**脚本坑**：`_PoseReplaceDialog` 那处 `child:` 前面有注释，导致参数名正则匹配失败而
被跳过；把注释移到 `return SsDialog(` **之前**再跑一次，3 个文件全部成功。

## 4. 必须公开的更正

| 轮次 | 结论 | 真伪 |
|---|---|---|
| V8.10 | 「`lib` 内 `AlertDialog` 归零，偏差 10 已消除」 | ❌ **假阴性**（判据看不到跨文件的 `return AlertDialog(`） |
| V8.13（本批） | 「16 处已全部迁移，门禁实测 `alertDialog` 字面量 = 0」 | ✅ 有门禁证据 |

真实账目：**16 处 = 已迁 11（V8.2/V8.7/V8.8/V8.9/V8.10）+ 本批 5**。

## 5. 门禁实测

| 门禁 | 结果 |
|---|---|
| `test/features/f4_editors_test.dart` | **6/6**（修前 `+5 -1`，15 条 ListTile 异常） |
| `dart format lib test` | 256 files（1 changed → 复跑 **0 changed**） |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!**（10.2s） |
| `flutter test --no-pub` | **543 passed + 34 skipped，EXIT=0**（= 基线，无回归） |
| `node tool/check_file_size.mjs` | **PASS**（最大 589 `ai_client.dart`） |
| `node tool/check_tokens.mjs` | **PASS**（186 文件、豁免 14；四类全 0） |
| `node tool/check_components.mjs` | **PASS**（99 文件；`alertDialog 0`） |

## 6. 基线锁定

`node tool/check_components.mjs --write-baseline` 成功（无指标上涨）：

```json
{ "textField": 60, "textFormField": 0, "bottomSheet": 4, "alertDialog": 0 }
```

**意义：R74 的 `alertDialog` 基线从 5 降到 0。今后任何新增 `AlertDialog(` 都会让 CI 直接红** ——
这条合同条款从此有门禁守着，而不是靠人记得。

## 7. 影响面自查

- 本轮**只碰** 3 个 `lib/features` 文件 + 1 个 `lib/core/design` 文件，无 schema / 无 provider / 无路由改动。
- 全量测试 `543 passed + 34 skipped` 与 v8.12.0 完全一致 → 无回归。
- 视觉归一化差异（**属收口目的，非回归**，如实登记）：5 处标题由 `AppFontSize.bodyXl/bodyLg` 改走
  `AppType.h2` 衬线；「添加」「生成估算」之外的主按钮变 `FilledButton`；
  `ResourceEditorDialog` 的删除钮失去 `p.danger` 文字色（保留为普通 `TextButton`）。

## 8. 一句话总结

这一批的价值一半在「迁完最后 5 处」，另一半在**发现并修掉了 `SsDialog` 自身缺
`Material` 的缺陷** —— 后者是靠一个真实用例（`f4` 的姿势替换弹层里有 `ListTile`）
逼出来的，前 11 处迁移因为弹层里没有 `ListTile` 而全部漏过。
