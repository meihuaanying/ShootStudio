# V8.16 / C2 第四批：`planner_module_editors_b.dart` 5 处 hint 型输入框收口

> 合同依据：R71「先增强 sanctioned API 再迁移」+ R82 反模式（「低清充数 / 虚报覆盖率 /
> 跳过门禁」出现即返工）。上一批 V8.14 已把 `SsTextInput` 的能力补齐到覆盖真实用到的
> 参数集合，本批起迁移退化为逐参数一一对应换壳。

## 1. 一句话结论

`lib/features` 裸 `TextField(` 由 **37 → 32**；组件门禁 `textField` 基线同步锁到 **32**
（只降不升）；`textFormField` 保持 0、`bottomSheet` 保持 4、`alertDialog` 保持 0；
六件门禁全绿（全量 test **548 passed + 34 skipped**，零回归）；**未为迁移放松任何判据**，
**也没有任何一处靠删参数凑迁移**。

## 2. 本批范围与逐处映射

文件：`app/lib/features/planner/planner_module_editors_b.dart`（321 行，5 处）。

这 5 处的形态与前三批不同 —— **全部是「只有 hint、没有 label」的行内编辑框**，
且 `decoration` 里只有 `hintText` + `isDense`：

| # | 原行 | 数据源 | 迁移后 |
|---|---|---|---|
| 1 | 87..101 | `rows[i]['item']` | `hint: '项目', dense: true` |
| 2 | 105..119 | `rows[i]['price']` | `hint: '金额', dense: true` |
| 3 | 124..138 | `rows[i]['note']` | `hint: '备注', dense: true` |
| 4 | 179..195 | `rows[i][fields[f]]` | `hint: labels[f], dense: true`（动态 hint） |
| 5 | 301..313 | `module.data['note']` | `hint: '补充说明（可空）', dense: true` |

**三条映射规则**（与前批一致，本批无新增规则）：

1. `TextField(` → `SsTextInput(`；
2. `decoration: [const] InputDecoration(hintText: X, isDense: true,)` → `hint: X,` + `dense: true,`；
3. `controller` / `onChanged` 原样保留。

`label` 可省略是 V8.14 放宽的结果（`String? label`），所以「只有 hint」这类输入框
现在也能换壳，不需要为它们编造一个 label。

## 3. ★ 如实登记的预存反模式（本批**未改**，不属机械迁移范围）

这 5 处都在 `build()` 里**现建 `TextEditingController(text: …)`**：

```dart
child: TextField(
  controller: TextEditingController(text: '${rows[i]['item'] ?? ''}'),
  ...
```

这是**本批之前就存在**的写法，不是迁移引入的。它的两个真实代价：

- **controller 从不释放** —— 每次 rebuild 新建一个，旧的既没人 dispose 也没人引用；
- **rebuild 会重置光标/选区** —— 用户输入 → `onChanged` 更新数据 → rebuild → 新
  controller 用模型值重新初始化 → 光标跳位。

**为什么本批不顺手修**：修它必须决定状态归属，两条路都会**改变行为**：

- 把 controller 提升出 `build()`（改 `StatefulWidget` / 建 controller 池）—— 改动面
  超出「机械迁移」，且这 5 处嵌在 `ListView` 行构造器里，提升需要额外设计；
- 改用 `SsTextInput(initialValue: …)` 让组件自持 controller —— 光标问题会消失，但
  **外部数据变更将不再反映到输入框**（当前写法每次 rebuild 都会刷新），属行为变更。

故本批**只登记不修**，把它作为独立一轮处理（建议单开一批：先定「这些行内编辑框的
真实数据源与重建时机」，再选 controller 归属）。登记在此以免后人以为迁移漏了什么。

## 4. 六件门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | **257 files, 0 changed**（1.43s）|
| `flutter analyze --no-pub --fatal-infos` | **No issues found!（12.0s）**|
| `flutter test --no-pub` | **548 passed + 34 skipped，All tests passed!，EXIT 0** |
| `node tool/check_file_size.mjs` | **PASS** |
| `node tool/check_tokens.mjs` | **PASS**（自造色值 / 内置色板 / 字号字重时长 / 间距圆角裸数字四类全 0）|
| `node tool/check_components.mjs` | **PASS**；`textField` **32**（基线 37）/ `textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0 |

`analyze` 无 issue 说明 `part of planner_page.dart` 的父库已能见到 `SsTextInput`，
本批不需要新增 import。

## 5. 基线锁定

`node tool/check_components.mjs --write-baseline`（降基线**不需要** `--allow-increase`）→
`app/tool/component_baseline.json`：

```json
{"textField": 32, "textFormField": 0, "bottomSheet": 4, "alertDialog": 0}
```

`at = 2026-10-16T16:44:02.038Z`。证据快照 `docs/qa/v8-components.json` 已同步刷新。
**意义：今后任何新增裸 `TextField(` 都会让 CI 直接红。**

## 6. 累计进度（C2）

| 阶段 | 文件 | 迁移数 | 门禁 `textField` |
|---|---|---|---|
| 起点 | — | — | 60 |
| V8.14 | `gear_browser_add.dart` 4 + `library_resource_editor.dart` 8 | 12 | 48 |
| V8.15 | `settings_page_sources.dart` | 11 | 37 |
| **V8.16** | `planner_module_editors_b.dart` | **5** | **32** |

**合计已迁 28 / 60。**

## 7. 剩余 32 处与后续

按密度：`planner/planner_module_editor.dart` 4、`planner/planner_module_editors_a.dart` 4、
`ai/ai_provider_card.dart` 3（含 `obscureText` 密钥框 → `obscure: true`）、
`planner/planner_page_dialogs.dart` 3、`libraries/gear_browser.dart` 2、
`planner/planner_page_pose_dialogs.dart` 2，另 14 个文件各 1 处。

C3（4 处 `showModalBottomSheet` → `showSsSheet`）与空态 `SsEmptyState`（引用 0）尚未开始。
