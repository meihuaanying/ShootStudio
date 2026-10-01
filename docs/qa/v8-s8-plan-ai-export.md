# V8/S8 · D155 策划案 + AI 成案 + 导出重构 — 完工报告

## 1. 结论

D155 三项要求全部落地：AI 面板收敛为**生成 → 阅读 → 修订**三态、成案阅读视图按**杂志内页排版**重排（Display 衬线大标题 + 眉题分节 + 图卡分镜 + KV 读数预算表 + 桌面双栏）、导出长图/PDF 版式按 §3 令牌重设计（衬线刊头、hairline 表格、页眉页脚、来源/许可附录页）。D150 一并落地：`.sspak` 升版到 v2，导入端按档位**迁移或明示拒绝**。工程侧按 D158 强制拆分清单把 4 个超限大文件全部降到 ≤600 行以内，白名单从 9 条降到 6 条。

## 2. AI 面板三态（D155）

| 状态 | 进入条件 | 呈现 |
|---|---|---|
| **描述**（input） | 无草稿，或上次草稿被取消 | 一句话输入 + 快捷指令 + **高级选项折叠**（本地引擎离线降级 toggle，`Key('ai-advanced')` ExpansionTile） |
| **生成中**（generating） | `state.generating == true` | 流式 mono 正文 + 可选推理链 + 尝试链 chip + 「取消生成」；尝试 >1 次时提示「本次已自动换商」（D40 同商换模型 → 换商） |
| **阅读成案**（reading） | 有草稿且未取消 | 来源 chip + 「阅读成案」/「写入画布」/「重新生成」+ 模块清单（逐个「插入」） |

- 新增 `app/lib/features/ai/ai_stage.dart`：`enum AiStage {input, generating, reading}` + `resolveAiStage(AiState)` + `AiStageBar`（三步编号眉题 + hairline 连接线）+ `AiGeneratingPanel` + `AiReadingPanel`。
- `AiController` 新增 `cancelGenerate()` 与 `_cancelRequested` 标志，在 6 个 await 检查点 + 局部闭包 `viaLocal` + `stage1`/`stage2` 循环里提前返回 `_cancelledDraft()`；`AiDraftResult` 新增 `cancelled` 字段。
- 被取消的草稿在三处都不可写入画布：`AiReadingPanel` 按钮置灰并换文案、`PlanReadView` 底部按钮 `onPressed: null`、`home_page.dart` 兜底 `if (draft.cancelled) return;`。

## 3. 成案阅读视图（杂志内页排版）

`plan_read_view.dart`（≈300 行）+ `plan_read_view_spread.dart`（extension 承载版面）：
- **刊头**：`appEyebrow('成案阅读视图')` + `textTheme.displayLarge`（`NotoSerifSC`）衬线大标题 + 副题 + 2px ink 横线。
- **目录**：桌面双栏（≥1040 宽）左 236px 侧栏，当前节 accent 左描边 2px + w600，点击 `Scrollable.ensureVisible(alignment: 0.02)`；窄栏回落单列。
- **KV 读数预算表**：hairline 表格，9 行（模块数 / 总分 / 细节分 / 一致分 / 输入 tokens / 输出 tokens / 耗时 / 通道 / 尝试链），标签 132px mono，值 mono；0 分显式渲染 `—` 而不是 `0.0`。
- **图卡分镜**：每个模块 = 编号眉题 `'${ordinal.padLeft(2,'0')} / ${category}'` + `AppType.h3` 标题 + mono `'${label}｜${id}'` + summary + 描边 `ModuleContentView(compact: true)`。
- **风险**：`shortcomings` + `schemaErrors`（danger 色点）；**附录**：原始 JSON（mono 11.5，限高内滚）。
- `static show(BuildContext, AiDraftResult, {required String idea})` 的返回值契约（`'accept'` / `'retry'` / `null`）保持不变，唯一调用点 `home_page.dart` 无需改签名。

## 4. 导出版式重设计（§3 令牌同源）

- **PDF**：每页页眉（`正片工坊 SHOOTSTUDIO` + 案名，下 hairline 0.6）与页脚（上 hairline + 状态 + `第 n / N 页`）；大标题 24px + letterSpacing 0.4 + 刊头主线 1.4；正文后追加**来源 / 许可附录页**（眉题 + 0.8 主线 + 逐行 hairline 表格，空来源显式写「未标注来源」）。
- **长图**：`_renderPart` 顶部刊头（品牌眉题 + 44px 衬线大标题 + 状态行 + 2.4px 主线），底部页脚（hairline + 案名 + 品牌 + `第 i / n 部分`）；`_text()` 新增 `align` 参数以支持右对齐。
- 三格式（PNG 长图 / PDF / .sspak）校验不回归。

## 5. `.sspak` v2 与迁移（D150）

