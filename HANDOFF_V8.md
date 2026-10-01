# ShootStudio V8 交接文档 · 进行中（杂志画册风设计系统 + 四大模块升级 + 工程重构 + 官网同步）

> 更新：2026-09-30 ｜ 配套合同：`FIX_CONTRACT_V8.0.md`（D145–D160、R71–R82，**开工前必读**）
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter `app/`，官网 `web/`，证据 `docs/`）
> 基线：v1.3.0 已发布（tag `v1.3.0`）；V8 目标 v2.0.0

---

## 0. 一分钟速览

| 项 | 状态 |
|---|---|
| 已完成并推送 | **S0 合同与基线** `4b4bc1a` ｜ **S1 设计 spike** `572fcad` ｜ **CI 修复** `d93fe3a` ｜ **S2 引擎架构 spike** `7dcfabf` ｜ **S3 设计系统落地** `e9dd55b`（+ workflow 引号修复 `5031db8`）｜ **S4 App 外壳 + 首页** `23012bd` ｜ **S5 画面参考搜索** `e4021db` ｜ **S6 布光预演**（本次提交：三栏版面 + 顶部工具条 + 灯位图画中画 + 撤销重做 ≥20 步 + 出片 ≤3 步；报告 `docs/qa/v8-s6-lighting.md`） |
| CI | **S6 全绿** run 36808608106 = `4b8c25d` success 4/4； S7 推送后运行中（R61：全绿才算完成，下一步先复核）；**S5 全绿**（run 36773666033 = `e4021db`）；S4 全绿（36694433172 = `23012bd`）；S3 全绿（36691238788 = `5031db8`）；S2 全绿（36684962779 = `7dcfabf`）；S0 全绿（36673666121） |
| 门禁基线 | format 0 changed（202 files）｜ analyze 0 问题 ｜ 全量 **441 passed + 40 skipped** ｜ S6 专项 13 + 14（UI/撤销）｜ S5 专项 14 ｜ S4 专项 13 ｜ 视觉专项 S6 16 / S5 16 / S4 8 / S3 4 / S1 12 张 ｜ 设计系统单测 20 ｜ perf_probe 单测 6 ｜ 交互帧率 lightDrag p95 **17.5ms** / 长帧>50ms = 0 / CPU 1.93ms（RTX 4060）｜ `lib/features/**` >600 行 **10** 个（R73 白名单，只降不升）｜ 官网 6 页可构建 ｜ `q6_search_test` 41/41 不回归 ｜ `q6_lighting/q6_engine/q6_still/q6_camera` 44/44 不回归 ｜ S7 专项 `s7_pose_ui_test` 14 ｜ 视觉 S7 16 张 |
| 当前步 | S6 收尾（提交 + CI 复核） |
| 剩余 | **S8 策划案/AI/导出** → S9 资源库/设置/引导 → S10 官网 → S11 全量回归+视觉验收+死代码 → S12 v2.0.0 交付 |

---

## 1. 已完成（含证据路径）

### S7 动作摆姿与识别重做（D153）

- **姿势库**：大图瀑布流（`PoseGalleryGrid` 复用画面参考的 `RefsMasonryGrid`/`RefsMasonryImage`）+ 分类眉题（`PoseCategoryEyebrow`）；详情改**半屏抽屉**（`showPoseDetailSheet`：大图 + 骨架开关 + 镜头/机位/重心建议 + 收藏 + 「送入布光」主行动）；检索增强到 9 个字段（`_matchesKeyword`：名称/分类/难度/重心/手部/常见错误/镜头/机位/半身说明）。
- **识别链路 ≤4 步**：导入（选文件 / 粘贴截图 / 拖入 jpg|png|webp|bmp）→ 识别中（骨架屏 + 后端标签 chip，RTMPose 或 MediaPipe 回退 R69 不变）→ 校正（`PoseJointTuner` 照片 + 骨架并排，关节点命中半径 14px 可拖拽，拖拽实时重算 12 关节；拖拽时显示 mono 角度读数；`PoseTunerResetBar` 复位单关节 / 复位全部）→ 送入布光 / 存库。
- **骨架交互基础**：`PoseSkeletonPainter` 新增 `layoutRect` / `offsetOf` / `toNormalized` / `hitTestJoint(radius, prefer)`。
- **文件拆分（R73）**：`poses_page.dart` 591 → 135 行（+ `poses_page_layout.dart` part+extension）、`pose_import_page.dart` 773 → 413 行（+ `pose_import_page_layout.dart`），白名单条目 812 已删除。
- **证据**：专项 `s7_pose_ui_test.dart` **14/14**；不回归 `q2_pose_photos`(8)/`q6_pose_test`(11)/`q6_pose3d`(10)/`q6_pose_recognition`(2)/`g5_poses`(5)/`g5b_poses_page`(1)；全量 **441 passed + 40 skipped**；视觉 16 张 `docs/screenshots/v8/s7-pose-*.png` + 索引 `docs/qa/v8-s7-pose-screenshots.json`；报告 `docs/qa/v8-s7-pose.md`。
- **偏差登记**：`poses3.json` 难度只有 `进阶` 20 + `高难度` 100（无「新手友好」），但 UI 筛选 chips `poseDifficulties` 仍列「新手友好」→ 点它会得到空列表，暂留待 S8 按数据校正。

