# ShootStudio V7 交接文档 · 进行中（画面参考/显卡/布光/姿势识别/资源库）

> 更新：2026-09-23 ｜ 配套合同：`FIX_CONTRACT_V7.0.md`（D132–D144、R61–R70，**开工前必读**）
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter `app/`，官网 `web/`，证据 `docs/`）
> 基线：v1.2.0 已发布（tag `v1.2.0`）；V7 目标 v1.3.0

---

## 0. 一分钟速览

| 项 | 状态 |
|---|---|
| 已完成并推送 | **S0 合同** `be2c264` ｜ **S1 画面参考** `182ea8b`/`c6dd66e`/`44efb72`/`9ae31aa` ｜ **S2 显卡** `a90a202`/`b7ad285` ｜ **S3.1 three.js 升级** `2b57c7c`/`a0e836b` ｜ **S3.2 真实感** `9b2c729`/`1805425` ｜ **S3.3 布光功能**（本次提交） |
| CI | S3.2 已绿（run 35824614111）；S3.3 推送后运行中（R60：**全绿才算完成**，下一步先复核） |
| 门禁基线 | format 0 changed ｜ analyze 0 问题 ｜ 全量 **278 passed + 26 skipped** ｜ `q6_search_test` 41/41 ｜ `q6_lighting_test` 32 预设 ｜ live 搜索 23/23 ｜ 引擎包 1.1MB + pathtracer 220.4KB（<2.2MB） |
| 剩余 | **S3.4 相机辅助 ｜ S4 姿势参考图 12×10 ｜ S5 RTMPose/RTMW3D 识别 ｜ S6 资源库 100% ｜ S7 v1.3.0 发布** |

---

## 1. 已完成（S0–S3.3，含证据路径）

### S0 合同（`be2c264`）
`FIX_CONTRACT_V7.0.md`：D132–D144 + R61–R70（含 Getty 移除、Step 3 顺序修正、许可门控、NGA/Walters 索引方案、硬件适配）。

### S1 画面参考极简 + 主题 + 搜索扩展（D132–D134）
- **极简 UI**：`lib/features/refs/refs_page.dart` 重写（搜索框 + 8 常用主题标签行 + 结果网格 + 详情弹窗 + 我的画板 + 免责声明 + 粘贴截图/本地导入/以图搜图）；删除 `search_page.dart`；PD 别名索引拆为 `lib/services/pd_film_index.dart`（q5 门禁改 import）。
- **主题**：`theme_packs.dart` 24→48；`matchThemePack`（≥3 字或占比过半）、`commonThemePacks`（8 常用）；策划案主题联动（refs 页读最新策划案 theme 模块预填并自动检索）。
- **7 个开放源**：`openverse/wikimedia/wellcome/smk/loc_source.dart`（keyless）+ `open_index_source.dart`（NGA/Walters 内置索引）；`search_keys.dart` 注册；`result_ranker` 权重；`SearchEngine.allDomains` 全混合。
- **数据**：`assets/content/search/open_index/{nga,walters}.json`（各 300 条 CC0）；构建工具 `tool/build_open_index.py`（CSV 缓存 `tool/open_index_cache/` 已 gitignore）。
- **NetRouter**：隧道白名单新增 5 域；修复 3 处异步错误泄漏（zone 保护 / `client.done` / DoH try-catch）。
- **证据**：`q6_search_test` 41/41；live 23/23 → `docs/qa/search-live-2026-09-23T12-49-14.txt`（Wellcome 6 条、SMK 10 条可达；Openverse 握手失败/Wikimedia 超时/LoC 403 —— 代码就绪，网络恢复即生效）。

### S2 显卡适配（D135）
- C++：`windows/runner/gpu_utils.{h,cpp}` DXGI 枚举（过滤软件/虚拟适配器）+ `shoot_studio/gpu` channel（`flutter_window.cpp`）；`main.cpp` 读 `%LOCALAPPDATA%\ShootStudio\gpu_mode.txt` 注入 WebView2 参数（discrete → `--force_high_performance_gpu`；software → SwiftShader）。
- Dart：`lib/services/gpu/gpu_info.dart`、`lib/services/engine/engine_reload.dart`（重载信号 + GPU 渲染器 notifier）；`engine_view.dart` 监听重载并在就绪后抓 `getEngineStats().gpu.renderer`；`engine.js` 暴露 `gpu:{renderer,profile,api:'gpu-info-v7'}`。
- 设置页「显卡」卡片：适配器列表 + 自动/独显优先/核显优先/软件渲染 + 识别后端 CPU/GPU + 当前引擎 GPU + 保存（热重载，未切换提示重启）。
- 证据：`q6_engine_test` +5；Windows 构建 + `smoke_launch.ps1` **LAUNCH-OK**；本机 RTX 4060 Laptop 8GB + Iris Xe + MuMu 虚拟适配器（已过滤）。

