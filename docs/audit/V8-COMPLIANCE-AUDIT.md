# ShootStudio 全面合规审计报告（对比两份任务书）

> 审计基准：`BUILD_CONTRACT.md`（V1–V7，D1–D24）+ `FIX_CONTRACT_V8.0.md`（V8，D145–D160 / R71–R82 / S0–S12）
> 审计时点：HEAD = `1ba20eb`（tag `v8.10.0`），工作区 clean，13 个 tag 全部已推送
> 方法：逐条读合同原文 → 对 `app/lib`、`app/assets/content`、`web/src`、`.github/workflows`、`docs/qa` 做机械扫描（脚本落在 `%TEMP%opencode\audit_*.py`）→ 关键结论逐条回源核实，不采信既有文档的自述口径

---

## 0. 一句话结论

**V8 合同 §1 的 S0–S12 与 §7 交付清单在「代码层」基本兑现**（D158 拆分、R71/R72/R73/R78 均已真实落地并接门禁），**但存在 1 个阻断级缺陷（CI 在 HEAD 上是红的）与 4 个「门禁虚设/口径失真」问题**，另有 3 个功能级未完成项（D5 局部、D4 内置浏览器、R76 启动迁移对话框）。**结论：不能按现状宣布「V8 全部完工」**——`HANDOFF_V8.md` §2 写的「无剩余待办」与实际不符。

---

## 1. 逐项对比：已达成（代码层实测，可复现）

### 1.1 数据/内容类决策（D19/D20/D7/D21/D22/D8）—— 超额完成

| 合同条款 | 要求 | 实测 | 判定 |
|---|---|---|---|
| **D19** 相机数据库 | ≥80 机身 / ≥120 镜头 | `assets/content/gear/gear.json` 共 **493 条**：camera **111** / lens **197** / light 157 / accessory 28，品牌 46 个 | ✅ 超额 |
| **D20** 灯具参数库 | 神牛/爱图仕/南光/智云/永诺… | gear.json 内 light **157 条**；另 `light_presets.json` = **32 套布光预设**（§4.1「32 预设」逐字命中） | ✅ |
| **D7** 模板库 | ≥8 套（Cos/汉服/JK/婚纱/商拍/写真/lo裙/双人） | `templates.json` = **恰好 8 套**，与合同八类一一对应 | ✅ |
| **D21** 服装分类 | 正装/休闲/汉服/JK/Lolita/Cos/婚纱/民族… | `clothing.json` **9 类** | ✅ |
| **D22** 道具预置 | 反光板/透明伞/花束/烟饼…含采购分工 | `props_presets.json` **14 条**（含 `owner` 字段） | ✅ |
| **D8** 提供方预设 | 13 个 | `provider_presets.dart` **14 个 id**（DeepSeek/OpenAI/aliyun/zhipu/moonshot/volcengine/anthropic/gemini/sensenova/opencode-zen/**opencode-go**/command-code/tokenrhythm/custom）= 合同 13 个的超集 | ✅ |

其他内容：`cities.json` 73 城市 ｜ `films.json` 24 部（含 frames）｜ 摆姿 `poses3.json` **120 条**（含 skeleton/joints/license/author）+ 旧库 `poses/poses.json` 256 条 ｜ `poses3/photos/` 120 张图 + 120 个 skeleton.json。

### 1.2 功能类决策（子代理逐条回源核实）