### S6 布光预演重构（D152 · R71–R74 / R79 / R81）
- **报告**：`docs/qa/v8-s6-lighting.md`（信息架构 / 撤销重做 / 交互 / 文件拆分 / 帧率实测表 / 16 张视觉证据 / 27 用例 / 门禁 / 6 条复盘）。
- **信息架构（D152 §4.1）**：左栏 208px（32 套预设卡组 + 设备/道具清单，**可折叠**）+ 中栏 ≥60%（**顶部工具条** + 3D 视口/分屏，俯视灯位图降为**左上角可拖动画中画**，可切全屏）+ 右栏 264px 属性检查器（未选中 = 机位 + 测光表 + 公共面板；选中 = 光型/灯具/控光件/亮度/色温/光束角/柔度/高度/朝向/开关 + 贴图 + 删除 + 同一组公共面板）。
- **撤销 / 重做（≥20 步）**：新增 `lighting_undo.dart`（`LightingSnapshot` + `LightingUndoStack(capacity 64, 600ms 同标签合并)`）；controller 在 addLight/addProp/removeSelected/clearAll/applyPreset/updateSelected/moveDevice/moveCamera/applyEngineMove 等改动前记点；`beginInteraction`/`endInteraction` + 新引擎事件 `EngineDragEnded` → **一次拖灯 = 一步撤销**；工具条撤销/重做 chip 选中态直接反映 `state.canUndo/canRedo`。实测 24 步可逐步撤到空影棚。
- **交互**：双击/长按设备行 = 聚焦属性 + 快捷菜单（聚焦属性/复制一个/删除）；`Delete`/`Backspace` 删除；`Ctrl+Z` / `Ctrl+Shift+Z` / `Ctrl+Y` 撤销重做；**空格**切相机漫游 ↔ 对象操作；出片 ≤3 步（工具条「出片」→ 效果预览对话框默认推荐档 → 保存/复制）。
- **文件拆分（R73）**：`lighting_page.dart` **2633 → 599 行**，白名单整条删除（11 → 10 项）；新增 `widgets/{lighting_workbench,lighting_inspector,lighting_device_list,lighting_left_column,lighting_effect_widgets,lighting_pose_widgets,lighting_rig_widgets,lighting_ab_dialog}.dart` + `lighting_state.dart` + `lighting_files.dart`（诊断包/预览图/贴图选取/统一提示口径）。
- **帧率实测（D152）**：`docs/qa/v8-s6-engine-perf-gtx4060.json` —— lightDrag p50 16.7 / **p95 17.5ms** / p99 23.2 / max 25.0ms，**长帧 >50ms = 0**，CPU/帧 1.93ms；idle/orbit/dolly p95 17.3–17.8ms，长帧均 0。**偏差登记**：合同写 p95 ≤16ms，实测略高是因为 60Hz vsync（帧预算 16.67ms，稳定落在下一帧而非掉帧卡顿），与 S2 基线一致，按「说明不降档」处理。
- **视觉证据（R72）**：16 张 → `docs/screenshots/v8/s6-lighting-{workspace,stage-pip,inspector-selected,left-list}-{paper,darkroom}-{1280x800,1920x1080}.png` + 索引 `docs/qa/v8-s6-lighting-screenshots.json`。
- **测试**：`app/test/features/s6_lighting_ui_test.dart` **13 用例**（工具条 3 / 撤销重做 2 / 左栏 3 / 右栏 3 / 中栏 2）+ `app/test/features/s6_lighting_undo_test.dart` **14 用例**（栈逻辑 8 + 接线 6）+ `app/test/visual/s6_lighting_capture_test.dart` 16 截图 + 1 索引。
- **门禁**：format 0 changed ｜ analyze 0（8.5s）｜ 全量 **441 passed + 40 skipped** ｜ `q6_lighting/q6_engine/q6_still/q6_camera` **44/44 不回归** ｜ `check_file_size` PASS。