### S3.1 three.js r169 → r186（D136 前半）
- `three@0.186.0`；**r18x 起 `build/` 无自包含 minified ESM** → 新增 `tool/engine_build/vendor_three.mjs`（esbuild 打包，可复现）；8 个 addons 同步；`RGBELoader` 已弃用 → 引擎改用 `HDRLoader`；`NOTICE.md` 更新。
- 证据：升级前后 `light_preset_qa` 27/27、0 失败；像素差表 `docs/qa/three-r169-r186-diff.md`（平均 6.69/255≈2.6%，归因 r181 PBR 能量守恒/PMREM/r183 光照重构）；`engine_mem_qa` LRU+堆 PASS；引擎包 984KB→约 1.0MB。

### S3.2 布光真实感（D137）
- **图案片投光**：`lights.js` 程序生成格栅/百叶窗纹理 → `SpotLight.map`；新增控光件 `gobo-blinds` + 预设 `blinds-window`（**28 套**）；`rig.js` 图案片夹视觉。
- **软阴影**：r186 移除 `PCFSoftShadowMap`（静默回退 PCF 且 `radius` 失效）→ 改 **VSMShadowMap**（blurSamples 8），`radius` 随附件柔度 × 灯距；新增 `setSoftShadows/getSoftShadows` + `quality_soft_shadows` + 画质面板开关；低配档回退 PCF。
- **面板灯阴影代理**：面板灯复用 SpotLight（intensity=0）投影；阴影预算 2→3 且纳入面板灯。
- **偏差登记**：IES 光型未实现（r186 核心无 `iesMap`），继续用测光表近似。
- 证据：`q6_lighting_test` 28 预设 + 新 token 全绿；`q6_engine_test` 软阴影持久化；全量 265+26；QA 28/28（`docs/screenshots/lighting-v6/*-r186s32.png`）。

### S3.3 布光功能（D138）
- **路径追踪静帧**（spike 先行）：`three-gpu-pathtracer@0.0.24` + `three-mesh-bvh@0.9.15`（r186 兼容）→ `tool/engine_build/pathtracer_build.mjs` 打 IIFE **`assets/engine/js/pathtracer.bundle.js`（220.4KB）**，复用引擎同一份 three（`window.__ssThree` shim），许可 `vendor/{PATHTRACER,MESHBVH}_LICENSE` 随包（R64）。
- **引擎 API**：`renderStill({mode:'path'|'supersample',width,height,samples,bounces,factor,useCameraRig})`、`warmPathTracer()`、事件 `stillProgress`/`stillRendered`、`capturePhoto(token)`；软件渲染/加载失败自动回退超采样（R69）；PMREM 环境贴图修复（路径静帧改用原始等距柱状 HDR）。
- **UI**：`still_export.dart`「效果预览」对话框（模式/分辨率/采样数/相机机位/进度/预览/自动存 `images/plans/静帧_*.png`，就绪 3s 后台预热）；`ab_compare.dart` + 「A/B 对比」对话框（冻结 A→调光→冻结 B→差异摘要/合成图）。
- **预设 28→32**：`blinds-window-hard`/`clamshell-hard`/`neon-tube`/`office-window`。
- **VSM 回归修复**（S3.2 引入）：r186 VSM 把 `receiveShadow` 物体也渲染进阴影贴图 → 灯具自身位于光锥内把场景压黑（修复前 VSM 32.6 vs PCF 109.8；0 灯≈3 灯）→ `lights.js excludeFromShadows()`。
- **偏差/限制登记**：路径追踪 16 samples 噪声大（128 可用）；灯具发光面在路径追踪中偏暗（无自发光语义）；首次编译 40–80s；预设 QA 走 SwiftShader 低配档 → PCF（VSM 证据用 headed 专项）。
- 证据：`q6_lighting_test` 32 预设 + 新 token；新增 `q6_still_test`；全量 **278+26**；`light_preset_qa` **32/32、0 失败**（`*-r186s33.png`）；`light_still_qa` → `docs/qa/light-still-ab-s33.json`（超采样 63–103ms；路径 480×360×128 首次 73.6s/二次 19.2s；A/B mean 1.62/255、2.4%）；`vsm_regression_qa` PASS → `docs/qa/vsm-regression-r186s33.json`（VSM 54.3 vs PCF 54.6，ratio 0.995；灯光增益 24）；spike 报告 `docs/qa/pathtracer-spike-report.md`。

---

## 2. 剩余待办（按合同 §3 顺序）

### S3.4 相机辅助（D139）
景深预览（光圈/对焦距离 → CoC 近似或后期模糊）、构图线/安全框、焦段与视野可视化增强。证据：截图 + 测试。

### S4 姿势参考图 12 类 × 10（D140）
- 新增「杂志大片」「影视感」两类，替换手部/表情；内置 Pexels 可商用杂志风；运行时「影视感参考」按需抓 TMDB（只存工作区，不入包）。
- 管线：`tool/gen_pose_photos_v7.py`（或改造 `gen_pose_photos_asian.py`）→ `extract_pose_skeletons.py extract --force` → `skeleton_to_joints.py build --force` → `node tool/pose_qa.mjs photo`；`q2_pose_photos_test` 更新为 12×10；attribution 更新。
- **注意**：分类数量/ID 变化会影响 `poses3.json`、UI 分类 chips 与 q2/f4 测试，需一并更新（R66：改测试不删测试）。