| 条款 | 内容 | 判定 | 关键证据 |
|---|---|---|---|
| D15 | 编辑停顿 3 秒自动快照 | ✅ | `planner_controller.dart:316-322` debounce + `spacing.dart:135 planPoll=3s`；8 个 mutator 全部调用 |
| D16 | 无限版本历史 + 里程碑命名 | ✅ | `PlanSnapshots` 表（`tables.dart:118`）；`milestoneNow()`（`:372`）；UI `'版本历史（无限保留）'` + `'创建里程碑'`；无 LIMIT/无删除 |
| D17 | 模块级 diff + 一键回滚 | ✅ | `planner_diff.dart:5 diffPlans()`；`'版本对比（历史 → 当前）'`；`restoreSnapshot()`（`:415`，回滚也产新快照） |
| D11 | 无 Key 本地规则引擎 100% 兜底 | ✅ | `local_engine.dart:4 LocalPlanEngine`；`ai_controller_generate.dart:83-86` 无 Key 分支 + `:269-272` 云端全失败降级 |
| D9 | AES-256-GCM + 钥匙串 + /models + 连通测试 | ✅ | `key_vault.dart:19 AesGcm.with256bits()`、`:40-43` 写 secure storage；`ai_client.dart:89 discoverModels`、`:63 testConnectivity` |
| D10 | 智能路由 + 观测台 | ✅ | `ai_controller.dart:142-151 routed` 按 priority 排序；`ai_controller_generate.dart:99` 同商换模型→换商；`ai_panel.dart:361 _buildObservatory`（调用次数/成功率/平均延迟/tokens） |
| D6 | 必须人体 3D 模型、禁简笔画 | ✅ | `assets/engine/js/person.js:8-13` 12 关节常量、`:32 THREE.CapsuleGeometry`、`:57 buildPerson()`；`pose_landmark_math.dart:292 engineJoints` |
| D23 | 自定义上传参考图（五库+模块+封面+导出+3D 贴图） | ✅ | `library_resource_editor.dart:1`（五库同构）、`:65 _pickImages`；`tables.dart:10 coverImage`；`exporter_sspak.dart:149`；`lighting_models.dart:70` 贴图占位 |
| D2 | 本地优先 SQLite + 工作区 | ✅ | `workspace.dart:27 initAt()`；`database.dart:13 @DriftDatabase`、`:60 schemaVersion=1` |
| D3 | Actions 双端打包 + Release + Pages + 公告 JSON | ✅ | `release.yml:26-30` matrix(win+android)、`:101 release` job、`:134 website`(Pages)、`:161-190` patch announcements.json |

### 1.3 工程/视觉硬规则

| 条款 | 要求 | 实测 | 判定 |
|---|---|---|---|
| **R71** | 令牌唯一来源，禁硬编码 | `AppTokens.` 旧令牌 **0 处**；`Color(0x` 25 处全在 exporter_render/draw + planner_page_dialogs（CustomPainter/PDF，合同豁免）；`SnackBar(` **0**（全走 ssToast）；`Card(` **0** | ✅ |
| **R72** | 每页明暗双主题 × 1280×800/1920×1080 截图 | `docs/screenshots/v8/` **138 张 PNG**；且 **10 处 `matchesGoldenFile`**（`app/test/visual/s3–s9` 各 1 + `golden_screens_test.dart` 3）做**像素级比对**，跑在 CI `analyze-test` job 内 | ✅ 真门禁 |
| **R73** | features ≤600 / core/design ≤300 | features **99 文件 0 超**；core/design **16 文件 0 超**（max `ss_empty.dart` 252） | ✅ 当前值合规（但见 §2.3 白名单问题） |
| **R78** | 证据入 git | `docs/qa/` **86 个证据文件**（S0–S12 阶段报告 + 令牌/规模/截图清单 + 引擎基线 + spike 报告） | ✅ |
| **D158** | 强制拆分 5 个巨型文件 | `planner_page.dart` 2637→≤531 ｜ `lighting_page.dart` 2633→547 ｜ `exporter.dart` 1683→已拆 ｜ `gear_browser.dart` 1273→已拆 ｜ `settings_page.dart` 1195→已拆 ｜ `refs_page.dart` 850→574 | ✅ |
| §5 官网令牌 | `tokens.css` 与 `AppTokensV2` **逐字一致** | 两侧各 **22 个 hex，交集 22，单侧独有 0** | ✅ |
| §3.5 / S3 | `core/design/` ≥15 组件 | **16 个文件**，barrel `widgets.dart` 导出 11 个组件模块；demo 页 `dev/design_demo_page.dart` 列 16 项，设置页 `kDebugMode` 入口 `'设计组件预览'` | ✅ |
| D160 | v2.0.0 交付 | `pubspec.yaml` **2.0.0+9** ｜ `kAppVersion` **2.0.0** ｜ `announcements.json` **2.0.0** ｜ tag `v2.0.0` 已发布（APK 428.2MB / Win zip 303.5MB + 双 .sha256） | ✅ |
| D13 | 官网 GSAP 滚动叙事 | `web/src/scripts/motion.js:10-11` 真 import gsap + ScrollTrigger | ⚠️ 部分（Three.js 见 §2.5） |

---

## 2. 实现差异与未完成项

### 🔴 P0 —— 阻断级：CI 在 HEAD 上是红的（真缺陷，非环境抖动）

