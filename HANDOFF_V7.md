# ShootStudio V7 交接文档 · 进行中（画面参考/显卡/布光/姿势识别/资源库）

> 更新：2026-09-24 ｜ 配套合同：`FIX_CONTRACT_V7.0.md`（D132–D144、R61–R70，**开工前必读**）
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter `app/`，官网 `web/`，证据 `docs/`）
> 基线：v1.2.0 已发布（tag `v1.2.0`）；V7 目标 v1.3.0

---

## 0. 一分钟速览

| 项 | 状态 |
|---|---|
| 已完成并推送 | **S0 合同** `be2c264` ｜ **S1 画面参考** `182ea8b`/`c6dd66e`/`44efb72`/`9ae31aa` ｜ **S2 显卡** `a90a202`/`b7ad285` ｜ **S3.1 three.js 升级** `2b57c7c`/`a0e836b` ｜ **S3.2 真实感** `9b2c729`/`1805425` ｜ **S3.3 布光功能** `c474cda`/`1978a91` ｜ **S3.4 相机辅助** `d235451` ｜ **S4 姿势参考图** `4157bb7` ｜ **S5-spike 识别路线** `bf9cb12` ｜ **S5 主体 端上识别集成**（本次提交） |
| CI | S5-spike **全绿**（run 35964914460 = bf9cb12 success）；S5 主体推送后运行中（R60：全绿才算完成，下一步先复核）；S4 的 35953854563、S3.4 的 35855722478、S3.3 的 35839154345/35842252891 亦 success |
| 门禁基线 | format 0 changed ｜ analyze 0 问题 ｜ 全量 **303 passed + 27 skipped** ｜ `q2_pose_photos_test` 8 用例 ｜ `q6_search_test` 41/41 ｜ `q6_lighting_test` 32 预设 ｜ `q6_camera_test` 10 ｜ `q6_pose3d_test` 11 ｜ `q6_pose_recognition_test` 2 ｜ `q6_pose3d_consistency`（`SS_POSE_ACCURACY=1` 门控，本机 PASS）｜ `pose_qa photo` 120/120（缺 0）｜ 引擎包 1.16MB + pathtracer 220.4KB（<2.2MB）｜ 识别模型 205MB（fp16 分片 184.8MB + yolox_tiny 20.2MB，R64） |
| 剩余 | **S6 资源库 100% ｜ S7 v1.3.0 发布** |

---

## 1. 已完成（S0–S5，含证据路径）

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

### S3.4 相机辅助（D139）
- **路径追踪景深（预览）**：`engine.js` 新增 `getCameraAssist()`（焦段 → 垂直/水平视野角、主体距离、主体处画幅高/宽、`dofAvailable`）与 DOF 相机同步（`PhysicalCamera`，仅该类型才会被 `PathTracingRenderer` 采信 bokehSize/focusDistance；`bokehSize = 焦距/fStop`）；`renderStill` 新增 `dof:{enabled,fStop,focusMode:'auto'|'manual',focusDistance}`，自动对焦 = 相机到主体（`activeSubject` + 1.35m 高度）距离；`stillRendered` 回传 `dof/fStop/focusDistance/focusMode`，回退超采样时带 `dofFallback`（R69）。
- **构图线/安全框**：`camera_helpers.dart`（`CameraGuideSettings`：三分线/安全框/中心十字/画幅裁切 none/16:9/9:16/1:1/2.35:1 + `CompositionGuidePainter` 画布叠加：裁切外压暗 + 三分线 + 5%/10% 安全框 + 中心十字 + 左上角 `焦段·类别·视野角·画幅高` 信息）；页面「构图辅助」chip 与机位面板开关，仅相机视角（看构图）时叠加。
- **焦段与视野可视化增强**：机位面板显示 `垂直视野 x° · 水平 x° · 主体距离 x.xxm · 画幅高 x.xxm`（与 `rig.js focalToFov` 同口径：全画幅 24mm 传感器高），景深不可用时提示；效果预览对话框新增「景深」开关（光圈 1.4–16、对焦自动/手动 0.3–12m），结果摘要带景深参数与回退提示。
- 证据：`q6_camera_test` 10 项（FOV/画幅换算、焦段分类、构图设置、Painter、bundle token、对话框景深 UI）；`q6_lighting_test` 新增 `camera-assist/getCameraAssist/fStop/focusDistance/PhysicalCamera/dofFallback` token；全量 **290 passed + 26 skipped**；format 0 changed、analyze 0 问题；`camera_assist_qa`（headed RTX 4060，480×360×48 samples）**PASS**：assist fov 16.07°（=期望）/主体距离 5.5m/画幅高 1.55m，主体框 p95 边缘锐度 无景深 136.0 → 自动对焦 121.0（0.89）→ 手动对焦 1m 50.1（0.369 ≤ 0.6，景深生效），payload dof=true / f1.4 / 自动 5.5m / 手动 1.0m → `docs/qa/camera-assist-r186s34.json` + 三张静帧 PNG。

