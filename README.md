# 正片工坊 ShootStudio

<!-- audit-note 2026-11-06 -->
本仓库采用 MIT 许可，见 [LICENSE](LICENSE)；`app/third_party/` 下的组件仍按各自的授权文件执行。

版本号是两套：`v2.x` 对外发布（当前 v2.1.0），`V8.x` 是内部迭代代号（当前 V8.26），别当成同一个序列。仓库里有约 1,949 个图片、字体等二进制文件，体积约 592 MB，没有启用 Git LFS，克隆会慢一些。

最后推送：2026-11-03。

把摄影正片策划四步流程——**FILMGRAB 找画面参考 → Set.a.light 布光预演 → posemaniacs 动作摆姿 → 一键成案**——做成本地优先的免费开源工作台（Windows + Android）。

当前版本：**v2.1.0**（V8.26：统一拍摄项目 / 安卓现场搭档 / 双模式布光 / 现场曝光同步）
上一版：**v2.0.0**（V8：设计系统落地 / 布光·摆姿·AI 成案与导出·资源库四大模块重做 / 官网重做 / 工程收敛）

- 当前合同：见 [FIX_CONTRACT_V8.0.md](FIX_CONTRACT_V8.0.md)（D145–D160 / R71–R82）
- 交接与基线：见 [HANDOFF_V7.md](HANDOFF_V7.md)（环境、管线、工具速查、执行记录）
- 构建约束：见 [BUILD_CONTRACT.md](BUILD_CONTRACT.md)
- 历史合同与交接（V1–V7 全部决策 D1–D144 / 规则 R1–R70）：见 [docs/archive/](docs/archive/)
- 产品需求：见 [docs/prd.html](docs/prd.html)
- 许可：MIT

## 快速开始

```powershell
cd app
flutter pub get
flutter run -d windows   # 或 -d android
flutter analyze && flutter test
```

## 目录

| 目录 | 内容 |
| --- | --- |
| app/ | Flutter 单代码库（Windows + Android） |
| app/assets/content/ | 内置内容包（模板/照片姿势库 poses3/设备与产品图/静帧/服装/道具/布光预设/城市/预算） |
| app/assets/engine/ | 内置 3D 布光/姿势引擎（three.js 单文件打包，离线可用，NOTICE 与许可见内） |
| app/assets/models/ | 人形 GLB（Quaternius 21 款 + MakeHuman 写实 1 款；细分经运行时 Loop，原模型保留轻量模式） |
| app/third_party/ | 工具链兼容加固的两个插件副本（见下方说明） |
| app/tool/ | 构建期管线（内容生成 / 数据抓取 / 骨架与关节推导 / QA 截图 / 引擎打包） |
| web/ | 官网（Astro + Tailwind + GSAP + Three.js，`npm run build` 输出静态站） |
| docs/ | 证据与文档（pose-qa3 照片姿势 QA、pose-qa 归档、screenshots、prd.html） |
| .github/workflows/ | CI（分析+测试+双端构建）与 Release（Tag 发版 + Pages + 公告 JSON） |

## 本地构建前置（Windows）

```powershell
# 1) 无管理员权限机器的插件链接预建（junction，无需 Developer Mode）
powershell -File tool/setup_symlinks.ps1    # 在 app/ 目录执行，然后 flutter pub get
#    每次改 pubspec 后重复：脚本 → pub get → 脚本

# 2) Windows 桌面构建依赖（junction / sqlite3.dll / nuget.exe 供 WebView2 SDK）
#    nuget.exe 需在 PATH（如 C:\dev\tools）：https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
powershell -File tool/setup_windows_build.ps1
```

Android 构建：安装 Android SDK（platform 36 + build-tools 35+）与 JDK 17，设置 `ANDROID_HOME` / `JAVA_HOME`（示例见 HANDOFF §1.3）。
`android/` 已内置阿里云 Maven 镜像与 compileSdk 全局对齐（适配 AGP 9）。

## third_party 加固说明（工具链兼容，不改变功能语义）

| 副本 | 改动 | 原因 |
| --- | --- | --- |
| flutter_secure_storage_windows | 移除 ATL 依赖，加入等价 `CA2W/CW2A` 兼容层 | VS2026 Build Tools 未安装 ATL 组件 |
| flutter_inappwebview_android | `proguard-android.txt` → `proguard-android-optimize.txt` | AGP 9 移除了旧默认混淆文件 |

两处均通过 `pubspec.yaml` 的 `dependency_overrides` 指向本地路径；上游修复后可移除覆盖。

## 发版

