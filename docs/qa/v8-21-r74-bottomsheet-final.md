# V8.21 / 批次 C3：R74 底部抽屉层 4 处 `showModalBottomSheet` 收口到 `showSsSheet`（+ `SsSheet` 拆文件）

> 本批把 `lib/features` 里**最后 4 处自拼的 `showModalBottomSheet`** 全部换成
> sanctioned `showSsSheet`，组件的**引用数从 0 变成 4（+ 1 条用例）**。
> 门禁实测 `showModalBottomSheet` 在 `lib/features` 里从 **4 → 0**，并把这份 0
> 写进组件基线锁定。为满足 R73 的 ≤300 行门禁，`SsSheet` 从 `ss_dialog.dart`
> **拆到新文件 `ss_sheet.dart`**（不是往白名单里塞超限文件）。

## 0. 为什么会有这一阶段

R74 组件收口分三层：`AlertDialog`（C1，V8.13 收口）、裸 `TextField`（C2，V8.20 收口 60/60）、
`showModalBottomSheet`（**C3，本批**）、空态 `SsEmptyState`（C4，待做）。

`SsSheet` / `showSsSheet` 早在 **V8.7** 就已建好（`core/design/ss_dialog.dart`，覆盖 R74 §3 C 类），
但**一直没有 feature 调用它** —— 底部抽屉仍由 4 处 feature 代码各自 `showModalBottomSheet`
自拼外壳（透明底、圆角、hairline、scrim、内边距）。审计表 C3 行给出的验收就是
「**SsSheet 引用从 0 变正数**」。本批即兑现这条。

## 1. 4 处迁移清单

| # | 入口 / 宿主 | 文件 | 原行 | 关键差异点 | 处理 |
|---|---|---|---|---|---|
| 1 | `showRefsHitDrawer` | `features/refs/refs_hit_drawer.dart` | 181 | 自带 eyebrow「PLATE · 详情」+ 标题 `hit.title`；底部 `viewInsets` 键盘内边距 | `eyebrow: 'PLATE · 详情'` + `title: hit.title`；抽屉表头改由 `showHeader` 开关控制 |
| 2 | `showPoseDetailSheet` | `features/poses/pose_gallery.dart` | 175 | 标题 + 副标题 `类别 · 难度`；右侧「骨架叠加」chip；`constraints: maxWidth 720` | `title` / `subtitle` / `trailing`（chip）/ `maxWidth: 720` |
| 3 | `showCharacterPicker` | `features/poses/character_picker.dart` | 38 | 标题「人物与服装」+ 长副标题；私有 `StatefulWidget` 内含「应用」钮 | `title` / `subtitle`；`_CharacterPickerSheet` 去掉自带表头，保留状态与「应用」钮 |
| 4 | `_showHistory` | `features/planner/planner_page_layout.dart` | 248 | 标题「版本历史（无限保留）」+ 右上「创建里程碑」钮 | `title` + `trailing`（创建里程碑钮） |

改法统一：`showModalBottomSheet<T>(…)` → `showSsSheet<T>(…)`，**外壳（底色 / 圆角 / hairline /
scrim / 内边距 / 标题排版）全部交给 `SsSheet`**，feature 只交内容。

### 1.1 `trailing` 为什么放到「标题下右对齐」而不是「标题同一行」
最直觉的实现是 `Row(children: [Expanded(标题块), trailing])`。但 `Row` + `Expanded` 一旦落在
**无界宽度**的宿主里（如没有 `Scaffold` 的单测壳）会直接抛
`RenderFlex children have non-zero flex but incoming width constraints are unbounded`。
`pose_gallery` 的旧代码就专门为此加过 `ConstrainedBox(maxWidth: 720)`。

故 `SsSheet` 把 `trailing` 渲染成 `Align(alignment: Alignment.centerRight, child: trailing!)`
—— 单占一行、右对齐，`Align` 在无界宽度下会收缩到子尺寸，**任何宿主都安全**。
新增的 `ss_dialog_test` 用例已显式断言「无 flex 溢出」。（见 §2、§5）

