# ShootStudio V6 交接文档（进行中）—— 搜索重做 + 3D 稳定/建模 + 端上识别 + 资源库图

> 更新：2026-09-19 ｜ 版本基线 `1.1.0+6`（目标 `1.2.0`）｜ 约束文件：`FIX_CONTRACT_V6.0.md`（**开工前必读**）
> 进度：**A（②引擎稳定化）✅ ｜ B（③3D 建模与布光）✅ ｜ C（①搜索重做）⏳ ｜ D（④姿势/端上识别）⏳ ｜ E（⑤资源库图）⏳ ｜ F（交付 v1.2.0）⏳**
> 本机状态：全量 **199 passed + 1 skipped**；`flutter analyze --fatal-infos` 0 问题；format 通过；引擎包 950.7KB；CI 全绿（e560bc2；a79f59a 镜像兜底修复在跑）
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter `app/`，官网 `web/`，证据 `docs/`）

---

## 0. 30 秒速览：下一步做什么

1. **C 阶段（搜索重做）**：按 `FIX_CONTRACT_V6.0.md` §3.C 建 `lib/services/search/`（sources/query_planner/result_ranker/image_to_search/theme_packs/search_cache）、重写画面参考页搜索 UI、AI 策划自动参考图；测试 `q6_search_test`；live 证据 `docs/qa/search-live-*.txt`。
2. **D 阶段（姿势/端上识别）**：`pose_detection: ^3.7.0` PoC（Windows+Android 构建）→ 全链路识别 → 120 张亚洲图重跑管线 → 精度报告。
3. **E 阶段（资源库图）**：`tool/gear_photos_v3/` + 增量同步 + 补图 UI；覆盖率报告。
4. **F 阶段**：全量门禁 → 双端构建 → v1.2.0（版本/公告/dist/合同日志/CI 绿）。

---

## 1. 已完成：A 阶段（②引擎稳定化）

**根因（实测确认）**：① `character.js` 缓存只增不减 → 切角色数次后 OOM；② `engine_view.dart` 把任何 `EngineErrorEvent` 当致命 → 销毁 WebView 降级（用户看到"3D 引擎加载失败，再点又正常"）。

**修复内容**
- `character.js`：实例 LRU（≤2）+ GLB LRU（≤3）+ 级联 `dispose`（细分几何/材质/骨骼 helper/标记）+ 在途保护（`instanceEntries`/`glbResolved`）+ 角色失败自动 `evictAll` 重试一次；`getCacheStats()`/`evictAll()`。
- `engine.js`：`window.onerror`/`unhandledrejection` 上报（fatal:false）；`setInterval` 心跳（1.5s，含 JS 堆内存）；`getEngineStats`/`evictCharacterCache`；性能档 `setPerformanceProfile('auto'|'high'|'low')`（低档：关接触阴影/1024 阴影/1×pixelRatio/细分≤1）。
- `engine_view.dart`：仅 `fatal:true` 降级；`onConsoleMessage` 落盘 `app.log`；20s 心跳超时自动重建 WebView（≤2 次）；「导出诊断包」按钮；`engine_bridge.dart` 新增 `EngineErrorEvent.fatal/source`、`EngineHeartbeat`、`EngineConsole`、`evaluate()`。
- Flutter：`LightingState.performanceProfile` + `quality_performance_profile` 持久化 + 画质面板三档；`lighting_page._exportDiagnostics()`（日志+引擎统计+场景 JSON+环境信息 → zip 到工作区 `diagnostics/`）。
- 测试：`test/features/q6_engine_test.dart`（5 项）；`tool/engine_mem_qa.mjs`。

**证据**：`docs/qa/engine-mem-2026-09-19-08-29-56.json` —— 23 角色连续切换 0 失败，LRU=2/3 PASS，堆增长 first 44.4 → peak 108 → last 59.9MB PASS。

---

## 2. 已完成：B 阶段（③3D 建模与布光）