**事实**：`CI 38218304083`（commit `1ba20eb` / tag `v8.10.0`）= **failure**。6 个 job 里 5 个 success（Analyze & Test ×2 / Website gate (D157) / Build Windows / Build Android APK），**`Engine perf gate` failure**。

**失败读数**：
```
[尝试 1/5] exit=0 逐相位帧数=0/1/1/3 总帧数=5     ← 被选为代表运行
NOTE 未出现四相位全出帧的健康运行
PASS 渲染循环有出帧（总帧数 > 0）:: 5
PASS orbit / PASS lightDrag（统计齐全）
FAIL dolly.p50 为数值 :: null
FAIL dolly.p95 为数值 :: null
FAIL dolly.p99 为数值 :: null
FAIL dolly.max 为数值 :: null
FAIL dolly.mean 为数值 :: undefined
FAIL dolly.fpsMean 为数值 :: undefined
[perf-gate] FAIL (6) → exit 1
```

**根因（我自己的门禁逻辑缺陷）**：`app/tool/engine_perf_gate.mjs:184`
```js
if (framesOf(representative, ph) > 0) {          // ← 第 184 行
  for (const k of STAT_KEYS) check(`${ph}.${k} 为数值`, isNum(v[k]), `${v[k]}`);
}
```
只要某相位 `engineFrames > 0`，就强制要求它 7 个统计量全为数值。而实测 **dolly 出了 3 帧但 `p50/p95/p99/max=null`、`mean/fpsMean=undefined`**（帧间隔样本 <2 时工具不产出分位数；但 `cpuMsPerFrame` 仍由「CPU 时间/帧数」算出所以是数）。

这与**偏差 9 承认的是同一个错误**：GPU-less 下每相位仅 1~3 帧，逐相位的「帧数」和「统计量」**都是噪音**。V8.5 只把「帧数」判据降级为 NOTE，**忘了「统计量完整性」判据也必须同源降级**。在 1~3 个样本上要求分位数，统计上无意义。

**修法（已定）**：
1. `:184` 的**逐相位**统计硬判 → 改为「**至少一个相位**拥有完整且为数值的 7 项统计集」硬判。仍能抓住「统计管线彻底坏掉 / 真空判据回归」（若 `Number(null)===0` 那个洞复现，所有相位都无数值 → FAIL），但不再因单相位样本不足而假红。
2. 代表运行选取：`:151` 从「总帧数最多」改为「**完整统计相位数最多**（平手再比总帧数）」。
3. 出帧但缺统计的相位 → `note`（与帧数对照同源）。
4. 保留全部现有硬判（exit 0 / 无 error / `warmup.settled` / `lightPoint.ok` / 总帧数 > 0）。
5. 反向验证：`tool/_deadloop_stub.mjs` 写「四相位全 0 帧」JSON → 必须 FAIL(≥1) 且 exit 1；**本次失败运行（orbit/lightDrag 统计完整）在新规则下应 PASS**。
6. 同步更新文件头注释 `:30`（现写「统计字段齐全且为数值」需改为「至少一个相位」）并新增一节说明。
7. 登记为**偏差 11**（或并入偏差 9 作「第二轮修订」）。

### 🟠 P1 —— 门禁虚设 / 口径失真（4 项）

#### 2.1 R74 弹层皮肤：5 处 `AlertDialog` 曾在 widget `build()` 内（**V8.13 已全部迁完，实测字面量 = 0**）
| 文件 | 行 | 宿主 |
|---|---|---|
| `features/libraries/library_resource_editor.dart` | 97 | `ResourceEditorDialogState.build()` |
| `features/planner/planner_page_dialogs.dart` | 220 | `_ColorPickerDialogState.build()` |
| `features/planner/planner_page_pose_dialogs.dart` | 22 | `_PoseInfoDialog.build()` |
| 同上 | 117 | `_PoseReplaceDialogState.build()` |
| 同上 | 217 | `_BudgetEstimateDialogState.build()` |

**全部是 `return AlertDialog(`，即必然渲染的 feature 侧弹层皮肤** → 违反 R74「对话框一律走 `lib/core/design/`」。
**偏差 10 的「`AlertDialog sites left=0`、本偏差已消除」是扫描口径缺陷造成的误判**：先前脚本只查 `showDialog<` 之后 1500 字符窗口内的 `AlertDialog`，漏掉了「widget class build 直接返回」这种形态。→ 偏差 10 已重开并更正，`HANDOFF_V8` 与 v8-10 报告的「归零」措辞已改。

