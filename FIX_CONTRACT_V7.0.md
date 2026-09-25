# FIX_CONTRACT_V7.0 —— 画面参考极简 + 主题搜索 + 显卡适配 + 布光升级 + 姿势/识别重构 + 资源库 100%（v1.3.0）

> 生效：2026-09-22
> 关系：在 V1–V6 之上，本文件与 V6 冲突处以本文件为准；未冲突条款（R41–R60 等）继续有效。
> 执行：按 §3 顺序 **一口气跑完，中途不停**；每步有硬门禁，失败修复重跑；每步完成后 `commit + push`，保持公开仓库 CI 全绿（R61/R60）。
> 证据：完成声明必须附测试输出 / 截图 / 文件路径 / 数量统计 / 本机实测数据。**没有证据 = 没完成**。
> 前提：用户已逐项确认 D132–D144（两轮问答 + 两处纠正：Getty 移除、Step 3 顺序）；执行中不得变更，确需变更先写偏差登记。

---

## 0. 用户确认决策（D132–D144，不可再改）

### 第①项 画面参考极简 + 主题搜索（D132–D134）

| 编号 | 决策 |
|---|---|
| D132 | **画面参考模块整体极简**。保留：搜索框、结果网格、详情弹窗、我的画板、免责声明（R47 合规）、粘贴截图、本地导入、以图搜图、主题标签行（8 常用 + 更多）。移除（仅 UI 入口，数据/服务保留供离线兜底与测试）：PD 静帧库入口、我的素材包、FILMGRAB、TMDB 快捷按钮、域/意图/仅可商用筛选 chips、历史/收藏、每源状态 chips、主题包弹层。 |
| D133 | **主题驱动**：① 关键词自动匹配 40+ 主题包（zhTerms 匹配 → enQuery 扩写 + 结果重排）；② 主题标签行（8 常用，可展开全部）；③ 策划案主题联动（读当前策划案主题模块自动带入）；④ 主题包 24 → **48**（新增影视感 / 杂志大片 / 画作风格等）。 |
| D134 | **搜索范围**：影视 + 画作 + 摄影 + 平面艺术**全混合**（无域筛选 UI，引擎保留 `SourceCapability` 元数据）。新增 **7 个开放源**：Openverse、Wikimedia Commons、Wellcome、SMK、LoC（keyless API；前两者走 DoH 隧道白名单）+ NGA、Walters（无查询 API：**内置精选 CC0 索引（各约 300 件）+ 运行时热链官方图片 + SearchCache 缓存**）。**不含 Getty**（Rights-Managed 图库代理，见 R63）。默认全显 + 可切「仅可商用」；逐图标注来源/许可。 |

### 第②项 显卡适配（D135）

