# V8.22 / 批次 C4 复核：R74 空态层「未收口」为误记 —— 实为 `SsEmpty`（18 处 / 13 文件）

> 本批**只改文档**（无任何代码变更）。目的：在动手做 C4 之前先核实前提，结果发现审计里
> 写着的「空态层未收口 / `SsEmptyState` 引用 0」**两处都不成立**。按 R82「禁止虚报」，
> 先把误判更正掉，而不是照着一个错误前提去「做 C4」。

## 0. 为什么会有这一批

审计 `docs/audit/V8-COMPLIANCE-AUDIT.md` §2.3 与批次 C 的 C4 行写着：

- §2.3：「`SsEmptyState` 引用 **0**（合同 §3.5 要求空态组件，已实现但 feature 侧零使用）」
- C4：「空态层：把 feature 侧手写空态改用 `SsEmptyState` …… 验收：`SsEmptyState` 引用从 0 变正数」

于是 C4 被排成一个 P2 收口批次。开工前先按 V8.19 的教训**核实现状**（`edit`/断言之前先 `grep` 真值），
一核就发现前提不成立。本批即这次核实与更正。

## 1. 一句话结论

**不存在 `SsEmptyState` 这个符号**（`app/` 下零命中）；空态组件的真名是 **`SsEmpty`**
（`app/lib/core/design/ss_empty.dart`，barrel 导出），且它**早已被 feature 侧广泛使用**
——**18 处 / 13 文件**，最早可追溯到 v1.1.0（commit `180ec63`）。所以 **R74 空态层实为已收口**，
C4 的原定验收项「引用从 0 变正数」从根上就不成立。

## 2. 证据（命令与实测输出）

| # | 命令（仓库根） | 输出 | 说明 |
|---|---|---|---|
| A | `git grep -n "SsEmptyState" -- app` | **exit 1，无命中** | 符号 `SsEmptyState` 在 `app/` 下**根本不存在** |
| B | `git grep -l "SsEmpty(" 9259ce8 -- app/lib/features` | **13 个文件** | 在审计当时（V8.19）就已经在用，不是后来才加的 |
| C | `git grep -l "SsEmpty(" -- app/lib/features` | **13 个文件** | 现状（HEAD）同为 13 文件 |
| C′ | `git grep -o "SsEmpty(" -- app/lib/features` | **18 处** | feature 侧引用计数 |
| D | `git grep -n "class SsEmpty" -- app/lib/core/design/ss_empty.dart` | `13:class SsEmpty extends StatelessWidget {` | 组件定义 |
| D′ | `git grep -n "ss_empty.dart" -- app/lib/core/design/widgets.dart` | `16:export 'ss_empty.dart';` | 已由 barrel 导出 |

> B 与 C 文件集完全一致 —— 说明「引用 0」不是「曾经为 0、后来被填上」，而是**审计当时就写错了**。

## 3. 组件真名与位置

- 文件：**`app/lib/core/design/ss_empty.dart`**（282 行），文件头即写明
  「`V8/D147 · S3：空态（衬线大字 + 一行指引 + 主行动，§3.5）与加载骨架屏（§3.5）。`」
- 类：**`class SsEmpty extends StatelessWidget`**（第 13 行）
  - 构造：`const SsEmpty({super.key, required this.icon, required this.title, this.hint, this.action, this.art})`
  - 字段：`IconData icon` / `String title` / `String? hint` / `Widget? action` / `SsArt? art`
  - 版式：`Center > Padding(AppSpace.block) > Column(min)`，`art != null` 时渲染 132×84 的
    `CustomPaint`（`_SsArtPainter`，hairline 线稿），否则退回 `Icon(size: 40)`；再依次是
    标题（`AppType.h2`）、`hint`（`AppType.small`，居中）、`action`。
- 同文件还含 `enum SsArt { film, light, pose, compass }`（空态插画四变体）、
  `class SsSkeleton`（骨架屏）、`class SsShimmer`（流光进度条）。
