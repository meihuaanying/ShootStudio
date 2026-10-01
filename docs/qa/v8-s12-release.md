# V8/S12 · D160 v2.0.0 交付 — 完工报告

## 1. 结论

V8 全面重做（S0–S12）收官。S12 完成版本同步（`pubspec 2.0.0+9` / `kAppVersion` / 官网三处 fallback / `.sspak` manifest）、2.0.0 公告改写（V8 要点 + 已知限制 + 数据兼容性说明三块全覆盖）、`web/dist` 重建、App 侧全量门禁四项全绿、官网在 v2.0.0 下重新实证。

**双端构建与体积记录在本机无法完成**（两个真实环境限制，见 §5），已如实登记为偏差；APK 与 Windows 安装包由 tag `v2.0.0` 触发的 `release.yml` 产出。

## 2. 版本同步总账（D160）

| 位置 | 原值 | 新值 |
|---|---|---|
| `app/pubspec.yaml:4` | `version: 1.3.0+8` | **`version: 2.0.0+9`**（build number 单调递增） |
| `app/lib/features/updater/updater.dart:15` | `const String kAppVersion = '1.3.0';` | **`'2.0.0'`** |
| `app/lib/features/export/exporter.dart` | — | import 区新增 `import '../updater/updater.dart';`（part 指令仍在所有声明之前） |
| `app/lib/features/export/exporter_sspak.dart:29` | manifest `'appVersion': '1.0.0'`（写死旧值） | **`'appVersion': kAppVersion`**（消除第二个版本源） |
| `web/src/pages/downloads.astro:3` | `\|\| '1.3.0'` | **`\|\| '2.0.0'`**（8 个 DOM id 与 fetch script 未动） |
| `web/src/pages/index.astro:5` | `\|\| '1.3.0'` | **`\|\| '2.0.0'`** |
| `web/public/announcements.json` | `version 1.3.0` / `publishedAt 2026-09-24` | **`2.0.0` / `2026-10-02`**，镜像 URL 全部切到 `v2.0.0` |
| `README.md:5-6 / :65` | 当前版本 v1.3.0 + V8 进行中；`git tag v1.3.0` | **当前版本 v2.0.0（V8）+ 上一版 v1.3.0（V7）**；`git tag v2.0.0` |

**故意未改**：`.github/workflows/release.yml:195` 的 `PUBLIC_APP_VERSION: ${{ github.ref_name }}`（tag 驱动，正确）；`web/package.json` 的 `1.0.0`（官网自身包版本，与 App 无关）；`HANDOFF_V7.md` / `FIX_CONTRACT_V8.0.md:5/226` / `HANDOFF_V8.md` 的 v1.3.0 历史记录（是证据链的一部分）。

**修掉的真实不一致**：`exporter_sspak.dart` 之前把 `appVersion` 硬编码成 `'1.0.0'`（一个比 App 版本旧一个大版本的错值），现在引用 `kAppVersion`，`.sspak` 包的版本信息只有一个来源。

## 3. 2.0.0 公告（`web/public/announcements.json`）

- `notes[]` 9 条，覆盖 D160 明文要求的三块：
  1. **V8 要点**：设计系统落地（令牌同源、明暗双主题「纸面 / 暗房」、眉题 + hairline 表格、衬线 Display、遵守系统减弱动效）；布光预演三栏重构（D152）；动作摆姿与识别重做（D153）；AI 成案与导出（D155）；资源库 / 设置 / 引导（S9）；官网重做（D157）；工程收敛（D158：≤600 行红线、5 个大文件分层拆开、死代码按引用计数清理、517 项测试 + 明暗双主题截图总表）。
  2. **数据兼容性说明**：数据库 schema 未变，v1.3.x 工作区可直接打开；`.sspak` 升 v2（旧包缺 `version` 字段时导入自动迁移并明示；更高版本明示拒绝并提示升级）；姿势 / 布光 / 资源包格式与内容包索引未变，CDN 增量下发通道兼容。
  3. **已知限制**：路径追踪首次编译 40–80s（已预热）、16 samples 噪声偏大建议 ≥128；极端姿态个别关节可能翻转（仅供参考）；资源库零售商层暂无数据、服装为可商用分类实拍；AI 成案需自配 Key，未配置时由本地规则引擎离线降级。