- `exporter.dart` 新增库级常量 `kSspakFormatVersion = 2` 与 `kSspakLayoutName = 'sspak-v2'`；`manifest.json` 带 `version` + `layout`，`plan.json` 带 `version`（`JsonEncoder.withIndent('  ')`）。
- `SspakImporter.import` 返回记录新增 `int? migratedFrom`；版本分档：
  - `v2` → 直接读，`migratedFrom == null`；
  - `v1` 或**缺 version 字段** → 迁移（结构相同，补默认），回报 `migratedFrom == 1`；
  - `> v2` → `FormatException('…（包内 vN），请先升级 App 再导入。')`；
  - `format != 'sspak'` → `FormatException('不是 .sspak 数据包…')`。
- `planner_page.dart` 导入成功 toast 明示迁移事实（`（已从 v1 自动迁移）`），不静默成功。

## 6. 文件拆分（R73 + D158）

| 文件 | 拆分前 | 拆分后 | 手法 |
|---|---|---|---|
| `planner/planner_page.dart` | 2637 | **196** | + 6 个 part（`canvas` / `layout` / `dialogs` / `module_editor` / `module_editors_a` / `_b`） |
| `export/exporter.dart` | 1682 | **202** | + 5 个 part（`render` / `draw` / `pdf` / `pdf_press` / `sspak`） |
| `ai/ai_controller.dart` | 1173 | **458** | + `ai_controller_generate.dart`(265) / `ai_controller_revise.dart`(430) |
| `export/exporter_pdf.dart` | 647（改版式后） | **506** | 再拆出 `exporter_pdf_press.dart`(168) |

`tool/file_size_baseline.json` 从 9 条降到 **6 条**（`gear_browser 1312` / `settings_page 1234` / `lighting_controller 760` / `ai_panel 747` / `libraries_page 808` / `ai_client 779`），`check_file_size.mjs` PASS。

## 7. 测试与门禁

| 项 | 结果 |
|---|---|
| `s8_ai_export_ui_test.dart`（新增专项） | **16 / 16 全绿** |
| `f4_export_test` / `ai_and_export_test` / `ai_pipeline_test` / `g2_ai_pipeline_test` / `plan_scorer_test` | 3 / 10 / 4 / 4 / 5 passed（不回归） |
| `s7_pose_ui_test` | 14 passed（不回归） |
| `flutter test --no-pub`（全量） | **493 passed + 42 skipped**，All tests passed |
| `dart format lib test` | 0 changed（239 files） |
| `flutter analyze --no-pub --fatal-infos` | No issues found |
| `node tool/check_file_size.mjs` | PASS（报告 `docs/qa/v8-file-size.json`） |

## 8. 视觉证据

`docs/screenshots/v8/s8-plan-<scene>-<theme>-<size>.png` 共 **20 张**（scene ∈ `reading` / `reading-cancelled` / `stage-generating` / `stage-reading` / `export`；theme ∈ `paper` / `darkroom`；size ∈ `1280x800` / `1920x1080`）+ 索引 `docs/qa/v8-s8-plan-screenshots.json`。视觉门禁 `test/visual/s8_plan_capture_test.dart` 出图 21 项全绿（20 截图 + 1 索引）。

## 9. 偏差与限制登记

- **`ai_panel.dart` 仍在白名单内（707 行 / 白名单 747）**：本轮只降到 707，未再拆（白名单只降不升，本次已从 810 降到 747）；后续 S9 可与 `gear_browser` / `settings_page` 一并处理。
- **`ai_client.dart`（679 行）与 `libraries_page.dart`（636 行）未动**：不在 D158 强制拆分清单里，保持现状以控制本轮风险。
- **PDF 中文依赖系统 CJK 字体**：`_loadCjkFont()` 找不到字体时仍产出 PDF，但会 `onProgress` 提示「未内嵌中文字体」，属既有行为，本轮未改（导出可用但不保证中文渲染）。
- **`.sspak` v1→v2 迁移是结构兼容迁移**（清单字段一致，只补版本标记）；若将来 v3 改动清单结构，迁移分支需要真正重排逻辑。

## 10. 测试逼出来的真实缺陷（非测试迁就）

1. `ai_controller` 拆分时若把 `state` 读写原样搬进 extension，会触发 `invalid_use_of_protected_member`；已在类内加 `AiState get _state` + `set _state` 访问器作为唯一通道。
2. `plan_read_view` 的目录项与正文眉题同名（`推理链` / `附录 · 原始文本`），证明「目录与正文一一对应」的实现是真实的，不是凑数。
3. 测试用 `find.text('写\ufffd\ufffd\ufffd画布并编辑')` 找不到按钮 —— 全仓扫描确认源码里「入」字在写入时被替换成 3 个 U+FFFD，修复后全仓 0 处。**写含中文的文件后必须扫 U+FFFD。**
4. `widget` 测试直接 `home: child` pump 时 `SsButton` 的 `InkWell` 抛 `No Material widget found`（4 个用例同时挂）—— 测试壳需 `Scaffold(body:)` 提供 Material 祖先，这是测试基建缺陷而非实现缺陷。