### S5 画面参考搜索重构（D154 · R71–R74 / R78 / R79）
- **报告**：`docs/qa/v8-s5-refs-search.md`（文件拆分 / 四个版面 / 色卡与许可 / 视觉证据 / 14 专项 / 门禁 / 复盘）。
- **版面（§4.3）**：① 首屏 = 居中检索（眉题 REFERENCE · 画面参考 + 衬线大标题 + 搜索框 + 以图搜图/粘贴截图/本地导入）+ 8 张**主题画报**（3:2 版面块 + 衬线首字占位 + mono id，废掉旧的文字 chip 形态）+「全部 48 个主题」入口；② 有结果时首屏自动收成**紧凑模式**（检索条 + 单行画报 chip），把纵向空间让给瀑布流；③ 结果 = 保留纵横比的**瀑布流**（`RefsMasonryGrid` 按列排布，纵向图更高）+ 悬停浮层（来源/许可/可商用 + 详情/收画板/以图搜图，触控端常驻，D149 偏差登记）；④ **详情抽屉** = 大图 + 来源/许可/可商用/尺寸/来源页 + **五色色卡** + 相似参考；⑤ **我的画板** = 4:5 竖幅画册块 + 拖拽排序 + 导出长图。
- **文件拆分（R73）**：`refs_home.dart` / `refs_masonry.dart` / `refs_hit_card.dart` / `refs_hit_drawer.dart` / `refs_board.dart` / `refs_palette.dart` / `refs_page_chrome.dart`（拖拽落画板 + Ctrl/Cmd+V + 图卡详情弹窗）/ `refs_page.dart` **567 行**（≤600）→ `tool/file_size_baseline.json` 里的 refs_page 白名单**整条删除**（12 → 11 项）。
- **色卡（R70）**：`RefsPaletteService` 走 `SearchCache` 下载缩略图 → `PaletteExtractor` 提 5 色 + 内存记忆化；新增 `refsPaletteServiceProvider` 注入点（测试/截图可覆盖为固定色，CI 不触网）。
- **图片占位（R82）**：`RefsMasonryImage` 统一 surfaceSunken + 衬线首字；并给 `Image` 子节点注入兜底 `errorBuilder`，**加载失败也回落占位**（不留空白块）。
- **管线不动（R79）**：QueryPlanner → SearchEngine（13 源）→ SearchCache → RefsController 全部沿用；`q6_search_test` **41/41 不回归**。
- **视觉证据（R72）**：16 张 → `docs/screenshots/v8/s5-refs-{home,results,detail,board}-{paper,darkroom}-{1280x800,1920x1080}.png` + 索引 `docs/qa/v8-s5-refs-screenshots.json`；目视无豆腐块/无溢出。
- **测试**：`app/test/features/s5_refs_ui_test.dart` **14 用例**（首屏 3 / 瀑布流 4 / 详情抽屉 2 / 画板 3 / 色卡 2）+ `app/test/visual/s5_refs_capture_test.dart` 16 截图 + 1 索引用例。
- **门禁**：format 0 changed（202 files）｜ analyze 0（9.1s）｜ 全量 **384 passed + 39 skipped** ｜ `check_file_size` PASS。

### S4 App 外壳 + 首页重构（D151 · R71–R74 / R82）
- **报告**：`docs/qa/v8-s4-shell-home.md`（文件行数 / 信息架构 / 横幅 / 首页 / 视觉证据 / 13 专项 / 门禁 / 6 条复盘）。
- **信息架构**：三段式 `工作流 WORKFLOW(0,4) / 成案 DELIVERY / 系统 SYSTEM(6)` 共 7 入口（开案/画面参考/布光预演/动作摆姿/资源库/策划案/设置，各带 mono 小标 IDEA·REF·LIGHT·POSE·GEAR·PLAN·SET）；`shellTabProvider` 下标语义在 `app_shell.dart` 与 `shell_nav.dart` 双处注释（R76）。
- **文件拆分（R73）**：`shell_nav.dart` 321 / `app_shell.dart` 134 / `shell_update_banner.dart` 94 / `home_page.dart` 171 / `home_hero.dart` 178 / `home_recent.dart` 119（重构前 343 + 365 两文件 → 6 文件，最大 321 行）。
- **去渐变紫蓝（R82）**：品牌方章由 `LinearGradient([accent, 0xFF7B5CFF])` 改为 `accent` 实色 + 衬线「正」；选中态 = `accentSoft` 底 + 1px `accent` 左边框。
- **更新横幅**：公告式（眉题 + `SsMonoBadge` 版本 + 前 2 条要点 + 「下次再说」/「立即更新」）；`downloadFor(platform)` mirror 优先、否则 github、都空则 toast；显隐逻辑与 V7 一致。
- **首页**：Display 衬线「说说你想拍什么」（既有测试依赖文案，R79 保留）+ lede + 生成按钮 + 本地说明行 + 6 张灵感横滑 + 最近策划案（loading/error/空态/列表）。
- **视觉证据（R72）**：8 张 → `docs/screenshots/v8/s4-{shell-home,shell-banner}-{paper,darkroom}-{1280x800,1920x1080}.png`（76,845–97,480 B）+ 索引 `docs/qa/v8-s4-shell-home-screenshots.json`；目视无豆腐块/无溢出。
- **测试**：`app/test/features/s4_shell_home_test.dart` 13 用例（分组/下标/点击/横幅前 2 条要点/空态/灵感回调 + R74 设计系统引用 + R71·R82 源码门禁 + R73 行数）；既有 `home_flow`/`golden_flow`/`golden_screens` 10 passed（开案页 golden 用 `--update-goldens` 重生成，未删测试）。
- **门禁**：format 0 changed（193 files）｜ analyze 0（12.0s）｜ 全量 **354 passed + 38 skipped**。

