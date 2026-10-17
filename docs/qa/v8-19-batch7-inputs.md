# V8.19 / C2 第七批：`gear_browser` + `planner_page_pose_dialogs` 共 4 处裸 `TextField` 收口

> 合同依据：R71「先增强 sanctioned API 再迁移」；R74 组件收口；R82「禁止虚报」。
> 前置：V8.14 已把 `SsTextInput` 从 7 参扩到 16 参（默认值逐一等于 Flutter 原生默认值），
> 所以本批仍是「逐参数一一对应换壳」，无一处靠删参数凑迁移。

## 1. 一句话结论

`lib/features` 裸 `TextField(` 由 **18 → 14**；组件门禁 `textField` 基线同步锁到 **14**（只降不升）；
`textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0 不变；六件门禁全绿，
全量 test **548 passed + 34 skipped** 零回归。

## 2. 本批 4 处逐处映射

| # | 文件 : 行 | 原写法要点 | 迁移后 |
|---|---|---|---|
| 1 | `libraries/gear_browser.dart:257` | `decoration: InputDecoration(hintText: '品牌/型号/焦段/F2.8/CRI', isDense: true)` + `onChanged` | `SsTextInput(hint: '品牌/型号/焦段/F2.8/CRI', dense: true, onChanged: …)` |
| 2 | `libraries/gear_browser.dart:439` | `controller` + `hintText: 'https://…（jpg/png/webp）'` + `isDense`（**在 V8.7 迁过的「粘贴图片链接」弹层内**） | `SsTextInput(controller: controller, hint: 'https://…（jpg/png/webp）', dense: true)` |
| 3 | `planner/planner_page_pose_dialogs.dart:131` | `hintText: '搜索姿势名，例如：回眸 / 蹲'` + `isDense` + `onChanged`（**在 V8.13 迁过的 `_PoseReplaceDialog` 内**） | `SsTextInput(hint: '搜索姿势名，例如：回眸 / 蹲', dense: true, onChanged: …)` |
| 4 | `planner/planner_page_pose_dialogs.dart:267` | `controller: _people` + `labelText: '人数（餐饮按人数估算）'` + `isDense` + `keyboardType: TextInputType.number`（**在 V8.13 迁过的 `_BudgetEstimateDialog` 内**） | `SsTextInput(controller: _people, label: '人数（餐饮按人数估算）', dense: true, keyboardType: TextInputType.number)` |

三条映射规则（与前几批一致）：
1. `TextField(` → `SsTextInput(`；
2. `decoration: [const] InputDecoration(hintText: X, isDense: true)` → `hint: X,` + `dense: true,`；
   `labelText: X` → `label: X`；
3. `controller` / `onChanged` / `keyboardType` / `child:` 一律原样保留。

注意第 2、3、4 处都**落在前几批已经迁成 `SsDialog` 的弹层内部** —— 说明 R74（弹层外壳）与 C2（输入框）
是两条正交的收口线：外壳换了不等于内部控件也换了。第 3 处所在弹层还刻意保留了
`SizedBox(width: 360, height: 380)`（因为内部有 `Expanded(ListView)`，需要界高度），本批只换输入框，未动它。

## 3. ★ 必须公开的执行偏差（本批最重要的一条记录）

**计划 4 处，但首轮只生效 3 处。** `gear_browser.dart` 的第 2 处 edit 工具返回了「成功」，
但收尾时 `check_components` 只报 `textField` 从 18 降到 **15**（而非 14）。改用
`grep -n "TextField(" app/lib/features` 实测，确认 `gear_browser.dart:439` 的 `TextField(` **仍在文件里**。
（期间本会话经历过两次服务器重启，已无法区分是「重启回滚」还是「当时其实没真正落盘」。）
随后对该处**补做 edit**，`textField` 由 15 降到 14，与预期一致。

**教训（已写进流程）**：`edit` 返回成功 **不等于** 文件已改。每批收尾必须
① `grep -n "TextField("` 实测计数，② 与 `check_components` 的读数对照，
不能只信编辑工具的返回值，也不能只信自己上一轮写的压缩摘要。

## 4. 六件门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | **257 files, 0 changed**（2.42s） |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!**（26.4s） |
| `flutter test --no-pub` | **548 passed + 34 skipped，All tests passed!**（零回归） |
| `node tool/check_file_size.mjs` | **PASS** |
| `node tool/check_tokens.mjs` | **PASS**（四类全 0） |
| `node tool/check_components.mjs` | **PASS**（`textField` **14**（基线 18）/ `textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0） |

## 5. 基线锁定

`node tool/check_components.mjs --write-baseline`（降基线不需 `--allow-increase`）：

```json
{"textField": 14, "textFormField": 0, "bottomSheet": 4, "alertDialog": 0}
```

`at = 2026-10-17T00:29:11.901Z`；证据快照 `docs/qa/v8-components.json` 已同步刷新。

## 6. 累计进度（C2 输入框层）

| 阶段 | 迁移数 | 余量 |
|---|---|---|
| 起点 | — | 60 |
| V8.14 | 12 | 48 |
| V8.15 | 11 | 37 |
| V8.16 | 5 | 32 |
| V8.17 | 8 | 24 |
| V8.18 | 6 | 18 |
| **V8.19** | **4** | **14** |

**合计已迁 46 / 60。**

## 7. 剩余 14 处与后续

每文件各 1 处（`grep` 实测行号）：
`home/home_hero.dart:55`、`poses/cinematic_refs.dart:140`、`settings/settings_page_cards.dart:178`、
`ai/ai_panel.dart:164`、`settings/settings_page.dart:263`、`libraries/libraries_page.dart:267`、
`poses/poses_page_layout.dart:42`、`refs/refs_home.dart:50`、`ai/ai_side_panel.dart:153`、
`poses/pose_import_page_layout.dart:280`、`planner/planner_page_canvas.dart:27`、
`planner/planner_page_layout.dart:432`、`lighting/widgets/lighting_inspector.dart:266`、
`lighting/widgets/lighting_pose_widgets.dart:227`。

之后：**C3** 4 处 `showModalBottomSheet` → `showSsSheet`；空态 `SsEmptyState` 引用 0 需逐处确认；
以及已登记未修的预存反模式（多处 `build()` 里现建 `TextEditingController(text: …)`）。

## 8. 一句话总结

本批技术上是 4 处例行换壳，但真正有价值的是第 3 节那条教训：
**编辑工具报「成功」不代表文件已改，收尾必须用 grep + 门禁实测交叉核对**。