- barrel：`app/lib/core/design/widgets.dart:16` → `export 'ss_empty.dart';`
  （因此凡 `import '.../core/design/widgets.dart'` 的文件都能直接用 `SsEmpty`）。

## 4. 合同与 S3 文档：空态项并没有规定类名

`FIX_CONTRACT_V8.0.md` §3.5「组件清单」原文（第 149 行）只列**交付物**、不列类名：

> 按钮（主红/描边/文字/图标四态）、输入框、搜索框、卡片（图卡/文卡/数据卡）、对话框、底部抽屉、
> Chip/标签、Tabs、**空态（衬线大字 + 一行指引 + 主行动）**、加载骨架屏、Toast、Tooltip、
> 分割线与区块眉题（Eyebrow + hairline）、图片帧…、KV 读数行…

映射到实现是另一份文档的职责：`docs/qa/v8-s3-design-system.md`
- 第 58 行：`| 空态 | SsEmpty（衬线大字 + 一行指引 + 主行动 + 4 种线稿 SsArt） |`
- 第 155 行：「空态用 `SsEmpty`（可指定 `SsArt`）；加载态用 `SsSkeleton`/`SsShimmer`」

即**权威实现名就是 `SsEmpty`**，`SsEmptyState` 是审计里凭空写出来的名字。
（R74 合同第 87 行的要求是「一律走 `lib/core/design/` 组件、feature 禁止新造同名基础组件」，
`SsEmpty` 完全满足。）

## 5. ★更正

1. **符号名错**：`SsEmptyState` 在 `app/` 下不存在（证据 A）。
2. **计数错**：「引用 0」不成立；真值是 **18 处 / 13 文件**（证据 B/C/C′）。
3. **错名已扩散**：`SsEmptyState` 被复制进下列 8 份批次报告 —— 其中最后一份是本会话自己写的：

   | 文档 | 行 |
   |---|---|
   | `docs/qa/v8-14-ss-input.md` | 177 |
   | `docs/qa/v8-15-settings-inputs.md` | 92 |
   | `docs/qa/v8-16-planner-editors.md` | 108 |
   | `docs/qa/v8-17-planner-editors2.md` | 102 |
   | `docs/qa/v8-18-provider-and-planner-dialogs.md` | 77 |
   | `docs/qa/v8-19-batch7-inputs.md` | 89 |
   | `docs/qa/v8-20-batch8-inputs.md` | 148 |
   | `docs/qa/v8-21-r74-bottomsheet-final.md` | 12 / 123 / 127 |

   处理：**本会话产出的 `v8-21` 文档 3 处就地改正**；更早的 7 份**保留原文作为历史观察**，
   在此统一声明「其中 `SsEmptyState` 系误名，应读作 `SsEmpty`」（沿用本项目「保留原始观察 + 单独更正」的先例，
   参见审计 §2.4 的 `> **更正（V8.12）**` 写法）。

## 6. feature 侧真实引用（18 处 / 13 文件）

| 文件 | 行 |
|---|---|
| `ai/ai_panel.dart` | 279, 395 |
| `libraries/gear_browser.dart` | 285, 326 |
| `libraries/gear_browser_catalogs.dart` | 139, 221 |
| `libraries/libraries_page.dart` | 355 |
| `lighting/widgets/lighting_inspector.dart` | 107 |
| `planner/planner_page_canvas.dart` | 9 |
| `planner/planner_page_layout.dart` | 172 |
| `poses/pose_gallery.dart` | 147 |
| `poses/pose_import_page.dart` | 482 |
| `poses/pose_import_page_layout.dart` | 75 |
| `poses/poses_page_layout.dart` | 71, 166, 273 |
| `refs/refs_board.dart` | 62 |
| `refs/refs_page.dart` | 497 |