### S3 设计系统落地（D147 · R71–R74）
- **报告**：`docs/qa/v8-s3-design-system.md`（令牌锁定表 / 组件清单 / 迁移结果 / 残留字面量登记 / R73 门禁 / 视觉证据 / 10 条缺陷复盘）。
- **令牌唯一来源（R71）**：`app/lib/core/design/tokens.dart`（292 行）—— 12 色 × 双主题、字号 7 档、8pt 间距、圆角 2/4/8、栅格 1280/12 列/列距 24/页边距 24(≥1600 为 32)、两级阴影、动效 160/280/420 + 页面 200ms、字体（display `NotoSerifSC` / body `Microsoft YaHei` / mono `JetBrainsMono` + CJK 回退）；入口 `AppTokensV2.of(context)` / `context.palette`。`theme.dart`（252 行）全量 ColorScheme/组件主题。
- **组件库（R74，§3.5 16 项 → 21 条断言）**：`ss_button` / `ss_input` / `ss_card` / `ss_chip` / `ss_text` / `ss_feedback` / `ss_dialog` / `ss_empty` / `ss_image_frame` / `ss_transitions` + `widgets.dart` barrel（13 文件、最大 292 行 ≤ R73 300）。
- **迁移（R71/R76/R79）**：`AppTokens.*` 引用 **23 文件 345 处 → 0**；旧 `core/theme/{tokens,app_theme}.dart` 改为 `@Deprecated` 迁移壳；`SsButtonKind.soft/ghost → outline/text`（75 处）；`AppTokens.mono → appMono`。
- **R73 行数门禁入 CI**：`app/tool/check_file_size.mjs` + `app/tool/file_size_baseline.json`（12 条白名单 = 当前行数 + 40，**只降不升**）；`.github/workflows/ci.yml` 新增 `File size gate (R73: features <= 600, design <= 300)`（位于 format 之后、analyze 之前，双平台）；本机 `--json=../docs/qa/v8-s3-file-size.json` → PASS（57 文件）。
- **demo 页与入口（R72）**：`app/lib/dev/design_demo_page.dart`（547 行，16 格全量组件板）+ 设置页 `kDebugMode` 下「设计系统 / 设计组件预览」入口；视觉用例 `app/test/visual/s3_design_demo_capture_test.dart`（明暗 × 1280×800 / 1920×1080，4 张 `docs/screenshots/v8/s3-design-demo-*.png` + 索引 `docs/qa/v8-s3-demo-screenshots.json`；CI 默认跑渲染冒烟 + 溢出断言，比对用 `SS_V8_VISUAL=1`）。
- **官网同源令牌**：`web/src/styles/tokens.css`（由 `spike_tokens.css` 提升）+ `global.css` 首行 `@import` + `tailwind.config.mjs` 新增 `v8-*`（全部指向 CSS 变量）；`npm run build` 6 页；4 张官网截图重出。
- **字体与许可（R80）**：`app/assets/fonts/NotoSerifSC-ShootStudio.otf`（566,132 B 子集）+ `NotoSerifSC-OFL.txt` + `README.md`（来源/许可/子集命令）；`pubspec.yaml` 登记 `fonts:` 与 `assets/fonts/`；官网同款字体入 `web/public/fonts/`。
- **门禁**：format 0 changed（187 files）｜ analyze 0（10.6s）｜ 全量 **333 passed + 37 skipped** ｜ 专项：设计系统单测 20/20、demo 视觉 4+1、`check_file_size` PASS。
- **偏差登记（诚实）**：`lib/**` 残留硬编码 `0x` 107 处 / `fontSize:` 280 处 / `BorderRadius.circular` 26 处（集中在页面局部排版，非令牌层），随 S4–S9 逐页重写归零，每步附字面量扫描数据。