### 1.2 被单测拦住的一次回归（如实记录）
第 1 处最初的做法是**直接删掉 `RefsHitDrawer` 自渲染的「PLATE · 详情 + 标题」表头**
（表头交给弹层）。这打断了 `test/features/s5_refs_ui_test.dart` —— 该用例**直接构造**
`RefsHitDrawer` 并断言 `PLATE · 详情` 与 `银翼杀手 · 街景霓虹` 各 `findsOneWidget`。

修正做法：给 `RefsHitDrawer` 加 `showHeader`（默认 `true`）开关。**单测直接构造时**保持
自带表头（契约不变）；**由 `showSsSheet` 承载时**置 `false`，表头交给弹层，避免标题重复。
这是「真实用例逼出正确 API 形状」的又一例。

## 2. ★ R71 先增强 sanctioned API 再迁移

`SsSheet` 与 `showSsSheet` 各补可选位，**默认值全部 = 不渲染 / null，对 V8.7 既有调用方零变更**：

| 新增 | 签名 | 落点 | 默认值（= 零变更） |
|---|---|---|---|
| `SsSheet.subtitle` | `String?` | 标题下 `AppType.small` + `p.muted`，距标题 `AppSpace.s1` | `null` → 不渲染 |
| `SsSheet.trailing` | `Widget?` | 标题/副标题下**右对齐单行**（`Align.centerRight`） | `null` → 不渲染 |
| `showSsSheet.subtitle` / `.trailing` | 透传给 `SsSheet` | — | `null` |
| `showSsSheet.maxWidth` | `double?` | `constraints: maxWidth == null ? null : BoxConstraints(maxWidth: maxWidth)` | `null` → 字节级同旧行为 |

`maxWidth` 用来**逐字复刻** `pose_gallery` 原本的 `constraints: const BoxConstraints(maxWidth: 720)`，
不是新发明。

新增用例（`test/core/ss_dialog_test.dart`，group「V8.7 弹层 API：SsSheet 装富内容」）：
`subtitle / trailing 与 maxWidth 约束（V8.21 新增）` —— 断言 `subtitle` 与 `trailing` 都渲染、
且**不出现 flex 溢出**。

## 3. ★ 结构性改动：`SsSheet` 拆出独立文件（R73 行数门禁）

`ss_dialog.dart` 加完 `subtitle` / `trailing` 后到 **313 行**，超 `lib/core/design` 单文件
**≤300** 的 R73 门禁（`test/features/s3_design_system_test.dart` 与 `tool/check_file_size.mjs`
双重把关）。**没有**用 `file_size_baseline.json` 白名单把它固化（那等于固化超限，违反 R82）。

做法：把底部抽屉整体拆到新文件 `core/design/ss_sheet.dart`（**113 行**，含 `SsSheet` + `showSsSheet`），
`ss_dialog.dart` 回到 **208 行**（只留 `SsDialog` / `SsDialogAction` / `showSsDialog` / `showSsConfirm`）。
`core/design/widgets.dart` barrel 补 `export 'ss_sheet.dart';`，**全 app 仍从同一 barrel 取组件**，
没有任何 feature 需要改 import。`s3_design_system_test` 的「barrel 导出全部组件文件」清单同步补
`'ss_sheet.dart'`。

## 4. ★ 如实登记（视觉归一化 = 收口目的，非回归）