覆盖 AI / 资源库 / 布光 / 策划 / 姿势 / 参考六个域。`lib/features` 之外另有 4 处：
`lib/dev/design_demo_page.dart:180`、`lib/services/engine/engine_view.dart:203`、
`test/visual/s5_refs_capture_test.dart:205`、`test/features/f5_polish_test.dart:91`。

## 7. 残余的真实缺口（逐处登记；**不机械替换**）

「空态层已收口」不等于「所有空文案都用了 `SsEmpty`」。仍有若干**行内手写空提示**未走组件，
登记如下（供后续逐处设计判断）：

| 文件:行 | 现写法 | 备注 |
|---|---|---|
| `home/home_recent.dart:58-70` | `SsCard` + `Text('还没有策划案', AppType.h3)` | 首屏区块自拼，未用 `SsEmpty` |
| `planner/module_content_view.dart:96` / `279` | `'（暂无色卡）'` / `'（暂无明细）'` | 紧凑列表内一行小字 |
| `planner/planner_page_layout.dart:272` | `Text('暂无快照')` | 本会话 C3 刚移入 `showSsSheet` 的空态 |
| `planner/planner_module_editors_a.dart:17` / `266` / `481` | `'还没有已保存的布光方案：去…'` 等 | 编辑器内提示 |
| `planner/planner_module_editors_b.dart:261-263` | `'…资源库还没有条目（去「资源库」新建）'` | 同上 |
| `planner/planner_module_editor.dart:302` / `449` / `464` | 空提示 | 同上 |
| `refs/refs_page.dart:491` / `496` | `_searching && _hits.isEmpty` 分支 | 「搜索中」态，未必是空态 |
| `libraries/gear_browser_card.dart:110` | 行内提示 | — |
| `libraries/libraries_page.dart:53` | `'暂无备注'` | 字段级占位 |
| `lighting/widgets/lighting_inspector.dart:4` | 注释「未选中时显示空态」 | 实际渲染见同文件 107 |

**重要判断**：上表多数是「紧致列表/字段里的一行小字」，不是整页空态。把它们一律换成
`SsEmpty`（居中衬线大字 + 大插画）会破坏紧凑布局语义 —— 那是**为了凑引用数而替换**，
属于 R82 反对的虚报方向。所以 C4 不应按原计划「批量替换」，而是**逐处判断**：只有真正的
整页/整区块空态才该用 `SsEmpty`。以此口径，C4 由 **P2 降为 P3（可选、逐处确认）**。

> **后续（V8.24）**：上述清单已**逐处复核完毕** —— 10 处中 8 处并非空态缺口（字段级占位 / 编辑器提示 / `ssToast` / 缩略图回退 / 本身就是 `SsEmpty` / 加载指示），仅 2 处为真实区块空态并已收口（`home/home_recent.dart` 首屏「最近的策划案」、`planner/planner_page_layout.dart:272` 版本历史抽屉）。逐条理由与门禁实测见 `docs/qa/v8-24-empty-gap-triage.md`。

## 8. 门禁影响

本批**零代码变更**（只改 `docs/`），因此：

- 六件门禁（format / analyze / test / file-size / tokens / components）**与 V8.21 完全一致、无需重跑**：
  沿用 V8.21 的实测 —— `flutter test --no-pub` **551 passed + 34 skipped**；
  `check_file_size` PASS（116 文件 / 白名单 0）；`check_tokens` PASS（四类 0）；
  `check_components` PASS（`textField 0` / `textFormField 0` / `bottomSheet 0` / `alertDialog 0`，基线均已锁定）。
- 组件基线 `app/tool/component_baseline.json` **不变**（空态不在其四类指标内）。

## 9. 一句话总结

**C4「空态层未收口」是基于一个不存在的类名（`SsEmptyState`）得出的错误结论；真相是
sanctioned 组件 `SsEmpty` 早已在 18 处 / 13 文件里被使用，R74 空态层实为已收口。
本批只做更正与残余登记，不做无意义的批量替换。**
