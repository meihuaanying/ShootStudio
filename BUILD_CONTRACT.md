# BUILD_CONTRACT —— 正片工坊（ShootStudio）一口气建完 · 强力约束文件

> 本文件是本项目构建期的最高约束。执行期间不得以任何理由缩水、降级、跳过其中条款。
> 如遇冲突，以本文件为准；如需变更，必须显式记录在文末「变更日志」并说明理由。
> 锁定时间：2026-09-10 ｜ 决策方式：grill-me 逐轮拷问，用户逐条确认。

## 0. 执行纪律（不可违反）

1. **中途不停**：按 §6 阶段顺序连续执行，每阶段结束仅用一句话向用户汇报，不提问、不等待确认。
2. **不许带病推进**：每阶段自校验（§7 验收门槛）失败必须原地修复后重验，禁止绕过（禁用 --no-verify、禁止注释掉失败测试）。
3. **不许缩水**：§2 决策清单中的每一项都是承诺。实现不了时记录阻塞原因并给出替代实现，替代实现必须满足同一用户价值。
4. **中文优先**：UI 文案、输入框、AI 提示词、注释、文档全部中文友好；所有输入框必须支持中文输入并跑通端到端结果。
5. **本地优先**：断网时除 AI 云端生成/更新检查外全部功能可用。
6. **安全底线**：API Key 绝不落明文、绝不进日志、绝不进 git；图片来源保留版权标注。

## 1. 产品定位（一句话）

把摄影正片策划的四步流程——**FILMGRAB 找画面参考 → Set.a.light 式布光预演 → posemaniacs 式动作摆姿 → 一键汇成策划案**——做成一个本地优先的免费开源桌面/移动工作台（Windows + Android），AI 大模型辅助成案。

## 2. 锁定决策清单（D1–D24，全部不可妥协）

### 平台与架构
- **D1** Flutter 单代码库，产出 Windows 安装包 + Android APK。
- **D2** 本地优先存储：SQLite（结构化数据）+ 工作区目录（图片/导出件），可选端到端加密云同步（v1 后）。
- **D3** GitHub 托管代码；GitHub Actions 自动打包双端产物并发布 Release；官网部署 GitHub Pages + 国内 CDN 镜像；应用内更新读取官网公告 JSON（版本更新走 Release、内容包更新走增量 JSON 包）。

### 视频流程四模块（核心中的核心）
- **D4 M1 画面参考库（FILMGRAB 转化）**：影片 → 静帧两层档案结构；按片名/导演/年份混合检索；点静帧提取五色色卡；保留出处标注；一键收入参考画板；内置浏览器面板访问 film-grab.com 一键截取。
- **D5 M2 布光预演室（Set.a.light 转化，双轨制）**：
  - 俯视灯位图：灯光/道具可拖拽，位置清单实时列出坐标/方位角/距离/功率/色温；
  - 实时 3D 预览：集成 direct-light（MIT，three.js/R3F）经 WebView 内嵌，场景 JSON 与 Flutter 双向桥接；俯视图 ↔ 3D 双向联动，页面开关可解耦；
  - 正面效果图选项保留，与俯视图一起作为策划补充展示，开关入设置页；
  - 有 API Key 时可一键 AI 照片级渲染（场景参数 → 多模态/图像模型）；
  - 布光单一键导出（灯位图 + 位置清单 + 效果预览图三件套）。
- **D6 M3 动作摆姿库（posemaniacs 转化，硬约束）**：**必须使用人体 3D 模型，禁止简笔画**；关节级姿势微调；分类检索（站姿/坐姿/蹲跪/动态/情绪）；今日姿势；收藏进姿势清单；**姿势可一键注入布光预演 3D 场景查看效果**。
- **D7 M5 策划编辑器**：积木式模块（主题/模特/场地/日照/参考样片/色卡/布光/姿势/服装/道具/妆造/分工/预算/自定义），拖拽排序，模板库起步 ≥8 套（Cos 正片/汉服/JK/婚纱/商拍/写真/lo裙/双人）。