**✅ V8.13 已收口（真归零，有门禁证据）**：上表 5 处全部由 `return AlertDialog(...)` 改为 `return SsDialog(...)`（外层 `showDialog` 不动），`node tool/check_components.mjs` 实测 `alertDialog 0`，且该 0 已写进 `tool/component_baseline.json`（只降不升）→ 今后新增任何 `AlertDialog(` 都会让 CI 红。过程中还修掉 `SsDialog` 自身一个真缺陷：它用 `Container(color: p.surface)` 直接装内容、**缺 Material 垫层**（`AlertDialog` 自带），导致内容里的 `ListTile` 报 15 条「background color or ink splashes may be invisible」断言；已包一层 `Material(type: MaterialType.transparency)`。详见 `docs/qa/v8-13-r74-alertdialog-final.md`。

#### 2.2 R74 输入框层未收口（偏差 6 后半，仍未做）
feature 侧裸 `TextField(`/`TextFormField(` = **60 处 / 24 文件**（审计时口径；settings_page_sources 11、library_resource_editor 8、planner_module_editors_b 5、planner_module_editors_a 4、planner_module_editor 4、gear_browser_add 4…），而 sanctioned `SsTextInput` 仅 **1 处 / 1 文件**、`SsSearchField` 仅 **1 处 / 1 文件**。

> **进度更新（V8.14）**：裸 `TextField(` 已由 **60 → 48**（`gear_browser_add.dart` 4 + `library_resource_editor.dart` 8 迁到 `SsTextInput`），组件门禁 `textField` 基线同步锁到 **48**（只降不升）；`SsTextInput` 本身扩展了 8 个参数并修掉 `initialValue` 静默失效缺陷。详见 `docs/qa/v8-14-ss-input.md`。余 48 处按文件分批。

#### 2.3 R74 底部抽屉层 + 空态层未收口
- 裸 `showModalBottomSheet` **4 处 / 4 文件**（refs_hit_drawer、pose_gallery、character_picker、planner_page_layout），而 `SsSheet` 引用 **0**、`showSsSheet` 仅 1。
- `SsEmptyState` 引用 **0**（合同 §3.5 要求空态组件，已实现但 feature 侧零使用）。

> 对比：**按钮/卡片/Chip/Toast 四层已真正收口**（`SsButton` 140 处/46 文件、`SsCard` 44/21、`SsChip` 52/22、`ssToast` 86/30、`showSsConfirm` 4/4、`SsDialogAction` 25/8、`showSsDialog` 12/7）。所以 R74 是**「四层已收口、三层未收口」**，不是全未做。

#### 2.4 R73 报告快照陈旧（**门禁本身有效**；V8.12/B1 已刷新快照）

> **更正（V8.12）**：本节原判「门禁形同虚设」**不成立** —— `tool/file_size_baseline.json` 的白名单**本来就是空表**，`check_file_size.mjs` 对超限文件取 `allowed = baseline[rel] ?? 0`，即 600/300 已被真实强制（注入 701 行 → FAIL exit 1；401 行的 design 文件 → FAIL exit 1）。真正陈旧的只是**证据快照** `docs/qa/v8-s3-file-size.json`，已刷新（`baseline_entries=0`）。下面保留原始观察作为历史记录。
`docs/qa/v8-s3-file-size.json` 的 `allowed` 字段仍是**拆分前**的上限（headroom +39~40）：
```
planner_page.dart        allowed 2676  (当前 ≤531)
lighting_page.dart       allowed 2672  (当前 547)
exporter.dart            allowed 1722
gear_browser.dart        allowed 1312
settings_page.dart       allowed 1234
ai_controller.dart       allowed 1162
refs_page.dart           allowed  889  (当前 574)
lighting_controller.dart allowed  828  (当前 549)
pose_import_page.dart    allowed  812  (当前 577)
ai_panel.dart / libraries_page.dart / ai_client.dart  allowed 810/808/779
```
→ `check_file_size.mjs` 判定 `current <= allowed`，因此**这些文件即使膨胀回旧上限（如 planner_page 涨回 2676 行）仍然 PASS**。门禁对它们等于失效。修法：把白名单刷新为当前实测行数（保留少量 headroom），或对已拆分文件直接把 `allowed` 降为 600。

