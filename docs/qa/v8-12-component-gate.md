# V8.12 / 批次 B：组件门禁落地 + R73 快照刷新 + 一份必须公开的更正

> 依据：`docs/audit/V8-COMPLIANCE-AUDIT.md` 排定的批次 B（B1/B2/B3）。
> 本阶段的核心产出不只是两件门禁，还包括**推翻我自己在 V8.10 写下的一个错误结论**。

## 0. 一句话结论

批次 B 三项全部完成，但其中 **B1 的立项前提是错的**（门禁本来就有牙齿），
而做 B2 的过程中发现 **R74 并未在 V8.10 收口到 0 —— 实际还剩 5 处活着的 `AlertDialog`**。
V8.10 的「lib 内 AlertDialog 归零」是**扫描假阴性**。本报告把这件事写清楚，
并已同步更正偏差登记、阶段报告与交接文档。

## 1. B1：R73 文件行数门禁 —— 前提误判，验收标准其实已满足

### 1.1 审计当时写的前提
> 「刷新 `docs/qa/v8-s3-file-size.json` 白名单为当前实测行数，使 R73 门禁重新有牙齿。」

### 1.2 实测：门禁一直有牙齿
`app/tool/check_file_size.mjs`（96 行）的判定逻辑：

```js
const allowed = baseline.baseline[rel] ?? 0;   // 白名单没有该文件 → 允许 0 行
if (lines > allowed) { violations.push(...) }  // 直接违规
```

限额 `lib/features/**/*.dart ≤ 600`、`lib/core/design/*.dart ≤ 300`，另有 `HEADROOM = 40`
的「基线上调」检查。而基线文件 `app/tool/file_size_baseline.json` 的 `baseline`
**本来就是空表（0 项）** —— 也就是说没有任何文件被豁免，600/300 一直在被真实强制。

**注入式验收（实测，脚本 `%TEMP%opencode/b1_probe.py`）**：

| 注入文件 | 结果 |
|---|---|
| `lib/features/_probe_700.dart`（701 行） | `exit=1` `✗ 701 行 > 允许 0（上限 600）` |
| `lib/core/design/_probe_400.dart`（401 行） | `exit=1` `✗ 401 行 > 允许 0（上限 300）` |
| 两文件删除后重跑 | `exit=0` `[file-size] PASS` |

**所以 B1 不需要改门禁代码。** 审计的前提误判来自对「白名单」二字的望文生义 ——
以为非空才是有效，实际这份门禁的设计是「空表 = 零豁免 = 最严」。

### 1.3 B1 唯一真交付：刷新陈旧的**证据快照**
真正陈旧的是报告快照 `docs/qa/v8-s3-file-size.json`：它记着 `"at": "2026-09-30T08:25:38.252Z"`，
里面还留着**拆分前**的 `lib/features/planner/planner_page.dart` `lines: 2637` / `allowed: 2676`。
门禁本身没错，但这份快照会让任何读它的人以为「有 2637 行的大文件被豁免」——
**证据与事实不符，就是文档缺陷**。已用门禁自身重新生成：

```
node tool/check_file_size.mjs --json=<绝对路径>
```
刷新后 `at=2026-10-16T07:19:30.516Z`、`baseline_entries=0`，旧的 2637 行条目消失。

**工具坑（已踩）**：该脚本只认 **`--json=<path>` 的等号形式**（源码 `argv.find((a) => a.startsWith(`--${name}=`))`）。
写成 `--json <path>`（空格分隔）会被**静默忽略**，不写文件、也不报错。

## 2. B2：新增组件门禁 `app/tool/check_components.mjs`

### 2.1 目的
R74 收口是「用 sanctioned 组件替换裸 Flutter 组件」。V8.2→V8.10 五轮都是**手工迁移**，
迁完没有任何东西阻止新代码再写回裸组件 —— 即「迁完就散架」。本门禁把当前存量钉成基线，
**只降不升**。

### 2.2 指标与 sanctioned 对应关系

