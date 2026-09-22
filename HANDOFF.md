# 正片工坊 ShootStudio —— 交接文档（V6 完成，v1.2.0 基线）

> **V6 已完成（v1.2.0）**：请优先阅读 [`HANDOFF_V6.md`](HANDOFF_V6.md) 与 [`FIX_CONTRACT_V6.0.md`](FIX_CONTRACT_V6.0.md)（搜索重做 + 3D 稳定/建模 + 端上识别 + 资源库图）。
> 更新：2026-09-22（V6 F 阶段交付完成；v1.2.0 已发布，官网 Pages 待开启后部署） ｜ 版本基线：`1.2.0+7`
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter 应用在 `app/`，官网在 `web/`，证据与文档在 `docs/`）
> 约束文件（必读，优先级从新到旧）：`FIX_CONTRACT_V6.0.md` → `FIX_CONTRACT_V5.0.md` → `FIX_CONTRACT_V4.0.md` → `FIX_CONTRACT_V3.0.md` → `FIX_CONTRACT_V2.0.md` → `FIX_CONTRACT_V1.0.1.md` → `BUILD_CONTRACT.md`

---

## 1. 环境配置（本机实测可用）

### 1.1 Flutter / Dart
- Flutter SDK：`C:\dev\flutter`；统一用绝对路径调用（避免 PATH 问题）：
  ```bash
  "C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" "C:/dev/flutter/bin/cache/flutter_tools.snapshot" <子命令>
  ```
- `pub get` 报 **symlink 错误**（无开发者模式）时：先跑 `powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_symlinks.ps1`，再 `pub get`，再跑一次脚本（每次改 pubspec 后重复）。
- 国内镜像（可选）：`PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。

### 1.2 Windows 构建
- 前置：`powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_windows_build.ps1`
  - 内容：junction 软链、`sqlite3.dll` 放入 Flutter bin / WindowsApps、`nuget.exe`（`C:\dev\tools`）供 flutter_inappwebview 拉 WebView2 SDK。
- 构建：`flutter build windows --release`（PATH 需含 `C:/dev/tools`）。
- 冒烟：`powershell -NoProfile -ExecutionPolicy Bypass -File tool/smoke_launch.ps1`（启动 8 秒验活，输出 `LAUNCH-OK`）。
- **WebView2 本地资源开关**（否则 3D 引擎永远"未就绪"）：`windows/runner/main.cpp` 早期设置
  `_wputenv_s(L"WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS", L"--allow-file-access-from-files")`；
  同文件还有单实例互斥体；**该文件注释只能 ASCII**（MSVC `/WX` + C4819）。
- `windows/CMakeLists.txt` 含 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`。

### 1.3 Android 构建
```bash
export ANDROID_HOME=C:/dev/android-sdk
export JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot"
flutter build apk --release
```
- `compileSdk` 全局对齐 36（`android/build.gradle.kts` 覆盖）；`kotlin.incremental=false`；阿里云 Maven 镜像已配。
- `third_party/` 覆盖：`flutter_secure_storage_windows`（ATL 兼容层）、`flutter_inappwebview_android`（proguard-android-optimize）。

### 1.4 Node / Python
- Node 24；esbuild 位于 `app/tool/engine_build/node_modules`。
- 引擎打包（改过 `assets/engine/js/**` 后**必须**重跑）：
  ```bash
  cd app && node tool/engine_build/bundle.mjs
  ```
  当前 `engine.bundle.js` ≈ **945 KB**（预算 ≤2.2MB）。
- Python 3.12（MS Store），pip 24；已装：`pillow numpy requests mediapipe`（如缺失 `pip install`）。
- Blender 便携版已用于写实管线（路径见 `docs/screenshots/realistic-build-report.json` 与 `tool/gen_realistic_character.py`）。