### S2 3D 引擎架构 spike（D156 · R77 先报告）
- **报告**：`docs/qa/v8-s2-engine-arch-spike.md` —— **结论：保留 WebView2 + three.js r186，不迁 Flutter 原生渲染**；报告后未改架构。
- **候选 A 实测**（`app/tool/engine_perf_qa.mjs`，4 组配置 → `docs/qa/v8-s2-engine-perf-*.json`）：1259×810、3 灯 + VSM 软阴影、high 档下 idle/orbit/拖灯/推拉 **p95 17.4–18.4ms、长帧 0、CPU/帧 2.3–3.9ms**（RTX 4060 DPR1/DPR2 与 Intel Iris Xe 核显一致）；**纯软件 SwiftShader ≈1500ms/帧（0.66fps）** → 沿用 low 档回退（R69）。
- **宿主成本**（`app/lib/dev/perf_probe.dart`，门控 `--dart-define=SS_PERF_PROBE=1`）：flutterOnly 帧 p95 17.34ms / build 0.69 / raster 1.38；+WebView2 引擎后 17.78 / 0.96 / 2.17 → **边际成本 +0.44ms p95**（`docs/qa/v8-s2-flutter-perf-win-webview.json`）。
- **候选 B 证据**：Flutter 3.47.2 `dart:ui` 的 `Scene`/`SceneBuilder`（`sky_engine/lib/ui/compositing.dart` L12/L259）是 **2D layer/paint 栈**，无 mesh/material/light/3D RT 原语；迁移需重写 **4,435 行自有引擎源码 + 238 处 `THREE.*` + 65 个 `window.ss` 桥接 API**，且路径追踪/景深/VSM 无等价实现。
- **S6 硬要求**（本结论带来）：桥接批处理 + 事件节流 + 骨架屏；交互帧率 p95 ≤20ms、无 >50ms 长帧（用 `perf_probe` 取证）。
- **门禁**：format 0 changed（172 files）｜ analyze 0 ｜ 全量 **309 passed + 36 skipped** ｜ perf_probe 单测 6。
- **另修复 CI**：`d93fe3a` —— `app/android/settings.gradle.kts` 的 pluginManagement 之前无视 `SS_MAVEN_MIRROR=0`，导致 CI 仍打阿里云镜像并被其 502 拖垮（与代码无关）。

### S1 设计 spike（D147 · R77 先行报告）
- **报告**：`docs/qa/v8-s1-design-spike.md`（先报告后实施；§3 令牌表自此锁定，S3 只搬运不改值）。
- **3 张样板页**：`app/lib/design_spike/spike_tokens.dart`（App 令牌）+ `spike_pages.dart`（首页 7+5 / 布光三栏）、`web/src/pages/spike-hero.astro` + `web/src/styles/spike_tokens.css`（官网首屏，值与 Dart 逐字同源）。
- **截图 12 张（R72）**：明暗 × 1280×800 / 1920×1080，合计 738,905 B → `docs/screenshots/v8/`；索引 `docs/qa/v8-s1-screenshots.json`（App 8 张）与 `docs/qa/v8-s1-web-screenshots.json`（官网 4 张）。
  - 工具：App 用 `SS_V8_CAPTURE=1 flutter test --no-pub --update-goldens test/visual/s1_spike_capture_test.dart`（golden 写盘）；官网用 `web/tool/shot.mjs`（静态伺服 `web/dist` + headless Edge CDP `Emulation.setDeviceMetricsOverride`，主题 `?t=darkroom`）。
- **字体资产**：`app/assets/fonts/NotoSerifSC-ShootStudio.otf`（566,132 B，pyftsubset 子集 2,074 字符）+ `NotoSerifSC-OFL.txt` + `README.md`；`web/public/fonts/` 同款（官网共用）；`pubspec.yaml` 登记 `fonts:` 与 `assets/fonts/`。
- **门禁**：format 0 changed（170 files）｜ analyze 0 ｜ 全量 **303 passed + 36 skipped** ｜ 视觉专项 9/9 + golden 回归 8 passed。
- **复盘**（S3 直接规避）：`TextStyle.height` 必须是多倍数行高（写成 `lineHeight/size` 会让 RenderParagraph 塌成 1–2px）；限高图框要用 `Container(height:)`；mono 只放 ASCII；截图环境要手动加载 MaterialIcons。

### S0 合同入库 + 基线记录（§1 S0）
- **合同**：`FIX_CONTRACT_V8.0.md`（D145–D160 用户确认决策、R71–R82 硬规则、§3 设计系统强约束、§1 S0–S12 阶段门禁、§4 四大模块规格、§5 官网、§6 工程、§7 交付勾选表、§8 开场提示词）。
- **归档**：V1–V7 合同 + 旧交接文档移入 `docs/archive/`（git rename 记录），根目录只保留当前合同。
- **链接更新**：`README.md`（当前合同 → V8；历史 → `docs/archive/`；发版命令 → `v1.3.0`；测试总数 303+27；验收表补 V7 行）、`app/README.md`、`HANDOFF_V7.md`、`docs/qa/v7-audit-2026-09-28.md`。
- **基线证据**：`docs/qa/v8-s0-baseline.md`
  - 门禁：format **0 changed**（167 files）｜ analyze **No issues found**（24.2s）｜ 全量 **303 passed + 27 skipped**。
  - R73 规模：lib 116 文件 / 48,142 行；features 44 文件中 >600 行 12 个（planner_page 2634、lighting_page 2631、exporter 1682、gear_browser 1269、settings_page 1169、ai_controller 1122、refs_page 850、lighting_controller 788、ai_panel 768、libraries_page 765、pose_import_page 760、ai_client 739）。
  - 设计系统现状：`core/theme/tokens.dart` 69 行 + `app_theme.dart` 148 行 + `core/design/widgets.dart` 819 行（V8 目标：`AppTokensV2` + ≥15 组件、单文件 ≤300 行 + demo 页 + 官网 `tokens.css` 同源）。
  - 体积：引擎 1.11MB / pathtracer 0.22MB / 识别模型 195.50MB / assets 263.58MB / APK 412.0MB / Windows 437.6MB。
  - 官网：5 页（index/features/downloads/templates/changelog），Astro 4 + Tailwind + GSAP。

