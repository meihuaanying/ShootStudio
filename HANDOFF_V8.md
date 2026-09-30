# ShootStudio V8 交接文档 · 进行中（杂志画册风设计系统 + 四大模块升级 + 工程重构 + 官网同步）

> 更新：2026-09-30 ｜ 配套合同：`FIX_CONTRACT_V8.0.md`（D145–D160、R71–R82，**开工前必读**）
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter `app/`，官网 `web/`，证据 `docs/`）
> 基线：v1.3.0 已发布（tag `v1.3.0`）；V8 目标 v2.0.0

---

## 0. 一分钟速览

| 项 | 状态 |
|---|---|
| 已完成并推送 | **S0 合同与基线**（本次提交）：`FIX_CONTRACT_V8.0.md` 入库；V1–V7 合同与旧交接归档至 `docs/archive/`；基线数据入档 `docs/qa/v8-s0-baseline.md` |
| CI | S0 推送后运行中（R61：全绿才算完成，下一步先复核）；V7 收尾提交 `454f460` run 36377508962 success 4/4 |
| 门禁基线 | format 0 changed（167 files）｜ analyze 0 问题 ｜ 全量 **303 passed + 27 skipped** ｜ `lib/features/**` >600 行 **12 个 / 15,177 行**（R73 待拆）｜ `lib/core/design/widgets.dart` 819 行（R73 上限 300）｜ 引擎包 1.11MB + pathtracer 0.22MB ｜ assets 263.58MB ｜ APK 412.0MB ｜ Windows release 437.6MB（1602 文件） |
| 当前步 | S0 收尾（提交 + CI 复核） |
| 剩余 | **S1 设计 spike** → **S2 引擎架构 spike** → **S3 设计系统落地** → S4 外壳/首页 → S5 画面参考 → S6 布光预演 → S7 动作摆姿与识别 → S8 策划案/AI/导出 → S9 资源库/设置/引导 → S10 官网 → S11 全量回归+视觉验收+死代码 → S12 v2.0.0 交付 |

---

## 1. 已完成（含证据路径）

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

1. **S1 设计方向 spike（R77）**：用 §3 令牌做 3 个样板页（App 首页 / 布光页 / 官网首页首屏）；明暗双主题 × 1280×800 + 1920×1080 截图（共 12 张）存 `docs/screenshots/v8/`；人工评审后**锁定令牌**；CI 绿。
2. **S2 3D 引擎架构 spike（D156）**：对比 ①WebView2 + three.js r186 现状 ②Flutter 原生渲染（flutter_gpu / Impeller Scene）；报告含交互帧率 p95（拖灯/旋转视角）、内存、集成成本、双端可行性、资产迁移代价 + 明确结论入 git；**报告前不改架构**；若保留 WebView 路线须同时交付交互层重构（桥接批处理/事件节流/骨架屏）。
3. **S3 设计系统落地**：`AppTokensV2`/`app_theme.dart` 全量替换 + `lib/core/design/` 组件库 ≥15（单文件 ≤300 行）+ 官网 `tokens.css`/tailwind 同步 + 字体资产（Noto Serif SC，OFL，随包子集化 ≤2MB，登记 attribution R80）；demo 页明暗截图；旧令牌 grep 清零。
4. **S4 App 外壳 + 首页**：导航/信息架构/更新横幅；页面文件 ≤600 行；widget 测试 + 截图门禁。
5. **S5 画面参考搜索（D154）**：首屏主题画报入口、瀑布流结果、画册式画板、以图搜图收口；`q6_search_test` 41/41 不回归。
6. **S6 布光预演（D152，按 S2 结论）**：左清单/中视口/右属性检查器、灯位拖拽 p95 帧耗时实测、撤销重做 ≥20 步、静帧导出 ≤3 步；`q6_lighting/q6_engine/q6_still/q6_camera` 不回归。
7. **S7 动作摆姿与识别（D153）**：大图瀑布流 + 详情抽屉、识别链路 ≤4 步、关节点拖拽校正；`q2_pose_photos/q6_pose3d/q6_pose_recognition` 不回归。
8. **S8 策划案 + AI + 导出（D155）**：AI 面板三态、成案阅读视图（杂志内页排版）、导出长图/PDF/.sspak 三格式校验不回归。
9. **S9 资源库 + 设置 + 引导**：覆盖率六类 100% 不回归（`gear_coverage.py`）、设置往返测试。
10. **S10 官网（D157）**：5 页按 §3 重排（首屏真实截图）、`npm run build` 5 页、桌面+移动截图、announcements 通道不回归。
11. **S11 全量回归 + 视觉验收 + 死代码清理（D158）**：全量门禁、7 页截图总表（明暗 × 2 分辨率）、死代码删除清单（先 grep 引用计数为 0）。
12. **S12 v2.0.0 交付（D160）**：版本同步（pubspec 2.0.0+N / `kAppVersion` / 公告 / `web/dist`）、双端构建 + LAUNCH-OK + 体积、tag `v2.0.0`、CI 全绿、§7 勾选表逐项打勾。

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

---

## 4. 新对话开场提示词（可直接粘贴）

> 继续 `D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio` 的 V8 全面重做：先读 `FIX_CONTRACT_V8.0.md`（D145–D160 / R71–R82）与 `HANDOFF_V8.md`（本文件）。
> 基线：v1.3.0（303 passed + 27 skipped）；已完成 S0（合同入库 + 基线 `docs/qa/v8-s0-baseline.md`）；下一步 **S1 设计 spike**（3 样板页 + 明暗双主题 × 两分辨率截图 + 锁定令牌），之后 S2 引擎架构 spike → S3 → S4–S9 → S10 → S11 → S12。
> 纪律：每步 format 0 changed / analyze 0 问题 / 全量 test / 专项证据 / push 后 CI 全绿（R81）才进下一步；spike 先行（R77）；无证据 = 未完成（R78）；不回归（R79）；许可红线（R80）。