### S5 识别 RTMPose/RTMW3D（D141）
1. **spike 先行**：HuggingFace 本机不可达 → `hf-mirror.com` 或 DoH 隧道下载 `Soykaf/RTMW3D-x` ONNX（rtmlib 配套，~369MB）；核验许可（预期 Apache-2.0）与量化/体积；`flutter_onnxruntime` Windows EP 验证（DirectML 是否内置；不可用则 CPU EP 或自编译）。
2. 新服务：检测（YOLOX/RTMDet 或复用 pose_detection）+ RTMW3D 3D → 12 关节映射 + 接地校准；旧 MediaPipe 路径保留回退直至 D128 门禁达标。
3. 模型随包（R53/R64）；离线一致性测试；`q6_pose_accuracy` 冲 均值 ≤5°/90% ≤10°。

### S6 资源库 100%（D142–D143）
- `brands.py` 扩展（佳能/尼康/索尼/松下/适马/富士/徕卡/大疆/智云等）；授权零售商 provider（B&H/Adorama/京东）；同系列近似 tier 标注；服装品牌图 + 道具实拍。
- 四层兜底口径与覆盖率报告更新（六类 100%）；`gear_coverage.py` + `gear_photo_sources.json` 重生成；fixture/selftest 保持绿。

### S7 v1.3.0 交付（D144）
门禁 → 双端构建 + LAUNCH-OK + APK 体积 → 版本/公告/dist/合同 §5/HANDOFF/下载页 → tag `v1.3.0` → CI 绿。

---

## 3. 本机环境与坑（V7 实测新增）

1. **本会话无 shell 工具**（工具集受限）：命令经 `subagent`（general）执行；下一会话若 shell 可用，直接按本文件命令跑即可。
2. **three r18x**：`build/three.module.min.js` 已移除且 `three.module.js` 依赖 `three.core.js` → 用 `tool/engine_build/vendor_three.mjs` 重建（esbuild，可复现）；`RGBELoader` 弃用改 `HDRLoader`；**`PCFSoftShadowMap` 被移除**（引擎已改 VSM）。
3. **HuggingFace 本机不可达**（S5 spike 第一风险）：需 `hf-mirror.com` 或 DoH 隧道。
4. **开放源可达性**：Openverse 握手失败 / Wikimedia 超时 / LoC 403（本机）；Wellcome/SMK 正常。许可门控：Getty 等 Rights-Managed 一律排除。
5. **`set VAR=1 &&` 陷阱**：cmd 下会带尾随空格，导致 env 比较失败；用 `$env:VAR='1'`（PowerShell）后再 `cmd /c`。
6. **测试计数会变**：新增测试后同步更新合同/HANDOFF 基线（当前 **278+26**）。
7. **QA 阴影类型**：`light_preset_qa` 用 headless Edge（SwiftShader）→ `effectiveProfile()='low'` 强制 PCF，预设截图**不覆盖 VSM 路径**；VSM 证据走 headed 独显专项 `node tool/vsm_regression_qa.mjs`（`--force_high_performance_gpu`）。
8. **路径追踪产物**：改 `engine.js` 后重打 `node tool/engine_build/bundle.mjs`；改 pathtracer 依赖/打包配置后重打 `node tool/engine_build/pathtracer_build.mjs`（生成 `tool/engine_build/.gen/three_global_shim.js`，已 gitignore）；首次路径追踪需 40–80s 编译（就绪后 3s 自动预热，二次亚秒级）。
9. **flutter/dart 不在 PATH**：用 `C:\dev\flutter\bin\flutter.bat` / `dart.bat`（Flutter 3.47.2 stable），命令在 `app/` 下执行。
10. 沿用 V6 坑表：format tall-style、改引擎 JS 必重打 bundle、QA 前杀 headless Edge、推送重试、Android 构建需 NDK 环境变量。

---

## 4. 新对话开场提示词（可直接粘贴）

> 继续 `D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio` 的 V7：先读 `HANDOFF_V7.md`（本文件）与 `FIX_CONTRACT_V7.0.md`（D132–D144/R61–R70）。
> 已完成 S0–S3.3 并推送（S3.3 的 CI 需先复核全绿）；基线 278 passed + 26 skipped。
> 请按 §2 顺序继续：**S3.4 相机辅助 → S4 姿势参考图 12×10 → S5 RTMPose/RTMW3D（先 spike HF 镜像/ORT-DirectML）→ S6 资源库 100% → S7 v1.3.0 发布**。
> 纪律：每步 format/analyze/全量 test + 专项证据 + `git push` 后 CI 绿（R60/R61）才进下一步；spike 先行（R67）；数据变更重跑全量证据（R68）。