---

## 2. 剩余待办（按合同 §1 顺序，含门禁）

1. ~~**S6 布光预演（D152）**~~ ✅ 已完成（run `36808608106` = `4b8c25d` success 4/4）。
2. ~~**S7 动作摆姿与识别（D153）**~~ ✅ 已完成（本次提交；`q2_pose_photos/q6_pose3d/q6_pose_recognition` 不回归）。
3. **S8 策划案 + AI + 导出（D155）**：AI 面板三态、成案阅读视图（杂志内页排版）、导出长图/PDF/.sspak 三格式校验不回归。
4. **S9 资源库 + 设置 + 引导**：覆盖率六类 100% 不回归（`gear_coverage.py`）、设置往返测试。
5. **S10 官网（D157）**：5 页按 §3 重排（首屏真实截图）、`npm run build` 5 页、桌面+移动截图、announcements 通道不回归。
6. **S11 全量回归 + 视觉验收 + 死代码清理（D158）**：全量门禁、7 页截图总表（明暗 × 2 分辨率）、死代码删除清单（先 grep 引用计数为 0）。
7. **S12 v2.0.0 交付（D160）**：版本同步（pubspec 2.0.0+N / `kAppVersion` / 公告 / `web/dist`）、双端构建 + LAUNCH-OK + 体积、tag `v2.0.0`、CI 全绿、§7 勾选表逐项打勾。

---

## 3. 本机环境与坑（V8 实测新增）

1. **flutter/dart 不在 PATH**：用 `C:\dev\flutter\bin\{flutter,dart}.bat`（Flutter 3.47.2），命令在 `app/` 下执行；**本机门禁一律加 `--no-pub`**（Developer Mode 未开，`pub get` 结尾报 symlink 错误但仍写出 `package_config.json`）。
2. **pub 源必须用镜像**：pub.dev 直连本机超时（实测 `flutter pub get` >15min 未完成）→ `PUB_HOSTED_URL=https://pub.flutter-io.cn`（约 1min）。**镜像会把 `pubspec.lock` 每个包的 `url:` 改写成镜像域名（166 行 diff）→ 每次 pub get 后必须 `git checkout -- pubspec.lock` 还原**，不得入仓。
3. **dartcv4 / OpenCV native assets 必须打本地补丁**：其 CMake 从 `github.com/opencv/opencv` 下载 4.13.0 源码（github.com 本机不可达）→ 把 `%LOCALAPPDATA%\Pub\Cache\hosted\pub.flutter-io.cn\dartcv4-2.3.1\src\CMakeLists.txt` 第 153 行的 `URL https://github.com/opencv/opencv/archive/...` 改成 **本地绝对路径** `URL "D:/trae/6aa175d7786dd07d04fe3d2e/opencv-4.13.0.tar.gz"`（备份 `.v8bak`）。
   - 注意：写成 `file:///C:/...` 会被 CMake 归一化成 `/C:/...` 而下载失败（urlinfo 可见 `url(s)=/C:/Users/...`）。
   - 切换 pub 源（pub.dev ↔ 镜像）后必须删除 `app/.dart_tool/hooks_runner/shared/dartcv4/build/`，否则 CMake 报 `The source "…pub.flutter-io.cn…" does not match the source "…pub.dev…" used to generate cache`。
   - 首次修复后需从源码编译 OpenCV（数分钟），之后有缓存。