### 模型设置（对齐 dsh-model-pro，见 github.com/wqy8593521/dsh-model-pro）
- **D8** 内置 13 个提供方预设，选中填 Key 即用：DeepSeek、OpenAI、阿里百炼、智谱 GLM、Moonshot Kimi、火山方舟、Anthropic Claude、Google Gemini、商汤 SenseNova、OpenCode Zen（https://opencode.ai/zen/v1）、Command Code（https://api.commandcode.ai/provider/v1）、基元律动 TokenRhythm（https://tokenrhythm.studio/v1）、自定义 OpenAI 兼容端点。
- **D9** 核心四件套：预设向导 + AES-256-GCM 本地加密存 Key（主密钥入系统钥匙串：Windows DPAPI / Android Keystore）+ 模型发现（GET /models）+ 真实连通性测试（显示延迟与回显）。
- **D10** 智能路由 + 观测台：多提供方聚合、失败自动切换、调用延迟/token 统计看板。
- **D11** 官方每月 30 次免费额度保留为备选通道（不配 Key 时用），默认引导自备 Key；无任何 Key 时本地模板规则引擎兜底，保证 100% 能产出基础策划案。

### 前端设计（对齐 deepseek.com/harness 水准）
- **D12** 官网 + App 全部升级：统一设计令牌（色彩/字体/间距/圆角/动效曲线），明暗双主题跟随系统。
- **D13** 官网完整叙事动效：GSAP 滚动叙事 + Three.js 元素 + Tailwind 基础件；App 端自研设计令牌组件库，拒绝 Material 默认脸。
- **D14** 所有需要用户输入的框尽量提供预选/推荐卡片，并以开关形式收进设置页。

### 策划书反复修改
- **D15** 全状态可编辑（定稿只是标签）+ 编辑停顿 3 秒自动快照。
- **D16** 无限版本历史 + 手动里程碑命名（如「客户确认版」）。
- **D17** 模块级 diff 对比视图（新增/删除/内容变更高亮），一键回滚任意版本。
- **D18** 单人本地编辑，交接靠 .sspak 数据包与长图/PDF 导出。

### 资源库与设备清单
- **D19** 相机数据库 ≥80 机身 / ≥120 镜头（佳能/尼康/索尼/富士/松下/适马/腾龙，含卡口/画幅/像素/重量/参考价，内容包可增量更新）。
- **D20** 灯具真实参数库（神牛/爱图仕/南光/智云/永诺等，功率/色温范围/显色指数/卡口/尺寸），选好一键放入布光预演 3D 场景并带真实光型。
- **D21** 服装分类目录（正装/休闲/汉服/JK/Lolita/Cos/婚纱/民族等）+ 每类 AI 生成示意图（免版权）+ 用户补充卡片（自填图与购买链接）。
- **D22** 道具清单预置常用道具卡片（反光板/透明伞/花束/烟饼等），含采购与分工字段（谁带/谁买）。
- **D23** 自定义上传参考图：五大资源库 + 策划案模块均支持上传并关联到具体道具/场景；图片作为卡片封面、随策划案导出、并作为贴图占位出现在布光 3D 场景对应道具位置。

### 质量增强
- **D24** 构建期间主动搜索 GitHub 高星开源项目与论文，把成熟实现集成进对应功能（已锁定：direct-light 作为 3D 布光引擎；models.dev 目录作为提供方数据补充；koki-relight 类深度估计作为 AI 重打光候选）。

## 3. 技术栈

| 层 | 选型 | 理由 |
| --- | --- | --- |
| App | Flutter 3.x / Dart，Riverpod 状态管理，drift(SQLite)，flutter_secure_storage | D1 D2 D9 |
| 3D 引擎 | direct-light（MIT）打包进本地资源，flutter_inappwebview + JS Bridge | D5 D6 |
| AI 通道 | OpenAI 兼容协议适配器 + Anthropic 适配器 + 本地规则引擎 | D8–D11 |
| 官网 | Astro + Tailwind + GSAP + Three.js，部署 GitHub Pages + CDN 镜像 | D3 D12 D13 |
| CI | GitHub Actions：analyze → test → build windows/apk → Release → 公告 JSON | D3 |

## 4. 目录结构（本地建仓 ShootStudio/）

```
ShootStudio/
├── BUILD_CONTRACT.md        # 本文件
├── app/                     # Flutter 单代码库
│   ├── lib/{core,features/{refs,lighting,poses,planner,libraries,ai,settings,updater}}
│   ├── assets/engine/       # direct-light 打包产物
│   └── test/
├── web/                     # 官网（Astro）
├── content/                 # 内置内容包：模板/姿势/布光预设/设备库/服装示意图
├── .github/workflows/       # release.yml
└── README.md
```

## 5. 阶段计划（按序执行，每阶段自校验）