### S4 姿势参考图（D140，10 类 × 12）
- **分类替换**（用户确认口径「10 类 × 12 张（字面替换手部/神态）」）：去掉「手部」「神态」，新增「杂志大片」（editorial，p085–p096）与「影视感」（cinematic，p097–p108），总量维持 120；合同 D140 原文「12 类 × 10」按偏差登记。
- **抓取器** `tool/gen_pose_photos_v7.py`：Pexels 主源 + 亚洲人过滤（`asian_score>=1`）+ 可商用许可 + 竖幅全身门控；原地替换 24 张并更新 `photos_manifest.json`（含 candidatePool）与 `attribution.json`（逐图登记，R63）；p106 首图 MediaPipe 未检出人体 → 重取（pexels 8683443）并重提骨架。
- **数据重建**：`extract_pose_skeletons.py extract --force` → `skeleton_to_joints.py build --force`（新类目补 `pose_name`/`CATEGORY_TIPS`/`CATEGORY_LENS`；120 条、限位 42、referenceOnly 17）→ `annotate_pose_visibility.py`（partialBody 26/120）。
- **UI**：`poseCategories` 改 10 类；新「影视感参考」入口 `cinematic_refs.dart`（TMDB 按需检索 → 只存工作区 `images/refs/` + 来源/许可标注，**不入包**，R63）。
- 证据：`node tool/pose_qa.mjs photo` 120/120 渲染 + 拼接（缺 0）、接地校准 120 条 rootY、重试 23/23；`q2_pose_photos_test` 8 用例全绿（含 p050 接地 `minY=0.0002`）；全量 **290 passed + 26 skipped**；format 0 changed、analyze 0；photos 120 jpg + 120 skeleton（10.45MB）、manifest 10 类 × 12、attribution 654 条；截图 `docs/pose-qa3/compare-*.png` / `overlay-*.png` / `qa_photo_state.json`。

### S5 spike：识别 RTMPose/RTMW3D 路线（D141 / R67，结论「可行」）
- **通道**：`huggingface.co` 本机不可达（超时）→ **`hf-mirror.com` 可达**（整包下载字节数与 API 声明一致）。
- **模型与许可**：RTMW3D-x ONNX（`Soykaf/RTMW3D-x`，apache-2.0，369,330,857 B）+ YOLOX ONNX（`hr16/yolox-onnx`，apache-2.0；nano 3.66MB / tiny 20.2MB / s 35.9MB / m 101.3MB / l 216.7MB）→ 均可随包（R63/R64）。
- **移植口径**（Dart 端须逐字对齐 rtmlib）：输入 `[1,3,384,288]` fp32；预处理 = bbox padding 1.25 → 3:4 等比扩展 → 288×384 仿射（黑边）→ ImageNet 归一化（**BGR**）；后处理 = `locs/2`（crop 像素）+ `z_m=(z/192-1)*2.1744869` + score=min(max_x,max_y)；133 关键点 → BlazePose 33 子集 + **骨长先验米制尺度**（中位数，10 条骨）→ 复用 `derive()` 12 关节/接地。
- **量化**：dynamic int8 92.9MB（关节角均差 **48.7°** ❌）/ static int8（30 张真图校准 QDQ）93.9MB（**22.7°** ❌）/ **fp16（keep_io_types）184.8MB（0.16° ✅ 推荐随包）**。
- **EP**：ORT 1.30 CPU fp32 600.9ms / fp16 609.7ms；DML（ORT 1.24.4）fp16 **8.7ms**（≈57×）——但 **flutter_onnxruntime 1.8.5 Windows 无 DML**（CMake 固定 CPU 包、插件只接受 CPU/CUDA）→ 端上 CPU EP。
- **随包方案（GitHub 100 MiB 单文件限制）**：fp16 拆 **2 片**（各 92,394,513 B）+ 首次使用本地拼装（无网络；实测 0.23s、SHA256 一致、ORT 输出逐元素相同）。
- **精度对比（参考）**：RTMW3D-x vs 现有 MediaPipe 参考（4 图 144 角）均差 20.13°、≤5° 35.4%（非门禁口径）。
- 证据：`docs/qa/rtmpose-spike-report.md` + `rtmpose-spike-{specs,infer,angle,detectors,quant,bench,bench-dml,split}.json`；脚本 `app/tool/rtmpose_spike.py`（fetch/specs/infer/compare/detcompare/quantize/bench/split）；检测器 IoU vs yolox_m：s 0.882 / tiny 0.881 / nano 0.875 → 建议随包 **yolox_tiny**。