### 1.5 网络与 DoH（关键；V5 已改为应用内统一通道，详见 HANDOFF_V5 §2.1）
- Pexels API/CDN：稳定可达（Key 在 `app/assets/config/image_sources.json`，**勿打印**）。
- Openverse API：**V5 实测不可用**（IP/SNI 级封锁，DoH 正确 IP 也快速失败）→ UI 标「实验性」排最后。
- **Wikimedia/TMDB API 被 DNS 污染**：应用内由 `lib/services/net_router.dart`（DoH 隧道，主端点 `doh.pub`）自动处理；脚本侧可用 `app/tool/doh.py`（DoH JSON + monkeypatch `socket.getaddrinfo` + 缓存 + 直连回退）。
- TMDB：API 经应用内隧道可达（内置 Key）；图片 CDN `image.tmdb.org` 直连可用。
- 凭据：`app/assets/config/image_sources.json`（Pexels Key、TMDB v3/v4；**已 gitignore**），模板 `image_sources.example.json`；设置页可清空/替换并配代理 `proxy_url`。

### 1.6 Headless 视觉验证
- Edge 路径：`C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe`；打开本地 `file://` 页面必须加 `--allow-file-access-from-files`。
- 现成脚本：`tool/pose_qa.mjs`（render/fix/golden/engine/report，CDP 截图）、`tool/qa_3d_lighting.mjs`（3D 角色截图 + 三角面探针）。
- 姿势 QA 产物：`docs/pose-qa/`（旧 256 姿势，304 张）；`docs/pose-qa3/`（V4 新姿势，compare/overlay）。

---

## 2. 已完成里程碑

### 2.1 V1–V3（已发布 1.0.3）
- 灰屏根因修复、全局错误兜底与日志、引擎懒加载、window_manager。
- AI 主链路：两段式生成（推理流→结构化 JSON）、原生 `json_schema(strict)`/Anthropic tool_use、PlanScorer（<90 重试一次）、全案阅读模式、对话式修订 + 模块级 diff、15 家提供方预置（OpenCode Go/DeepSeek/智谱/Kimi/通义/自定义等）、自动拉模型 + 质量优选 + 失败自动换商、Key AES-256-GCM 加密。
- 策划自动物化布光场景；分镜模块（8–12 镜，导出含分镜）。
- 布光：人体 v2、灯头朝向、虚拟测光表（EV/曝光/光比）、RectAreaLight LTC。
- 画面参考：PD 静帧库（10 部影片 56 帧）+ TMDB 剧照/动漫面板 + Pexels 智能搜图（中文→英文关键词）+ 我的素材包（文件夹监看）+ 剪贴板粘贴（pasteboard）+ 桌面拖拽（desktop_drop）。
- 资源库：设备 493 条（规格/拼音搜索、自定义、动效）、服装 9 类目实拍、许可页。
- 官网：Astro 首屏（SVG 光圈+胶片）、鼠标视差 + 滚动加速胶片、移动端溢出修复、公告 v1.0.3。
- 测试基线：**133 passed + 1 skipped**（live provider 测试默认跳过）。

### 2.2 V4 阶段成果（本轮）

**Q1 3D 高面数 + PBR（已完成）**
- `app/assets/engine/js/subdivision.js` + `vendor/three-subdivide/`：**保留蒙皮的 Loop 细分**（自研凸组合权重、Top-4 归一化、边界保持、WeakMap 缓存、自适应补细分）。
- `tool/subdivide_characters.mjs`：细分计划（目标 40k–60k，level2 80k–120k，硬上限 120k）。
- 21 个角色三角面 40,000–49,576（`manifest.triCount` 21/21 一致）；`setSubdivision(0/1/2)`（0=原模型 6,206 面轻量模式）。
- 材质预设 `setMaterialPreset('standard'|'realistic'|'light')`（皮肤 Fresnel 次表面近似、布料法线噪声、金属分类、PMREM 环境反射）；`setEnvIntensity`。
- 蒙皮保真探针 `qaSkinningProbe()`（level1 形变量与 level0 同量级）。
- 证据：`docs/screenshots/3d-fidelity-*.png`、`docs/screenshots/3d-fidelity-report.json`；测试 `test/features/q1_3d_fidelity_test.dart`（5/5）。

**Q1.5 写实模式（已完成，最高标准路线）**
- 管线：MakeHuman 官方 **CC0 系统资产包**（280,737,770 B，经 DoH + Range 分块并行下载）→ **MPFB2 + Blender 4.5.13 无头导出** → `assets/models/characters/realistic/mh-men-01.glb`。
- 产物：**84,550 三角面**、53 骨、9 网格全部蒙皮、5.28 MB、**12/12 关节映射命中**。
- API：`setCharacter('realistic-man-01')`、`listRealisticCharacters()`、`getSubjectStatus().boneMappingStats`。
- 证据：`docs/screenshots/realistic-view0.png / realistic-view1.png / realistic-posed.png`；`docs/screenshots/realistic-build-report.json`；测试 `test/features/q1b_realistic_test.dart`（4/4）。
- 已知修复：资产先于骨架加载、材质 BLEND 白名单、躯干链 remap 单位矫正（详见报告 JSON）。