| 编号 | 决策 |
|---|---|
| D135 | **设置页新增「显卡」卡片**：自动 / 独显优先 / 核显优先 / 软件渲染（排障）四态 + 显示本机 GPU 信息（型号/显存/独显核显）。**DXGI 枚举**（C++ 侧，过滤 `ROOT\` 虚拟与软件适配器）经 platform channel 暴露给 Dart；WebView2 通过 `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS` 注入 `--force_high_performance_gpu`（Edge ≥145 实测可用）与 `--use-angle` 相关参数；**切换后热切重建引擎 WebView，失败提示重启应用**。端上识别后端可选 CPU/GPU（DirectML EP，device_id 按 DXGI 枚举匹配独显），无独显自动回退（R69）。本机实测：RTX 4060 Laptop 8GB + Iris Xe + MuMu 虚拟适配器，WebView2/Edge 153.0.4234.48。 |

### 第③项 布光预演升级（D136–D139）

| 编号 | 决策 |
|---|---|
| D136 | **three.js r169 → r18x 纯迁移先行**（先升级、不加特性；diff 干净、回归可定位），随后性能：GPU 档位来自 DXGI 实测（替代 WebGL 字符串猜测）、自适应质量、阴影预算/实例化。 |
| D137 | **真实感**：区域光软阴影（PCSS / LTC）、纹理投光（软箱图案/格栅/色片）、IES 光型、材质与接触阴影改进。 |
| D138 | **功能**：路径追踪静帧导出（照片级「效果预览」）、A/B 对比、预设扩充。 |
| D139 | **相机辅助**：景深预览、构图线/安全框、焦段与视野可视化增强。 |
| 顺序 | **执行顺序 = 编号顺序**：D136（升级/性能）→ D137（真实感）→ D138（功能）→ D139（相机辅助）。 |

### 第④项 姿势参考图 + 端上识别（D140–D141）

| 编号 | 决策 |
|---|---|
| D140 | **姿势参考图 12 类 × 10 = 120**：新增「杂志大片」「影视感」两类，替换手部/表情；内置 Pexels 可商用杂志风；运行时「影视感参考」按需抓 TMDB 剧照/海报/静帧（只存工作区 + 来源/许可标注，**不入包**，V3 版权结论继续有效）。 |
| D141 | **识别走 RTMPose/RTMW3D ONNX 路线**（用户要求「准确率和稳定性最高的方案」）：YOLOX/RTMDet 检测 + RTMW3D-x ONNX（rtmlib 配套转换版）单模型直接出根相对 3D（绕开 D128 的 ROI 根因）；ONNX Runtime（`flutter_onnxruntime`，Windows DirectML EP + CPU 回退，device_id 对准独显）；**模型随包**（R53/R64）；冲 D128 门禁（均值 ≤5°、90% 样本 ≤10°）；旧 MediaPipe 路径保留为兼容回退直至新路径达标。spike 先行：HF 本机不可达 → `hf-mirror.com` / DoH 隧道双通道；模型许可核验（预期 Apache-2.0）后才入库；体积/量化评估（RTMW3D-x ~369MB）。 |

### 第⑤项 资源库 100%（D142–D143）

| 编号 | 决策 |
|---|---|
| D142 | **六类 100% 全覆盖**，四层兜底：① 品牌官网 ② 授权零售商（B&H/Adorama/京东）③ 同系列近似图（`tier=series`，UI 标注「同系列示意·非该型号」）④ 补图（本地/链接 + 来源登记）。品牌配置扩展：佳能/尼康/索尼/松下/适马/富士/徕卡/大疆/智云等。淘宝/亚马逊不做本地抓取、不接付费第三方 API（用户确认）。 |
| D143 | 服装 = 品牌官网/电商模特图；道具 = 品类实拍（Pexels）。 |

### 交付（D144）

| 编号 | 决策 |
|---|---|
| D144 | **v1.3.0**：`pubspec 1.3.0+N`、`kAppVersion`、公告（V7 要点 + 已知限制）、`web/dist` 重建、合同 §5 逐项追加、HANDOFF 同步、Windows 构建 + `smoke_launch.ps1`（LAUNCH-OK）、Android APK（记录体积）、打 tag `v1.3.0` 触发 release.yml、CI 全绿（R60）。 |

---

## 1. 执行顺序与阶段门禁

| 步骤 | 内容 | 门禁 |
|---|---|---|
| **S0** | 本文件 + 基线门禁 | format/analyze/全量 test 基线记录；提交推送 CI 绿 |
| **S1** | 画面参考（D132–D134） | `q6_search_test` 扩展全绿 + 7 新源离线 fixture + live 抽测证据 + UI 截图；全量 test；CI 绿 |
| **S2** | 显卡适配（D135） | Windows 构建 + LAUNCH-OK；设置往返测试；切换独显后 WebGL renderer 字符串变化证据；DXGI 过滤虚拟适配器单测；CI 绿 |
| **S3.1** | three.js 升级（D136 前半） | 升级前后 `light_preset_qa` 27 套渲染对比（差异逐条解释）；静态门禁更新；`q6_lighting_test` 全绿；CI 绿 |
| **S3.2** | 真实感（D137） | QA 渲染对比图 + 光型/软阴影证据；CI 绿 |
| **S3.3** | 功能（D138） | 路径追踪静帧样例 + 耗时数据；A/B 对比截图；CI 绿 |
| **S3.4** | 相机辅助（D139） | 景深/构图线截图 + 测试；CI 绿 |
| **S4** | 姿势参考图 12×10（D140） | 骨架/关节/QA 全量重跑；`q2_pose_photos_test` 更新全绿；attribution；抽检图；CI 绿 |
| **S5** | 识别 RTMPose/RTMW3D（D141） | spike 报告（许可/下载通道/DML EP/量化）；`q6_pose_accuracy` 达标或登记偏差；一致性/导入流程测试；CI 绿 |
| **S6** | 资源库 100%（D142–D143） | 覆盖率报告六类 100%（含 tier 分布与四层来源）；fixture/selftest；来源抽检；CI 绿 |
| **S7** | v1.3.0 交付（D144） | 全量门禁 + 双端构建 + LAUNCH-OK + APK 体积 + tag 发布 + CI 绿 |

---

## 2. 硬规则（V7 增补，违反即返工）

- **R61 步进门禁**：每步必须 `dart format lib test`（0 changed）、`flutter analyze --fatal-infos`（0 问题）、全量 `flutter test`、本步专项测试全绿、`git push` 后 CI 全绿，才可进入下一步；失败修复重跑。
- **R62 fixture 化（延续 R48）**：所有新图源/抓取器/模型管线必须离线 fixture 测试；live 仅作证据；CI 不依赖外网。
- **R63 许可红线**：只接「开放获取机构 + 逐图开放许可」；**禁止 Rights-Managed/图库代理源（Getty Images、Shutterstock 等）进入抓取管线或统一结果网格**；新开放源全收但**逐图标注**，NC/ND 不计入「仅可商用」；影视图（TMDB）绝不入包；NGA 仅取 `openaccess=1`；Walters 采用防御性门控（pre-1928 + 有图 + 排除出借/涉版权记录）；LoC 按 Rights Advisory、SMK 按 `public_domain`、Wellcome 按许可字段逐条门控。
- **R64 模型随包（延续 R53）**：识别模型不得首次使用时下载；入库前核验许可并登记 attribution。
- **R65 体积/性能记录**：D95 不限包体，但每步记录引擎包大小、APK 体积、识别耗时与精度、静帧导出耗时。
- **R66 不回归**：V6 功能与测试不得删减，仅允许本文件明确变更项（PD 库入口、姿势分类、筛选 chips 等）；对应测试同步更新而非删除。
- **R67 spike 先行**：ONNX/DirectML、RTMW3D 下载与量化、路径追踪、three.js 升级，先做最小可行性 spike 并写合同日志，再正式实施。
- **R68 数据变更重跑证据**：姿势图 → 骨架/关节/QA 全量重跑；资源库 → 覆盖率报告重生成；报告与元数据入 git。
- **R69 硬件降级**：无独显/驱动异常/模型加载失败必须自动回退（核显/CPU/软渲/旧识别路径），不得白屏或崩溃；回退路径必须有测试。
- **R70 反模式**：低清/水印图充数、虚报覆盖率、近似图不标注、删测试换绿、跳过门禁——出现即返工。

---

## 3. 交付清单（按步骤）

### S1 画面参考（D132–D134）
1. `lib/features/refs/refs_page.dart` + `search_page.dart` 极简重做（保留清单见 D132；主题标签行 8 常用 + 更多）。
2. `lib/services/search/`：主题匹配器（zhTerms → pack，扩写 + 重排）、策划案主题联动、48 主题包；新源适配器 `openverse/wikimedia/wellcome/smk/loc/nga/walters_source.dart`；许可标注字段；「仅可商用」过滤口径。
3. NGA/Walters 索引构建脚本（`tool/build_open_index.py`，产出 `assets/content/search/open_index/{nga,walters}.json`，含来源/许可/图片 URL 证据）。
4. `NetRouter` 隧道白名单增补（api.openverse.org、commons.wikimedia.org、upload.wikimedia.org）。
5. 测试：`q6_search_test` 扩展（主题匹配、许可门控、7 源 fixture、NGA/Walters 索引完整性、极简 UI widget 测试）。

### S2 显卡（D135）
1. C++：`windows/runner/` DXGI 枚举（过滤 `ROOT\`/软件适配器）→ method channel；WebView2 参数按设置注入。
2. Dart：`lib/services/gpu/`（枚举模型/持久化 `gpu_mode`、`gpu_recognize_backend`）+ 设置页显卡卡片。
3. 引擎热切：切换后重建 WebView（失败提示重启）；识别后端切换即时生效。
4. 测试：枚举解析单测（含虚拟适配器过滤）、设置往返、引擎重建状态机、降级路径。

### S3 布光（D136–D139）
1. 引擎 JS 升级 + 适配（静态门禁 token 更新）；QA 渲染对比证据。
2. PCSS/LTC 纹理投光/IES/材质；路径追踪静帧导出；A/B 对比；相机辅助。
3. 测试：`q6_lighting_test`/`q1_3d_fidelity_test`/`q5_material_test` 等同步更新；`light_preset_qa` 全量截图。

### S4 姿势参考图（D140）
1. `tool/gen_pose_photos_v7.py`（Pexels 杂志风 12 类 × 10，新增杂志大片/影视感；替换手部/表情）→ 骨架/关节/QA 全量重跑。
2. UI：「影视感参考」（TMDB 按需抓取）入口；attribution 更新；`q2_pose_photos_test` 更新为 12×10。

### S5 识别（D141）
1. spike：模型下载（hf-mirror/隧道）、许可核验、ORT DML EP 验证、量化/体积评估。
2. `lib/services/pose/` 新服务（RTMDet/YOLOX 检测 + RTMW3D 3D + 12 关节映射 + 接地校准）；旧 MediaPipe 路径保留回退。
3. 精度对比（D128 门禁）+ 稳定性（多张/多人/低置信）+ UI 集成。

### S6 资源库（D142–D143）
1. `brands.py` 品牌扩展；授权零售商 provider；同系列兜底 tier；服装品牌图 + 道具实拍。
2. `gear_coverage.py` 100% 口径；`gear_photo_sources.json` 四层来源统计；补图入口保留。

### S7 交付（D144）
1. 全量门禁 + Windows/Android 构建 + smoke + APK 体积。
2. 版本/公告/dist/合同 §5/HANDOFF/下载页同步；tag `v1.3.0` 发布；CI 绿。

---

## 4. 环境与踩坑（V7 增补）

1. **本机双显卡**：RTX 4060 Laptop 8GB（VEN_10DE）+ Iris Xe（VEN_8086）+ MuMu 虚拟适配器（`ROOT\DISPLAY`）；DXGI 枚举必须过滤虚拟/软件适配器，DirectML device_id 按厂商匹配独显；默认 adapter 0 为核显，独显注入是真实收益。
2. **WebView2/Edge 153.0.4234.48**：`--force_high_performance_gpu` 可用（Edge ≥145）；参数经 `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS` 在环境创建时读取，热切需重建 WebView。
3. **HuggingFace 本机不可达**：RTMW3D 模型获取走 `hf-mirror.com` 或 DoH 隧道；`flutter_onnxruntime` 原生库安装期从官方仓库下载（同 flutter_litert 风险，需缓存/重试/镜像）。
4. **three.js 升级 breaking changes**：跨 r169→r18x 需逐条核对（stencil 默认关闭、RGBELoader→HDRLoader 重命名、PBR 能量守恒外观变化等）；升级与特性分开提交，diff 干净。
5. **开放源许可**：Openverse/Wikimedia 逐图许可；Wellcome/SMK/LoC 按各自 rights 字段；NGA `openaccess=1`；Walters pre-1928 防御门控；**Getty 等图库代理一律排除**。
6. 其余沿用 V6 坑表（format tall-style、引擎包重打、QA 渲染前杀 headless Edge、推送重试、Android 构建需 NDK 环境变量等）。

---

## 5. 变更日志（执行时追加）

| 日期 | 步骤 | 变更 | 证据 |
|---|---|---|---|
| 2026-09-22 | S0 | V7 合同建立：D132–D144 两轮确认（含 Getty 移除、Step 3 顺序修正、许可门控、NGA/Walters 索引方案、硬件适配）；基线门禁记录 | 本文件；基线：format 0 changed、analyze 0 问题、全量 **249 passed + 25 skipped**；硬件侦察：RTX 4060 Laptop 8GB + Iris Xe + MuMu 虚拟适配器，WebView2/Edge 153.0.4234.48 |
| 2026-09-23 | S1 | **画面参考极简 + 主题驱动 + 搜索扩展（D132–D134）**：① `refs_page.dart` 重写为极简页（搜索框 + 8 常用主题标签行 + 结果网格 + 详情弹窗 + 我的画板 + 免责声明 + 粘贴截图/本地导入/以图搜图），删除搜图工作台 `search_page.dart`（PD 别名索引拆为 `services/pd_film_index.dart`，q5 门禁改 import）；② 主题包 24→**48**（新增影视感剧照/杂志大片/画作风格/港风/新中式等），新增 `matchThemePack`（具体性规则：≥3 字或占比过半，避免短词劫持组合查询）、`commonThemePacks`（8 常用）、策划案主题联动（refs 页读最新策划案 theme 模块预填并自动检索）；③ 新增 **7 个开放源**：Openverse/Wikimedia/Wellcome/SMK/LoC（keyless）+ NGA/Walters（内置精选 CC0 索引各 300 条 + 热链 + SearchCache）；许可门控（全收但逐图标注，NC/ND 不计可商用；LoC Rights Advisory、SMK public_domain、NGA openaccess=1、Walters pre-1928+排除出借/涉版权）；`SearchEngine.allDomains` 全混合；NetRouter 白名单 + 修复 3 处隧道异步错误泄漏（zone 保护/done future/DoH try-catch，R43）；④ 构建工具 `tool/build_open_index.py`（NGA objects+published_images / Walters art+media+creators，CSV 缓存 gitignore） | `q6_search_test` **41/41**（新增：Openverse 许可/NC-ND、Wikimedia extmetadata、Wellcome、SMK 门控、LoC 门控、NGA/Walters 索引解析与资产加载、主题自动匹配、48 主题包+8 常用、allDomains）；全量 **259 passed + 26 skipped**；live **23/23** → `docs/qa/search-live-2026-09-23T12-49-14.txt`（Wellcome 6 条 PDM、SMK 10 条 CC0 可达；Openverse 握手失败/Wikimedia 超时/LoC 403 本机不可达，代码就绪待网络恢复，已在证据登记）；索引资产 `assets/content/search/open_index/{nga,walters}.json`（300+300，CC0）；format 0 changed、analyze 0 问题 |
| 2026-09-23 | S2 | **显卡适配（D135）**：① C++ `windows/runner/gpu_utils.{h,cpp}` DXGI 枚举（过滤软件适配器与虚拟显示驱动：MuMu/virtual/idd 等）+ `shoot_studio/gpu` method channel（flutter_window 注册）；② `main.cpp` 读取 `%LOCALAPPDATA%\ShootStudio\gpu_mode.txt` 注入 WebView2 参数：discrete → `--force_high_performance_gpu`（Edge ≥145 实测可用）、software → `--disable-gpu --use-angle=swiftshader --enable-unsafe-swiftshader`、auto/integrated → 默认；③ Dart `services/gpu/gpu_info.dart`（适配器解析/厂商与独显标签/模式文件读写/识别后端常量）+ `services/engine/engine_reload.dart`（全局重载信号 + 引擎 GPU 渲染器 notifier）；`engine_view.dart` 监听重载信号重建 WebView 并在就绪后抓取 `getEngineStats().gpu.renderer`；`engine.js` 暴露 `gpu:{renderer,profile,api:'gpu-info-v7'}`；④ 设置页新增「显卡」卡片：适配器列表（型号/厂商/独显核显/显存）+ 3D 引擎四态（自动/独显优先/核显优先/软件渲染）+ 识别后端 CPU/GPU（D141 用）+ 当前引擎 GPU + 保存（热重载，未切换提示重启） | `q6_engine_test` 新增 5 项（bundle GPU 标记/模式文件往返与非法回退/适配器解析/重载信号/设置持久化）；全量 **264 passed + 26 skipped**；format 0 changed、analyze 0 问题；`flutter build windows --release` 成功 + `smoke_launch.ps1` **LAUNCH-OK**；本机适配对象：RTX 4060 Laptop 8GB（VEN_10DE）+ Iris Xe + MuMu 虚拟适配器（已过滤） |
| 2026-09-23 | S3.1 | **three.js r169 → r186 纯迁移（D136 前半，不加特性）**：npm 获取 three@0.186.0（`build/three.module.js` 已非自包含，用项目 esbuild 打成自包含 minified ESM 供 `three` 别名）+ 8 个 addons 同步升级（RGBELoader 已降级为弃用 shim → 引擎改用 `HDRLoader`，features 串与 q5 门禁同步）；`vendor/THREE_LICENSE`/`NOTICE.md` 更新；未改动任何渲染特性代码 | 升级前后 `light_preset_qa` **27/27、0 失败（前后一致）**；像素差对比 → `docs/qa/three-r169-r186-diff.md`（平均 6.69/255≈2.6%，最大 clamshell 11.84；差异归因 r181 PBR 能量守恒/PMREM 改进/r183 光照重构，预期内）；`engine_mem_qa` LRU PASS + 堆增长 PASS（first 54.8 / peak 82.9 / last 43.3 MB）；`test_aim` ALL PASS；全量 **264 passed + 26 skipped**；format 0 changed、analyze 0 问题；引擎包 984KB→约 1.0MB（<2.2MB 门禁） |
| 2026-09-23 | S3.2 | **布光真实感（D137）**：① 图案片投光：`lights.js` 程序生成格栅/百叶窗纹理（CanvasTexture），`honeycomb-grid`/`softbox-grid` 走格栅、新增控光件 **`gobo-blinds`（百叶窗光影）** 走条纹，经 `SpotLight.map` 投影；`rig.js` 新增图案片夹视觉；新增预设 **`blinds-window`（百叶窗光影，28 套）**；② 软阴影：r186 移除 `PCFSoftShadowMap`（静默回退 PCF 且 `shadow.radius` 失效）→ 改用 **VSMShadowMap**（`blurSamples=8`），`shadow.radius` 随附件柔度 × 灯距变化（1–24），新增 `setSoftShadows/getSoftShadows` API + `quality_soft_shadows` 设置 + 画质面板「软阴影（VSM）」开关，性能优先档自动回退 PCF；③ 面板灯阴影代理：面板灯复用同位置 SpotLight（intensity=0）投影，阴影预算 2→3 且纳入面板灯；④ **偏差登记**：IES 光型未实现——r186 核心无 `iesMap` 属性（vendored 构建中确认），IESLoader 为独立 addon 且不支持灯具光型绑定；光型继续用测光表按附件衰减近似，后续若上游恢复 iesMap 再接入 | `q6_lighting_test` 预设 27→**28** 且新 token（setSoftShadows/getSoftShadows/gobo-blinds）全绿；`q6_engine_test` 新增软阴影持久化（默认开、关后重启保持）；全量 **265 passed + 26 skipped**；format 0 changed、analyze 0 问题；`light_preset_qa` **28/28、0 失败**（新增 `blinds-window-r186s32.png` 78.9KB，条纹投光可见）；`test_aim` ALL PASS；引擎包约 1.0MB |
| 2026-09-23 | S3.3 | **布光功能（D138）**：① **路径追踪静帧导出**（spike 先行 R67）：`three-gpu-pathtracer@0.0.24`+`three-mesh-bvh@0.9.15`（r186 兼容，`xatlas-web` 不打包）→ `tool/engine_build/pathtracer_build.mjs` 打 IIFE **`assets/engine/js/pathtracer.bundle.js`（220.4KB，SSPathTracer）**，复用引擎同一份 three（`window.__ssThree` 全局 shim），`vendor/{PATHTRACER,MESHBVH}_LICENSE` 随包（R64）；`engine.js` 新增 `renderStill({mode:'path'|'supersample',width,height,samples,bounces,factor,useCameraRig})`+`warmPathTracer()`+`stillProgress/stillRendered` 事件+`capturePhoto(token)`；软件渲染/模块加载失败自动回退超采样（`fallbackReason`，R69）；**PMREM 环境贴图修复**（`EquirectHdrInfoUniform` 不能消费 PMREM → 路径静帧期间改用原始等距柱状 HDR `studioEquirectEnv`）；② **A/B 布光对比**：`ab_compare.dart`（阈值 12/255 差异统计 + 960×416 并排合成图）+ 页面「A/B 对比」对话框（冻结 A → 调光 → 冻结 B → 差异摘要 + 存 `images/plans/AB对比_*.png`，`capturePhoto` token 路由 ab-a/ab-b）；③ **效果预览 UI**：`still_export.dart`（照片级/快速、640×480/960×720/1280×960、采样 64–512 或 2–3×、用相机机位、进度/结果预览、自动存 `images/plans/静帧_*.png`），引擎就绪后 3s 后台预热；④ **预设 28→32**：`blinds-window-hard`（百叶硬光窗影）/`clamshell-hard`（硬光夹光）/`neon-tube`（霓虹灯管）/`office-window`（办公室窗光）；⑤ **VSM 回归修复（S3.2 引入的 bug）**：r186 `WebGLShadowMap` 在 VSM 下会把 `receiveShadow` 物体也渲染进阴影贴图，灯具自身（柔光箱箱体等）位于灯前且在光锥内 → 整个场景被压黑（修复前 VSM 32.6 vs PCF 109.8，0 灯与 3 灯几乎无差异）→ `lights.js` 新增 `excludeFromShadows()`（灯具视觉不投影不接收阴影）；⑥ **偏差/限制登记**：路径追踪 16 samples 噪声大（128 可用）；灯具发光面（MeshBasicMaterial）在路径追踪中呈暗色（无自发光语义）；首次编译 40–80s（预热/二次亚秒级）；预设 QA 为 SwiftShader 低配档 → `effectiveProfile()='low'` 强制 PCF，故 VSM 证据另走 headed 独显专项（`tool/vsm_regression_qa.mjs`） | `q6_lighting_test` 预设 28→**32** + 新 token（renderStill/warmPathTracer/path-tracer/supersample/stillProgress/stillRendered/capture-token/getLightDebug）+ 路径追踪包随包测试；新增 `q6_still_test`（A/B 统计/合成/会话状态机）；全量 **278 passed + 26 skipped**；format 0 changed、analyze 0 问题；`light_preset_qa` **32/32、0 失败**（`docs/screenshots/lighting-v6/*-r186s33.png`）；`light_still_qa`（headed RTX 4060）超采样 640×480×2 = 63–103ms、路径追踪 480×360×128 首次 73.6s/二次 19.2s（≈150ms/sample）、A/B mean 1.62/255+2.4% 变化（差异中等）→ `docs/qa/light-still-ab-s33.json`；`vsm_regression_qa` **PASS**（VSM 54.3 vs PCF 54.6，ratio 0.995≥0.6；灯光增益 24≥15）→ `docs/qa/vsm-regression-r186s33.json`+3 PNG；spike 报告 `docs/qa/pathtracer-spike-report.md`；引擎包 1.1MB + pathtracer 220.4KB（<2.2MB） |
| 2026-09-23 | S3.4 | **相机辅助（D139）**：① **路径追踪景深预览**：`engine.js` 新增 `getCameraAssist()`（焦段→垂直/水平视野角、主体距离、主体处画幅高/宽、`dofAvailable`）与 `syncDofCamera()`（`SSPathTracer.PhysicalCamera` 单例、filmGauge=36、`bokehSize=焦距/fStop`、`focusDistance` 米；自动对焦 = 相机到主体（`activeSubject` + 1.35m）距离）；`renderStill` 新增 `dof:{enabled,fStop 1–22,focusMode:'auto'|'manual',focusDistance 0.3–30m}`，`stillRendered` 回传 `dof/fStop/focusDistance/focusMode`，低配/加载失败回退超采样带 `dofFallback`（R69）；**坑（已修复）**：`FEATURE_DOF` 是编译期定义，普通相机与 PhysicalCamera 混用会触发材质重编译挂起（`isCompiling=true` 期间 `renderSample()` 不推进 → 采样恒 0 死锁，实测 868s 零采样）→ 恒用 PhysicalCamera（无景深时 `fStop=1000`，散景 ≈0.08mm），`getPathTracerState().debug` 可查 `dofDefine/isCompiling`；② **构图线/安全框**：新增 `camera_helpers.dart`（`CompositionGuidePainter`：三分线、5%/10% 安全框、中心十字、画幅裁切 16:9/9:16/1:1/2.35:1 + 框外压暗 + 焦段/视野/画幅信息），机位面板「构图辅助」开关组，相机视角时叠加在 3D 视图；③ **焦段与视野可视化增强**：机位面板显示「垂直视野 x° · 水平 x° · 主体距离 x.xxm · 画幅高 x.xxm」（与 `rig.js focalToFov` 同口径：全画幅 24mm 传感器高）；效果预览对话框新增景深开关（光圈 1.4–16、对焦自动/手动 0.3–12m） | `q6_camera_test` 新增 **10 项**（FOV/画幅换算、焦段分类、构图设置、Painter、bundle token、对话框景深 UI）；`q6_lighting_test` token 追加 `camera-assist/getCameraAssist/fStop/focusDistance/PhysicalCamera/dofFallback`；全量 **290 passed + 26 skipped**；format 0 changed、analyze 0 问题；`camera_assist_qa`（headed RTX 4060，480×360×48）**PASS**：assist fov 16.07°（=期望）/主体距离 5.5m/画幅高 1.55m；主体框 p95 边缘锐度 无景深 136.0 → 自动对焦 121.0（0.89）→ 手动对焦 1m 50.1（0.369，景深生效）；payload dof=true/f1.4/自动 5.5m/手动 1.0m；`docs/qa/camera-assist-r186s34.json` + 三张静帧 PNG；`light_preset_qa` **32/32、0 失败**（r186s34，与 s33 像素完全一致 mean 0.000 = 无回归）；引擎包 1.16MB + pathtracer 220.4KB |
| 2026-09-24 | S4 | **姿势参考图（D140）**：① **分类替换**：按用户确认口径「10 类 × 12 张（字面替换手部/神态）」——去掉「手部」「神态」，新增 **「杂志大片」（editorial，p085–p096）** 与 **「影视感」（cinematic，p097–p108）**，总量维持 120（合同 D140 原文「12 类 × 10」按偏差登记）；② **抓取器** `tool/gen_pose_photos_v7.py`（Pexels 主源 + 亚洲人过滤 `asian_score>=1` + 可商用许可 + 竖幅全身门控；原地替换 24 张，更新 `photos_manifest.json`（含 candidatePool 新类目键）与 `attribution.json` 逐图登记 R63；p106 首图 MediaPipe 未检出人体 → 重取 pexels 8683443 并重提骨架）；③ **数据重建**：`extract_pose_skeletons.py extract --force`（24 张）→ `skeleton_to_joints.py build --force`（为杂志大片/影视感补 `pose_name`/`CATEGORY_TIPS`/`CATEGORY_LENS` 规则；写入 120 条、限位 42、referenceOnly 17）→ `annotate_pose_visibility.py`（partialBody 26/120）；④ **UI**：`poseCategories` 改 10 类；新增「影视感参考」入口 `cinematic_refs.dart`（TMDB 按需检索 → 只存工作区 `images/refs/` + 来源/许可标注，**不入包**，R63）；⑤ **测试**：`q2_pose_photos_test` / `g5_poses_test` 更新为 10 类 × 12（改测试不删测试 R66）；⑥ **偏差/坑登记**：合同 D140 写「12 类 × 10」，实际执行用户确认的「10 类 × 12」（替换手部/神态，总量 120）；pose_qa 已知坑：个别姿势第二遍渲染测量滞后会留下校准前 bounds → `node tool/pose_qa.mjs photo --ids p0xx` 单条重跑自愈（p050 即如此） | 证据：`node tool/pose_qa.mjs photo` 120/120 渲染 + 拼接（缺 0）、接地校准 120 条 rootY 修正、首轮失败 23 条重试 23/23；`q2_pose_photos_test` 8 用例全绿（含 p050 接地 `minY=0.0002`）；全量 **290 passed + 26 skipped**；format 0 changed、analyze 0 问题；数据：photos 120 jpg + 120 skeleton（10.45MB）、manifest 10 类 × 12、attribution 654 条；截图 `docs/pose-qa3/compare-*.png` / `overlay-*.png` / `qa_photo_state.json` |
| 2026-09-24 | S5-spike | **识别 RTMPose/RTMW3D spike（D141 / R67，结论：可行）**：① **通道**：huggingface.co 本机不可达（超时）→ **hf-mirror.com 可达**（整包下载字节数与 API 声明一致）；② **模型与许可**：RTMW3D-x ONNX（Soykaf/RTMW3D-x，apache-2.0，369,330,857 B；备镜像 bukuroo/RTMW3D-ONNX 同字节）+ YOLOX ONNX（hr16/yolox-onnx，apache-2.0；nano 3.66MB / tiny 20.2MB / s 35.9MB / m 101.3MB / l 216.7MB），均可随包（R63/R64）；③ **规格与移植口径**：输入 fp32 `[1,3,384,288]`，输出 simcc x/y/z（`output`/`1554`/`1556`）；预处理 = bbox padding 1.25 + 3:4 等比扩展 + 288×384 仿射（黑边）+ ImageNet 归一化（**BGR**）；后处理 = `locs/2` + `z_m=(z/192-1)*2.1744869` + score=min(max_x,max_y)；133 关键点 → BlazePose 33 子集 + 骨长先验米制尺度（中位数）→ 复用 `derive()` 12 关节/接地；④ **量化**（R65）：dynamic int8 92.9MB（关节角均差 **48.7°** ❌）/ static int8（30 张真图校准 QDQ）93.9MB（**22.7°** ❌）/ **fp16（keep_io_types）184.8MB（0.16° ✅ 推荐随包，体积 −47.5%）**；⑤ **EP**：ORT 1.30 CPU fp32 600.9ms / fp16 609.7ms；DML（ORT 1.24.4 + onnxruntime-directml）fp16 **8.7ms**（≈57×）但 **flutter_onnxruntime 1.8.5（MIT，内置 ORT 1.23.0）Windows 不支持 DML**（CMake 固定下载 CPU 版、插件只接受 CPU/CUDA）→ 端上走 CPU EP，DML 登记为后续自编译项；⑥ **随包方案（GitHub 100 MiB 单文件硬限制）**：fp16 拆 **2 片**（各 92,394,513 B）入库 + 首次使用本地拼装（无网络，R64）；实测拼装 0.23s、SHA256 一致、ORT 三输出逐元素相同（max diff 0.0）；⑦ **精度对比（参考）**：RTMW3D-x vs 现有 MediaPipe 参考（4 图 144 角）均差 20.13°、≤5° 35.4%——注：D141 门禁 `q6_pose_accuracy` 为「端上移植 vs Python」一致性口径（D128 现 14.48°/67%），非模型间差异 | 证据：`docs/qa/rtmpose-spike-report.md` + `rtmpose-spike-{specs,infer,angle,detectors,quant,bench,bench-dml,split}.json`；脚本 `app/tool/rtmpose_spike.py`（fetch/specs/infer/compare/detcompare/quantize/bench/split）；检测器 IoU vs yolox_m：s 0.882 / tiny 0.881 / nano 0.875 → **建议随包 yolox_tiny**；format 0 changed、analyze 0 问题、全量 290 passed + 26 skipped |
| 2026-09-24 | S5 | **端上识别 RTMPose/RTMW3D（D141）**：① **运行时**：`onnxruntime`（gtbluesky FFI 1.4.1，内置 ORT 1.15.1，Android/Windows/Linux 二进制随插件）——可在 `flutter test` 内跑真实模型（一致性门禁可执行）；弃用 `flutter_onnxruntime`（MethodChannel 测试内不可用 + Windows 无 DML）；② **纯 Dart 数学层** `lib/services/pose3d/`：几何（bbox 1.25 padding + 3:4 扩展、288×384 双线性 warp 黑边、BGR + ImageNet 归一化、NCHW；YOLOX letterbox pad=114/半像素中心）、解码（simcc argmax/2 + `z=(z/192-1)*2.1744869` + 2D 重投影；YOLOX anchor-free strides 8/16/32 + 逐类 NMS）、映射（133→BlazePose 33 + 骨长先验中位数尺度 + 髋中心 world）、拼装（fp16 分片流式 + SHA256/字节校验 + 复用与失败清理）；③ **引擎与门面**：`pose3d_engine.dart`（`Pose3dDetector` 抽象；`load(detBytes:,poseBytes:)` 用 `fromBuffer` 绕开 Windows `fromFile` wchar bug）、`pose_recognition_service.dart`（RTMPose 优先 → 模型缺失/拼装/加载失败自动回退 MediaPipe，R69；`backendLabel`/`backendNote`）；④ **UI**：`pose_import_page.dart` 换门面、状态显示后端、骨架 JSON `model` 字段按后端区分；⑤ **随包（R64）**：`app/assets/models/pose3d/`（`rtmw3d-x-fp16.onnx.part0/.part1` 各 92,394,513 B + `yolox_tiny.onnx` 20,219,662 B + `NOTICE.md` Apache-2.0 署名；pubspec assets 登记） | 证据：一致性 **PASS**（`docs/qa/pose3d-consistency-report.json`；参考 `docs/qa/pose3d-consistency-reference.json`，由 `tool/rtmpose_spike.py reference` 生成、含 clamp 同口径）worstIou **0.9942**、kpXY 1.15px、kpZ 0.0179m、scaleRel 2.82%、rootYΔ 0.0055、rootPitchΔ 2.33°、**关节均值 2.8°/p90 6.81°/中位数 0.32°**（D141 口径 均值 ≤5°、p90 ≤10° 达标）；`q6_pose3d_test` 11 项 + `q6_pose_recognition_test` 2 项 + 门控一致性 1 项；全量 **303 passed + 27 skipped**、format 0 changed、analyze 0 问题；偏差登记：① solve_limb 离散扫描 + 限位罚项存在多个近等价值（输入方向差 0.4° 即可切换最小值，Python 自对自复现）→ 关节以中位数/均值+p90 断言，最大 90.5° 仅记录；② 门控测试曾 1 次瞬时失败（随后连续 4 次通过，记为本机风险）；③ 尺度容差 5%（cv2 与 Dart `image` JPEG 解码差异 → 短骨 dxy 敏感） |
| 2026-09-24 | S6 | **资源库 100%（D142–D143）**：① 品牌配置扩展 8 家（Canon/Nikon/Sony/Panasonic/Sigma/Fujifilm/Leica/DJI，`brands.py` 共 25 家）② 新增授权零售商 provider（`providers/retail.py`：B&H/Adorama best-effort + 离线 fixtures；PROVIDER_ORDER official→retail→jd→amazon→taobao→keyword）③ 同系列近似兜底层 `series_fallback.py`（`tier=series` + `extra.refId` 可追溯、禁链式借用、donor 必须带本地池文件）④ 开放图源氛围实拍兜底（`keyword.py` 扩展 light/camera/lens，`tier=atmosphere` 标注）⑤ `normalize_tiers.py` 补齐 37 条历史开放图源 tier/layer ⑥ `gear_coverage.py` 100% 口径（TARGETS 全 1.0、byTier/byLayer/fallbackLayers 四层来源统计 → `docs/qa/gear-coverage-v7.json`）⑦ 来源抽检门禁 `gear_sources_spotcheck.py`（确定性抽样 12 条，R63/R70）⑧ CI 新增 3 个 Linux 门禁步骤（selftest / coverage / spotcheck）⑨ 偏差登记：服装维持 Pexels 可商用模特图（品牌官网/电商图反爬 + 版权风险，D143 未逐字执行）；零售商层本轮数据 0 条（同因） | 证据：覆盖率六类 100%（camera 111/111、lens 197/197、light 157/157、accessory 28/28、clothing 9/9、props 14/14；pass=true、missingTotal=0、exit 0）；byTier {product 366 / atmosphere 76 / series 74}；byLayer {builtin 289 / official 98 / keyword 76 / series 44 / open 9}；fallbackLayers {official 98 / series 44 / retail 0 / manual 0}；sources 218 条逐条登记（official 98 / pexels 76 / series-fallback 44）；来源抽检 12/12（`docs/qa/gear-sources-spotcheck.json`）；`selftest.py` PASS（3 品牌/零售商/端到端/断点续跑/失败重试）；`q6_gear_test` 7/7；全量 303 passed + 27 skipped；format 0 changed、analyze 0 |
| 2026-09-25 | S7 | **v1.3.0 发布（D144）**：① 版本同步：`app/pubspec.yaml` 1.2.0+7 → **1.3.0+8**、`updater.dart` `kAppVersion='1.3.0'`、`web/public/announcements.json`（version 1.3.0 + 9 条 note + downloads 直链）、`web/src/pages/{index,downloads,changelog}.astro`（`PUBLIC_APP_VERSION` 注入；`web/dist/` 为 gitignore，由 release.yml 重建）；② 双端构建（本机）：Windows release `flutter build windows --no-pub --release` 成功 + `tool/smoke_launch.ps1` **LAUNCH-OK**（1602 文件 / 437.6MB 未压缩）、Android `flutter build apk --release` → **`app-release.apk` 412.0MB**（v1.2.0 209.0MB；+203MB ≈ RTMW3D-x fp16 184.8MB + YOLOX-tiny 20.2MB 随包，R64）；③ 门禁：format 0 changed（167 files）、analyze 0 问题、全量 **303 passed + 27 skipped**；④ 偏差/坑登记：本机 Android 构建受 github.com 不可达影响（dartcv4 的 CMake FetchContent 需下载 OpenCV 4.13.0 源码）→ 用本地已有 tarball（95,420,275 B）配 `file://` 补丁构建（仅本机 pub cache，不入仓）；本机 Windows 构建需为 17 个插件建 junction 绕过 Developer Mode 符号链接限制 | 证据：`app/build/windows/x64/runner/Release/`（LAUNCH-OK 输出）、`app/build/app/outputs/flutter-apk/app-release.apk` 412.0MB、format/analyze/test 输出、tag `v1.3.0` 触发的 release.yml run（见 HANDOFF §0） |
|  |  |  |  |

---

## 6. 反模式（出现即返工）

- 极简后把「加入画板/来源许可」一起砍掉（合规与工作流红线）。
- 把 Rights-Managed 图库内容混进结果网格或安装包。
- 显卡切换后白屏/崩溃、无降级路径。
- 先写光照特性再升级 three.js（返工）。
- 用低清/水印图充数、近似图不标注、覆盖率虚报。
- 删测试/跳门禁换绿；CI 带红继续开发。
