# ShootStudio V5 交接文档（已完成）—— 搜索可用性 + 布光真实性 + 手部动作

> 更新：2026-09-17 ｜ 当前版本 `1.1.0+6`（已发布）｜ 约束文件：`FIX_CONTRACT_V5.0.md`
> 进度：**Q1 ✅ ｜ Q2 ✅ ｜ Q3 ✅ ｜ Q4 ✅**（含证据与双端构建，偏差见合同 §5 变更日志）
> 本机状态：**186 passed + 1 skipped**（全量）；`flutter analyze --fatal-infos` 0 问题；`dart format --set-exit-if-changed` 通过；Windows `LAUNCH-OK`；APK **105.7MB**
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter 在 `app/`，官网 `web/`，证据 `docs/`）

---

## 0. 30 秒速览：本轮收尾结果（全部完成）

1. **引擎包已重打**（`engine.bundle.js` ≈ 945KB / 预算 ≤2.2MB），含 HDRI 接线、接触阴影、手部/环境光/材质全部改动。
2. **Q3 已完成**：HDRI 加载（实测 `env=hdr`）+ `pubspec` env 目录 + attribution 登记 + 接触阴影（仅 realistic，`quality_contact_shadow`）+ 材质 QA 截图 + `q5_material_test`（9/9）。
3. **Q2 证据已补全**：手部矩阵 **60/60**（`docs/screenshots/hands/`）+ 环境光开/关 + R34 纯黑探针（avg 15.7/255）。
4. **Q4 已收尾**：全量门禁 → Windows/APK 双端构建（LAUNCH-OK / 105.7MB）→ v1.1.0（版本/公告/dist/合同日志/HANDOFF）。
5. 临时截图已清理（§4.3），仅保留正式矩阵与对比图。

---

## 1. 环境配置（本机实测可用）

### 1.1 Flutter / Dart
- Flutter SDK：`C:\dev\flutter`；统一绝对路径调用（避免 PATH 问题）：
  ```bash
  "C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" "C:/dev/flutter/bin/cache/flutter_tools.snapshot" <子命令>
  ```