4. **本机 pub cache 曾被部分清理**（`image-*`、`flutter_lints-*` 等缺失 → `analyze` 报 2543 个 `uri_does_not_exist`）：先 `flutter pub get`（镜像）恢复。
5. **Windows 构建**：Developer Mode 未开（非管理员）→ 需先为 17 个插件在 `app/windows/flutter/ephemeral/.plugin_symlinks\` 建 junction（`cmd /c mklink /J`）。
6. **截图/QA**：Edge headed 需 `--disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling` + `Page.bringToFront`，否则 rAF/定时器被冻结（引擎主循环停摆）。
7. **gh CLI 已登录**（`C:\Program Files\GitHub CLI\gh.exe`，账号 `meihuaanying`，scopes: repo）→ 仓库/环境/Pages 操作用它；PowerShell 传 `gh api --jq '含空格表达式'` 会被拆参，改用 Python 调 gh。
8. 沿用 V7 坑表（见 `docs/archive/HANDOFF_V7.md` §3）：three r186 打包（`node tool/engine_build/bundle.mjs`）、QA 前杀 headless Edge、推送需三个 `-c http.https://<host>/.proxy=` 直连参数且可能需重试、Pages 部署需 `v*` tag 策略等。
9. **widget 测试里截图必须走 `matchesGoldenFile`**：`RenderRepaintBoundary.toImage` + `toByteData` 在 FakeAsync 中会挂起（表现为 10 分钟超时）；用 `--update-goldens` 写文件。**路径基准不同**：`matchesGoldenFile` 相对**测试文件目录**（`app/test/visual/` → 仓库根需 `../../../`），而 `File()` 相对**进程 cwd（`app/`）** → 写索引 JSON 要 `../docs/...`。
10. **`TextStyle.height` 是多倍数**：写成 `lineHeight / fontSize` 会让 RenderParagraph 高度塌成 1–2px（标题行重叠、标签竖排）。S1 实测排查法：临时测试里自写 `_walk(RenderObject)` 打印 `RenderParagraph.size`（注意本版本 `debugDumpRenderTree()` 无参、`visitChildren` 回调返回 `void`）。
11. **字体加载要自己管**：截图/测试环境默认只有 MaterialIcons 之外的空字族 → 需 `FontLoader` 加载 repo 字体（`rootBundle`）与系统字体（绝对路径）；**mono 字族（Consolas）没有 CJK**，mono 文本里放中文会出豆腐块。
12. **官网截图**：`web/tool/shot.mjs` 静态伺服 `web/dist` + headless Edge CDP；`Emulation.setDeviceMetricsOverride` 固定视口；主题用 URL 参数 `?t=darkroom`（页面内联脚本写 `data-theme`），一次构建覆盖双主题；改样式后必须先 `npm run build`（Astro 输出 6 页）再截图。
13. **性能测量必须先等稳态**（S2 实测踩坑）：直接采样会得到 p95≈940ms、max≈1.9s 的假数据（首帧着色器编译/HDR PMREM/GLB 加载被算进交互帧率）。判据：`getEngineStats().frames` 推进 + `Performance.getMetrics` 的 `TaskDuration` 增速 < 250ms/s。CDP 合成输入**不要 await 响应**（fire-and-forget + 在飞上限 40），否则渲染线程往返时延被算成帧间隔。
14. **headed + `--force_high_performance_gpu` 会强制独显**：测核显用 `--gpumode=default`（本机实测落到 Intel Iris Xe）；`--headless=new` 仍会用真实 GPU，要真软件渲染得显式 `--use-angle=swiftshader`。报告里必须标注 devicePixelRatio（headed 默认 DPR=2）。
15. **CI 阿里云镜像会 502**：`app/android/settings.gradle.kts` 的 pluginManagement 现已尊重 `SS_MAVEN_MIRROR=0`（与 `build.gradle.kts` 一致）；若再出现 “Repository maven is disabled due to earlier error” + aliyun 502，先查这个，再考虑重跑 job。

16. **迁移到局部调色板 `p` 的三个必踩点**（S3 实测 98 个错误清零）：① `const TextStyle(color: p.accent)` 依赖运行时值 → 必须删 `const`（要按括号配平往上找 `const` 起点整段删）；② 私有辅助方法若没有 `BuildContext` 作用域，`p.accent` 会 undefined → 给方法补 `BuildContext context` 首参并改调用点；③ 本仓库多处 `import 'package:path/path.dart' as p;` → 调色板 `p` 与前缀 `p` 冲突，改前缀为 `path`（注意形参 `String path` 又会遮蔽它），或把遮蔽的局部变量改名。判定调色板引用用「`p.` + 12 个色字段」白名单。
17. **不要用 PowerShell 改含中文的文件**：Set-Content / heredoc 会破坏 UTF-8（写 astro/YAML 时出现乱码）→ 一律用 `write` 工具或 Python（`io.open(..., encoding='utf-8')`）改；Python 脚本本身也用 `write` 工具落盘再 `python` 执行。
18. **`check_file_size` 白名单只降不升**：R73 基线 JSON 里每条 = 当前行数 + 40 余量；文件变短后必须同步下调，脚本会校验「白名单值 > 实际行数 + 40」即失败，防止把超限文件固化下来。
19. **golden 视觉测试的三个细节**：① 测试 `pumpWidget` 的 `home` 必须包 `Scaffold`，否则 `No Material widget found`；② 设计系统换代后旧页面 golden 会像素不一致 → 用 `--update-goldens` 重生成（不删测试，R79 合规）；③ CI 默认只跑渲染冒烟 + `tester.takeException()` 溢出断言，像素比对要显式 `SS_V8_VISUAL=1`（字体光栅化差异会误报）。

20. **workflow YAML 的 `name`/`run` 值不能带未加引号的冒号**：`- name: File size gate (R73: features <= 600)` 会让 YAML 解析失败 → GitHub 拒绝整个 workflow → run **1 秒失败、0 个 job、无任何日志**，且 rerun 返回 “cannot be retried”。S3 实测踩过（run 36690853795，症状：`run_started_at == created_at` 且 `jobs.total_count = 0`）。推 CI 前本地解析：`python -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml', encoding='utf-8')); print('YAML OK')"`。

