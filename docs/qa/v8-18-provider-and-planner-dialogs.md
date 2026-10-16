# V8.18 / C2 第六批：ai_provider_card + planner_page_dialogs 共 6 处裸 TextField 收口

> 承接 V8.14 / V8.15 / V8.16 / V8.17。本批仍走 R71「先增强 sanctioned API 再迁移」的既定套路 ——
> V8.14 已把 `SsTextInput` 的能力补齐到覆盖 60 处真实用到的参数集合，所以本批可以逐参数一一对应换壳，
> **没有一处靠删参数凑迁移**。

## 1. 一句话结论

`lib/features` 裸 `TextField(` 由 **24 → 18**；组件门禁 `textField` 基线同步锁到 **18**（只降不升）；
`textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0 不变；六件门禁全绿（全量 test **548 passed + 34 skipped**，零回归）。

## 2. 本批 6 处逐处映射

| # | 文件 | 行 | 关键参数 | 迁移后 |
|---|---|---|---|---|
| 1 | `ai/ai_provider_card.dart` | 84..90 | `labelText` + `isDense` | `label: 'Base URL', dense: true` |
| 2 | `ai/ai_provider_card.dart` | 92..111 | `obscureText: _obscure`（变量）+ 动态 `hintText` + `suffixIcon: IconButton` | `obscure: _obscure, label: provider.keyHint, hint: <条件表达式>, dense: true, suffix: IconButton(…原样…)` |
| 3 | `ai/ai_provider_card.dart` | 117..123 | 条件表达式内 `? TextField(...)` | `? SsTextInput(controller: _model, label: '模型名', dense: true,)` |
| 4 | `planner/planner_page_dialogs.dart` | 71..77 | `focusNode` + `maxLines: 8` + `hintText`（**原无 `isDense`**） | `focusNode: _focus, maxLines: 8, hint: widget.hint, onChanged: widget.onChanged`（**刻意不加 `dense`**） |
| 5 | `planner/planner_page_dialogs.dart` | 148..155 | `labelText` + `isDense`（`child:` 内） | `child: SsTextInput(controller: _controller, label: '城市（内置城市库，输入即筛选）', dense: true, onChanged: _filter)` |
| 6 | `planner/planner_page_dialogs.dart` | 265.. | `labelText` + `isDense` | `label: '色值 #RRGGBB', dense: true`（`onChanged` 里的 HSV 解析体一字未动） |

三条映射规则（与前几批一致）：

1. `TextField(` → `SsTextInput(`；
2. `decoration: [const] InputDecoration(labelText: X, isDense: true)` → `label: X,` + `dense: true,`（`hintText:` 同理 → `hint: X,`）；
3. `controller` / `onChanged` / `child:` / 条件表达式结构原样保留。

## 3. 本批新覆盖到的 `SsTextInput` 能力（V8.14 扩展的回报）

本批用到了扩展后新增的 **`obscure`（传变量而非字面量 `true`）/ `suffix`（IconButton）/ `focusNode` / `maxLines`**，
以及原有的 `label` / `hint`（含三目条件表达式）/ `dense`。
**如果 V8.14 没有先做能力扩展，这 6 处里至少 #2、#4 两处只能靠删参数（=改行为）才能换壳。**

另：#4 原代码**没有** `isDense`，故迁移后也**不加** `dense` —— `dense: false` 与不传等价，但不传更贴近原文意图。

## 4. 六件门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | **257 files, 0 changed**（首跑 1 changed → 复跑归零） |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!（9.8s）** |
| `flutter test --no-pub` | **548 passed + 34 skipped, All tests passed!，EXIT 0** |
| `node tool/check_file_size.mjs` | **PASS** |
| `node tool/check_tokens.mjs` | **PASS**（自造色值 / 内置色板 / 字号字重时长 / 间距圆角裸数字 四类全 0） |
| `node tool/check_components.mjs` | **PASS**；`textField` **18**（基线 24）/ `textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0 |

## 5. 基线锁定

`node tool/check_components.mjs --write-baseline`（**降基线不需 `--allow-increase`**）→

```json
{"textField": 18, "textFormField": 0, "bottomSheet": 4, "alertDialog": 0}
```

`at = 2026-10-16T17:03:15.239Z`；证据快照 `docs/qa/v8-components.json` 已同步刷新。
**含义：今后任何新增的裸 `TextField(` 都会让 CI 直接红。**

## 6. 累计进度（C2）

| 批次 | 文件 | 迁 | 余 |
|---|---|---|---|
| 起点 | — | — | 60 |
| V8.14 | `gear_browser_add.dart` 4 + `library_resource_editor.dart` 8 | 12 | 48 |
| V8.15 | `settings_page_sources.dart` | 11 | 37 |
| V8.16 | `planner_module_editors_b.dart` | 5 | 32 |
| V8.17 | `planner_module_editor.dart` 4 + `planner_module_editors_a.dart` 4 | 8 | 24 |
| **V8.18** | **`ai_provider_card.dart` 3 + `planner_page_dialogs.dart` 3** | **6** | **18** |

**合计已迁 42 / 60。**

## 7. 剩余 18 处与后续

按密度：`libraries/gear_browser.dart` 2、`planner/planner_page_pose_dialogs.dart` 2，另 14 个文件各 1 处。
之后是 **C3**（4 处 `showModalBottomSheet` → `showSsSheet`：`planner/planner_page_layout.dart:252`、
`refs/refs_hit_drawer.dart:187`、`poses/character_picker.dart:41`、`poses/pose_gallery.dart:186`）
与空态 `SsEmptyState`（引用 0，需逐处确认）。

## 8. 一句话总结

纯机械迁移的第六批：`SsTextInput` 的能力面已经够宽，本批 6 处（含 1 处 `obscure` 变量、1 处 `suffix`、1 处 `focusNode`+`maxLines`）
全部逐参数一一对应换壳；基线从 24 降到 18，下降本身就是可验证的证据。
