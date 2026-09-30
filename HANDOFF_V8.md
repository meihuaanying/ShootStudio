# ShootStudio V8 交接文档 · 进行中（杂志画册风设计系统 + 四大模块升级 + 工程重构 + 官网同步）

> 更新：2026-09-30 ｜ 配套合同：`FIX_CONTRACT_V8.0.md`（D145–D160、R71–R82，**开工前必读**）
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter `app/`，官网 `web/`，证据 `docs/`）
> 基线：v1.3.0 已发布（tag `v1.3.0`）；V8 目标 v2.0.0

---

## 0. 一分钟速览

| 项 | 状态 |
|---|---|
| 已完成并推送 | **S0 合同与基线** `4b4bc1a` ｜ **S1 设计 spike** `572fcad`（3 样板页 + 12 张明暗双主题截图 + 令牌锁定；报告 `docs/qa/v8-s1-design-spike.md`）｜ **CI 修复** `d93fe3a`（pluginManagement 尊重 `SS_MAVEN_MIRROR`，修阿里云 502 导致的 APK job 失败）｜ **S2 引擎架构 spike**（本次提交，报告 `docs/qa/v8-s2-engine-arch-spike.md`） |
| CI | S2 推送后运行中（R61：全绿才算完成，下一步先复核）；S0 全绿（36673666121）；S1 run 36679632640 的 Analyze/Test/Build Windows ✅、**Build Android APK ❌（阿里云 502，已由 `d93fe3a` 修复，待新 run 验证）** |
| 门禁基线 | format 0 changed（172 files）｜ analyze 0 问题 ｜ 全量 **309 passed + 36 skipped** ｜ 视觉专项 9/9 + golden 回归 8 passed ｜ perf_probe 单测 6 ｜ 引擎帧率 p95 ≤18.4ms（独显/核显）｜ Flutter 宿主 +WebView 增量 +0.44ms p95 ｜ `lib/features/**` >600 行 **12 个**（R73 待拆）｜ 引擎包 1.11MB + pathtracer 0.22MB ｜ 识别模型 195.50MB ｜ 衬线字体子集 0.54MB ｜ assets 263.58MB ｜ APK 412.0MB ｜ Windows 437.6MB |
| 当前步 | S2 收尾（提交 + CI 复核） |
| 剩余 | **S3 设计系统落地** → S4 外壳/首页 → S5 画面参考 → S6 布光预演 → S7 动作摆姿与识别 → S8 策划案/AI/导出 → S9 资源库/设置/引导 → S10 官网 → S11 全量回归+视觉验收+死代码 → S12 v2.0.0 交付 |

---

## 1. 已完成（含证据路径）

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

1. **S3 设计系统落地**：`AppTokensV2`/`app_theme.dart` 全量替换 + `lib/core/design/` 组件库 ≥15（单文件 ≤300 行）+ 官网 `tokens.css`/tailwind 同步 + 字体资产（Noto Serif SC，OFL，随包子集化 ≤2MB，登记 attribution R80）；demo 页明暗截图；旧令牌 grep 清零。
2. **S4 App 外壳 + 首页**：导航/信息架构/更新横幅；页面文件 ≤600 行；widget 测试 + 截图门禁。
3. **S5 画面参考搜索（D154）**：首屏主题画报入口、瀑布流结果、画册式画板、以图搜图收口；`q6_search_test` 41/41 不回归。
4. **S6 布光预演（D152，按 S2 结论）**：左清单/中视口/右属性检查器、灯位拖拽 p95 帧耗时实测、撤销重做 ≥20 步、静帧导出 ≤3 步；`q6_lighting/q6_engine/q6_still/q6_camera` 不回归。
5. **S7 动作摆姿与识别（D153）**：大图瀑布流 + 详情抽屉、识别链路 ≤4 步、关节点拖拽校正；`q2_pose_photos/q6_pose3d/q6_pose_recognition` 不回归。
6. **S8 策划案 + AI + 导出（D155）**：AI 面板三态、成案阅读视图（杂志内页排版）、导出长图/PDF/.sspak 三格式校验不回归。
7. **S9 资源库 + 设置 + 引导**：覆盖率六类 100% 不回归（`gear_coverage.py`）、设置往返测试。
8. **S10 官网（D157）**：5 页按 §3 重排（首屏真实截图）、`npm run build` 5 页、桌面+移动截图、announcements 通道不回归。
9. **S11 全量回归 + 视觉验收 + 死代码清理（D158）**：全量门禁、7 页截图总表（明暗 × 2 分辨率）、死代码删除清单（先 grep 引用计数为 0）。
10. **S12 v2.0.0 交付（D160）**：版本同步（pubspec 2.0.0+N / `kAppVersion` / 公告 / `web/dist`）、双端构建 + LAUNCH-OK + 体积、tag `v2.0.0`、CI 全绿、§7 勾选表逐项打勾。

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

---

## 4. 新对话开场提示词（可直接粘贴）

> 继续 `D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio` 的 V8 全面重做：先读 `FIX_CONTRACT_V8.0.md`（D145–D160 / R71–R82）与 `HANDOFF_V8.md`（本文件）。
> 基线：v1.3.0；已完成 S0（合同 + `docs/qa/v8-s0-baseline.md`）、S1（设计 spike：`docs/qa/v8-s1-design-spike.md`）、S2（引擎架构 spike：`docs/qa/v8-s2-engine-arch-spike.md` → **保留 WebView2 + three r186**）；全量 **309 passed + 36 skipped**。
> 下一步 **S3 设计系统落地**（把 S1 锁定的 §3 令牌搬进 `lib/core/design/`，组件 ≥15、单文件 ≤300 行、`core/design/` 目录 ≤300 行，CI 加 `tool/check_file_size.mjs`；官网 `tokens.css` 同步；旧令牌 grep 清零），之后 S4–S9 模块重做 → S10 官网 → S11 全量回归+视觉验收 → S12 v2.0.0 交付。
> 纪律：每步 format 0 changed / analyze 0 问题 / 全量 test / 专项证据 / push 后 CI 全绿（R81）才进下一步；spike 先行（R77）；无证据 = 未完成（R78）；不回归（R79）；许可红线（R80）。
