# V8.8 / R74 第二批：AlertDialog → sanctioned API（迁 4，剩余 3）

> 接续 `docs/qa/v8-7-r74-api-and-migrations.md`。该报告确立了 sanctioned 弹层 API
> （`showSsDialog<T>` + `SsDialogAction`）并完成首批 4 处迁移；本轮把它推到**剩 3 处**。

## 1. 计数口径（本报告以此为准）

`lib/` 全树（`core/design/` 自身除外，**170 个 Dart 文件**）扫 `showDialog<`
且 1500 字符窗口内含 `AlertDialog`：

| 阶段 | 迁走 | 剩余 |
|---|---|---|
| V8.2 | 3（→ `showSsConfirm`） | 8 |
| V8.7 | 4 | 7 → 经重扫修正为 7 |
| V8.8 | 4（实际改 5 个调用点） | **3** |

累计 **11 − 8 = 3**。剩余 3 处见 §4。

> 说明：V8.8 实际改动 **5 个调用点**、但其中 `planner_page_layout.dart` 含 2 处，
> 而它在 V8.7 已被计过一次文件级命中，故「迁走 4」按文件级计。

## 2. 本批迁移的 5 个调用点

宽度对齐公式沿用 V8.7 确立的 `maxWidth = 原 SizedBox.width + 48`
（`SsDialog` 自身两侧 padding 是 `AppSpace.block` = 24）。

### 2.1 `refs_page_chrome.dart` · `showRefFrameDialog`（`void`）
- 原：`showDialog<void>` + `AlertDialog` + 3 个 `TextButton`。
- 新：`showSsDialog<void>` + `maxWidth: 468`（原 `SizedBox(width: 420)`）。
- `actions: (ctx) => [...]` 三个动作全部 `primary: false`：
  - 「打开来源页」：`onPressed` 内 `launchUrl` **不 pop**（与原语义一致）；
  - 「移出画板」：`onRemove()` 后 `pop`；
  - 「关闭」：仅 pop。
- 引入局部 `final AppPalette p = context.palette;` 替代原 `ctx.palette`
  （builder 的 `ctx` 与页面 `context` 不是同一个，取色板要用页面级）。
- **归一化差异（需登记）**：弹层小标题由 `AppType.h3` 改走 `SsDialog` 的
  `AppType.h2`（衬线）——这正是 R74 收口的目的，不是回归。

### 2.2 `updater/updater_download_sheets.dart` · 确认下载（`void`）
- 原：`AlertDialog` + 2 个 `SsButton(dense: true)`。
- 新：`showSsDialog<void>`，`actions` 为 `SsDialogAction('取消', primary: false)`
  与 `SsDialogAction('打开下载', onPressed: pop + launchUrl)`。
- **按钮形态差异（需登记）**：`SsButton` → `FilledButton` / `TextButton`。
  这是 sanctioned API 的既定形态（`SsDialogAction.primary` 决定），非本批引入。
- child 文本取色用 `context.palette.ink` / `.muted`。

### 2.3 `planner/planner_page_layout.dart` · `_showTemplatePicker`（`void`）
- 原：`AlertDialog` + `SizedBox(640×460)` + `GridView.builder` + 1 个「取消」。
- 新：`showSsDialog<void>` + `maxWidth: 688`。
- **嵌套 Navigator 坑（本批第 2 次踩，已固化为写法）**：`showDialog` 默认
  `useRootNavigator: true`，而 `child:` 是构造期参数、拿不到弹层自己的 `ctx`，
  所以卡片的 `Navigator.pop` 必须用 `Builder` 取：
  ```dart
  child: Builder(builder: (inner) => GestureDetector(
    onTap: () { if (inner.mounted) Navigator.of(inner).pop(); ... },
    ...)),
  ```
  `inner.mounted` 判空是必须的（用户可能已用遮罩关掉弹层）。

### 2.4 `planner_page_layout.dart` · 版本对比（`void`）
- 原：`AlertDialog` + `SizedBox(560×420)` + `ListView` + 1 个「关闭」。
- 新：`showSsDialog<void>` + `maxWidth: 608`。
- child 内不使用 `Navigator`，故**无需** `Builder`；滚动由 `SsDialog` 的
  `Flexible(SingleChildScrollView(...))` 提供。
- 顺带消掉原来 AlertDialog content 外层与自身各一层滚动导致的「两层滚动」。

