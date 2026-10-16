# V8.17 / C2 第五批：两个 planner 文件共 8 处裸 `TextField(` 收口

> 合同依据：R71「先增强 sanctioned API、再迁移」；R74 输入框层收口；
> R79「测试数只增不减」；R82 反模式（「低清充数 / 虚报覆盖率 / 跳过门禁」出现即返工）。

## 1. 一句话结论

`lib/features` 裸 `TextField(` 由 **32 → 24**；组件门禁 `textField` 基线同步锁到 **24**
（只降不升）；`textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0 均不变；
六件门禁全绿（全量 test **548 passed + 34 skipped**，零回归）；
**未放松任何判据，无一处靠删参数凑迁移**。

## 2. 本批范围与逐处映射

| # | 文件 | 原行 | 类型 | 迁移后 |
|---|---|---|---|---|
| 1 | `planner/planner_module_editor.dart` | 18..25 | hint | `hint: '模块标题', dense: true` |
| 2 | 同上 | 96..104 | label | `label: '纬度', dense: true` |
| 3 | 同上 | 108..116 | label | `label: '经度', dense: true` |
| 4 | 同上 | 121..131 | hint | `hint: '日期 yyyy-MM-dd', dense: true` |
| 5 | `planner/planner_module_editors_a.dart` | 379..388 | hint | `hint: '焦段', dense: true` |
| 6 | 同上 | 407..416 | hint | `hint: '机位', dense: true` |
| 7 | 同上 | 420..429 | hint | `hint: '姿势', dense: true` |
| 8 | 同上 | 436..445 | hint | `hint: '备注（可选）', dense: true` |

映射规则只有三条（与 V8.14/V8.15/V8.16 完全一致）：

1. `TextField(` → `SsTextInput(`；
2. `decoration: const InputDecoration(hintText: X, isDense: true)` → `hint: X,` + `dense: true,`；
3. `decoration: const InputDecoration(labelText: X, isDense: true)` → `label: X,` + `dense: true,`。

`controller` / `onChanged` / 外层 `child:` 一律原样保留。
`SsTextInput` 在 V8.14 已把 `label` 放宽为可空，所以「只有 hint、没有 label」的
行内编辑框（本批 6 处）也能换壳 —— 这是 V8.14 那次 API 增强的直接收益。

## 3. ★ 如实登记的预存反模式（本批未改）

这 8 处（以及 V8.16 的 5 处）都在 `build()` 里现建 `TextEditingController(text: …)`：

```dart
SsTextInput(
  controller: TextEditingController(text: module.title),   // ← 每次 rebuild 都新建
  hint: '模块标题',
  dense: true,
  onChanged: …,
)
```

两个真实代价：

- 旧 controller **从不释放**（无 `dispose`）；
- 每次 rebuild 都会用新 controller 重建输入框，**光标位置与选区会被重置**。

**不顺手修的理由**：修它必须决定状态归属，而两条路都改变行为 ——
把 controller 提升出 `build()` 需要把它挂到 State 上（这些控件嵌在
`ListView` 的行构造器里，改动面超出机械迁移）；改用 `SsTextInput(initialValue:)`
则会让外部数据变更不再反映到输入框（当前靠「每次重建 controller」实现同步）。
故本批**只登记、不修**，建议单开一批（与 V8.16 报告 §3 同一笔账）。

## 4. 六件门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | **257 files, 0 changed**（1.17s）|
| `flutter analyze --no-pub --fatal-infos` | **No issues found!（9.5s）**|
| `flutter test --no-pub` | **548 passed + 34 skipped, All tests passed!, EXIT 0**（零回归）|
| `node tool/check_file_size.mjs` | **PASS** |
| `node tool/check_tokens.mjs` | **PASS**（四类全 0）|
| `node tool/check_components.mjs` | **PASS**（`textField` **24**（基线 32）/ `textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0）|

## 5. 基线锁定

`node tool/check_components.mjs --write-baseline`（降基线不需 `--allow-increase`）→

```json
{"textField": 24, "textFormField": 0, "bottomSheet": 4, "alertDialog": 0}
```

`at = 2026-10-16T16:53:14.496Z`；证据快照 `docs/qa/v8-components.json` 已同步刷新。
**今后任何新增裸 `TextField(` 都会让 CI 直接红。**

## 6. 累计进度（C2 输入框层收口）

| 阶段 | 迁 | 文件 | 计数 |
|---|---|---|---|
| 起点 | — | — | 60 |
| V8.14 | 12 | `gear_browser_add.dart` 4 + `library_resource_editor.dart` 8 | 48 |
| V8.15 | 11 | `settings_page_sources.dart` | 37 |
| V8.16 | 5 | `planner_module_editors_b.dart` | 32 |
| **V8.17** | **8** | `planner_module_editor.dart` 4 + `planner_module_editors_a.dart` 4 | **24** |

**合计已迁 36 / 60。**

## 7. 剩余 24 处与后续

按密度：`ai/ai_provider_card.dart` 3（含 `obscureText` 密钥框 → `obscure: true`）、
`planner/planner_page_dialogs.dart` 3、`libraries/gear_browser.dart` 2、
`planner/planner_page_pose_dialogs.dart` 2，另 14 个文件各 1 处。

之后是 **C3**（4 处 `showModalBottomSheet` → `showSsSheet`：`planner/planner_page_layout.dart:252`、
`refs/refs_hit_drawer.dart:187`、`poses/character_picker.dart:41`、`poses/pose_gallery.dart:186`）
与空态 `SsEmptyState`（当前引用 0，需逐处确认哪些空列表该用它）。
