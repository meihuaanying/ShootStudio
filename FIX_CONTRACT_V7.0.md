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
| 2026-09-23 | S2 | **显卡适配（D135）**：① C++ `windows/runner/gpu_utils.{h,cpp}` DXGI 枚举（过滤软件适配器与虚拟显示驱动：MuMu/virtual/idd 等）+ `shoot_studio/gpu` method channel（flutter_window 注册）；② `main.cpp` 读取 `%LOCALAPPDATA%\ShootStudio\gpu_mode.txt` 注入 WebView2 参数：discrete → `--force_high_performance_gpu`（Edge ≥145 实测可用）、software → `--disable-gpu --use-angle=swiftshader --enable-unsafe-swiftshader`、auto/integrated → 默认；③ Dart `services/gpu/gpu_info.dart`（适配器解析/厂商与独显标签/模式文件读写/识别后端常量）+ `services/engine/engine_reload.dart`（全局重载信号 + 引擎 GPU 渲染器 notifier）；`engine_view.dart` 监听重载信号重建 WebView 并在就绪后抓取 `getEngineStats().gpu.renderer`；`engine.js` 暴露 `gpu:{renderer,profile,api:'gpu-info-v7'}`（引擎包重打 960.9KB）；④ 设置页新增「显卡」卡片：适配器列表（型号/厂商/独显核显/显存）+ 3D 引擎四态（自动/独显优先/核显优先/软件渲染）+ 识别后端 CPU/GPU（D141 用）+ 当前引擎 GPU + 保存（热重载，未切换提示重启） | `q6_engine_test` 新增 5 项（bundle GPU 标记/模式文件往返与非法回退/适配器解析/重载信号/设置持久化）；全量 **264 passed + 26 skipped**；format 0 changed、analyze 0 问题；`flutter build windows --release` 成功 + `smoke_launch.ps1` **LAUNCH-OK**；本机适配对象：RTX 4060 Laptop 8GB（VEN_10DE）+ Iris Xe + MuMu 虚拟适配器（已过滤） |
|  |  |  |  |

---

## 6. 反模式（出现即返工）

- 极简后把「加入画板/来源许可」一起砍掉（合规与工作流红线）。
- 把 Rights-Managed 图库内容混进结果网格或安装包。
- 显卡切换后白屏/崩溃、无降级路径。
- 先写光照特性再升级 three.js（返工）。
- 用低清/水印图充数、近似图不标注、覆盖率虚报。
- 删测试/跳门禁换绿；CI 带红继续开发。