### S5 主体：端上识别集成（D141）
- **运行时**：`onnxruntime`（gtbluesky FFI 1.4.1，内置 ORT 1.15.1；Android/Windows/Linux/macOS 二进制随插件）——可在 `flutter test`（Dart VM/FFI）内跑真实模型，一致性门禁可执行；弃用 `flutter_onnxruntime`（MethodChannel 测试内不可用 + Windows 无 DML）。
- **纯 Dart 数学层** `lib/services/pose3d/`：`pose3d_geometry.dart`（bbox→1.25 padding + 3:4 扩展、288×384 双线性 warp 黑边、BGR + ImageNet 归一化、NCHW；YOLOX letterbox pad=114/半像素中心）、`pose3d_decode.dart`（simcc argmax/2 + `z=(z/192-1)*2.1744869` + 2D 重投影；YOLOX anchor-free 解码 strides 8/16/32 + 逐类 NMS）、`pose3d_mapping.dart`（133→BlazePose 33 + 骨长先验中位数尺度 + 髋中心 world）、`pose3d_assembly.dart`（fp16 分片流式拼装 + SHA256/字节校验 + 复用与失败清理）。
- **引擎/门面**：`pose3d_engine.dart`（`Pose3dDetector` 抽象 + `Pose3dEngine.load(detBytes:,poseBytes:)`（`fromBuffer`，绕开 Windows `fromFile` wchar bug）+ detect→`Pose3dPerson`）、`pose_recognition_service.dart`（RTMPose 优先；模型缺失/拼装/加载失败自动回退 MediaPipe，R69；`backendLabel`/`backendNote`）。
- **UI 接入**：`pose_import_page.dart` `_service` 换门面、状态文案显示后端、骨架 JSON `model` 字段按后端区分（RTMPose/RTMW3D-x(fp16)+YOLOX-tiny / MediaPipe 回退）。
- **随包（R64）**：`app/assets/models/pose3d/`（`rtmw3d-x-fp16.onnx.part0/.part1` 各 92,394,513 B + `yolox_tiny.onnx` 20,219,662 B + `NOTICE.md`，Apache-2.0 署名；pubspec assets 登记）。
- **测试**：`q6_pose3d_test`（11 项：几何/解码/映射/拼装，纯 Dart fixture）；`q6_pose_recognition_test`（2 项：后端映射 + R69 回退）；`q6_pose3d_consistency_test`（`SS_POSE_ACCURACY=1` 门控，8 图 Dart 引擎 vs Python 参考）。
- **一致性证据**（`docs/qa/pose3d-consistency-report.json`，参考 `docs/qa/pose3d-consistency-reference.json` 由 `tool/rtmpose_spike.py reference` 生成、含 clamp 同口径）：worstIou **0.9942**、kpXY 1.15px、kpZ 0.0179m、scaleRel 2.82%、rootYΔ 0.0055、rootPitchΔ 2.33°、**关节均值 2.8° / p90 6.81° / 中位数 0.32°**（D141 口径 均值 ≤5°、p90 ≤10° 达标）。
- **偏差/坑登记**：① `solve_limb` 离散扫描 + 限位罚项存在多个近等价值（输入方向差 0.4° 即可切换最小值，Python 自对自复现 shoulder_r.ry Δ43.3°）→ 关节以中位数/均值+p90 断言，最大 90.5° 仅记录；② 门控测试曾 1 次瞬时失败（随后连续 4 次通过，记为本机风险）；③ 尺度容差 5%（cv2 与 Dart `image` 的 JPEG 解码差异 → 短骨 dxy 敏感）。

---

## 2. 剩余待办（按合同 §3 顺序）