**Q3 产品图（已完成）**
- 相机覆盖 **106/111（95.5%）**、镜头 **183/197（92.9%）**（product+series；无"氛围图冒充"）。
- `tool/gen_product_photos.py`（DoH + Wikimedia/Openverse/Wikipedia 兜底、严格型号 token 匹配、断点续跑）+ `tool/normalize_product_photos.py`（白底/Otsu 主体/纯白 4:3/1100px/q84/去 EXIF/灰世界白平衡）。
- `assets/content/gear/photo2/`：内置文件已按预算筛到 135 个（非内置 158 个移到 `tool/gear_photo_pool/` 不入包）；`gear_photos2.json` 含 byModel/byKind/stats/builtinTop100/runtimeUrl（**87.7% 为 Openverse 代理，国内可达**）。
- 应用：`lib/services/gear_photo_sync.dart`（运行时同步）、`gear_browser.dart`（显示链 photo2→用户目录→缓存→插画 + 来源标注 + 同步按钮）。
- 缺口：camera 5 条 / lens 14 条无开放许可图；内置 Top100 中 9 条为 series（清单在 `gear_photos2.json.stats`）。

**Q2 照片姿势库（数据管线 + 应用接入，已完成）**
- 数据：`assets/content/poses3/poses3.json`（**120 条**，10 类目 × 12；除照片/骨架/12 关节外，新增 `partialBody`（35 条半身/特写标注）、`bodySpan`、`overlay`/`overlayRel`）；`photos/`（jpg + `*.skeleton.json` + `*.overlay.png` 共 360 文件）。数据已由骨架重建并重跑接地校准（`tool/pose_qa.mjs photo`）。
- QA 证据：`docs/pose-qa3/`（`compare-*.png` 120、`overlay-*.png` 120、`qa_photo_state.json`（含全量 bounds + 校准累积）、`QA_REPORT.md`）。
- 应用接入：`ContentPacks.poses()` 读 poses3（`posesLegacy()` 保留归档能力）；`PoseEntry` 扩展照片/骨架/置信度/referenceOnly/partialBody/署名；姿势页改版为**照片为主**（网格骨架缩略图 → 详情大图/骨架/镜头机位要领/出处）；「导入到布光预演」；**移除页面内 3D 查看器**；布光页右栏新增「关节微调」（bridge.setJoint 实时）+「画质」（细分/材质/环境反射，持久化）；导出 R25 双模式（照片默认带署名 / 骨架示意）。
- 端上识别（D67）：**按合同 §4.4 降级**（`pose_detection`→`opencv_dart` 构建期编译全量 OpenCV，体积突破 R22）；入口给出可读提示；`pose_landmark_math.dart`（Dart 端推导）保留并由 q2 等价性测试守护。
- 测试：`q2_pose_photos_test.dart` 8/8（含 world3d→12 关节与 Python 管线逐条等价断言）。

**B/C 引擎桥接与发布（已完成）**
- `engine_bridge.dart` 新增 `setSubdivision/setMaterialPreset/setEnvIntensity`；布光页画质面板持久化到工作区设置；人物选择器显示写实角色（`realistic:true`）、面数与「写实」标签。
- 版本 `1.0.4+5`；`kAppVersion=1.0.4`；`web/public/announcements.json` + `web/dist` 已重建；合同日志（含偏差）已追加。
- 验证：**全量测试 156 passed + 1 skipped**；Windows 构建 + 冒烟 `LAUNCH-OK`；**APK 104.1MB（≤150MB）**。

---

## 3. 关键管线代码速查

