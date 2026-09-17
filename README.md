# 正片工坊 ShootStudio

把摄影正片策划四步流程——**FILMGRAB 找画面参考 → Set.a.light 布光预演 → posemaniacs 动作摆姿 → 一键成案**——做成本地优先的免费开源工作台（Windows + Android）。

当前版本：**v1.0.4**（V4 摄影真实性升级：高面数 3D / 照片姿势库 / 产品图规范化）

- 交接与基线：见 [HANDOFF.md](HANDOFF.md)（环境、管线、工具速查、执行记录）
- V4 合同与偏差：见 [FIX_CONTRACT_V4.0.md](FIX_CONTRACT_V4.0.md)（D61–D77 / §4.4-1）
- 构建约束：见 [BUILD_CONTRACT.md](BUILD_CONTRACT.md)
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
git tag v1.0.4 && git push origin v1.0.4
```

流水线自动：analyze + test → Windows 安装包 / Android APK → SHA-256 → GitHub Release →
更新 `web/public/announcements.json`（版本 / 下载直链）→ 部署官网 Pages。
模板 / 姿势包 / 布光预设等内容更新不打 Tag，直接更新 CDN 上的 JSON，应用启动时增量拉取。

## 验收状态（S1–S6 + V4）

| 阶段 | 自校验 | 状态 |
| --- | --- | --- |
| S1 底座 | dart analyze 零告警；建库单测绿 | ✓ |
| S2 核心四模块 | 黄金流程走查（参考→布光→姿势→成案）测试全绿 | ✓ |
| S3 AI 与导出 | Mock API 全链路单测；三格式落盘校验（PNG 魔数 / PDF 头 / .sspak 往返） | ✓ |
| S4 版本与资源 | 快照回滚 + 模块级 diff 单测；设备/服装/道具数据完整性校验 | ✓ |
| S5 官网与更新 | Astro 构建 5 页；更新三态（有新/最新/断网）Mock 单测 | ✓ |
| S6 双端冒烟 | Windows exe 构建 + 启动冒烟；APK 构建（v1.0.4：**104.1MB** ≤150MB） | ✓ |
| V4 摄影真实性 | 3D 高面数（40k–60k 面断言）/ 照片姿势库（120 条 + 骨架 + 12 关节推导等价）/ 产品图覆盖率（相机 95.5%、镜头 92.9%） | ✓ |

测试总数：**156 项 + 1 skipped**（live provider 默认跳过），全绿。
门禁可重复执行：`dart format --output=none --set-exit-if-changed lib test` 与 `flutter analyze --fatal-infos`。
端上照片识别按合同 §4.4 降级为「内置骨架 + 可读提示」（原因与验证见 FIX_CONTRACT_V4.0.md §4.4-1）。

## 凭据与发布卫生

- 真实凭据只放在 `app/assets/config/image_sources.json`（已被 `.gitignore` 排除）；
  公开仓库请改用 `image_sources.example.json` 作为模板，用户在设置页填写。
- AI Key 同理：应用内 AES-256-GCM 加密存本地工作区，不写入源码与日志。
- 发布前自检：`git grep -nE "sk-|apiKey|readToken|Authorization: Bearer"`（应只命中文档占位符）。