| # | 事实 |
|---|---|
| a | 4 处抽屉底色 / 圆角 / hairline / scrim / 内边距 / 标题排版**统一由 `SsSheet` 提供**（收口的**目的**，与前两批同类）。 |
| b | `pose_gallery` 的「骨架叠加」chip、`planner` 的「创建里程碑」钮：从**标题同一行**移到**标题下右对齐单行**（见 §1.1，刻意为之以避开无界宽度抛错）。 |
| c | `RefsHitDrawer` 被承载时 `showHeader: false`，表头改由弹层给 —— **独立构造的渲染契约不变**（`s5_refs_ui_test` 原样通过）。 |
| d | `_CharacterPickerSheet` 去掉自带 `SafeArea` / `Padding` / `SsSectionTitle`（改由弹层提供）；「应用」钮与其状态**仍留在 `StatefulWidget` 内**（它读 `_selection` / `_loaded`，无法外移）。 |
| e | `refs` 原本的 `MediaQuery.viewInsets.bottom` 键盘内边距**保留**。 |
| f | `pose_gallery` 的 `constraints: maxWidth 720` 由 `showSsSheet(maxWidth: 720)` 复刻。 |

## 5. 门禁实测

| 门禁 | 结果 |
|---|---|
| `test/features/s3_design_system_test.dart` | **PASS**（修前 `≤300 行` 一条红，313 → 拆文件后 113） |
| `test/features/s5_refs_ui_test.dart` | **PASS**（修前表头删除导致 1 条红，`showHeader` 后通过） |
| `dart format lib test` | 258 files（**0 changed**，复跑确认） |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!** |
| `flutter test --no-pub` | **551 passed + 34 skipped，EXIT=0**（基线 550+34，+1 = 本批新用例，零回归） |
| `node tool/check_file_size.mjs` | **PASS**（116 文件；白名单 0 项；最大 589 `ai_client.dart`） |
| `node tool/check_tokens.mjs` | **PASS**（187 文件、豁免 14；四类全 0） |
| `node tool/check_components.mjs` | **PASS**（99 文件；`↓ bottomSheet 0（基线 4）`、`textField 0`、`textFormField 0`、`alertDialog 0`） |

## 6. 基线锁定

`node tool/check_components.mjs --write-baseline --json=../docs/qa/v8-components.json`（`at=2026-10-17T03:14:27.132Z`）：

```json
{ "textField": 0, "textFormField": 0, "bottomSheet": 0, "alertDialog": 0 }
```

**意义：R74 的 `bottomSheet` 基线从 4 降到 0。今后任何新增裸 `showModalBottomSheet(` 都会让 CI 直接红。**
证据快照同步刷新（`pass=true`）：`docs/qa/v8-components.json`（`…03:14:27.136Z`）、
`docs/qa/v8-file-size.json`（`…27.389Z`）、`docs/qa/v8-tokens.json`（`…27.628Z`）。

## 7. 累计进度（R74 组件收口）

| 层 | 批次 | 指标 | 门禁基线 |
|---|---|---|---|
| 弹层 `AlertDialog` | C1（V8.13） | 5 → 0 | `alertDialog 0` |
| 输入框裸 `TextField` | C2（V8.14–V8.20，8 批） | 60 → 0 | `textField 0` |
| 底部抽屉 `showModalBottomSheet` | **C3（V8.21，本批）** | **4 → 0**（`SsSheet` 引用 0 → 4 + 1 用例） | **`bottomSheet 0`** |
| 空态 `SsEmptyState` | C4 | 待做 | — |

## 8. 后续

- **C4**：空态层 `SsEmptyState`（当前引用 0，需逐处确认哪些空态该收口）。
- **预存反模式批次**：`build()` 内现建 `TextEditingController(text: …)`（本批未碰，仍是 3 处 + 前几批登记的若干处）。

## 9. 一句话总结

这一批把 R74 的**底部抽屉层从 0 引用做到 4 处全部收口（门禁 `bottomSheet 4 → 0`）**，
顺带按 R73 的门禁把 `SsSheet` 干净地拆成独立文件（而非白名单固化超限），
并且**两条既有单测各拦住了一次下意识回归**（refs 表头删除、设计文件超行），
最终把 API 形状收敛到「对外零变更」的 `subtitle` / `trailing` / `maxWidth` 三个可选位。