| 脚本 | 用途 | 命令（工作目录 `app/`） | 产物 |
|---|---|---|---|
| `tool/gen_content*.dart` | 基础内容包 | `dart run tool/gen_content.dart` 等 | `assets/content/**` |
| `tool/gen_poses_v2.dart` | 旧 256 姿势（V4 后被替换） | — | `assets/content/poses/poses.json` |
| `tool/gen_gear_v2.dart` | 设备库 493 条 + 插画 | `dart run tool/gen_gear_v2.dart --offline` | `gear.json` / `gear/img/*` |
| `tool/gen_characters.dart` | Quaternius 21 角色 + 发型 | `dart run tool/gen_characters.dart` | `assets/models/characters/**` |
| `tool/gen_icons.dart` | 应用图标 | `dart run tool/gen_icons.dart` | `assets/icon/*`、`windows/runner/resources/app_icon.ico`、mipmap |
| `tool/gen_pd_stills.dart` | PD 电影静帧（≥10 部 56 帧） | `dart run tool/gen_pd_stills.dart` | `assets/content/stills/**` |
| `tool/gen_clothing_photos.dart` | 服装 9 类目实拍 | `dart run tool/gen_clothing_photos.dart` | `assets/content/clothing/photo/**` |
| `tool/subdivide_characters.mjs` | 细分计划与校验 | `node tool/subdivide_characters.mjs` | `manifest.triCount` |
| `tool/qa_3d_lighting.mjs` | 3D 角色截图/面数探针 | `node tool/qa_3d_lighting.mjs --chars qs-men-casual --views 0,1 --label x%v.png` | `docs/screenshots/**` |
| `tool/gen_realistic_character.py` | 写实角色（MPFB2+Blender） | 见 `realistic-build-report.json` 中完整命令 | `assets/models/characters/realistic/*.glb` |
| `tool/doh.py` | DoH 解析/补丁/分块下载 | `python tool/doh.py get <url>` | 供其它脚本 import |
| `tool/gen_product_photos.py` | 产品图抓取（DoH） | `python tool/gen_product_photos.py` | `gear/photo2/**`、`gear_photos2.json` |
| `tool/normalize_product_photos.py` | 产品图规范化 | `python tool/normalize_product_photos.py` | 同上 |
| `tool/gen_pose_photos.py` | 姿势照片（Pexels/DoH） | `python tool/gen_pose_photos.py` | `poses3/photos/**` |
| `tool/extract_pose_skeletons.py` | MediaPipe 骨架 + 拼接 | `python tool/extract_pose_skeletons.py` | `*.skeleton.json`、`overlay` |
| `tool/skeleton_to_joints.py` | 3D 关键点→12 关节（raw） | `python tool/skeleton_to_joints.py build` | `poses3.json` |
| `tool/annotate_pose_visibility.py` | 半身/特写标注（partialBody） | `python tool/annotate_pose_visibility.py` | `poses3.json` 字段 |
| `tool/gen_pose_qa3_report.py` | QA 报告 | `python tool/gen_pose_qa3_report.py` | `docs/pose-qa3/QA_REPORT.md` |
| `tool/pose_qa.mjs` | 姿势 QA 截图/接地校准/报告 | `node tool/pose_qa.mjs photo`（校准并重渲染）/ `render`（单张/证据图） | `docs/pose-qa3/**`、`qa_photo_state.json` |
| `tool/prune_gear_photo2.py` | 包体清理（非内置产品图出包） | `python tool/prune_gear_photo2.py` | `tool/gear_photo_pool/` |

**poses3 重建链（顺序不可省，接地校准在 QA 步骤）**：
```bash
python tool/extract_pose_skeletons.py     # 照片→骨架（已抓图时）
python tool/skeleton_to_joints.py build   # 骨架→12 关节（rootY 为原始推导值）
node tool/pose_qa.mjs photo               # 渲染→接地校准（写回 rootY）→重渲染→拼接对比图
python tool/annotate_pose_visibility.py   # 标注 partialBody/bodySpan（不覆盖 rootY）
python tool/gen_pose_qa3_report.py        # 汇总 QA_REPORT.md
```
| `tool/engine_build/bundle.mjs` | 引擎打包（必跑） | `node tool/engine_build/bundle.mjs` | `assets/engine/js/engine.bundle.js` |
| `tool/setup_symlinks.ps1` / `setup_windows_build.ps1` / `smoke_launch.ps1` | 环境与冒烟 | 见 §1 | — |
| `tool/verify_hero_shot.dart` | 官网首屏校验 | `dart run tool/verify_hero_shot.dart ../docs/screenshots/web-hero.png` | `HERO-OK` |

