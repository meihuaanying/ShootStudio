# V8.20 / C2 第八批：剩余 14 处裸 `TextField(` 全清（C2 输入框层收口）

> 合同依据：R71「先增强 sanctioned API 再迁移」；R74 组件收口；R82「禁止虚报」。
> 前置：V8.14 已把 `SsTextInput` 从 7 参扩到 16 参（默认值逐一等于 Flutter 原生默认值），
> V8.20 再按 R71 补 `prefix` / `enabled` / `style` 3 个参数后才动刀，
> 所以本批仍是「逐参数一一对应换壳」，无一处靠删参数凑迁移。

## 1. 一句话结论

`lib/features` 裸 `TextField(` 由 **14 → 0**（C2 输入框层收口完成，累计 **60/60**）；
组件门禁 `textField` 基线同步锁到 **0**（只降不升）；
`textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0 不变；六件门禁全绿，
全量 test **550 passed + 34 skipped**（较上批 548 多的 2 条即本批新增的 `SsTextInput` 用例，零回归）。

## 2. 本批 14 处逐处映射

| # | 文件 : 行（迁移前） | 原写法要点 | 迁移后 |
|---|---|---|---|
| 1 | `home/home_hero.dart:55` | `controller` + `maxLines: 3` + `minLines: 1` + `textInputAction: newline` + `style: AppType.body.style(ink)` + `hintText: '输入主题想法（支持中文）…'` + `hintStyle: AppType.body.style(muted)` | `SsTextInput(controller: controller, maxLines: 3, minLines: 1, textInputAction: TextInputAction.newline, hint: '输入主题想法（支持中文）…')` |
| 2 | `poses/cinematic_refs.dart:140` | `controller: _text` + `onSubmitted: (String _) => _search()` + `hintText: '片名 / 影人 / 氛围词'` + `isDense` | `SsTextInput(controller: _text, onSubmitted: (String _) => _search(), hint: '片名 / 影人 / 氛围词', dense: true)` |
| 3 | `settings/settings_page_cards.dart:178` | `controller: key` + `obscureText: true` + 三目 `hintText: view.hasKey ? '已保存（重新输入可覆盖）' : view.preset.keyHint` + `isDense` | `SsTextInput(controller: key, obscure: true, hint: view.hasKey ? '已保存（重新输入可覆盖）' : view.preset.keyHint, dense: true)` |
| 4 | `ai/ai_panel.dart:164` | `controller: _theme` + `maxLines: 3` + `hintText: '例：雨夜赛博朋克风初音正片，霓虹雨夜，未来感'`（**无 `isDense`**） | `SsTextInput(controller: _theme, maxLines: 3, hint: '例：雨夜赛博朋克风初音正片，霓虹雨夜，未来感')` |
| 5 | `settings/settings_page.dart:263` | `controller: TextEditingController(text: _announcementUrl ?? '')` + `labelText: '公告 JSON 地址（空 = 官方默认；支持自建站点 / 内网）'` + `isDense` + `onSubmitted`（见 §4.2） | `SsTextInput(controller: TextEditingController(text: _announcementUrl ?? ''), label: '公告 JSON 地址（空 = 官方默认；支持自建站点 / 内网）', dense: true, onSubmitted: …)` |
| 6 | `libraries/libraries_page.dart:267` | `hintText: '搜索名称 / 地区…'` + `isDense` + `onChanged: controller.setKeyword`（在 `SizedBox(width: 220, …)` 内） | `SsTextInput(hint: '搜索名称 / 地区…', dense: true, onChanged: controller.setKeyword)` |
| 7 | `poses/poses_page_layout.dart:42` | `hintText: '搜索姿势名称…'` + `isDense` + `onChanged: controller.setKeyword`（在 `SizedBox(width: 200, …)` 内） | `SsTextInput(hint: '搜索姿势名称…', dense: true, onChanged: controller.setKeyword)` |
| 8 | `refs/refs_home.dart:50` | `controller` + `focusNode` + `textInputAction: search` + `onSubmitted: (String _) => onSearch()` + `hintText: '搜影片 / 导演 / 演员 / 画作 / 摄影主题（中英文均可）'` + `isDense` + `prefixIcon: Icon(Icons.search_rounded, size: 18)` | `SsTextInput(controller: controller, focusNode: focusNode, textInputAction: TextInputAction.search, onSubmitted: (String _) => onSearch(), hint: '搜影片 / 导演 / 演员 / 画作 / 摄影主题（中英文均可）', dense: true, prefix: const Icon(Icons.search_rounded, size: 18))` |
| 9 | `ai/ai_side_panel.dart:153` | `controller: _input` + `hintText: '例如：主光再近一点 / 换夜景霓虹 / 预算减半'` + `isDense` + `enabled: !_busy` + `onSubmitted: (String _) => _send()` | `SsTextInput(controller: _input, hint: '例如：主光再近一点 / 换夜景霓虹 / 预算减半', dense: true, enabled: !_busy, onSubmitted: (String _) => _send())` |
| 10 | `poses/pose_import_page_layout.dart:280` | `controller: _name` + `labelText: '姿势名称'` + `isDense` | `SsTextInput(controller: _name, label: '姿势名称', dense: true)` |
| 11 | `planner/planner_page_canvas.dart:27` | `controller: TextEditingController(text: state.title)` + `hintText: '策划案标题'` + `isDense` + `style: TextStyle(fontSize: AppFontSize.body, fontWeight: AppFontWeight.bold)` + `onChanged: controller.setTitle`（见 §4.2） | `SsTextInput(controller: TextEditingController(text: state.title), hint: '策划案标题', dense: true, style: const TextStyle(fontSize: AppFontSize.body, fontWeight: AppFontWeight.bold), onChanged: controller.setTitle)` |
| 12 | `planner/planner_page_layout.dart:432` | `controller: ctl` + `hintText: '如：客户确认版'`（**无 `isDense`**，`_askLabel` 内） | `SsTextInput(controller: ctl, hint: '如：客户确认版')` |
| 13 | `lighting/widgets/lighting_inspector.dart:266` | `controller: TextEditingController(text: selected.note)` + `hintText: '备注（≤200 字）'` + `maxLines: 2` + `onChanged: (String v) => controller.updateSelected((DeviceSpec d) => d.note = v)`（见 §4.2） | `SsTextInput(controller: TextEditingController(text: selected.note), hint: '备注（≤200 字）', maxLines: 2, onChanged: (String v) => controller.updateSelected((DeviceSpec d) => d.note = v))` |
| 14 | `lighting/widgets/lighting_pose_widgets.dart:227` | `controller: _saveCtl` + `hintText: '另存为姿势名称'` + `isDense` | `SsTextInput(controller: _saveCtl, hint: '另存为姿势名称', dense: true)` |

三条映射规则（与 V8.14—V8.19 一致）：
1. `TextField(` → `SsTextInput(`；
2. `decoration: [const] InputDecoration(hintText: X, isDense: true)` → `hint: X,` + `dense: true,`；
   `labelText: X` → `label: X`；
3. `controller` / `onChanged` / `keyboardType` / `child:` 一律原样保留。

**导入说明**：14 个目标文件全部能解析到 `SsTextInput` —— 9 个直接 import
`core/design/widgets.dart`；5 个是 `part of` 一个已经 import 了 widgets.dart 的父页面
（`settings_page_cards.dart` ← `settings_page.dart`；`poses_page_layout.dart` ← `poses_page.dart`；
`pose_import_page_layout.dart` ← `pose_import_page.dart`；`planner_page_canvas.dart` /
`planner_page_layout.dart` ← `planner_page.dart`），因此**没有新增任何 import**。

## 3. ★ R71 API 增强（本批前置动作）

三处目标文件用到了 `SsTextInput` 当时不支持的写法，按 R71「先增强 sanctioned API 再迁移」
**先把能力补进 `SsTextInput`，再换壳**，并把补参写进单测：

| 新增参数 | 默认值 | 透传到 | 哪个站点需要它 |
|---|---|---|---|
| `prefix` (`Widget?`) | `null` | `InputDecoration.prefixIcon` | `refs/refs_home.dart` 的 `prefixIcon: Icon(Icons.search_rounded, size: 18)` |
| `enabled` (`bool`) | `true` | `InputDecoration.enabled` | `ai/ai_side_panel.dart` 的 `enabled: !_busy`（`_busy` 时置灰发送框） |
| `style` (`TextStyle?`) | `null` | `TextField.style`（`null` 时回落到原有 mono / 正文默认） | `planner/planner_page_canvas.dart` 的加粗标题样式 |

**零变更论证**：三个默认值都等于 Flutter 原生默认值 —— `prefixIcon` 默认 `null`、
`InputDecoration.enabled` 原生默认就是 `true`、`style` 默认 `null` 时 build 内仍走
`widget.mono ? appMono(...) : AppType.body.style(...)`。因此**对 V8.14—V8.19 已迁的 46 处调用方
零行为变更**（这一点由全量 test 的 548 → 550 零回归、且旧用例全绿共同佐证）。

**新增单测**（`app/test/core/ss_input_test.dart`，在既有 5 条之外）：
- `prefix / enabled / style 透传（V8.20 新增）` —— 传 `enabled: false` + `prefix: Icon(search)` +
  加粗 `style`，断言 `decoration.prefixIcon` 是那个 Icon、`decoration.enabled` 为 `false`、
  `TextField.style.fontWeight` 为 bold；
- `enabled 默认 true、style 默认沿用正文（零变更）` —— 不传这三参时断言
  `decoration.enabled` 为 `true`、`prefixIcon` 为 `null`、`style.fontWeight` 非 bold。

## 4. ★ 如实登记（偏差与预存反模式）

### 4.1 `home_hero.dart` 去掉的 `style` / `hintStyle` 与默认值逐字节相同

第 1 处原写法显式写了 `style: AppType.body.style(p.ink)` 与
`hintStyle: AppType.body.style(p.muted)`，迁移后删去。**这不是「删参数凑迁移」**：
`SsTextInput` 在非 mono 分支下 build 出来用的就是这两个完全相同的表达式
（`style: AppType.body.style(p.ink)`、`hintStyle: AppType.body.style(p.muted)`），
即显式值 == 默认值，属**可证零变更**。若原作者写的是别的颜色/字号，则会改用 `style:` 参数保留，
而不是删掉。

### 4.2 三处 `build()` 内现建 `TextEditingController(text: …)` 的预存反模式（本批未改）

第 5（`settings_page.dart`）、11（`planner_page_canvas.dart`）、13（`lighting_inspector.dart`）
三处的 `controller: TextEditingController(text: …)` 是**预存反模式**，不是本批引入的。
按 V8.16 / V8.17 起沿用的约定，本批**原样保留**、只登记不改：
- 旧 controller 从不 `dispose`；
- 重建（rebuild）会重置光标 / 选区；
- 若改写成 `SsTextInput(initialValue: …)`，会让「外部数据变化后输入框同步刷新」失效
  （`initialValue` 只在首帧生效）；
- 正确修法需要先定状态归属（controller 提到 State 字段并 dispose），会改变行为，
  属独立议题，不塞进本次「换壳」批次。

### 4.3 执行纪律：`edit` 返回成功 ≠ 文件已改

V8.19 曾出现「`edit` 返回成功但 `gear_browser.dart:439` 的 `TextField(` 仍在」的事故，
教训已写进流程（不能只信编辑工具返回值，也不能只信自己上一轮的压缩摘要）。
**本批收尾严格照做**：`grep -n "TextField(" app/lib/features` 实测为 **0 命中**
（迁移前为 14），与 `check_components` 读数（`textField` 14 → 0）交叉核对一致。
本批 14 处 edit **全部真实落盘，无一处复现 V8.19 的异常**。

## 5. 六件门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | **257 files, 3 changed**（3 处为换行折行，`git diff` 核对为纯格式，无逻辑变化） |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!**（19.9s） |
| `flutter test --no-pub` | **550 passed + 34 skipped，All tests passed!**（新增 2 条用例，零回归） |
| `node tool/check_file_size.mjs` | **PASS**（115 个 dart 文件；0 条白名单） |
| `node tool/check_tokens.mjs` | **PASS**（四类全 0） |
| `node tool/check_components.mjs` | **PASS**（`textField` **0**（基线 14）/ `textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0） |

格式折行的 3 个文件：`planner/planner_page_layout.dart`、`poses/pose_import_page_layout.dart`、
`settings/settings_page_cards.dart`。

## 6. 基线锁定

`node tool/check_components.mjs --write-baseline --json=../docs/qa/v8-components.json`
（降基线不需 `--allow-increase`；注意 `--json=` 必须用等号形式，空格形式会被静默忽略）：

```json
{"textField": 0, "textFormField": 0, "bottomSheet": 4, "alertDialog": 0}
```

`at = 2026-10-17T02:34:56.396Z`；证据快照已同步刷新且 `pass = true`：
`docs/qa/v8-components.json`（02:35:12.121Z）、`docs/qa/v8-file-size.json`（02:35:12.497Z）、
`docs/qa/v8-tokens.json`（02:35:12.985Z）。

**意义**：`textField` 的 60 → 0 是真降下来的，而不是把门禁放宽 —— 基线从 60 一路锁到 0，
仍保持「只降不升」，此后任何新增裸 `TextField(` 都会让门禁 FAIL。

## 7. 累计进度（C2 输入框层 —— 本批收口）

| 阶段 | 迁移数 | 余量 |
|---|---|---|
| 起点 | — | 60 |
| V8.14 | 12 | 48 |
| V8.15 | 11 | 37 |
| V8.16 | 5 | 32 |
| V8.17 | 8 | 24 |
| V8.18 | 6 | 18 |
| V8.19 | 4 | 14 |
| **V8.20** | **14** | **0** |

**合计已迁 60 / 60 —— C2 输入框层收口完成。**

## 8. 后续

- **C3**：4 处 `showModalBottomSheet` → `showSsSheet`（组件门禁 `bottomSheet` 当前 4，未降）。
- 空态：`SsEmptyState` 引用 0，需逐处确认后接入。
- 已登记未修的预存反模式：本批 §4.2 的 3 处 `build()` 内现建 `TextEditingController(text: …)`，
  待状态归属定案后单独批次处理。

## 9. 一句话总结

本批把 C2 的最后 14 处一次清干净（60/60，`textField` 基线锁到 0），
关键动作是**先按 R71 给 `SsTextInput` 补 `prefix` / `enabled` / `style` 三个默认值等于原生的参数**
（配 2 条单测），从而做到 14 处全是「逐参数一一对应换壳」、无一处删参数凑迁移；
同时如实登记了 `home_hero` 删除的两个显式样式（与默认值逐字节相同）与 3 处预存反模式（未改）。
