# V8.14 / 批次 C2：增强 sanctioned 输入件并迁移首批 12 处裸 `TextField`

> 依据：`docs/audit/V8-COMPLIANCE-AUDIT.md` 批次 C 的 **C2**（裸 `TextField(` 60 处 / 24 文件），
> 以及 R71「先增强 sanctioned API 再迁移」的既定套路。

## 0. 一句话结论

`lib/features` 的裸 `TextField(` 由 **60 处降到 48 处**；组件门禁基线已同步锁到 48，
`alertDialog` 保持 0、`bottomSheet` 保持 4。本轮**没有为了迁移而放松任何判据**，
而且顺手修掉了一个此前一直静默失效的真缺陷（`SsTextInput.initialValue`）。

## 1. 为什么先改 sanctioned 组件，而不是直接替换

勘察（`lib/features/**/*.dart`，剥注释后统计）60 处的顶层具名参数频次：

| 参数 | 处数 |
|---|---|
| `decoration` | 60（全部） |
| `controller` | 56 |
| `onChanged` | 23 |
| `obscureText` | 8 |
| `maxLines` | 5 |
| `onSubmitted` | 5 |
| `keyboardType` | 3 |
| `textInputAction` | 2 |
| `style` | 2 |
| `focusNode` | 2 |
| `minLines` | 1 |
| `maxLength` | 1 |

而扩展前的 `SsTextInput` 只接受 `label / hint / controller / initialValue / onChanged /
obscure / mono / suffix`。也就是说 **60 处里有相当一部分根本无法机械替换** ——
强行替换只能靠删参数，那等于改行为（丢掉 `maxLength` 的输入上限、丢掉 `onSubmitted`
的提交回调、丢掉 `keyboardType` 的数字键盘）。所以按既定套路：**先把 sanctioned
组件的能力补齐，再迁移**。

## 2. `SsTextInput` 的能力扩展（对既有调用方零变更）

`app/lib/core/design/ss_input.dart`：

- `label` 由 `required String` 放宽为 `String?`（**源兼容**：原调用方仍传 `label:`；
  放宽是为了让只有 `hintText` 的搜索型输入也能用本组件）。
- 新增（全部默认值 = `TextField` / `InputDecoration` 的默认值，因此**行为零变更**）：

| 新参数 | 默认值 | 用途 |
|---|---|---|
| `onSubmitted` | `null` | 回车提交回调 |
| `maxLines` | `1` | 多行输入 |
| `minLines` | `null` | 多行输入最小高度 |
| `maxLength` | `null` | 输入上限（含计数器） |
| `keyboardType` | `null` | 数字键盘等 |
| `textInputAction` | `null` | 键盘动作键 |
| `focusNode` | `null` | 外部焦点控制 |
| `dense` | `false` | 映射到 `InputDecoration(isDense:)` |

- 组件由 `StatelessWidget` 改为 `StatefulWidget`（原因见 §3）。

「零变更」不是口头保证：新参数默认值与 Flutter 原生默认值逐一相同，
且本轮跑完全量 `flutter test`（**548 passed + 34 skipped**，与上一版基线 543 + 5 条新用例吻合）
——**没有任何既有用例变红**。

## 3. 顺手修掉的真缺陷：`initialValue` 静默失效

原 `SsTextInput` 声明了 `final String? initialValue`，但 `build()` **从头到尾没用过它**
（`TextField` 本身没有 `initialValue` 参数，只有 `controller`）。也就是说
`SsTextInput(label: '项目名', initialValue: 'CITY-NIGHT')` 会渲染成一个**空框**，
不报错、不告警。

全仓 `SsTextInput(` 调用点只有 **1 处**：`app/lib/dev/design_demo_page.dart:358`
（`SsTextInput(label: '项目名', initialValue: 'CITY-NIGHT', mono: true)`）—— 正是被静默忽略的那个。

修法：组件改为 `StatefulWidget`，在 `initState()` 里
「仅当调用方没给 `controller` 且给了 `initialValue` 时」自建一个
`TextEditingController(text: initialValue)`，并在 `dispose()` 释放。
调用方给了 `controller` 就以调用方的为准（优先级明确）。

> 这条属于「sanctioned 组件自身的缺陷」，不是迁移引入的问题 —— 与 V8.13 修
> `SsDialog` 缺 `Material` 是同一类收获：**只有真正把调用点搬过去，才会踩出组件里的洞**。

## 4. 本轮迁移的 12 处

### 4.1 `app/lib/features/libraries/gear_browser_add.dart`（4 处）

`_AddGearBody.build` 里的 4 个字段（原均带 `decoration: InputDecoration(labelText:, isDense: true)`）：

```dart
SsTextInput(label: '品牌', controller: brand, dense: true),
SsTextInput(label: '型号', controller: model, dense: true),
SsTextInput(label: '卡口（可空）', controller: mount, dense: true),
SsTextInput(
  label: '参考价（可空）',
  controller: price,
  dense: true,
  keyboardType: TextInputType.number,
),
```