---

## 4. 未完成待办（V4 已收尾；以下为可选后续）

### A. Q2 收尾 —— ✅ 已完成
照片姿势库已接入（内容层 + 姿势页照片改造 + 导入布光 + 关节微调 + 测试更新 + QA_REPORT）；端上识别按合同 §4.4 降级并登记偏差（FIX_CONTRACT_V4.0.md §5）。

### B. 引擎桥接与 UI —— ✅ 已完成
1. `engine_bridge.dart`：`setSubdivision(int)`、`setMaterialPreset(String)`、`setEnvIntensity(double)` 已接入。
2. 布光页「画质」区已落地（细分/材质/环境反射 + 工作区设置持久化）。
3. 人物选择器已显示写实角色与面数（`realistic:true` → 「写实」标签）。
4. 长图/PDF 姿势模块支持「照片 / 骨架示意」（R25，默认照片带署名）。

### C. 发布收尾 —— ✅ 已完成
1. 版本 `1.0.4+5`；公告 `web/public/announcements.json` v1.0.4；`web/dist` 重建。
2. 全量测试 156 passed + 1 skipped；`flutter analyze` 0 问题。
3. 双端构建：Windows（`LAUNCH-OK`）；Android APK **104.1MB**（R22 ≤150MB）。
4. 合同日志已追加（含端上识别偏差 §4.4-1）。

### D. 清理 —— 逐步完成
1. `assets/content/gear/photo2/` 已只保留内置 96 个（7MB；非内置 197 个在 `tool/gear_photo_pool/`，运行时素材同步）。
2. 残留脚本 `patch_g3.py` / `patch_g3d.py` / `fix_lints.py` 已删除。
3. 旧姿势数据 `assets/content/poses/poses.json`（256 条）归档保留（`ContentPacks.posesLegacy()` 可加载；应用默认读 poses3）。
4. `docs/pose-qa3/qa_photo_state.json` 为 QA 校准状态（含 bounds 全量与校准累积）；`overlay-*.png`/`compare-*.png` 为逐条证据。

**2026-09-16 严格复核清理（已执行）**
- 删除：根 `content/`（过期副本，唯一差异为旧版 attribution 存根，无任何代码/工作流引用）；`docs/assets/demos.js`（prd.html 无外链脚本）；临时 QA 截图 `docs/screenshots/{crop-strip,test-strip,engine-boot,web-mobile}.png`；`docs/pose-qa3/legacy-*.png`（旧轻量假人渲染，已被 compare 图取代）；`app/test/features/failures/`（golden 失败差异缓存）；`app/*.iml`（IDE 元数据）；`app/android/.kotlin/` 与 gradle kotlin 错误日志；`tool/gen_product_photos.dart`（脚本自述「已被 Python 版取代」）；`tool/px.dart`、`tool/crop_png.dart`（无引用）；`tool/probe_gear_photos.py`（一次性探针，规则已入 q3 测试）；`third_party/*/{example,test}`（上游示例/测试，构建不引用）。
- 保留：`tool/gear_photo_pool/`（12MB 非内置产品图暂存，用于后续内置扩充，不入包）；`tool/gen_poses_v2.dart`（归档姿势的生成器，保留溯源）。
- 代码复核修正：删除 `PosesController.onJointClicked/selectedJoint` 与 `PoseSkeletonPainter.showPoints`、`PosePhotoView.placeholderIcon` 等死代码/未用参数；抽取 `tripleOf` 到 `core/utils/json_utils.dart`（三处重复解析去重）；`_PoseInfoDialog` 改为展示照片与署名（不再引用已移除的 3D 查看器）；导出长图姿势照片绘制区与文字不再重叠；PDF 对无照片条目保留文字行；降级提示文案去除内部编号（面向用户可读）。
- 文档：README（根 + app/）全量同步（目录/前置/发版/验收/V4 状态）；HANDOFF 记录本清单。
- 构建缓存瘦身：`app` 4.6GB → 419MB（仅保留交付物 `flutter-apk/app-release.apk` 与 `windows/x64/runner/Release/`；Gradle/CMake 中间产物、符号/映射缓存、`app/docs/pose-qa3` 过期副本（80MB）、`.dart_tool/{flutter_build,hooks_runner,build}`、`windows/flutter/ephemeral` 已清；冒烟复验 LAUNCH-OK）。下次构建前按 README 先跑 `setup_symlinks.ps1` / `setup_windows_build.ps1`。
- 验证：全仓 `dart format --set-exit-if-changed` 通过（此前 35 文件未格式化）；`flutter analyze --fatal-infos` 0 问题；**156 passed + 1 skipped**；Windows 重建 + 冒烟 `LAUNCH-OK`；APK 重建 104.1MB（109,151,355 B）。