### 2.5 `libraries/gear_browser.dart` · 同步器材图进度弹层（`void`）
- 原：`showDialog<void>` + `barrierDismissible: false` + **无按钮** +
  `ValueListenableBuilder` 进度条。
- 新：`showSsDialog<void>` + `barrierDismissible: false`，进度件放 `child:`。
- 该函数原本就用**页面级** `context` pop（`if (context.mounted) Navigator.of(context).pop();`），
  不依赖 builder `ctx` → 迁移干净，是本批最简单的一处。

## 3. 测试：新增第 ⑦ 条，钉住 `SsDialogAction` 的 null 语义

### 起因（一个会静默出错的坑）
读源码 `app/lib/core/design/ss_dialog.dart:201` 得到：
```dart
final VoidCallback handle = onPressed ?? () => Navigator.of(context).pop();
```
即 **`onPressed` 为 null 不是「禁用按钮」，而是「只 pop」**。

这在迁移中是双向陷阱：
- 若以为是「禁用」而给按钮传 `null`，弹层会被意外关掉；
- 若反过来把 `null` 直接透给 `TextButton`（老写法），按钮会变成**灰色禁用态**、
  弹层**关不掉**（用户只能点遮罩 —— 而 `barrierDismissible: false` 时连遮罩都无效）。

`showSsConfirm` 与 V8.7/V8.8 的 12 处迁移都依赖这个语义，但**此前无任何断言**。

### 写法
`app/test/core/ss_dialog_test.dart` 追加：
```dart
testWidgets('SsDialogAction 无 onPressed 时点一下就能关掉弹层', (tester) async {
  // 开弹层 → tap '关闭' → expect(find.text('关闭动作回归'), findsNothing)
});
```
实测 `00:01 +7: All tests passed!`（7/7）。

## 4. ★ 剩余 3 处（如实登记，不是「没时间」而是「需要重构」）

| # | 文件:行 | 跨度 | 返回 | 为何不能直接套 API |
|---|---|---|---|---|
| 1 | `lib/features/libraries/gear_browser_add.dart:11` | 104 行 | `bool` | 富内容**新增表单**（多字段 + 校验 + 提交），直接搬进 `child:` 需先决定「表单状态放弹层内还是页面内」，还牵扯提交流程的 await 链 |
| 2 | `lib/features/libraries/gear_browser_card.dart:259` | 203 行 | `void`，3 动作 | 全树最长（203 行），富内容 + **图片链**（缩略图/预览/加载态），搬到 `child:` 要拆出多个子件 |
| 3 | `lib/features/poses/pose_import_page_layout.dart:54` | 52 行 | `(String?, String?)` | 用 **`StatefulBuilder`**，状态活在弹层内部；迁移前必须先决定状态归属（提为页面级 State 还是保留局部），**不是替换调用即可** |

这 3 处的共同点：**它们的问题不是「没用 sanctioned API」，而是「弹层内容本身需要拆件」**。
替换调用点是最后一步，不是第一步。故登记为偏差 10 的未收口部分（见
`docs/qa/v8-r71-deviations.md`），修复条件写明「逐处迁移；第 3 处建议单独开一轮」。

## 5. 门禁实测（全绿）

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 256 files, **0 changed** |
| `flutter analyze --no-pub --fatal-infos` | **No issues found**（10.6s） |
| `flutter test --no-pub` | **542 passed + 34 skipped**, `EXITCODE=0` |
| `node tool/check_file_size.mjs` | **PASS**（最大 566 行 `lib/features/poses/poses_controller.dart`；次 550 `lighting_controller.dart`） |
| `node tool/check_tokens.mjs` | **PASS**（扫 186 个 Dart 文件、豁免 14；自造色值 0 / 内置色板 0 / 字号字重时长 0 / 间距圆角裸数字 0） |

测试计数：V8.7 基线 541 → **542**（+1 新用例，无删改断言，符合 R79）。
本批 5 处迁移在迁移中途单独跑过一次全量，得 541 passed 证实未引入回归。

## 6. 影响面自查
- 5 处改动全部**返回值语义逐字保持**（`void` 仍 `void`，`onRemove` / `launchUrl`
  的调用时机与顺序不变）。
- 5 处全部为弹层替换，**不涉页面布局**：不触碰栅格、间距、路由。
- 两处登记为归一化差异（标题字级、按钮形态），均为 R74 收口的既定目标。
- 无新增依赖、无 `pubspec.yaml` 变更、无资源变更。