### 🟡 P2 —— 功能级未完成（3 项 + 1 项部分）

| 条款 | 要求 | 实测 | 判定 |
|---|---|---|---|
| **D5** | 布光双轨制（俯视图 + 3D + **正面效果图选项保留且开关入设置页** + 有 Key 时一键 AI 照片级渲染） | 俯视灯位图 ✅（`lighting_controller.dart:269` 拖动）｜3D WebView ✅（`engine_view.dart:234 InAppWebView`）｜**「正面效果图开关入设置页」NOT FOUND**（`features/settings/*` 搜 `正面/效果/预览/开关/启用` 无命中；效果预览作为右栏组件 `lighting_effect_widgets.dart:14` 存在，但无设置页开关） | **PARTIAL** |
| **D4** | 内置浏览器访问 film-grab.com | **NOT FOUND**。film-grab.com 仅出现在 `net_router.dart:32`（DoH 隧道域名白名单）、`films.json` 的 `sourceUrl`、`tables.dart:30` 注释。全库唯一的 `InAppWebView` 是 3D 引擎；所有来源链接走 `launchUrl(LaunchMode.externalApplication)` **外部浏览器**（如 `refs_hit_drawer.dart:131`） | **NOT FOUND** |
| **R76 / D150** | 启动检测旧数据 → 迁移/重置二选一对话框 | **NOT FOUND**。`main.dart` 无任何旧数据检测（仅日志/窗口/runApp）；启动路径只处理 `NeedWorkspaceException → onboarding`。已有的是 **`.sspak` 导入**时的版本分档明示（`exporter_sspak.dart:216`），以及 `database.dart:65` 的空 `onUpgrade` 钩子 | **NOT FOUND**（= 偏差 8，已登记，理由=schema 未破坏） |
| **D14** | 输入框预选/推荐卡片 + 开关收进设置页 | 预选/推荐卡片 ✅（`ai_side_panel.dart:32 _quick` 快捷 chip；`planner_module_editors_a.dart:154 SsChip`）；设置页确有开关（GPU 后端 `settings_page_gpu.dart:106`、AI 渠道 `settings_page_cards.dart:136`），但**「某个输入区开关被搬进设置页」的具体证据未找到** | **PARTIAL** |

### 🟢 P3 —— 低优先 / 卫生问题

1. **开放偏差 1–9 仍在**（详见 `docs/qa/v8-r71-deviations.md`）：圆角 `oversizeSoft10/20` 超 ≤8 刻度（偏差 1）｜updater `sha256` 不闭环（偏差 2）｜`KeyVault.storageAvailable` 不拦截写入（偏差 3）｜`AppRadius.pill=999`（偏差 4）｜`AppSpaceFine`/`AppFontSize` 细阶未标 `@Deprecated` 且无软门禁（偏差 5）｜`AppWait.planReveal/cardHover` 不在三档（偏差 7）｜R76 未实现（偏差 8）｜引擎门禁放宽（偏差 9）。
2. **`three` 是死依赖**：`web/package.json` 声明 `three ^0.169.0`，但 `web/src/**` 全量搜 `three`/`THREE`/`WebGL` **零命中** → 合同 D13「官网 GSAP 滚动叙事 **+ Three.js**」未达成，§6「官网删未用依赖」也未达成。
3. **合同「13 源」是陈旧计数**：实际注册源 **20 个**（`search_keys.dart:64 sources()`，含 D134 新增 7 个开放源）。`git log --diff-filter=A v2.0.0..HEAD -- app/lib/services/search/sources/` **为空 → V8 期间零新增源，R75 未被违反**。属合同文本与实现的数字不一致（可补注）。
4. **`web/package.json` version=1.0.0** vs app 2.0.0（package.json 版本非 App 版本，低优先）。
5. **`app/tool/` 下 53 个 QA/内容生成脚本未接 CI**（离线证据生成器，结果落 `docs/qa/*.json`；可接受，但应在文档里说清「哪些是门禁、哪些是离线工具」）。
6. `HANDOFF_V8.md` §2 写「剩余待办 —— 无（V8 完工）」，**与 §2 的实际发现不符**，需更正。

---

## 3. 下一步计划（待办 / 优先级 / 预期完成时间）