### S6 资源库 100%（D142–D143）
- `brands.py` 扩展（佳能/尼康/索尼/松下/适马/富士/徕卡/大疆/智云等）；授权零售商 provider（B&H/Adorama/京东）；同系列近似 tier 标注；服装品牌图 + 道具实拍。
- 四层兜底口径与覆盖率报告更新（六类 100%）；`gear_coverage.py` + `gear_photo_sources.json` 重生成；fixture/selftest 保持绿。

### S7 v1.3.0 交付（D144）
门禁 → 双端构建 + LAUNCH-OK + APK 体积 → 版本/公告/dist/合同 §5/HANDOFF/下载页 → tag `v1.3.0` → CI 绿。

---

## 3. 本机环境与坑（V7 实测新增）

1. **本会话无 shell 工具**（工具集受限）：命令经 `subagent`（general）执行；下一会话若 shell 可用，直接按本文件命令跑即可。
2. **three r18x**：`build/three.module.min.js` 已移除且 `three.module.js` 依赖 `three.core.js` → 用 `tool/engine_build/vendor_three.mjs` 重建（esbuild，可复现）；`RGBELoader` 弃用改 `HDRLoader`；**`PCFSoftShadowMap` 被移除**（引擎已改 VSM）。
3. **HuggingFace 本机不可达**（S5 spike 第一风险）：`hf-mirror.com` 可用（实测整包下载字节数与 API 声明一致），模型下载走镜像即可。
4. **开放源可达性**：Openverse 握手失败 / Wikimedia 超时 / LoC 403（本机）；Wellcome/SMK 正常。许可门控：Getty 等 Rights-Managed 一律排除。
5. **`set VAR=1 &&` 陷阱**：cmd 下会带尾随空格，导致 env 比较失败；用 `$env:VAR='1'`（PowerShell）后再 `cmd /c`。
6. **测试计数会变**：新增测试后同步更新合同/HANDOFF 基线（当前 **303+27**）。
7. **QA 阴影类型**：`light_preset_qa` 用 headless Edge（SwiftShader）→ `effectiveProfile()='low'` 强制 PCF，预设截图**不覆盖 VSM 路径**；VSM 证据走 headed 独显专项 `node tool/vsm_regression_qa.mjs`（`--force_high_performance_gpu`）。
8. **路径追踪产物**：改 `engine.js` 后重打 `node tool/engine_build/bundle.mjs`；改 pathtracer 依赖/打包配置后重打 `node tool/engine_build/pathtracer_build.mjs`（生成 `tool/engine_build/.gen/three_global_shim.js`，已 gitignore）；首次路径追踪需 40–80s 编译（就绪后 3s 自动预热，二次亚秒级）。
9. **flutter/dart 不在 PATH**：用 `C:\dev\flutter\bin\flutter.bat` / `dart.bat`（Flutter 3.47.2 stable），命令在 `app/` 下执行。
10. 沿用 V6 坑表：format tall-style、改引擎 JS 必重打 bundle、QA 前杀 headless Edge、推送重试、Android 构建需 NDK 环境变量。
11. **路径追踪景深（D139）**：`three-gpu-pathtracer` 只在传入的相机是 `SSPathTracer.PhysicalCamera` 实例时才应用景深（`PhysicalCameraUniform.updateFrom` 对其他相机把 bokehSize 归零）→ 引擎用 `syncDofCamera()` 单例同步位置/朝向/fov；`bokehSize = 焦距/fStop`（mm），`focusDistance` 为米。**坑（已修复）**：`FEATURE_DOF` 是编译期定义——若「无景深静帧用普通相机、景深静帧改用 PhysicalCamera」，定义翻转会触发材质 `recompilation` → `compileAsync` 挂起（`isCompiling=true` 期间 `renderSample()` 完全不推进）→ samples 永远为 0 的死锁（实测 868s 零采样）。修复：`syncDofCamera()` **恒返回 PhysicalCamera**（filmGauge=36），无景深时 `fStop=1000` 把散景压到亚毫米级（≈0.08mm），保证定义恒为 1；`getPathTracerState().debug` 可查 `dofDefine/isCompiling/compilePending/bokehSize`。
12. **相机辅助 QA**：`node tool/camera_assist_qa.mjs --suffix r186s34`（headed + 独显，port 9988）验证 `getCameraAssist()` 数值 + 三张静帧（无景深/自动对焦/手动 1m）清晰度比值；报告 `docs/qa/camera-assist-*.json`。`testWidgets` 里做真实 IO 必须 `tester.runAsync` 包裹、避免 `pumpAndSettle`（FakeAsync 会挂）。**坑：Edge headed 窗口被遮挡/后台化后 `document.visibilityState='hidden'`，rAF 与定时器被冻结**（引擎主循环停摆、路径追踪永不推进，但 CDP `Runtime.evaluate` 仍可用，故不是死锁）→ 启动参数必须带 `--disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling` 并 `Page.bringToFront`；`renderStill` 返回 Promise，CDP 求值需 `awaitPromise:false` + 轮询 `__ssOutbox`（否则 awaitPromise 永久挂起）。
13. **pose_qa 接地测量滞后**：`node tool/pose_qa.mjs photo` 个别姿势第二遍渲染测量滞后会留下校准前 bounds → 表现为 `q2_pose_photos_test`「p0xx 最终 rootY 未贴地（minY=...）」；自愈：`node tool/pose_qa.mjs photo --ids p0xx`（单条两遍会重测并更新 bounds/calibrations）。本次 p050 即如此（未改 pose_qa.mjs 代码）。
14. **GitHub 单文件 100 MiB 硬限制**：fp16 RTMW3D（184.8MB）不能单文件入库 → 拆 2 片（`.part0/.part1`，各 92,394,513 B）+ 首次使用本地拼装（SHA256 一致、ORT 输出逐元素相同、本机 0.23s）；备选 Git LFS 因 CI 免费额度（1GB/月，单次 checkout 即耗 185MB）风险高，未采用。
15. **flutter_onnxruntime（Windows）无 DML**：插件 CMake 固定下载官方 CPU 版、providers 只接受 CPU/CUDA → 端上只能 CPU EP；fp16 权重 + `keep_io_types` 使 IO 仍 fp32（已在 ORT 1.24.4/1.30 验证），但 Windows 插件 FP16 支持矩阵标「计划中」，S5 主体需真机验证（失败回退 fp32/MediaPipe）；DML 仅 Python 侧（`onnxruntime-directml`，RTX 4060 fp16 8.7ms ≈57×），自编译 ORT 登记为后续项；Android 需 proguard `-keep class ai.onnxruntime.** { *; }`。
16. **onnxruntime FFI（gtbluesky 1.4.1）坑**：`OrtSession.fromFile` 在 Windows 传 `char*` 而 ORT 要 `wchar_t*` → 报 “File doesn't exist”，**必须 `OrtSession.fromBuffer(bytes, options)`**；`flutter test` 里需先用绝对路径 `DynamicLibrary.open('...\Pub\Cache\hosted\pub.dev\onnxruntime-1.4.1\windows\onnxruntime.dll')` 预加载（应用构建时插件会把 DLL 拷到 exe 旁）；pub.dev 直连下载 tarball 会反复 reset → 用 `pub.flutter-io.cn` 镜像（`https://pub.flutter-io.cn/api/archives/onnxruntime-1.4.1.tar.gz`，SHA256 与 pub.dev 官方一致）。
17. **本机 Developer Mode 未开启（非管理员）**：`flutter pub get` 结尾报 “Building with plugins requires symlink support…”，`windows/flutter/ephemeral/.plugin_symlinks` 为空 → **本机无法 `flutter build windows`（含插件）**；`package_config.json` 仍会写入，所以 `flutter test --no-pub` / `flutter analyze --no-pub` 照常可用（本机所有门禁均加 `--no-pub`）；CI（管理员）不受影响。
18. **一致性门控测试（S5）**：`SS_POSE_ACCURACY=1 flutter test --no-pub test/features/q6_pose3d_consistency_test.dart`（本机 ~13–15s；首跑曾瞬时失败 1 次，随后连续 4 次通过）；关节角断言用 中位数 ≤5° + 均值 ≤5° + p90 ≤10°（`solve_limb` 离散翻转可致单点最大 90.5°，仅记录）；参考 JSON 重生成：`python tool/rtmpose_spike.py reference`（改动管线口径时必须重跑）。

---

## 4. 新对话开场提示词（可直接粘贴）

> 继续 `D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio` 的 V7：先读 `HANDOFF_V7.md`（本文件）与 `FIX_CONTRACT_V7.0.md`（D132–D144/R61–R70）。
> 已完成 S0–S5 并推送（S5 主体的 CI 需先复核全绿）；基线 303 passed + 27 skipped。
> 请按 §2 顺序继续：**S6 资源库 100% → S7 v1.3.0 发布**。
> 纪律：每步 format/analyze/全量 test + 专项证据 + `git push` 后 CI 绿（R60/R61）才进下一步；spike 先行（R67）；数据变更重跑全量证据（R68）。