| 指标 | 模式 | 当前 | 应改用 |
|---|---|---|---|
| `textField` | `\bTextField(<…>)?(` | **60** | `SsTextInput` / `SsSearchField` |
| `textFormField` | `\bTextFormField(<…>)?(` | **0** | `SsTextInput`（含校验场景） |
| `bottomSheet` | `showModalBottomSheet(<…>)?(` | **4** | `showSsSheet` |
| `alertDialog` | `AlertDialog(` | **5** | `showSsDialog` / `SsDialog` |

扫描 `lib/features/**/*.dart`（99 个文件），**先剥注释**（行尾 `//` 与 `/* */` 块），
避免把注释里的示例算进去。

### 2.3 一个真实的实现坑：Dart 泛型调用
初版把 `showModalBottomSheet` 报成 **0 处**（真值 4）。原因是 Dart 允许把类型实参夹在
函数名与左括号之间：

```dart
showModalBottomSheet<void>(...)
showModalBottomSheet<CharacterSelection>(...)
```

固定字符串 `showModalBottomSheet(` 一个都匹配不到。修法是让每个模式都允许可选类型实参：

```js
const TYPE_ARGS = String.raw`(?:\s*<[^<>()]*>)?`;
// 再 new RegExp(...) 拼装
```

**同类缺陷正是 R74 假阴性的成因**（见 §3），所以这个 bug 值得单列。

### 2.4 基线与「只降不升」

- 基线文件 `app/tool/component_baseline.json`：`{version, note, at, metrics, totals, files}`。
- 复跑时若任一指标总量**上涨** → `FAIL` 并打印涨了什么；另做逐文件 diff（前 20 条）。
- 播种必须显式：首次 `--write-baseline` **被拒绝**（rc=1，因为基线为空、全部指标都算「上涨」）
  —— 这是刻意的设计（要求人工复核过数字才能定基线），需 `--write-baseline --allow-increase`。
- 三个开关：`--json=<path>` 落证据 / `--write-baseline` 写基线 / `--write-baseline --allow-increase` 显式允许上调。

**反向验证（证明不是装饰门禁）**：临时新增 `lib/features/_cmp_probe.dart`（含 1 个 `TextField`）

```
✗ textField 61 处（基线 60）      rc=1
```

删除该文件后 → `[components] PASS`，`rc=0`。

### 2.5 证据与 CI 接线

- 证据快照 `docs/qa/v8-components.json`（`at=2026-10-16T07:21:49.326Z`，totals 与基线一致），**入库**。
- `.github/workflows/ci.yml` 的 `analyze-test` job，在 token gate 之后、`flutter analyze` 之前插入：

```yaml
      - name: "Component gate (R74 no new bare TextField / bottom sheet / AlertDialog)"
        run: node tool/check_components.mjs --json=../docs/qa/v8-components.json
```

（全局 `defaults.run.working-directory: app`，故用 `../docs/qa/...` 写到仓库根。）
YAML 已用 `yaml.safe_load` 验证可解析，`analyze-test` 的 step 顺序为：
checkout | flutter-action | pub mirror | sqlite(Linux) | sqlite(Windows) | pub get |
dart format | File size gate | Design token gate | **Component gate** | flutter analyze |
Engine aim math | Gear pipeline selftest | Gear coverage | Gear sources spot-check | flutter test。

## 3. ★ 必须公开的更正：R74 并未收口到 0，还剩 5 处活着的 `AlertDialog`

### 3.1 V8.10 写下的结论（错误）
> 「lib 内 AlertDialog 归零」「偏差 10 已消除」。

### 3.2 事实
`lib/features` 内 `AlertDialog(` 字面量实测 **5 处**，且**全部是活代码路径**：