> 时间按「单个熟悉本仓库的开发者、含门禁与自查」估算；每项均遵守既有流程：改完跑五件门禁（`dart format lib test` 0 changed / `flutter analyze --no-pub --fatal-infos` No issues / `flutter test --no-pub` ≥543 passed + 34 skipped / `check_file_size` / `check_tokens`）→ commit → tag → push → 盯 CI。

### 批次 A：止血（建议立即做，共约 1 天）

| # | 待办 | 优先级 | 预估 | 验收 |
|---|---|---|---|---|
| A1 | 修 `engine_perf_gate.mjs:184` 假红（改「至少一个相位统计完整」+ 代表运行改选「完整统计相位数最多」+ 注释同步 + 反向验证死循环替身） | **P0** | 0.5 天 | 本机 PASS；死循环替身 FAIL(≥1)/exit 1；CI 在 HEAD 转绿 |
| A2 | 登记**偏差 11**（或并入偏差 9 第二轮修订），写明 V8.5 修订不完整、由 v8.10.0 的 CI 真实抓到、修正后剩余口径（绝对帧耗时仍为人工判据） | **P0** | 0.2 天 | 偏差文件更新 |
| A3 | 更正 `HANDOFF_V8.md` §2 与 `docs/qa/v8-10-r74-final.md` 的「R74 归零 / 无剩余待办」措辞，改为指向本审计报告 | **P1** | 0.2 天 | 两文件更新 |
| A4 | 跑 tag `v8.11.0` + push + 确认 CI 全绿（这是「CI 恢复绿」的证据） | **P0** | 0.2 天 | run conclusion=success |

> **A 之外的 CI 可靠性新发现（2026-10-16，建议并入批次 D 或单列）**：
> tag `v8.11.0` 触发的 `Release` run `38844794006` 在 job `Build & Collect (android)`
> 失败，根因是 AGP 自动安装 `cmake;3.22.1`（`flutter_litert` 插件原生构建所需）
> 时报 `com.android.builder.sdk.InstallFailedException`，`BUILD FAILED in 14m 46s`。
> **判定为 flake 而非回归**：同一 commit 上 CI 的 `Build Android APK`（与
> `release.yml:74` 完全相同的 `flutter build apk --release`）是 **success**；
> v8.10.0 的 Release 也是 success。两个 workflow **都没有**任何 CMake 预装步骤，
> 完全依赖 AGP 自动安装 —— 那条路径本身不稳定。
> **建议加固**：给两个 workflow 的 android 构建 job 各加一个**带防护**的
> `sdkmanager "cmake;3.22.1"` 预装步骤（每步 `|| echo "::warning::..."` 兜底，
> 避免加固本身引入新故障），或至少给 `flutter build apk --release` 加一次失败重试。

### 批次 B：把门禁修成真门禁（约 1.5 天）

> **2026-10-16 执行结果**：B1 / B3 已闭合，B2 已交付。**B1 的前提经复核为误判**（详见下表）。

| # | 待办 | 优先级 | 预估 | 验收 | 状态 |
|---|---|---|---|---|---|
| B1 | ~~刷新白名单~~ → **实为：刷新陈旧证据快照**。复核更正：`app/tool/file_size_baseline.json` 的 `baseline` **本来就是空表（0 项）**，而 `check_file_size.mjs` 对超限文件取 `allowed = baseline[rel] ?? 0` → 600/300 限额**已被真实强制**，门禁并非「形同虚设」。真正陈旧的是证据快照 `docs/qa/v8-s3-file-size.json`（仍记着拆分前 `planner_page.dart` 2637 行 / `allowed` 2676 行，会让读者误判门禁失效） | **P1** | 0.3 天 | 注入 701 行 `lib/features` 文件 → FAIL exit 1；注入 401 行 `lib/core/design` 文件 → FAIL exit 1；清理后 PASS | ✅ 完成（快照已刷新至 2026-10-16，`baseline_entries=0`；反向验证两种限额各 FAIL 一次） |
| B2 | 给 R74 剩余三层（输入框 / 底部抽屉 / 弹层）接上机械门禁：新增 `app/tool/check_components.mjs`，统计 feature 侧裸 `TextField` / `TextFormField` / `showModalBottomSheet` / `AlertDialog(` 并**只降不升** | **P1** | 0.7 天 | 门禁入 CI；基线入库；反向验证能拦新增 | ✅ 完成（`component_baseline.json` 入库：`textField 60 / textFormField 0 / bottomSheet 4 / alertDialog 5`；CI 步骤已加进 `analyze-test`；反向验证：临时加 1 个 `TextField` → FAIL exit 1，清理后 PASS；证据 `docs/qa/v8-components.json`） |
| B3 | 更正**偏差 10**：重开为「R74 未真正归零」，列出 §2.1 的 5 处 `return AlertDialog(`（含宿主类/行号），并说明原扫描口径缺陷 | **P1** | 0.3 天 | 偏差文件更新 | ✅ 完成（偏差 10 的标题 / 现状 / 状态三处已改为「16 处中已迁 11、剩 5」，并写明漏计成因；`HANDOFF_V8.md` 三处「R73 白名单陈旧」同步更正） |