| 阶段 | 产出 | 自校验 |
| --- | --- | --- |
| S1 底座 | Flutter 工程 + 工作区建库 + 设计令牌（明暗双主题） | `dart analyze` 零告警；建库单测绿 |
| S2 核心四模块 | 参考库 / 布光（含 WebView 引擎桥接）/ 摆姿（人体模型关节调整）/ 编辑器 | 黄金流程走查脚本通过 |
| S3 AI 与导出 | 13 提供方预设、加密 Key、模型发现、连通测试、路由观测台；长图/PDF/.sspak 导出 | Mock API 全链路单测；三格式落盘校验 |
| S4 版本与资源 | 自动快照/无限历史/diff/回滚；设备库/服装目录/道具预设/自定义上传关联 | 快照回滚单测；数据完整性校验 |
| S5 官网与更新 | Astro 官网（叙事动效、双主题、下载中心）、Release 流水线、公告 JSON、应用内更新 | 流水线试跑；更新三态（有新/最新/断网）模拟 |
| S6 双端冒烟 | Windows 安装包 + APK 构建，黄金流程在 Windows 端实跑 | 构建产物存在且冒烟用例通过 |

## 6. 验收门槛（全部满足才算「建完」）

1. `dart analyze` 零告警；数据层/布光方位角计算/色卡提取/版本比较/快照 diff 单测全绿。
2. 黄金流程走查：找一帧参考 → 摆一套三点布光（俯视图拖动，3D 同步）→ 挑三个人体姿势注入场景 → 中文描述生成策划案 → 反复修改并回滚一版 → 导出长图，全链路通过。
3. 所有输入框中文输入端到端跑通（含 AI 中文提示词生成）。
4. Windows 与 Android 构建产物均生成且可起装。

## 7. 变更日志

| 日期 | 变更 | 理由 |
| --- | --- | --- |
| 2026-09-10 | 初版锁定（D1–D24） | grill-me 拷问确认 |
| 2026-09-11 | drift `references()` 改为 `customConstraint` 显式外键 | drift_dev 2.31 + Dart 3.13 组合下 `references()` 解析失效、外键未生成（实测级联删除不生效）；customConstraint 保证 SQL 层外键与级联真实生效 |
| 2026-09-11 | `app_theme.dart` 的 `Typography.material2024`→`material2021`、`CardTheme`→`CardThemeData` | 地基代码与当前 Flutter SDK（3.47）兼容性修复，analyze 归零所需 |
| 2026-09-11 | 新增 `cryptography` 依赖 | D9 AES-256-GCM 加密所需（`crypto` 包不支持 GCM） |
| 2026-09-11 | 打包 WebView 引擎所需 three.js 相关文件将本地 vendored 于 `assets/engine/js/`（three.module.min.js、OrbitControls、RectAreaLightUniformsLib、RoomEnvironment） | 附录 B4 离线要求；不依赖运行时 CDN |
| 2026-09-11 | 引擎改为 esbuild 预打包单文件（`tool/engine_build/bundle.mjs` → `engine.bundle.js`），源码保持 ES Module 结构 | WebView 对 `file://` 下 ES Module/importmap 兼容性差；单文件 classic script 全平台稳定 |
| 2026-09-11 | 关闭 `require_trailing_commas` lint（格式门禁由 `dart format` 承担） | Dart 3.13 tall-style formatter 与该校验规则冲突（formatter 负责逗号布局）；`dart analyze` 仍需零告警 |
| 2026-09-11 | 人像模型为自研关节假人（Capsule 形体 + 12 关节 + root 变换），未采用 direct-light 的第三方角色 GLB | direct-light 内置 GLB 为特定角色资产（版权风险）；D6「人体 3D 模型」由自研假人满足，direct-light 语义（灯具/控光件/白棚渲染理念）已署名改编 |
| 2026-09-11 | Windows 构建：`flutter_secure_storage_windows` 以 `third_party/` 本地加固版覆盖（移除 ATL 依赖，等价 CA2W/CW2A 兼容层）；`windows/CMakeLists.txt` 全局定义 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` | 本机 VS2026 Build Tools 不含 ATL 组件，且 MSVC 14.51 将实验性协程弃用视为错误；两处均为工具链兼容适配，不改变功能语义 |
| 2026-09-11 | Windows 构建依赖 `nuget.exe`（flutter_inappwebview_windows 构建期拉取 WebView2 SDK）；安装脚本与说明见 README | 插件官方要求；已提供 `tool/setup_windows_build.ps1` 一键准备 |
| 2026-09-11 | Android 构建：`flutter_inappwebview_android` 以 `third_party/` 本地加固版覆盖（`proguard-android.txt` → `proguard-android-optimize.txt`）；全局 `afterEvaluate` 将各插件 compileSdk 对齐 36；`kotlin.incremental=false`；Gradle 使用阿里云 Maven 镜像 | AGP 9 移除旧 ProGuard 配置；flutter_plugin_android_lifecycle 要求 API 36；Windows 下 Kotlin 增量缓存易被文件锁干扰；maven.google.com 在本地网络不可达 |
| 2026-09-11 | 官网按 §3 技术栈实现为 Astro + Tailwind + GSAP + Three.js（`web/`，5 页静态输出），部署路径 `web/dist` 接入 release.yml Pages | 与契约一致，无降级 |

---

# 执行者附录（写给执行构建的模型）

> 你将按本文件一口气建完项目。以下提示能帮你少踩坑。**先读完本附录再动手。**

## A. 环境与网络（中国网络必配）

```powershell
# Flutter/pub 国内镜像（每次开新终端都要设，或写入用户环境变量）
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
```

- Flutter SDK：从镜像站下载稳定版 zip 解压到工作区外（如 `C:\flutter` 或 `%USERPROFILE%\flutter`），把 `bin` 加 PATH；验证 `flutter --version`。
- Windows 桌面构建需要 Visual Studio 2022（含「使用 C++ 的桌面开发」工作负载）；Android 构建需要 Android SDK + 接受 licenses（`flutter doctor --android-licenses`）。缺什么按 `flutter doctor -v` 提示装。
- 网络受限时所有外网依赖（npm/pub/GitHub 克隆）一律换镜像；GitHub 克隆失败可试 `https://ghproxy.com/` 前缀或镜像站。