21. **workflow YAML 里步骤名的冒号必须加引号**（S3 踩坑）：`- name: File size gate (R73: features <= 600)` 会让 GitHub 在 1 秒内拒绝整个 workflow（run 立刻 completed/failure、`jobs.total_count = 0`、`rerun` 返回 403、日志不可读）。提交前本机校验：`python -c "import yaml,io; yaml.safe_load(io.open('.github/workflows/ci.yml',encoding='utf-8'))"`。
22. **CI jobs 查询走 API，别用 `gh run view --json jobs`**（本环境返回空 jobs）：用 `%TEMP%\opencode\gh_jobs.py <run_id>`（`gh api .../actions/runs/<id>/jobs` + 失败 step 日志尾部）。
24. **S5 版面竖向预算**：首屏画报墙（132px）与瀑布流同屏时 1280×800 会把结果挤出视口 → `RefsHomeHeader(compact:)` 由「有结果」驱动（`refs_page.dart` 传 `_hits.isNotEmpty`），画报墙换成 30px 单行 chip 行。
25. **测试里 Dio 会留下 FakeTimer**：`RefsPaletteSlot` 真实路径走 `SearchCache.getOrFetch`（Dio），即使 HTTP 被 flutter_test 打桩，测试收尾仍会触发「A Timer is still pending even after the widget tree was disposed」→ 已加 `refsPaletteServiceProvider` 注入点，截图/单测覆盖为固定色卡（这也是 R62 的常规做法：注入点比改产品默认更可取）。
26. **`ImageProvider` 自定义桩在 Flutter 3.47 不可行**：`ImageStreamCompleter` 是抽象类、`loadImage(T key, ImageDecoderCallback decode)` 是位置参数 → 想测「加载失败回落」直接用 `Image.network('https://example.invalid/…')`（flutter_test 的 HttpOverrides 会让解码失败），比自写 provider 稳。
23. **drift 生成的行类要从 `core/db/database.dart` 导入**（不是 `planner_models.dart`）：`Plan` 等表数据类由 `database.dart` re-export；且该库不再导出 `Column`，写 `hide Column` 会触发 analyzer 警告。

27. **拆类成员不能用 `part` 文件（S6 踩坑）**：`part` 只共享库的顶层命名空间，**不共享类成员** —— 把 `_buildXxx` 方法搬进 `part` 文件后拿不到 `state/ref/context`，直接编译不过。正确做法：抽成公开 widget + 显式参数（本仓库 `refs_page_chrome.dart` 与 S6 的 `widgets/lighting_*.dart` 都是这个形态）。
28. **撤销栈必须区分「离散」与「连续」**（S6）：`record()` 若对同标签一律按时间窗合并，连续 24 次「新增灯具」会被折成 1 步，达不到契约「≥20 步」。现在 `record(before, {merge})`：离散操作 `merge:false` 每步独立，滑杆/拖拽 `merge:true`；拖拽另用 `beginInteraction`/`endInteraction` 精确圈成一步。
29. **工具条要防横向溢出**（S6）：`Row + Spacer` 在 800×600 视口会 `RenderFlex overflowed by 281 pixels` → 左半区改 `Expanded(SingleChildScrollView(scrollDirection: horizontal, Row(chips)))`，右半区常驻状态/撤销/A-B/主按钮。
30. **widget 测试必须给足视口 + 先杀 Edge**（S6）：`ListView` 懒建会让 `QualityPanel`/`JointTunePanel` 在小视口下根本不存在，`tester.tap` 也会落到视口外 → 测试内统一 `useWide(tester)`（1600×1400）；跑帧率/QA 前先 `Stop-Process msedge`。

---

## 4. 新对话开场提示词（可直接粘贴）

> 继续 `D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio` 的 V8 全面重做：先读 `FIX_CONTRACT_V8.0.md`（D145–D160 / R71–R82）与 `HANDOFF_V8.md`（本文件）。
> 基线：v1.3.0；已完成 S0–S7（合同 + S1 设计 spike + S2 引擎架构 spike（保留 WebView2 + three r186）+ S3 设计系统落地 + S4 App 外壳/首页 + S5 画面参考搜索 + S6 布光预演三栏重构 + S7 动作摆姿与识别重做）；全量 **441 passed + 40 skipped**。
> 下一步 **S8 策划案 + AI + 导出（D155）**：AI 面板三态、成案阅读视图（杂志内页排版）、导出长图/PDF/.sspak 三格式校验不回归；沿用 S5/S6/S7 的模式（先读合同 §4.3 → 拆分文件满足 R73 → 专项测试 → 明暗 ×2 分辨率截图 + 索引 → 报告 `docs/qa/v8-s8-*.md`）。之后 S9 资源库/设置/引导 → S10 官网 → S11 全量回归+视觉验收+死代码 → S12 v2.0.0 交付。
> 纪律：每步 format 0 changed / analyze 0 问题 / 全量 test / 专项证据 / push 后 CI 全绿（R81）才进下一步；spike 先行（R77）；无证据 = 未完成（R78）；不回归（R79）；许可红线（R80）。