### 可选后续（V4 之外）
- 端上识别：若接受包体/构建成本，可重新评估引入 `pose_detection`（Dart 推导已就绪）。
- 半身/特写姿势（35 条 `partialBody`）可用全身实拍替换后重跑管线，减少「仅供参考」标注。
- 手部/神态类近景照片的单目 3D 姿态歧义（肘/腕深度）可考虑接入带深度的重建或人工校正。

---

## 5. 速查命令

```bash
# 测试（全量）
cd app && "C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" "C:/dev/flutter/bin/cache/flutter_tools.snapshot" test
# 分析
cd app && "C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" analyze
# 引擎重打包（改引擎 JS 后必跑）
cd app && node tool/engine_build/bundle.mjs
# Windows 构建 + 冒烟
cd app && powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_windows_build.ps1
cd app && "C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" "C:/dev/flutter/bin/cache/flutter_tools.snapshot" build windows --release
cd app && powershell -NoProfile -ExecutionPolicy Bypass -File tool/smoke_launch.ps1
# Android
cd app && export ANDROID_HOME=C:/dev/android-sdk JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot" && flutter build apk --release
# 官网
cd web && npm run build
# 抓取脚本（示例）
cd app && python tool/gen_product_photos.py        # 产品图（DoH）
cd app && python tool/extract_pose_skeletons.py    # 姿势骨架
```

---

## 6. 坑与注意事项（重复踩过的）

1. **本 shell 的 heredoc 会吞反斜杠/长内容**：写文件用 `write` 工具或"写 .py 文件再执行"，别用大 heredoc。
2. PowerShell 5.1 读无 BOM UTF-8 会乱码：`.ps1` 只写 ASCII。
3. MSVC `/WX` + C4819：Windows C++ 源文件注释只允许 ASCII。
4. `flutter test` 里 drift 必须 `NativeDatabase.memory()`（`FLUTTER_TEST` 守卫）；`path_provider` 用 `test/support/test_env.dart` 方法通道 mock；异步等待用 `settleUntil`（`tester.runAsync`）。
5. 控制器防抖（快照 3s）与 SnackBar 计时器会导致 "pending timer"：用例结尾 `pump` 走完（f4 测试里有 `settleTimers` 可复用）。
6. ListTile 放在有背景的 `DecoratedBox`（SsCard）里会触发 Flutter 断言：用 `Material(type: transparency)` 包裹。
7. golden 变更要 `--update-goldens` 并肉眼复核，不要盲更。
8. 引擎 `file://` XHR 依赖 `--allow-file-access-from-files`（Windows runner 已设；headless Edge 需命令行加）。
9. 每改 `pubspec` → symlink 脚本 → `pub get` → symlink 脚本。
10. 代理/DoH：应用内统一走 `NetRouter`（用户代理 > DoH 隧道 > 直连；TMDB/Wikimedia 等被污染域名走隧道）；Pexels 直连即可；Openverse 实测不可用（实验性）。

---

## 7. 新对话开场建议

> `ShootStudio` 的 V4 已完成并发布 v1.0.4（先读 `FIX_CONTRACT_V4.0.md` 与本 `HANDOFF.md`，尤其是 §5 变更日志与 §4.4-1 端上识别偏差）。
> 如继续迭代：优先处理「可选后续」（端上识别重新评估 / 替换 35 条半身姿势照片 / 近景手部神态的单目 3D 歧义），或按新合同开展 V5。
> 基线数据：`assets/content/poses3/poses3.json`（120 条）、`app/assets/content/gear/gear_photos2.json`（内置 96 + 运行时 197）、`assets/models/characters/realistic/mh-men-01.glb`（84,550 面）。