**这 4 处已被现有测试真实验证**：`test/features/q6_gear_test.dart` 的
「添加设备」弹层端到端用例会输入品牌/型号 → 保存 → 查库，迁移后该文件 **9/9 全绿**。
（同文件的 `DropdownButtonFormField(initialValue: kind, …)` 未动 —— 不属 `TextField(` 统计口径。）

### 4.2 `app/lib/features/libraries/library_resource_editor.dart`（8 处）

| 字段 | 迁移后 |
|---|---|
| `_name` | `SsTextInput(label: '名称（2–30 字，必填）', controller: _name, maxLength: 30, onChanged: (_) => setState(() {}))` |
| `_contact` | `SsTextInput(label: '联系方式', controller: _contact)` |
| `_region` | `SsTextInput(label: '地区', controller: _region)` |
| `_price` | `SsTextInput(label: '合作报价 / 参考价', controller: _price)` |
| `_height` | `SsTextInput(label: '身高三维', controller: _height)` |
| `_style` | `SsTextInput(label: '风格 / 标签描述', controller: _style)` |
| `_tagCtl` | `SsTextInput(label: '标签（回车添加，≤10 个）', controller: _tagCtl, onSubmitted: …)` |
| `_note` | `SsTextInput(label: '备注（≤2000 字）', controller: _note, maxLines: 3)` |

（后 4 处外层原本是 `Expanded(child: TextField(…))`，迁移后为 `Expanded(child: SsTextInput(…))`。）

映射规则只有两条：`TextField(` → `SsTextInput(`；`decoration: InputDecoration(labelText: X)`
→ `label: X`。其余参数（`controller` / `maxLength` / `onChanged` / `onSubmitted` / `maxLines`）
原样保留，**没有任何一处靠删参数来凑迁移**。

## 5. 新增测试 `app/test/core/ss_input_test.dart`（5 条，全绿）

| 用例 | 守的是什么 |
|---|---|
| ① `initialValue` 生效 | §3 那个静默失效缺陷的回归（`find.text('CITY-NIGHT')` 命中） |
| ② 调用方 `controller` 优先于 `initialValue` | 优先级契约 |
| ③ `maxLines/minLines/maxLength` 透传 | 迁移中最容易被丢掉的参数 |
| ④ `onSubmitted/keyboardType/textInputAction` 透传 | 同上（并真的调一次回调验证接到） |
| ⑤ `obscure/dense` 透传 + `label` 可省略 | 新放宽的 `String? label` |

`_wrap` 只需 `MaterialApp(home: Scaffold(...))`（组件只读 `Theme.of(context).brightness`，
不需要 `ProviderScope`）。

## 6. 六件门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 257 files，**0 changed**（首跑 1 changed，复跑归零） |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!** |
| `flutter test --no-pub` | **548 passed + 34 skipped**（基线 543 + 5 条新用例，**零回归**） |
| `node tool/check_file_size.mjs` | **PASS**（Top：575 `refs_page.dart` / 566 `poses_controller.dart` / 550 `lighting_controller.dart`） |
| `node tool/check_tokens.mjs` | **PASS**（四类全 0） |
| `node tool/check_components.mjs` | **PASS**；`textField` **48（基线 60 → 已锁 48）**、`textFormField` 0、`bottomSheet` 4、`alertDialog` 0 |

## 7. 基线锁定

`node tool/check_components.mjs --write-baseline`（**降低基线不需要 `--allow-increase`**）：

```json
"textField": 48, "textFormField": 0, "bottomSheet": 4, "alertDialog": 0
```

证据快照 `docs/qa/v8-components.json` 已同步刷新。
**意义**：`textField` 的 60 → 48 是真降下来的，而不是把门禁放宽 ——
今后任何新增裸 `TextField(` 都会让 CI 直接红。

## 8. 如实登记的归一化差异

迁移后这些输入框的样式改由 `SsTextInput` 决定：

- 文字样式：`AppType.body.style(p.ink)`（原来是 `ThemeData` 的默认 body 样式）；
- 装饰：`InputDecoration(labelText:)`（原来也是 `labelText`，**这一项无变化**）；
- 密度：`gear_browser_add.dart` 的 `isDense: true` 用新参数 `dense: true` 精确保留；
  `library_resource_editor.dart` 原本就没有 `isDense`，`dense` 默认 `false` → 一致。

即：**唯一可见差异是文字样式改走令牌**（这正是收口目的），密度与标签位置未变。

## 9. 剩余与后续计划

- **C2 剩余 48 处**（按密度降序）：`settings/settings_page_sources.dart`(11)、
  `planner/planner_module_editors_b.dart`(5)、`planner/planner_module_editor.dart`(4)、
  `planner/planner_module_editors_a.dart`(4)、`ai/ai_provider_card.dart`(3)、
  `planner/planner_page_dialogs.dart`(3)、`libraries/gear_browser.dart`(2)、
  `planner/planner_page_pose_dialogs.dart`(2)，另 14 个文件各 1 处。
  其中用到 `obscureText`(8) 的（如 `ai/ai_provider_card.dart` 的密钥框）可直接用 `obscure: true`。
- **C3**：4 处 `showModalBottomSheet` → `showSsSheet`。
- **空态**：`SsEmptyState` 引用数为 0，需逐处确认是否真有该场景。