**根因（实测确认）**：① `spotTarget` 挂成灯头子对象 → 正上方灯被算成水平照射；② 23 套预设 `rotationY` 全为 0；③ 造型过于简陋（灯架=圆柱、柔光箱=白盒、无相机）。

**修复内容**
- 新增 `assets/engine/js/aim.js`（纯函数 `computeAim`/`aimDirection`，+X 约定；`tool/test_aim.mjs` 单测已入 CI）。
- 新增 `assets/engine/js/rig.js`：参数化建模（普通/C架/横臂灯架、灯头+卡口+肋条、16 种控光件、相机三脚架+机身+镜头）、`focalToFov`。
- `lights.js` 重写：几何自动瞄准（`offsetYaw/offsetPitch` 手动偏移）、16 种控光件（新增八角/长条/反光伞/透光伞/旗板/色片/柔光箱格栅）、光锥可视化（`setLightCones`）、软硬阴影随附件（`shadowRadius`）、色片染色。
- `engine.js`：`setCameraRig/getCameraRig`、`setCameraView`（POV，+Z 转 -Z 观察补 180°）、`setLightCones/getLightCones`；场景 JSON 新增 `camera`。
- Flutter：`CameraRigData`（场景往返）、`DeviceSpec.stand/offsetYaw/offsetPitch`、俯视图机位图标 + 视野扇形（随焦段）+ 机位拖动；右栏「机位」面板（焦段/高度/俯仰/偏航 + 显隐 + 看构图）；工具条「相机视角」chip；画质面板「光锥可视化」开关（持久化 `quality_light_cones`）；`light_meter.dart` 按控光件衰减表校准。
- 预设：`tool/rewrite_light_presets.mjs` → **27 套**（新增 clamshell/hair-light/split-rim/gel-party），全部 `rotationY=0` + `stand`/`offset` 字段，附件语义升级（octa/umbrella/strip/gel）。
- QA 工具：`tool/light_preset_qa.mjs`（`--bundle <path>` 支持 before 对比）。

**证据**：`docs/screenshots/lighting-v6/`（27 张 after + 4 张 before + qa-after/qa-before.json）；`tool/test_aim.mjs` ALL PASS；`test/features/q6_lighting_test.dart` 8/8；全量 199+1。

---

## 3. 待做：C / D / E（按合同 §3 执行）

### C（①搜索重做）—— 关键点
- 源（免 Key 优先）：TMDB（主，隧道）/ Pexels / Met / 芝加哥 / 克利夫兰 / V&A / AniList（GraphQL POST，实测可用）；WikiArt+Artvee 抓取；Europeana/Smithsonian/Harvard/Rijksmuseum 预留 Key。
- 统一接口 `SourceCapability`；`QueryPlanner`（意图分类+AI 扩词+翻译+缓存）；`ResultRanker`（匹配分/源权重/分辨率/许可/去重）；`ImageToSearch`（AI 视觉描述→搜，无视觉能力时降级）；20 个主题包；5GB LRU 缓存。
- UI：Tab（影视/艺术/摄影）+ 人名按作品分组 + 每源状态/重试/分页 + 许可筛选 + 一键入案；AI 策划自动附参考图（5–10 张）。
- 门禁：`q6_search_test`；`docs/qa/search-live-*.txt`（中/英/人名/主题 ≥20 用例）。

### D（④姿势/端上识别）—— 关键点
- **先 PoC**：`pose_detection: ^3.7.0`（BlazePose 33 点，Windows+Android）；Windows 构建需 CMake 拉 opencv_dart 预编译库；**若失败** → 回退 `flutter_litert` 自研管线（合同 D123）。
- 服务：`lib/services/pose/`（detector/joint_mapper 复用 `pose_landmark_math.dart`/grounding）。
- UI：导入照片 → 多人点选 → 骨架叠加 → 12 关节 → **手动**再导入；覆盖内置参考图（可恢复）+ 新建自定义；工作区存储。
- 120 张亚洲图：`tool/gen_pose_photos_asian.py`（Pexels + 正版图库混合）→ 重跑骨架/接地/对比管线 → 精度报告（均值 ≤5°、90% ≤10°）。
- 门禁：`q6_pose_test`。

