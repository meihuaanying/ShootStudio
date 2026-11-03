# V8.26 · v2.1.0 交付 — 完工报告

## 1. 结论

V8.26 交付四项能力：**统一拍摄项目（schema v3）**、**安卓拍摄现场搭档**、**双模式布光**、**现场曝光同步**。

本机门禁五项全绿，其中此前未纳入执行清单的**设计令牌门禁**在本轮首次跑通并修掉 4 处新增违规（详见 §3）。
APK 与 Windows 安装包不在本机构建，由 tag `v2.1.0` 触发的 `release.yml` 产出，结果见 §5。

## 2. 版本同步总账

| 位置 | 新值 |
| --- | --- |
| `app/pubspec.yaml` | **`version: 2.1.0+10`**（build number 单调递增） |
| `app/lib/features/updater/updater.dart` | **`const String kAppVersion = '2.1.0';`** |
| `web/src/pages/downloads.astro` | fallback **`'2.1.0'`**（8 个 DOM id 与 fetch script 未动） |
| `web/src/pages/index.astro` | fallback **`'2.1.0'`** |
| `web/public/announcements.json` | `version 2.1.0` / `publishedAt 2026-11-02` / 下载直链 v2.1.0 / `ops` 新增一条 |
| `web/package.json` | **`2.1.0`**（官网自身包版本，随发版对齐） |
| `README.md` | 当前版本 v2.1.0（V8.26）+ 上一版 v2.0.0；tag 命令改为 `v2.1.0` |
| `HANDOFF_V8.md` §0.1 | 标题与状态改为「随 v2.1.0 发布」，验证基线补提交号与 CI 产物口径 |

## 3. 设计令牌门禁修复

`node tool/check_tokens.mjs` 在本轮之前从未跑过，首次执行报 4 处违规，全部来自新增文件：

| 位置 | 原写法 | 改为 | 说明 |
| --- | --- | --- | --- |
| `field_exposure_brief.dart:108` | `appMono(..., size: AppFontSize.body)` | `AppType.body.size` | 等值 14pt，不再新增字号令牌引用 |
| `field_page.dart:142` | 同上 | 同上 | 同上 |
| `project_switcher.dart:97` | `size: AppFontSize.caption` | 省略（`appMono` 默认即 caption） | 等值 11pt |
| `project_switcher.dart:153` | `size: AppFontSize.h3` | `AppType.h3.size` | 等值 17px 图标 |
| `field_exposure_brief.dart:132` | `EdgeInsets.only(top: 4)` | `EdgeInsets.only(top: AppSpace.s1)` | 等值 4px |
| `lighting_exposure_panel.dart:73` | `EdgeInsets.all(10)` | `EdgeInsets.all(AppSpace.s3)` | 10 → 12px，从细阶回到八点刻度（该面板为新增，无 golden 基线） |

修复后细阶用量三档全降：`AppSpaceFine 72`（基线 73）、`AppFontSize 238`（基线 240）、`AppRadiusFine 6`（基线 9）。

## 4. 门禁结果（2026-11-02 本机）

| 门禁 | 命令 | 结果 |
| --- | --- | --- |
| 格式 | `dart format --output=none --set-exit-if-changed lib test` | 273 文件，**0 changed** |
| 文件行数 | `node tool/check_file_size.mjs` | 扫描 126 文件，**PASS**（最大 589 行，白名单 0 项） |
| 设计令牌 | `node tool/check_tokens.mjs --json=../docs/qa/v8-tokens.json` | 自造色 0 / 内置色板 0 / 字面量 0 / 裸间距 0，**PASS** |
| 静态分析 | `flutter analyze --no-pub --fatal-infos` | **No issues found**（112.4s） |
| 全量测试 | `flutter test --no-pub --reporter compact` | **594 passed + 34 skipped，exit 0**（1:43） |
| 官网构建 | `npm run build`（web/） | **5 页构建成功**（5.35s），首页 fallback 渲染 v2.1.0 |

## 5. CI 产物（2026-11-03 00:50 UTC 实测）

| 项 | 结果 |
| --- | --- |
| Release run | `41551855090` **success**（32m36s，00:18 → 00:50 UTC） |
| Windows 安装包 | `shoot-studio-v2.1.0-windows.zip` · 318,359,984 B（303.6 MiB）· SHA-256 `ce21e081e2a1b2ac2abf750f2f6928367d7618b7eb7d882f9d145af99636b280` |
| Android APK | `shoot-studio-v2.1.0-android.apk` · 450,018,722 B（429.2 MiB）· SHA-256 `2ab5a25000de8e72649a84819d3e80c175fc268645b63da9ceafc433ebccfa33` |
| GitHub Release | <https://github.com/meihuaanying/ShootStudio/releases/tag/v2.1.0>（非草稿、非预发布） |
| 官网 | Pages 部署 success；线上 `announcements.json` 版本 2.1.0，双端直链与 SHA-256 与 Release 资产逐位一致 |

## 6. 已知限制

- 校准曝光是照度修正后的摄影估算，需要照度计与试拍复核，不等同硬件测光或专用闪光测光。
- 安卓端定位为现场搭档，不提供完整 3D 布光编辑；复杂预演建议桌面或横屏。
- 全量测试中的 Drift 多实例警告与字体缺字（`¥` / `•`）提示为测试环境既有非致命信息。
- 本机未安装 Android SDK licenses 且无法访问 `maven.google.com`，双端安装包以 CI 产物为准。
