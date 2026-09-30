# V8 S0 基线记录（合同 `FIX_CONTRACT_V8.0.md` §1 · S0）

- 日期：2026-09-30
- 基线：v1.3.0（tag `v1.3.0`，main HEAD `454f460`）
- 目标：v2.0.0（杂志画册风设计系统 + 四大模块升级 + 工程架构重构 + 官网同步）
- 本步结论：合同入库 + 历史合同归档 + 基线门禁与规模/体积数据入档（供 S1–S11 对比）

## 1. 本次入库内容

| 项 | 说明 |
| --- | --- |
| 新增 | `FIX_CONTRACT_V8.0.md`（D145–D160、R71–R82、§1 S0–S12 门禁、§3 设计系统强约束、§4 四大模块规格、§5 官网、§6 工程、§7 交付勾选表） |
| 归档（git rename） | `docs/archive/`：`FIX_CONTRACT_V1.0.1–V7.0.md`、`HANDOFF.md`、`HANDOFF_V5.md`、`HANDOFF_V6.md`、`HANDOFF_V6_CONTINUE.md`、`HANDOFF_V6_E_CONTINUE.md` |
| 链接更新 | `README.md`（当前合同 → V8、历史 → `docs/archive/`、发版命令 → `v1.3.0`、测试总数 → 303+27、验收表补 V7 行）、`app/README.md`、`HANDOFF_V7.md`（配套合同 → `docs/archive/FIX_CONTRACT_V7.0.md`）、`docs/qa/v7-audit-2026-09-28.md`（依据 → `../archive/FIX_CONTRACT_V7.0.md`） |

## 2. 基线门禁（`app/`，本机实测）

| 项 | 命令 | 结果 |
| --- | --- | --- |
| 格式 | `dart format --output=none --set-exit-if-changed lib test` | **Formatted 167 files（0 changed）** |
| 静态分析 | `flutter analyze --no-pub --fatal-infos` | **No issues found!**（24.2s） |
| 全量测试 | `flutter test --no-pub` | **303 passed + 27 skipped，All tests passed!** |

（与合同 §头「基线：v1.3.0 …303 passed + 27 skipped」一致；本步未改动任何 `lib/`、`test/` 代码，计数为纯净基线。）

## 3. R73 文件规模基线（S3–S9 拆分清单输入）

- `app/lib` Dart 文件 **116 个 / 48,142 行**；`app/test` **51 个 / 11,121 行**
- `lib/features/**` 共 44 个文件，其中 **>600 行 12 个 / 15,177 行**（R73 要求全部拆到 ≤600）：

| 行数 | 文件 | 归属步 |
| --- | --- | --- |
| 2634 | `lib/features/planner/planner_page.dart` | S8 |
| 2631 | `lib/features/lighting/lighting_page.dart` | S6 |
| 1682 | `lib/features/export/exporter.dart` | S8 |
| 1269 | `lib/features/libraries/gear_browser.dart` | S9 |
| 1169 | `lib/features/settings/settings_page.dart` | S9 |
| 1122 | `lib/features/ai/ai_controller.dart` | S8 |
| 850 | `lib/features/refs/refs_page.dart` | S5 |
| 788 | `lib/features/lighting/lighting_controller.dart` | S6 |
| 768 | `lib/features/ai/ai_panel.dart` | S8 |
| 765 | `lib/features/libraries/libraries_page.dart` | S9 |
| 760 | `lib/features/poses/pose_import_page.dart` | S7 |
| 739 | `lib/features/ai/ai_client.dart` | S8 |

- 另有大文件在 R73 覆盖范围外但需随重构处理：`lib/core/db/database.g.dart` 8,919（drift 生成物，随 `build_runner` 产出，不计红线）、`lib/services/search/pinyin_data.dart` 1,412（数据表）、`lib/services/content_packs.dart` 812、`lib/services/gear_photo_sync.dart` 677、`lib/services/net_router.dart` 618。
- `lib/core/**` 现状：`db/database.g.dart` 8,919、`design/widgets.dart` 819、`db/tables.dart` 168、`theme/app_theme.dart` 148、`providers.dart` 91、`db/database.dart` 87、`workspace/workspace.dart` 78、`theme/tokens.dart` 69、`bootstrap/app_bootstrap.dart` 62、`utils/json_utils.dart` 59。

