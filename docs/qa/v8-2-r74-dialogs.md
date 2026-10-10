# V8.2 R74 弹层组件收口（第 1 批：纯确认型）

> 合同 R74：「按钮/输入框/卡片/对话框/标签/空态/加载态/Toast 一律走
> `lib/core/design/`；feature 内禁止新造同名基础组件。」
> 本文登记第 1 批（纯确认型弹层）的迁移结果，以及**为什么剩下的 27 处
> 不能一起迁**。

## 1. 背景：为什么这是问题

`lib/core/design/ss_dialog.dart` 提供的 sanctioned 弹层 API ——
`SsDialog` / `SsSheet` / `showSsConfirm` / `showSsSheet` —— 在 V8 收尾时
**零引用**。也就是说设计系统自以为提供了弹层，实际上 feature 全部在裸写
`showDialog + AlertDialog`，"禁止新造同名基础组件"这半句做到了（feature 里
没有叫 `SsDialog` 的类），但"一律走 design 组件"这半句没做到。

实测（`lib/` 全树，`core/design/` 自身除外）：**26 处 `showDialog`、
20 处 `AlertDialog`**。

## 2. 第 1 批迁移（3 处，全部语义等价）

| 文件 | 原形态 | 迁移后 |
|---|---|---|
| `features/poses/poses_page_layout.dart` ~`:397` | `AlertDialog(title + content: Text, 取消/删除)` | `showSsConfirm(confirmLabel: '删除')` |
| `features/libraries/library_resource_editor.dart` ~`:271` | `AlertDialog(title + content: Text 清单, 取消/仍要删除)` | `showSsConfirm(confirmLabel: '仍要删除')` |
| `features/export/export_panel.dart` ~`:62` | `AlertDialog(title + content: Text 失效清单, 取消/继续导出)` | `showSsConfirm(confirmLabel: '继续导出')` |

### 语义等价性核对（这是迁移唯一的风险点）

`showSsConfirm` 内部实现是 `final bool? r = await showDialog<bool>(...); return r ?? false;`。
所以原调用方收到 `null`（点遮罩关闭）的场景，在迁移后收到 `false`。逐个核对：

| 文件 | 原写法 | 新写法 | 是否等价 |
|---|---|---|---|
| `poses_page_layout.dart` | `bool? confirmed` + `if (confirmed == true)` | `bool confirmed` + `if (confirmed)` | ✅ null 与 false 都不删 |
| `library_resource_editor.dart` | `bool? ok` + `if (ok == true)` | `bool ok` + `if (ok)` | ✅ null 与 false 都不删 |
| `export_panel.dart` | `bool? go` + `if (go != true) return` | `bool go` + `if (!go) return` | ✅ null 与 false 都中止导出 |

三处原确认按钮都不是红色/错误色，故 `danger` 保持默认 `false`，视觉一致。

三处的 import 原本就指向 `core/design/widgets.dart`（poses 经父文件
`poses_page.dart` 的 part 传递），**未新增 import**。

## 3. 为什么剩余 27 处不一起迁

逐处看过，全部**至少违反一条迁移条件**，具体分三类：

### A. 内容是表单 / 列表 / 富媒体（21 处）
`showSsConfirm` 的 `child` 参数只接受 `Text(message)`，装不下这些：
- 带 `TextField` 表单：`gear_browser_add.dart:11`（下拉 + 4 输入框）、
  `planner_page_dialogs.dart:220`（取色器）、
  `pose_import_page_layout.dart:54`（命名 + chips）、
  `gear_browser.dart:446`（粘贴链接）、
  `library_resource_editor.dart:97`（编辑条目本体）、
  `planner_module_editor.dart:418`
- 带 `GridView` / `ListView`：`refs_page.dart:384`（芯片列表）、
  `planner_page_layout.dart:188/362`（模板库 / 版本 diff）、
  `planner_page_pose_dialogs.dart:117`（姿势搜索列表）
- 富内容：`refs_page_chrome.dart:85`（图卡详情 + 3 按钮含 `launchUrl`）、
  `updater_download_sheets.dart:47`（SHA-256 摘要 + `SelectableText`）、
  `gear_browser_card.dart:259`（图片 / 规格）、
  `planner_page_pose_dialogs.dart:22`（照片 / 骨架）、
  `cinematic_refs.dart:16`、`planner_page.dart:102/159`、
  `planner_module_editors_a.dart:221`、`lighting_page_ab.dart:49/61`
- 进度型：`gear_browser.dart:340`（`ValueListenableBuilder` + 进度条 +
  `barrierDismissible: false`）

### B. 单按钮提示、pop<void>（4 处）
`showSsConfirm` 的契约是「返回布尔、必有两个按钮」；单按钮提示没有布尔可返回，
硬套会把返回值语义改坏。对应 `refs_page.dart:384`、`refs_page_chrome.dart:85`、
`planner_page_layout.dart:188/362`、`updater_download_sheets.dart:47`
（其中若干与 A 类重叠）。

### C. 返回值不是布尔（6 处，迁移会直接改变调用方语义）
| 文件 | pop 的返回类型 | 迁移后果 |
|---|---|---|
| `planner_page_layout.dart:430` | `String` | 调用方拿到 `bool`，功能直接坏 |
| `gear_browser.dart:404` | `String`（file / url） | 同上 |
| `pose_import_page_layout.dart:54` | `(String?, String?)` | 同上 |
| `planner_page_pose_dialogs.dart:117` | `Map` | 同上 |
| `planner_page_pose_dialogs.dart:217` | record | 同上 |
| `planner_module_editor.dart:418` | `String` | 同上 |

## 4. 结论与后续

- 第 1 批 3 处已迁，`showDialog` / `AlertDialog` 裸用法 48 → **42**。
- 剩余 27 处**不是懒得上，是不能机械替换**：需要给 `SsDialog` 补一个
  「返回任意类型 T」的泛型入口（覆盖 C 类 6 处），以及确认 `SsSheet` 的
  bottom-sheet 形态是否适用于富内容场景（覆盖 A 类大部分）。
- 建议 V8.3 做的是**增强 sanctioned API**（给 `SsDialog` 加泛型、
  给 `SsSheet` 补富内容用例），而不是继续往 feature 里塞 `showSsConfirm`。
  API 不够用的时候硬迁，就是把 R74 从「没收口」变成「收口了但到处都是
  if 判断特例」，反而更糟。

## 5. 门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 复跑 0 changed |
| `flutter analyze --no-pub --fatal-infos` | No issues found |
| `flutter test --no-pub` | 532 passed + 34 skipped（与迁移前一致） |
| `check_file_size.mjs` | PASS |
| `check_tokens.mjs` | PASS（四类全 0） |