> **B2 实测补充（供批次 C 选型）**：`showModalBottomSheet` 的 4 处是
> `planner_page_layout.dart:252`、`refs_hit_drawer.dart:187`、`character_picker.dart:41`、
> `pose_gallery.dart:186`；`AlertDialog` 的 5 处即 §2.1 的 5 个 widget 类。
> 实现门禁时**必须让每个模式允许可选类型实参**（`showModalBottomSheet<void>(`），
> 否则会漏计 —— 这是初版实测踩到的坑，已修。最大单点输入框是
> `settings_page_sources.dart`（11 处）。

### 批次 C：R74 收口（把三层做完，约 3 天）

| # | 待办 | 优先级 | 预估 | 验收 |
|---|---|---|---|---|
| C1 | 迁移 §2.1 的 **5 处 `AlertDialog`** → `showSsDialog`（都是 widget build 直接返回，迁法同 V8.10：拆 body + `showSsDialog<T>`；`_ColorPickerDialog` 与 `_PoseReplaceDialog` 有内部状态，需按 V8.9 的「独立 StatefulWidget」范式） | **P1** | 1 天 | ✅ **完成（V8.13）**。实际迁法是**原地把 `return AlertDialog(...)` 换成 `return SsDialog(...)`**，保留各自的 StatefulWidget 与内部状态（不必拆 body、不必换 `showSsDialog<T>` —— 那是 V8.10 对「`showDialog<T>` 调用点」的迁法；本 5 处是「widget `build()` 直接返回」，迁法不同）。`check_components` 实测 `alertDialog 0` 且基线已锁定为 0；`flutter test` **543 passed + 34 skipped**（= 基线，无回归）。顺带修掉 `SsDialog` 缺 `Material` 的真缺陷（见 §2.1）。报告 `docs/qa/v8-13-r74-alertdialog-final.md`。 |
| C2 | 输入框层收口：`SsTextInput`/`SsSearchField` 覆盖 60 处裸 TextField（**分批做**：先 settings 11 + library_resource_editor 8 + gear_browser_add 4 = 23 处，约 1 天；其余按文件分批） | **P1** | 1.5 天 | 裸 TextField 计数下降；新增 `SsTextInput` 用例 —— **▶ 进行中（V8.14）**：首批 12 处已迁（`gear_browser_add.dart` 4 + `library_resource_editor.dart` 8），组件门禁 `textField` 基线 60→48；新增 `app/test/core/ss_input_test.dart` 5 条用例（全绿）；`SsTextInput` 扩展 8 个参数（`onSubmitted`/`maxLines`/`minLines`/`maxLength`/`keyboardType`/`textInputAction`/`focusNode`/`dense`，默认值 = 原生默认值，对既有调用方零变更）并修掉 `initialValue` 静默失效缺陷；六件门禁全绿（test **548 passed + 34 skipped**）；报告 `docs/qa/v8-14-ss-input.md`。**▶ 进行中（V8.15）**：`settings/settings_page_sources.dart` 11 处已迁（6 个 `obscure: true` 密钥框、1 个 `keyboardType: TextInputType.number`、4 个 `dense: true`），组件门禁 `textField` 基线 48→**37**（累计已迁 23/60）；全量 test **548 passed + 34 skipped** 零回归；报告 `docs/qa/v8-15-settings-inputs.md`。**▶ 进行中（V8.16）**：`planner/planner_module_editors_b.dart` 5 处 hint 型输入框已迁（`hint:` + `dense: true`；含 1 处动态 hint `labels[f]`），组件门禁 `textField` 基线 37→**32**（累计已迁 28/60）；全量 test **548 passed + 34 skipped** 零回归；报告 `docs/qa/v8-16-planner-editors.md`。余 32 处按文件分批 |
| C3 | 底部抽屉层：4 处 `showModalBottomSheet` → `showSsSheet` | **P2** | 0.5 天 | `SsSheet` 引用从 0 变正数 |
| C4 | 空态层：把 feature 侧手写空态改用 `SsEmptyState` | **P2** | 0.3 天 | `SsEmptyState` 引用从 0 变正数 |