### E（⑤资源库图）—— 关键点
- 覆盖率：相机/镜头 ≥95%，灯具/附件/服装/道具 ≥90%。
- 渠道：官网 > 京东 > 亚马逊 > 淘宝（尽力而为+缺口清单）；运行时候选缓存不入 git/包；V4 白底 4:3 规范化；「补图」UI；增量同步（断点续传+缺口报告）。
- 门禁：`q6_gear_test`；`docs/qa/gear-coverage-v6.json`。

---

## 4. 本机环境与坑（V6 实测新增）

1. **shell 不稳定**：同一会话里会在 bash/PowerShell 间漂移；多行 bash 函数/heredoc 会失败。**所有命令用简单形式**；Dart/Flutter 用转发脚本：
   - `C:\Users\Lenovo\AppData\Local\Temp\opencode\dart.cmd <args>`（dart）
   - `C:\Users\Lenovo\AppData\Local\Temp\opencode\flutter.cmd <args>`（flutter tools snapshot）
   - 需要重定向输出时用 `cmd /c "... > file"`（PowerShell 的 `>` 会写 UTF-16）。
2. **改完 Dart 必须 format**：`dart format lib test`，否则 CI 第一步直接红（本机与 CI 判定一致，别以为是版本差异）。
3. **改过 `assets/engine/js/**` 必须重打引擎包**：`node tool/engine_build/bundle.mjs`，然后 bundle 静态门禁测试才有效。
4. **CI 的 Android 构建走官方 Maven**：`ci.yml` build-apk 设 `SS_MAVEN_MIRROR=0`（阿里云镜像偶发 502，会让 Gradle 禁用仓库→误判失败）；本地构建不设该变量仍走镜像。
5. **推送**：本机 git 配了 github.com 代理 `127.0.0.1:7890`（常不在线）；直连可用时用
   `git -c http.https://github.com/.proxy= -c http.https://codeload.github.com/.proxy= -c http.https://api.github.com/.proxy= -c http.version=HTTP/1.1 push`。CI 必须全绿（R60）。
6. **引擎包静态门禁只能断言字符串常量**（minify 不改对象键/字符串字面量）；新 API 记得加进 `window.ss.features`。
7. **预设数据引用校验**：`q6_lighting_test` 会拿 `light_presets.json` 里的 fixture/modifier 去 bundle 里找（注意 `null` 要 `?? ''` 兜底）。
8. **QA 特写相机**受 `OrbitControls.minDistance` 限制（V5 已放宽逻辑，`qaAllowDistance`）；QA 页面等 HDRI 最多 12s。
9. **`docs/screenshots/lighting-v6/` 是 B 阶段正式证据**，勿清；清理只删临时图。

---

## 5. 常用命令

```bash
cd app && node tool/engine_build/bundle.mjs          # 改引擎 JS 必跑
cd app && node tool/test_aim.mjs                      # 瞄准数学单测
cd app && node tool/light_preset_qa.mjs --cones 1     # 27 套预设渲染
cd app && node tool/engine_mem_qa.mjs                 # 角色 LRU/内存门禁
cd app && node tool/pose_qa.mjs hands --skip-existing --workers 1
cd app && <dart.cmd> format lib test
cd app && <flutter.cmd> analyze --fatal-infos
cd app && <flutter.cmd> test
```

---

## 6. 新对话开场建议

> 继续 `D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio` 的 **V6 收尾**：先读 `FIX_CONTRACT_V6.0.md`（D94–D131 + R41–R60）与本文件。
> A/B 已完成并推送（CI 绿）；从 **C 阶段（搜索重做）** 开始，按合同 §3.C → §3.D → §3.E → §3.F 推进，每阶段门禁通过后 commit+push 并追加合同 §5 日志。
> 基线：全量 **199 passed + 1 skipped**；引擎包 950.7KB；CI 绿。