| 宿主类 | `return AlertDialog(` | 渲染调用点（证明活着） |
|---|---|---|
| `ResourceEditorDialog` | `library_resource_editor.dart:97` | `libraries_page.dart:451` |
| `_ColorPickerDialog` | `planner_page_dialogs.dart:220` | `planner_module_editor.dart:420` |
| `_PoseInfoDialog` | `planner_page_pose_dialogs.dart:22` | `planner_module_editors_a.dart:223` |
| `_PoseReplaceDialog` | `planner_page_pose_dialogs.dart:117` | `planner_module_editors_a.dart:236` |
| `_BudgetEstimateDialog` | `planner_page_pose_dialogs.dart:217` | `planner_module_editors_b.dart:52` |

### 3.3 假阴性的成因（技术根因）
V8.10 的终局扫描用的是：

> 「找 `showDialog<` 调用点，看它后面 ±1500 字符窗口里有没有 `AlertDialog`」

但这 5 处的形态是 **「独立 widget 类的 `build()` 里 `return AlertDialog(`」**，
调用点在**另一个文件**：

```dart
// planner_module_editor.dart:420
showDialog<void>(builder: (_) => const _ColorPickerDialog())

// planner_page_dialogs.dart:220  （另一个文件）
class _ColorPickerDialog extends StatefulWidget { ... build() => AlertDialog(...) }
```

调用点的 1500 字符窗口里**永远看不到 `AlertDialog` 字面量** → 扫描得出 0。
这不是「迁完了」，是**没看见**。与 §2.3 的泛型漏计是同一类缺陷：**用「附近有没有某字符串」
代替「这个符号在哪里被渲染」**。

### 3.4 真实账目
**原始 16 处 `AlertDialog` = 已迁 11（V8.2 三处 + V8.7 四处 + V8.8 四处中的迁移部分 + V8.9 一处 + V8.10 两处）+ 剩 5（从未被计入）。**

先前审计的「C 类」其实**记过** `planner_page_pose_dialogs.dart:117/217` 并注明「helper 返回 AlertDialog，调用方另找」，
但 V8.10 的终局扫描把它当成了 0 —— 结论错了，记录没错，是最后一步没对上。

### 3.5 已做的更正
- `docs/qa/v8-r71-deviations.md` **偏差 10 重新开放**：标题改为「R74 组件收口未完成（16 处中已迁 11，剩 5 处仍活着）」，
  列出 5 处宿主类/行号/渲染调用点，状态改为「**仍未消除**」，并写明假阴性成因。
- `docs/audit/V8-COMPLIANCE-AUDIT.md` 同步更正。
- `HANDOFF_V8.md` 三处「R73 白名单陈旧（门禁形同虚设）」改为准确表述。
- 本报告。

## 4. B3：偏差 10 更正 —— 已在批次 A2 提前完成

## 5. 门禁实测（本阶段）

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 256 files，**0 changed** |
| `flutter analyze --no-pub --fatal-infos` | **No issues found**（11.9s） |
| `flutter test --no-pub` | **543 passed + 34 skipped**（无 Dart 改动，与 v8.11.0 一致） |
| `node tool/check_file_size.mjs` | **PASS**（115 文件，白名单 0 项） |
| `node tool/check_tokens.mjs` | **PASS**（0 / 0 / 0 / 0） |
| `node tool/check_components.mjs` | **PASS**（60 / 0 / 4 / 5） |

## 6. 影响面

- **零 Dart 改动**：本阶段只新增两个 Node 工具、一份基线/证据 JSON，改 `ci.yml` 与三份文档。
  故测试计数与 v8.11.0 完全一致，无回归面。
- 新增的 `Component gate` 是**软门禁**：它只拦「新增裸组件」，不要求立刻迁移存量 ——
  存量迁移（批次 C）可以按自己的节奏做，做完把基线往下调即可。

## 7. 一句话总结

批次 B 交付了两件真门禁，但更有价值的是它**暴露了我自己的一个错误结论**：
用「字符串附近有没有」代替「符号在哪里被渲染」，会把「没看见」误报成「已完成」。
偏差 10 已重新开放，真实数字是 **16 处已迁 11、剩 5**。