### 批次 D：功能缺口（约 2.5 天）

| # | 待办 | 优先级 | 预估 | 验收 |
|---|---|---|---|---|
| D1 | **D5**：补「正面效果图」开关到设置页（设置项 + 持久化 + 布光页读取），并明确「有 Key 时一键 AI 照片级渲染」的入口是否存在 | **P2** | 0.7 天 | 设置项可见、状态持久、布光页行为随开关变化；补测试 |
| D2 | **D4**：内置浏览器访问 film-grab.com（复用 `engine_view.dart` 的 `flutter_inappwebview`，或明确降级为「外部浏览器 + 在合同里登记偏差」——**建议先与用户确认口径**） | **P2** | 1 天 | 二选一，且结论写进偏差表 |
| D3 | **D14**：核实并补齐「输入区开关收进设置页」的具体项（需先与用户对齐「哪个开关」） | **P3** | 0.3 天 | 对齐后落地 |
| D4 | **R76/D150**：实现启动旧数据检测 → 迁移/重置对话框（**前置**：先确认是否计划在 V9 改 schema；若改则必做） | **P3** | 0.5 天 | 幂等脚本 + 测试；或明确登记「V9 再做」 |

### 批次 E：卫生（约 1 天）

| # | 待办 | 优先级 | 预估 | 验收 |
|---|---|---|---|---|
| E1 | 删 `web` 的 `three` 死依赖（或补上 Three.js 用法，二选一）；顺带核对 `web/package.json` version | **P3** | 0.3 天 | `npm ls three` 无未用依赖；官网 CI 仍绿 |
| E2 | 偏差 1/4/5/7 的收编：`AppSpaceFine`/`AppFontSize` 细阶标 `@Deprecated` + `check_tokens.mjs` 加「Fine 细阶计数只降不升」软门禁；圆角 oversizeSoft10/20 与 `AppRadius.pill` 做一次视觉复核（改或显式豁免） | **P3** | 0.5 天 | 门禁 + 偏差表更新 |
| E3 | 合同文本补注：把「13 源」更正为 20 源（注明 D134 新增 7 个）；`app/tool` 文档区分「CI 门禁」与「离线证据工具」 | **P3** | 0.2 天 | 文档更新 |

### 建议执行顺序与里程碑

```
第 1 天   A1–A4  → tag v8.11.0（CI 恢复绿，这是最重要的信号）
第 2–3 天 B1–B3  → tag v8.12.0（门禁有牙齿，R74 口径更正）
第 4–6 天 C1–C4  → tag v8.13.0（R74 三层收口）
第 7–9 天 D1–D4  → tag v8.14.0（功能缺口；D2/D3 需先与用户对齐口径）
第 10 天  E1–E3  → tag v8.15.0（卫生）
```

**总预估：约 9–10 个工作日**（含每轮门禁与自查）。若只做「止血 + 门禁修正」（批次 A+B），**约 2.5 天**即可让「CI 绿 + 门禁不再虚设 + 口径诚实」。

### 需要用户先拍板的两件事（会影响 D2/D3/D4 的做法）
1. **D4 内置浏览器**：是真要做内置 WebView 浏览 film-grab.com，还是接受「外部浏览器 + 登记偏差」？
2. **R76 启动迁移对话框**：V9 是否计划改数据库 schema / 工作区结构？若否，可继续按偏差 8 登记不动。

---

## 附：审计方法与本报告的自我约束

- 所有数字均来自本机实测脚本输出（`%TEMP%opencode\audit_*.py` / `audit_*.txt`），或对具体文件的逐行回源核实；**未采信既有文档的自述结论**（偏差 10 的「归零」正是被这样推翻的）。
- 已知的两处**先前文档口径错误**已在本报告更正：①偏差 10 的 `AlertDialog left=0`；②「R72 只截图不校验」的推测（实际有 10 处 `matchesGoldenFile` 像素门禁）。
- 本报告未修改任何产品代码；所有修复项均为待办。