- `ops[]` 1 条：`v2.0.0 · V8 全面重做：设计系统落地 + 布光/摆姿/AI 成案与导出/资源库四大模块重做 + 官网重做`（`2026-10-02`）。
- `downloads.*.sha256` 保持占位「发布时由 CI 写入」（CI 在 release 阶段写入）。

## 4. 门禁与实证（全部实测）

| 项 | 结果 |
|---|---|
| `dart format lib test` | **0 changed**（247 files） |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!**（9.9s） |
| `flutter test --no-pub` | **517 passed + 43 skipped**，All tests passed |
| `node tool/check_file_size.mjs` | **PASS**（白名单 4 条：lighting_controller 760 / ai_panel 747 / libraries_page 808 / ai_client 779） |
| `web/ npm run build` | **5 page(s) built**，`web/dist` 重建完成 |
| `web/ node tool/shot_s10.mjs` | **30/30 张**，`brokenImgs` 全 0；announcements 通道读数已是 `2.0.0` 且镜像 URL 含 `v2.0.0` |

**体积基线**（沿用 S6 历史记录 `README.md:81`，本机未重新产出）：APK **412.0MB**、Windows release **437.6MB**、引擎包 **1.16MB**、pathtracer **220.4KB**。

## 5. 偏差与限制登记（本机真实受阻原因，不编造数字）

1. **Windows release 构建本机无法完成 —— `flutter_litert` 需联网下载原生库**。
   - 第一次失败：`Building with plugins requires symlink support. Please enable Developer Mode in your system settings.`（本机 Developer Mode 未开）。
   - 已用仓库自带的 `app/tool/setup_symlinks.ps1` 绕行（junction 不需要 Developer Mode），symlink 问题解决。
   - 第二次失败：CMake 报错 `flutter_litert: could not download https://github.com/hugocornellier/flutter_litert/releases/download/litert-desktop-gpu-v1.0.0/dxil.dll`（`flutter/ephemeral/.plugin_symlinks/flutter_litert/windows/CMakeLists.txt:77`）→ `Unable to generate build files`，exit 1。
   - **性质**：网络取不到 GitHub release 资产，与代码无关。CI / release runner 能正常下载。
2. **Android APK 本机无法构建**：`flutter doctor` 实测 ✓ Windows Version、✓ Visual Studio - develop Windows apps、✗ Android toolchain（无 Android SDK）；Flutter 3.35.7 / Dart 3.9.2。
3. **LAUNCH-OK 未在本机执行**：`app/tool/smoke_launch.ps1`（D160 点名）需要 release 产物；产物由 release.yml 产出后可在 CI 日志里取证。
4. **两者的产出路径**：打 tag `v2.0.0` → `release.yml`（`on: push: tags: ['v*.*.*']`，job `build` 矩阵 `windows@windows-latest` + `android@ubuntu-latest`，`fail-fast: false`）产出 Windows 安装包与 APK，并写入 `announcements.json` 的 `sha256`。
5. **本轮未做**：App 侧 4 个白名单文件（`lighting_controller` / `ai_panel` / `libraries_page` / `ai_client`）的进一步拆分 —— 不在 D158 强制拆分清单内，且 `lib/features/**` >600 行的文件数已从 10 降到 4。

## 6. 交付物清单

- `docs/qa/v8-s12-release.md`（本文件）
- 版本同步：`app/pubspec.yaml`、`app/lib/features/updater/updater.dart`、`app/lib/features/export/exporter.dart`、`app/lib/features/export/exporter_sspak.dart`、`web/src/pages/downloads.astro`、`web/src/pages/index.astro`、`web/public/announcements.json`、`README.md`
- 文档：`HANDOFF_V8.md`（§0 / §1 / §2 / §3 / §4）、`FIX_CONTRACT_V8.0.md` §7 勾 `[x] S12`
- 截图与索引（S11 已入库，S12 未重出）：`docs/screenshots/v8/` 共 178 张（App 侧 28 张总表 + 各阶段专项 + 官网 30 张）、`docs/qa/v8-s11-overview-table.md`、`docs/qa/v8-s11-screenshots.json`、`docs/qa/v8-s10-web-screenshots.json`