## 4. 设计系统现状（S3 输入）

| 项 | 现状 | 目标（§3 / D147） |
| --- | --- | --- |
| 令牌 | `lib/core/theme/tokens.dart` 69 行（旧 `AppTokens`） | 全量替换为 `AppTokensV2`（§3 色彩/字号/间距/圆角/动效），旧令牌 `@Deprecated` 一个迭代后删除，grep 引用清零 |
| 主题 | `lib/core/theme/app_theme.dart` 148 行 | 明暗双主题对齐 §3 色板（paper/darkroom） |
| 组件库 | `lib/core/design/widgets.dart` 819 行（1 个文件） | 拆分为 ≥15 个组件、单文件 ≤300 行（R73/R74），带 demo 页 |
| 官网令牌 | `web/` Tailwind 主题（无 v8 令牌） | `web/src/styles/tokens.css` 与 `AppTokensV2` 逐字同源 |
| 字体 | 现状系统字体 | 标题 Noto Serif SC（OFL，随包子集化 ≤2MB，需登记 attribution，R80） |

## 5. 体积基线（R65 / D151）

| 对象 | 大小 |
| --- | --- |
| `assets/engine/js/engine.bundle.js` | 1.11 MB |
| `assets/engine/js/pathtracer.bundle.js` | 0.22 MB |
| 识别模型（fp16 分片 ×2 + yolox_tiny） | 88.11 + 88.11 + 19.28 = 195.50 MB |
| `assets/` 合计 | **263.58 MB / 1,143 文件**（`content` 40.30 MB / 1,065；`poses3` 11.39 MB / 243） |
| Android APK（v1.3.0） | 412.0 MB |
| Windows release（未压缩） | 437.6 MB / 1,602 文件 |

## 6. 官网现状（S10 输入）

- Astro 4 + Tailwind + GSAP，5 页：`index` / `features` / `downloads` / `templates` / `changelog`；`web/dist` 由 CI 重建（gitignore）。

## 7. 本机环境（沿用/新增 V7 坑，V8 执行期必读）

1. `flutter`/`dart` 不在 PATH → `C:\dev\flutter\bin\{flutter,dart}.bat`（Flutter 3.47.2）；**本机所有门禁加 `--no-pub`**（Developer Mode 未开，`pub get` 结尾会报 symlink 错误但仍写出 `package_config.json`）。
2. **pub 源**：pub.dev 直连本机超时（实测 `flutter pub get` >15min 未完成）→ 必须用镜像 `PUB_HOSTED_URL=https://pub.flutter-io.cn`（约 1 分钟）。镜像会把 `pubspec.lock` 里每个包的 `url:` 从 `https://pub.dev` 改写为镜像域名（166 行 diff）→ **每次 pub get 后必须 `git checkout -- pubspec.lock` 还原**，不得入仓。
3. **dartcv4 / OpenCV native assets**：其 CMake `FetchContent` 从 `github.com/opencv/opencv` 下载 4.13.0 源码（github.com 本机不可达）→ 用本地 tarball 补丁：把 `%LOCALAPPDATA%\Pub\Cache\hosted\pub.flutter-io.cn\dartcv4-2.3.1\src\CMakeLists.txt` 第 153 行 `URL https://github.com/opencv/opencv/archive/...` 改为 `URL file:///C:/Users/Lenovo/AppData/Local/Temp/opencode/opencv-4.13.0.tar.gz`（备份 `.v8bak`；tarball 95,420,275 B，来自 `app/.dart_tool/hooks_runner/shared/dartcv4/build/*/_deps/opencv-subbuild/opencv-populate-prefix/src/4.13.0.tar.gz`）。**切换 pub 源后必须删除 `app/.dart_tool/hooks_runner/shared/dartcv4/build/`**，否则 CMake 报 `The source "…pub.flutter-io.cn…" does not match the source "…pub.dev…" used to generate cache`。
4. Windows 构建：需先为 17 个插件在 `app/windows/flutter/ephemeral/.plugin_symlinks\` 建 junction（`cmd /c mklink /J`）。
5. 截图/QA：Edge headed 需 `--disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling` + `Page.bringToFront`，否则 rAF/定时器被冻结。