```bash
git tag v2.1.0 && git push origin v2.1.0
```

流水线自动：analyze + test → Windows 安装包 / Android APK → SHA-256 → GitHub Release →
更新 `web/public/announcements.json`（版本 / 下载直链）→ 部署官网 Pages。
模板 / 姿势包 / 布光预设等内容更新不打 Tag，直接更新 CDN 上的 JSON，应用启动时增量拉取。

## 验收状态（S1–S6 + V4/V7/V8.26）

| 阶段 | 自校验 | 状态 |
| --- | --- | --- |
| S1 底座 | dart analyze 零告警；建库单测绿 | ✓ |
| S2 核心四模块 | 黄金流程走查（参考→布光→姿势→成案）测试全绿 | ✓ |
| S3 AI 与导出 | Mock API 全链路单测；三格式落盘校验（PNG 魔数 / PDF 头 / .sspak 往返） | ✓ |
| S4 版本与资源 | 快照回滚 + 模块级 diff 单测；设备/服装/道具数据完整性校验 | ✓ |
| S5 官网与更新 | Astro 构建 5 页；更新三态（有新/最新/断网）Mock 单测 | ✓ |
| S6 双端冒烟 | Windows exe 构建 + 启动冒烟；APK 构建（v1.3.0：**412.0MB**，含 RTMW3D fp16 185MB + YOLOX-tiny 20MB 随包） | ✓ |
| V4 摄影真实性 | 3D 高面数（40k–60k 面断言）/ 照片姿势库（120 条 + 骨架 + 12 关节推导等价）/ 产品图覆盖率 | ✓ |
| V7 升级 | three.js r186 + VSM/路径追踪静帧 + 相机辅助；RTMW3D-x 端上识别（一致性 均值 2.8°/p90 6.81°）；资源库六类覆盖率 100% + 抽检 12/12 | ✓ |
| V8.26 项目化与现场 | schema v3 迁移 + 项目隔离；安卓现场搭档；双模式布光；五项门禁（format / 行数 / 令牌 / analyze / 594 测试）；tag `v2.1.0` CI success | ✓ |

当前工作区测试基线：**594 passed + 34 skipped**（2026-11-02 本机全量，live provider 默认跳过），全绿。
门禁可重复执行：`dart format --output=none --set-exit-if-changed lib test` 与 `flutter analyze --fatal-infos`。
端上照片识别：V7 起为 RTMW3D-x(fp16)+YOLOX-tiny 端上推理（模型随包，Apache-2.0），MediaPipe 自动回退；一致性报告见 `docs/qa/pose3d-consistency-report.json`。历史合同见 `docs/archive/`。

## v2.1.0 新增能力（V8.26，已发布）

当前工作区在 v2.0.0 之后增加了以下能力，尚未提交、打 Tag 或发布安装包：

- **统一拍摄项目**：策划案、布光场景、画板引用、项目姿势清单和现场状态按项目隔离；旧数据自动归入默认项目。SQLite schema 升至 **v3**，保留 v1 起的历史数据迁移。
- **安卓拍摄现场搭档**：窄屏底部导航、项目切换、离线策划查看、现场清单、备注和姿势大图；现场状态按“项目＋策划案”持久化。
- **双模式布光**：保留创意预演经验模型；新增基于实测入射照度的校准曝光、固定 ISO/快门计算、校准凭证持久化和改灯后的复校提醒。
- **现场曝光同步**：安卓/窄屏现场页读取策划关联的布光场景，显示校准参数、创意参考或明确的“待校准 / 需复校”状态。
- **工程收口**：真实运行平台判断 Android 布局；内容包测试补齐 SHA-256 安全合同；首页 Windows golden 随项目切换器更新。

验证口径：`flutter analyze --no-pub --fatal-infos` 零问题，全量 **594 passed + 34 skipped**，设计令牌与文件行数门禁 PASS。安装包由 tag `v2.1.0` 触发 CI 产出并已发布：Windows **303.6 MiB** / Android APK **429.2 MiB**（Release run `41551855090`，32m36s）。校准曝光仍是需要照度计与试拍复核的摄影估算，不是硬件测光或专用闪光测光。

## 凭据与发布卫生

- 真实凭据只放在 `app/assets/config/image_sources.json`（已被 `.gitignore` 排除）；
  公开仓库请改用 `image_sources.example.json` 作为模板，用户在设置页填写。
- AI Key 同理：应用内 AES-256-GCM 加密存本地工作区，不写入源码与日志。
- 发布前自检：`git grep -nE "sk-|apiKey|readToken|Authorization: Bearer"`（应只命中文档占位符）。