- `pub get` 报 symlink 错误（无开发者模式）：`powershell -File tool/setup_symlinks.ps1` → `pub get` → 再跑一次脚本（**每次改 pubspec 后重复**）。
- 国内镜像（可选）：`PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。

### 1.2 Windows 构建
- 前置：`powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_windows_build.ps1`（junction / `sqlite3.dll` / `nuget.exe` 拉 WebView2 SDK；`C:\dev\tools` 需在 PATH）。
- 构建：`flutter build windows --release`；冒烟：`powershell -File tool/smoke_launch.ps1`（输出 `LAUNCH-OK`）。
- WebView2 本地访问开关在 `windows/runner/main.cpp`（`--allow-file-access-from-files`，注释仅 ASCII，MSVC `/WX`）。

### 1.3 Android 构建
```bash
export ANDROID_HOME=C:/dev/android-sdk
export JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot"
flutter build apk --release   # 上次 104.1MB（预算 ≤150MB）
```
- compileSdk 全局对齐 36；阿里云 Maven 镜像；`third_party/` 两个兼容加固副本（`flutter_secure_storage_windows`、`flutter_inappwebview_android`，`dependency_overrides` 指向）。

### 1.4 Node / Python / 引擎打包
- Node 24；esbuild 在 `app/tool/engine_build/node_modules`。
- **改过 `app/assets/engine/js/**` 必须重跑**：`cd app && node tool/engine_build/bundle.mjs`（esbuild minify，输出 `engine.bundle.js`，当前约 959KB / 预算 ≤2.2MB）。
- Python 3.12（MS Store）：已装 `pillow numpy requests mediapipe`。
- 引擎打包别名：`three` → `js/vendor/three.module.min.js`，`three/addons` → `js/jsm`（新增 addon 直接放 `js/jsm/**` 即可）。

### 1.5 网络与 DoH（V5 关键）
- **本机实测（2026-09-16）**：`api.pexels.com` 直连 200/0.6s；`api.openverse.org` 即便 DoH 正确 IP 也 0.23s 快速失败（SNI/IP 级封锁）；`api.themoviedb.org` 系统 DNS 被污染但**正确 IP 可达**；`image.tmdb.org` 直连可用；Wikimedia/archive.org 正确 IP 也不可达；**`doh.pub` 可用**，Cloudflare/Google DoH 不可用；`dl.polyhaven.org` / `cdn.jsdelivr.net` / `ambientcg.com` 可达。
- 应用内 **DoH 本地隧道**（V5 新增）：`lib/services/net_router.dart`，见 §2.1。
- Headless 视觉验证：Edge 路径 `C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe`（`--allow-file-access-from-files`）；QA 脚本见 §5。
- 凭据：`app/assets/config/image_sources.json`（Pexels/TMDB，gitignored；**勿打印**），模板 `image_sources.example.json`。

---

## 2. 已完成

### 2.1 Q1 搜索可用性（全部完成）

**网络通道（新文件 `lib/services/net_router.dart`，约 500 行）**
- 三态：用户代理 > DoH 隧道（仅被污染域名）> 直连；`HttpOverrides.global` 全局注入（Dio / `Image.network` / 一切 `dart:io` HttpClient 自动生效）。
- DoH 客户端：JSON API，端点顺序 `doh.pub` → AliDNS → Cloudflare → Google；TTL 缓存 + 并发去重。
- 本地 CONNECT 隧道：`ServerSocket`（仅 127.0.0.1 随机端口）+ 盲转发（端到端 TLS，不换证书）；单订阅转发（避免 Socket 二次 listen）。
- `NetRouter.I.dio({retries=2,...})` 带指数退避重试（429/5xx/超时/连接错误）；**测试环境默认关重试**（`debugRetriesInTests`，q5 测试显式打开）。
- 域名门控：`themoviedb.org`、`tmdb.org`、`openverse.org`、`wikimedia.org`、`wikipedia.org`、`archive.org`、`film-grab.com` 走隧道。
- 统一入口：`makeDio()`（`lib/services/net.dart`）已改为委托 NetRouter；启动时在 `core/providers.dart::_open()` 配置（`FLUTTER_TEST` 跳过）；设置页保存时重配。
- 设置页新增：网络通道三选（自动/强制直连/使用代理）+ 「通道测速」（Pexels/TMDB API/TMDB 图床 状态+耗时）。

**搜索服务（重写 `lib/services/image_sources.dart`）**
- 源顺序 Pexels（主）→ TMDB → Openverse（实验性，UI 明示）；`SourcePage{hits,hasMore}`、`SourceStatus{ok,count,elapsedMs,error,...}`、`SmartSearchResult`；跨源去重；`describeNetworkError()` 输出带域名与建议的可读错误。
- 词表扩至 **200+**（`kSceneKeywordMap`）；`translateSceneToKeywords` 未命中返回空串（R33 禁止原样发中文）；`hasAsciiQuery`/`needsAiTranslate`。
- AI 兜底：`lib/services/query_translator.dart`（用已配置默认 AI 提供方，6s 超时，缓存 `settings.query_translation_cache` LRU 200，未配置返回空串）。
- 搜索历史/收藏：`lib/services/search_prefs.dart`（`search_history` / `search_favorites`，JSON）。
- 内置 Key 默认启用（D82）：智能搜图/TMDB 弹窗缺 DB Key 时回退 `loadNetConfig()`。

**画面参考页（`lib/features/refs/refs_page.dart`）**
- 智能搜图弹窗重写：AI 翻译状态、每源状态 chips（点按单源重试、「重试失败源」）、分页「加载更多」（18/页）、历史/收藏行、下载走统一通道（超时+重试）、署名标注。
- PD 静帧库搜索：`kPdFilmAliases`（10 部影片中文别名/主创/题材）+ `pdFilmMatches()`（空格分词 AND，可搜 title/year/导演/别名/帧标题/作者）+ 加载失败提示（不再无限转圈）。
- TMDB 弹窗：统一通道（`makeDio`→NetRouter）+ 内置 Key 回退 + 可读错误 + **「改用本地 PD 静帧库」降级按钮**（D84）。

**证据与测试**
- Live 证据：`docs/qa/net-probe-20260916.txt`（Pexels 200/681ms；**TMDB 经隧道 200/3.5s**；Openverse 失败符合预期）。
- 测试：`test/services/q5_net_router_test.dart`（6 项：域名门控、代理优先级、DoH 解析缓存/回退、**真实 CONNECT 隧道字节透传**、重试退避）；`test/features/q5_search_test.dart`（7 项：PD 多字段、词表红线、历史/收藏、翻译器降级、错误可读）；`g6_assets_test.dart` 搜索组已按新 API 重写（4 项）。

### 2.2 Q2 环境光 + 手部动作（代码完成，证据待补）

**引擎（`app/assets/engine/js/**`，⚠️ 需重打包）**
- 环境光：`studio.js` 持有半球光引用 + `setAmbientEnabled`；**修复 PMREM 重复创建/未释放**（现只在 studio 创建一次）；`engine.js`：`ambientEnabled/environmentIntensity` + `applyAmbient()` + `window.ss.setAmbientEnabled/getAmbientEnabled`（关 = 半球光隐藏 + `scene.environmentIntensity=0`，含金属反射）。
- 手部：`character.js` 新增
  - `discoverHands()`：按骨架家族（MH `index_01_l…` / Quaternius `Index2.L…`）自发现手指链，**自标定屈伸轴与符号**（卷向手腕）与张开轴/符号（远离中指），无需人工标定；`handSupport` 上报各手支持与每指数。
  - `HAND_PRESETS`（12 单手，curls/spread/wrist）+ `HAND_DUAL_PRESETS`（抱拳/拱手/合十）；`handLocalQuat()` 集成进 `applyPose` 递归（手骨独立于 12 关节，R35）；腕部附加旋转（wrist delta）。
  - 公开 API：`setHandPose(side,preset)`（双手预设同时写两侧）、`setHandCurls(side,{curls,spread,wrist})`、`getHandState`、`getHandSupport`、`listHandPresets`、`resetHands`；`applyScene` 支持 `subject.hands`。
  - QA：`qaFocusHand(side,dist)` + qa.html 参数 `handL/handR/handcam/handdist/ambient/handdebug`。
- `features` 串已加 `setAmbientEnabled setHandPose … hand-bones`。

**Flutter**
- 桥接（`engine_bridge.dart`）：`setAmbientEnabled` / `setHandPose` / `setHandCurls` / `resetHands`。
- 数据模型：`HandPoseState` + `handsToJson/handsFromJson`（`services/content_packs.dart`）；`PoseEntry.handsL/handsR`；`LightingSceneData.hands/ambientEnabled` + `toEngineJson(hands:)`（`features/lighting/lighting_models.dart`）。
- 预设表镜像：`features/lighting/hand_presets.dart`（15 个，含双手组合的**手臂叠加** `arms`）。
- 控制器（`lighting_controller.dart`）：`setAmbientEnabled`（持久化 `quality_ambient_enabled`）、`setHandPreset/setHandCurl/setHandSpread/resetHands/applyHandsFromPose`、场景往返（保存/载入含 hands+ambient）、`injectPose(..., handL, handR)`。
- 自定义姿势（D88）：`PosesController.saveCustomPose(...)` 把 `_hands` 写入 `jointsJson` 保留键，`_loadCustomPoses` 解析还原；姿势页导入布光时携带 hands；布光页「关节微调」新增**「另存为姿势」**（含手部）。
- UI（`lighting_page.dart`）：右栏「画质」区新增**环境光开关**（关时反射滑杆置灰但记忆强度）；新增**「手部动作」面板**（左/右手切换、12 单手预设 + 3 双手组合 chips、5 指弯曲滑杆 + 张开度、恢复默认、轻量假人显示禁用提示）。
- 测试：`test/features/q5_hands_test.dart` **8/8**（预设表完整性、引擎 bundle 静态门禁、场景/姿势 JSON 往返、R35 手部不影响 12 关节、环境光持久化、双手组合手臂叠加、`_hands` 往返、旧数据兼容）。

**证据（已完成）**
- `tool/pose_qa.mjs hands --skip-existing --workers 1`（15 预设 × 左右 × 2 骨骼 = 60 张 → `docs/screenshots/hands/`）：**60/60**，failures=[]（`qa_state.json` hands.count=60；17 张 CDP 超时项已由单线程补全）。
- `tool/pose_qa.mjs hands-env`：`env-ambient-on.png` / `env-ambient-off.png` 对比 + `env-ambient-dark.png` 纯黑探针（关环境光+关灯：中心区域 avg=15.7/255）。
- 视觉抽查结论（已人工确认）：fist/peace/thumbsUp/wave 等手型方向正确、无穿模反关节；托腮/合十的手部形态正确但单臂不含抬臂（预设仅腕+指，手臂叠加归双手组合与姿势库）。

---

## 3. Q3 写实材质（已完成）

### 3.1 已完成部分
- **分类修复**（`materials.js::classifyMaterialName`）：`Human.body/lips/ears/fingernails/teeth/tongue/face → skin`；`hair|brow|eyelash|short01 → hair`；`eye|high-poly → eye`；金属/鞋保持。
- **R37 贴图保护**：`baseSnapshot` 记录 `normalMap/roughnessMap/metalnessMap/alphaMap`；`applyMaterialPreset` 每次**先恢复 authored 贴图**，仅在「无 authored normalMap 且 hasUV」时才注入布料噪声（不再清空贴图）。
- **皮肤 SSS（D89）**：运行时生成 128×128 **预积分皮肤 BRDF LUT**（`getSkinLutTexture()`，解析近似）+ **wrap diffuse**（替换 `float dotNL = saturate(...)`）+ 边缘散射注入；`customProgramCacheKey = 'ss-skin-sss-v2'`。
- **布料 sheen**：注入式 Fresnel 绒感（`attachClothSheen`，realistic 的 cloth 生效，强度 0.07）。
- **阴影调优**：`lights.js` 阴影 2048²、bias -0.0005、normalBias 0.025、radius 3。
- **HDRI 资产已就位（未接线）**：
  - `assets/engine/env/studio_small_03_1k.hdr`（Poly Haven CC0，1.69MB，实测下载 200）；
  - `assets/engine/js/jsm/loaders/RGBELoader.js`（three r169，jsdelivr 200）。

### 3.2 剩余工作（已全部完成，实作记录）
1. **引擎 HDRI 接线**（`engine.js`）：已按 `document.baseURI`（与 character.js 的 `assetBase()` 同源解析）加载 `env/studio_small_03_1k.hdr` → `PMREMGenerator.fromEquirectangular` → 替换 `scene.environment`（释放 studio 的 RoomEnvironment 贴图；失败回退原环境）；`send('environmentChanged',{source})`；新增 `getEnvironmentSource()`。QA 实测 6/6 张 `env:"hdr"`。
2. **`pubspec.yaml`**：已声明 `- assets/engine/env/`。
3. **attribution**：HDRI 条目已登记（CC0 / polyhaven.com / Poly Haven）。
4. **接触阴影**（D91）：`engine.js` 程序化径向渐变 `CanvasTexture` 贴地平面（y=0.004，`depthWrite:false`，随包围盒缩放，0.8s 节流更新），API `window.ss.setContactShadow/getContactShadow`；**按 R38 仅 realistic 生效**（standard/light 与 V4 一致）；Flutter 侧 `LightingState.contactShadow`（默认开）+ `quality_contact_shadow` 持久化 + bridge + 画质面板开关。
5. **重打引擎包** + QA：`material-{skin,cloth,metal}-{realistic,standard}.png`（皮肤为脸部近景验证 SSS/wrap）+ `material-contact-{on,off,standard}.png`（开/关像素 diff 4540 px）。
6. **`test/features/q5_material_test.dart`**（9/9 绿）：分类正则与顺序断言 + R37 贴图保护 + SSS/sheen 特征 + bundle 静态门禁 + HDRI 文件/pubspec/attribution + QA 证据文件齐备 + 接触阴影持久化/默认开/与环境光互不联动。

---

## 4. Q4 与证据（已完成）

### 4.1 证据清单（Q2/Q3 门禁，全部就位）
| 项 | 命令 | 结果 |
|---|---|---|
| 手部矩阵 60 张 | `cd app && node tool/pose_qa.mjs hands --skip-existing --workers 1 --timeout 120000` | `docs/screenshots/hands/` = **60**（15 预设×2 手×2 骨骼），failures=[]，`qa_state.json` hands.count=60 |
| 环境光对比 + 探针 | `node tool/pose_qa.mjs hands-env --char qs-men-casual` | `env-ambient-on/off.png` + `env-ambient-dark.png`（R34 探针 avg=15.7，仅背景可见） |
| 材质对比 | `node tool/pose_qa.mjs material [--targets skin,cloth,metal,contact]` | `material-{skin,cloth,metal}-{realistic,standard}.png`（6）+ `material-contact-{on,off,standard}.png`（3），所有探针 `env:"hdr"` |
| 视觉目检 | 逐张打开 | 手型方向正确、无穿模反关节；环境光关=仅灯具；皮肤 SSS/布料 sheen/金属 HDRI 反射可见；接触阴影开/关像素 diff=4540px |

### 4.2 Q4 发布清单（已完成）
1. 门禁：`dart format --set-exit-if-changed lib test` 通过；`flutter analyze --fatal-infos` 0 问题；`flutter test` = **186 passed + 1 skipped**。
2. Windows：`setup_windows_build.ps1` → `build windows --release` → `smoke_launch.ps1`（`LAUNCH-OK process alive (onboarding page)`）。
3. Android：`build apk --release` = **105.7MB**（≤150MB）。
4. `v1.1.0`：`pubspec.yaml` `version: 1.1.0+6`、`kAppVersion='1.1.0'`、`web/public/announcements.json`（v1.1.0 要点）+ `web/src/pages/{index,downloads,changelog}.astro` 版本占位同步 → `web/dist` 已重建。
5. `FIX_CONTRACT_V5.0.md` §5 变更日志已补 Q1–Q4 行 + 5 条偏差；`HANDOFF.md` 顶部已指向本文件（V5 已完成）。

### 4.3 清理（已完成）
- 已删除临时手部调试图：`hand-test-p001.png`、`handcheck-*.png`、`handzoom-*.png`（含 `-crop`）；保留 `hands/` 正式矩阵。
- 未出现仓库外 `docs/`（全程用 `--out docs/...`）。
- 临时对比图 `_tmp-contact-compare.png` 已删除。
- 可选：引擎包变更后 `app/build/` 中间产物可再瘦身（保留 `flutter-apk/` 与 `windows/x64/runner/Release/`）。

---

## 5. 关键文件与管线速查（V5 新增/修改）

| 文件/工具 | 说明 |
|---|---|
| `lib/services/net_router.dart` | **新**：DoH 隧道/代理/直连三态 + 全局注入 + 重试；测试钩子 `debugSetResolver` / `debugRetriesInTests` |
| `lib/services/image_sources.dart` | **重写**：Pexels/TMDB/Openverse 聚合（分页/状态/去重/可读错误） |
| `lib/services/query_translator.dart` | **新**：AI 检索词翻译 + 缓存（`query_translation_cache`） |
| `lib/services/search_prefs.dart` | **新**：搜索历史/收藏（`search_history`/`search_favorites`） |
| `lib/features/lighting/hand_presets.dart` | **新**：15 个手部预设（含双手组合手臂叠加） |
| `lib/features/lighting/{lighting_models,lighting_controller,lighting_page}.dart` | 场景 hands/ambient、手部/环境光状态与 UI、另存为姿势 |
| `lib/features/poses/{poses_controller,poses_page}.dart` | `_hands` 保留键往返、导入布光携带手部 |
| `lib/services/content_packs.dart` | `HandPoseState` / `handsToJson/FromJson` / `PoseEntry.handsL/R` |
| `lib/features/refs/refs_page.dart` | PD 别名搜索 + 智能搜图弹窗重写 + TMDB 降级按钮 |
| `lib/features/settings/settings_page.dart` | 网络通道 UI + 测速 + 保存重配 |
| `lib/core/providers.dart` | 启动配置 NetRouter（FLUTTER_TEST 跳过） |
| `assets/engine/js/{materials,lights,studio,engine,character,qa.html}` | 材质升级 / 阴影调优 / 环境光 / HDRI/接触阴影 / 手部系统 / QA 参数（preset/contact/focus/probe） |
| `assets/engine/env/studio_small_03_1k.hdr` | **已接线**（CC0；`getEnvironmentSource()` 实测 `hdr`） |
| `assets/engine/js/jsm/loaders/RGBELoader.js` | **已接线** |
| `tool/net_probe.dart` | **新**：网络通道实网探针（live 证据，输出到 `docs/qa/`） |
| `tool/pose_qa.mjs` | `hands`（`--skip-existing/--workers/--timeout`）/ `hands-env`（含纯黑探针）/ `material`（皮肤/布料/金属/接触阴影 + 探针）子命令 |
| 测试 | `q5_net_router_test`(6) / `q5_search_test`(7) / `q5_hands_test`(8) / `q5_material_test`(9) |

**日常工作流**：
```bash
cd app
node tool/engine_build/bundle.mjs                    # 改过引擎 JS 必跑
node tool/pose_qa.mjs hands --skip-existing --workers 1   # 手部 60 张门禁（增量补全）
node tool/pose_qa.mjs hands-env                      # 环境光对比 + 纯黑探针
node tool/pose_qa.mjs material --presets realistic,standard   # 材质/接触阴影对比
dart run tool/net_probe.dart                         # 网络 live 证据
"C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" "C:/dev/flutter/bin/cache/flutter_tools.snapshot" test
```

---

## 6. 坑与注意事项（V5 新增，重复踩过）

1. **引擎包是压缩产物**：flutter 测试里只能断言**字符串常量**（API 名/特性串/预设 id/`ss-skin-sss-v2`），局部变量名（`discoverHands`/`handLocalQuat`/`ambientEnabled`）会被 minify。
2. **`HttpOverrides.global`**：生产由 NetRouter 安装；**flutter test 环境跳过**（避免 pending timer 与真实网络）；`NetRouter.dio()` 在测试环境默认 `retries=0`，q5 网络测试用 `NetRouter.debugRetriesInTests = true` 打开。
3. **Socket 不可二次 listen**：隧道实现必须单订阅转发（已实现，勿改回 cancel+pipe）。
4. **手部 QA 渲染超时**：2 workers + realistic 模型易 `CDP 超时`；用 `--workers 1` 或分批重跑；失败项会打印在日志里。
5. **qa.html 相机顺序**：`handcam` 特写必须在 `setQaView()` **之后**调用（否则被覆盖）。
6. **`--out` 相对仓库根**：`pose_qa.mjs` 的 `repoRoot` 是 `app/..`，传 `--out ../docs/...` 会写到仓库外（用 `--out docs/...`）。
7. **HDRI/接触阴影已接线**：`assets/engine/env/` 已入 pubspec/attribution；HDRI 加载失败自动回退 RoomEnvironment（QA 以 `getEnvironmentSource()` 判定）；接触阴影**仅 realistic 生效**（R38，standard/light 与 V4 一致）。QA 特写（`qaFocusHand/qaFocusJoint`）会临时放宽 `OrbitControls.minDistance`，否则被 1.2m 钳制。
8. **写实模型体积**：`realistic-man-01`（84k 面 + 贴图）手部 QA 渲染慢，属预期。
9. **`_hands` 保留键**：只进 `jointsJson`，解析时必须 `remove` 后再入 12 关节（否则关节面板会多出一项）。
10. **pending timer 断言**：任何在 widget 测试里触发的网络/延时都必须可关（参考 `debugRetriesInTests`）。

---

## 7. 新对话开场建议

> `D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio` 的 **V5 已全部完成并发布 v1.1.0**（先读 `FIX_CONTRACT_V5.0.md` 与本 `HANDOFF_V5.md`）。
> 基线：全量 **186 passed + 1 skipped**、`analyze --fatal-infos` 0 问题、format 通过；引擎包 945KB（已重打）；手部截图 60/60；Windows LAUNCH-OK；APK 105.7MB。
> 如继续迭代（v1.2.0 候选，见 `web/src/pages/changelog.astro` 计划项）：云端模板市场 / 双人姿势包 / 布光预设社区分享；或 V4 遗留的端上照片识别重新评估。
> 注意：改任何 `assets/engine/js/**` 后必跑 `node tool/engine_build/bundle.mjs` 并让 `q5_*` 静态门禁复绿。