## B. 推荐执行顺序（不要跳步）

1. `flutter create app --platforms=windows,android --org com.shootstudio`（本仓库 app/ 下已有部分源码，直接覆盖合并）
2. `cd app && flutter pub get` → `dart run build_runner build --delete-conflicting-outputs`（生成 drift 的 database.g.dart）
3. 按 §5 的 S1→S6 顺序实现；每阶段末尾跑该阶段自校验。
4. **引擎**：three.js 必须本地化打包进 `app/assets/engine/`（从 npmmirror 下载 `three` 包的 `three.module.min.js`），禁止运行时从 CDN 拉（离线要求）。direct-light（MIT）可整体克隆后取其场景/假人/灯光逻辑适配为无 React 依赖的纯 three.js 单页（R3F 工程打进 WebView 太重），保留其 LICENSE 与 NOTICE 署名。
5. **WebView 桥接**：用 `flutter_inappwebview` 的 `addJavaScriptHandler` / `evaluateJavascript` 实现场景 JSON 双向同步；Windows 端用户机器需有 WebView2 Runtime（安装包检测并引导安装）。

## C. 常见坑（提前规避）

- drift 表结构变更后必须重跑 build_runner，否则运行时才报错。
- flutter_secure_storage 在 Windows 上依赖 DPAPI，无需额外配置；Android 需 `android:allowBackup="false"` 之外注意 minSdk ≥ 23。
- 密钥加解密：AES-256-GCM 用 `cryptography` 或自实现（crypto 包）；nonce 随机生成、密文 Base64 存库；主密钥走 flutter_secure_storage。
- WebView 里加载本地资产：`InAppLocalhostServer` 或 `loadFile(assetPath)`，不要用 `file://` 直读（Android 限制）。
- PDF 导出用 `pdf` 包矢量绘制灯位图；长图用 `image` 包离屏拼接，高度超 30000px 自动分页。
- 中文输入：不要对输入框加任何 ASCII-only 的 inputFormatter；AI 提示词模板全部中文。

## D. 已完成的地基（别重写，直接续建）

`app/` 下已存在：`pubspec.yaml`（依赖清单）、`analysis_options.yaml`、`lib/core/theme/`（明暗双主题设计令牌）、`lib/core/workspace/workspace.dart`、`lib/core/db/`（drift 全量表结构）、`assets/engine/engine.html`（引擎入口）。先 `build_runner` 生成 `database.g.dart` 再续写 features。

## E. 汇报与纪律

按 §5 阶段顺序执行；每阶段结束一句话汇报（阶段名 + 自校验结果）。全程不向用户提问——所有决策已在 §2 锁死；遇到 §2 未覆盖的细节，自行选择最符合用户价值的实现并在变更日志记录。

