# V8.15 / C2 第二批：`settings_page_sources.dart` 11 处裸 `TextField(` 收口

> 承接 `docs/qa/v8-14-ss-input.md`（V8.14：`SsTextInput` 扩能力 + 首批 12 处迁移）。
> 本批按文件密度推进，取全仓密度最高的 `settings/settings_page_sources.dart`（11 处）。

## 0. 一句话结论

`lib/features` 裸 `TextField(` 由 **48 → 37**；组件门禁 `textField` 基线同步锁到 **37**
（只降不升）。`alertDialog` 保持 **0**、`bottomSheet` 保持 **4**（C3 待做）。
**未为迁移放松任何判据**，全量 test 零回归。

## 1. 本批范围与迁移映射（11 处）

映射规则只有三条（与 V8.14 完全一致）：

| # | 原写法 | 迁移后 |
|---|---|---|
| 1 | `TextField(` | `SsTextInput(` |
| 2 | `decoration: const InputDecoration(labelText: X)` | `label: X` |
| 3 | `isDense: true` | `dense: true` |

另有 `obscureText: true` → `obscure: true`（V8.14 已支持该参数）。

| controller | 迁移后 label | 额外参数 |
|---|---|---|
| `_pexels` | `'Pexels API Key（可空）'` | `obscure: true, dense: true` |
| `_tmdb` | `'TMDB API Key（可空）'` | `obscure: true, dense: true` |
| `_europeana` | `'Europeana Key（可空，填入即启用）'` | `obscure: true, dense: true` |
| `_smithsonian` | `'Smithsonian Key（可空）'` | `obscure: true, dense: true` |
| `_harvard` | `'Harvard Art Museums Key（可空）'` | `obscure: true, dense: true` |
| `_rijks` | `'Rijksmuseum Key（可空）'` | `obscure: true, dense: true` |
| `_cacheLimit` | `'搜图缓存上限（MB）'` | `keyboardType: TextInputType.number, dense: true` |
| `_proxy` | `'网络代理（http://127.0.0.1:7890，可空；留空时自动使用 DoH 隧道）'` | `dense: true` |
| `_packDir` | `'我的素材包目录（放入剧照/动漫截图，启动自动索引）'` | `dense: true` |
| `_gearDir` | `'器材官方图目录（“型号.jpg”命名，自动匹配设备库）'` | `dense: true` |
| `_gearCacheLimit` | `'器材图缓存上限（MB，按最早访问清理）'` | `dense: true` |

**没有一处靠删参数凑迁移**：11 处原有的 `controller` / `obscureText` / `keyboardType` /
`isDense` / `labelText` 全部在 `SsTextInput` 上有对应参数（这正是 V8.14 先扩 API 的意义）。

## 2. 归一化差异（如实登记）

| 项 | 变化 |
|---|---|
| 文字样式 | 改走 `AppType.body.style(p.ink)`（原裸 `TextField` 走 theme 默认）。**唯一可见差异，正是收口目的** |
| `labelText` 位置 | 无变化（`InputDecoration(labelText:)` → `label:` 仍落在 `labelText`） |
| `isDense` | 11 处原均为 `true` → `dense: true`，精确保留 |
| 密钥框遮挡 | `obscureText: true` → `obscure: true`，行为一致 |

## 3. 六件门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 257 files，**0 changed** |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!**（8.4s） |
| `flutter test --no-pub` | **548 passed + 34 skipped，All tests passed!**（= 基线，本批未新增用例，零回归） |
| `node tool/check_file_size.mjs` | PASS |
| `node tool/check_tokens.mjs` | PASS（四类全 0） |
| `node tool/check_components.mjs` | PASS（`textField` **37**（基线 48）/ `textFormField` 0 / `bottomSheet` 4 / `alertDialog` 0） |

## 4. 基线锁定

`node tool/check_components.mjs --write-baseline`（**降基线不需 `--allow-increase`**）→

```json
{"textField": 37, "textFormField": 0, "bottomSheet": 4, "alertDialog": 0}
```

`at = 2026-10-16T09:23:49.537Z`；证据快照 `docs/qa/v8-components.json` 已刷新。
**意义：今后任何新增裸 `TextField(` 都会让 CI 直接红（`analyze-test` job 的 Component gate 步骤）。**

## 5. 累计进度（C2）

| 批次 | 文件 | 处数 | 门禁 `textField` |
|---|---|---|---|
| 起点 | — | — | 60 |
| V8.14 | `gear_browser_add.dart`(4) + `library_resource_editor.dart`(8) | 12 | 48 |
| **V8.15** | `settings_page_sources.dart` | 11 | **37** |
| 合计已迁 | — | **23 / 60** | — |

## 6. 剩余 37 处与后续

按密度（`tool/check_components.mjs` 逐文件计数）：`planner/planner_module_editors_b.dart` 5、
`planner/planner_module_editor.dart` 4、`planner/planner_module_editors_a.dart` 4、
`ai/ai_provider_card.dart` 3（含 `obscureText` 密钥框 → 用 `obscure: true`）、
`planner/planner_page_dialogs.dart` 3、`libraries/gear_browser.dart` 2、
`planner/planner_page_pose_dialogs.dart` 2，另 14 个文件各 1 处。

另：**C3** 4 处 `showModalBottomSheet` → `showSsSheet`
（`planner/planner_page_layout.dart:252`、`refs/refs_hit_drawer.dart:187`、
`poses/character_picker.dart:41`、`poses/pose_gallery.dart:186`）；
空态 `SsEmptyState` 引用 0 需逐处确认。

## 7. 一句话总结

本批是纯机械迁移：因为 V8.14 已把 `SsTextInput` 的能力补齐到「覆盖 60 处真实用到的参数
集合」，这批 11 处才能**逐参数一一对应**地换壳，而不是靠删参数。门禁基线的下降（48 → 37）
就是这次收口的可验证证据。
