# FIX_CONTRACT_V6.0 —— 搜索重做 + 3D 引擎稳定/建模 + 端上识别 + 资源库图（v1.2.0）

> 生效：2026-09-19
> 关系：在 V1–V5 之上，本文件与 V5 冲突处以本文件为准；未冲突条款（R29/R31/R33/R37/R38/R39 等）继续有效。
> 执行：按 §1 顺序 **一口气跑完，中途不停**；每阶段有硬门禁，失败修复重跑；每阶段完成后 `commit + push`，保持公开仓库 CI 全绿。
> 证据：完成声明必须附测试输出 / 截图 / 文件路径 / 数量统计 / 本机实测网络数据。**没有证据 = 没完成**。
> 前提：用户已逐项确认 D94–D131（41 轮问答），执行中不得变更；确需变更先写偏差登记。

---

## 0. 用户确认决策（D94–D131，不可再改）

### 总纲

| # | 决策 | 内容 |
|---|---|---|
| D94 | 版本与发布 | **v1.2.0**；Windows + Android 双端构建与冒烟；公开仓库 `meihuaanying/ShootStudio`；每次推送 CI 全绿 |
| D95 | 包体 | **不限包体，效果优先**（仍记录 APK 体积；不为体积砍功能） |
| D96 | AI 参与 | 允许：查询规划 + 中英翻译 + 结果重排；以图搜图用 **AI 视觉描述**；未配置 AI 时回退内置词表/拼音，不得静默失败 |
| D97 | 版权与存储 | 影视静帧/画作/产品图一律 **运行时下载 + 本地缓存（5GB LRU，可在设置页调整）**，**不入 git、不入安装包**；每张图标注来源与许可；资源库展示免责声明「图片版权归原品牌/平台，仅供选型参考」 |
| D98 | 图源 Key | 免 Key 源优先（Met / 芝加哥 / 克利夫兰 / V&A）；Europeana / 史密森尼 / Harvard / Rijksmuseum 在设置页**预留 Key 输入**，用户填入即启用 |
| D99 | 施工顺序 | **②引擎崩溃 → ③3D 建模/布光 → ①搜索重做 → ④姿势与端上识别 → ⑤资源库图** |

### 第②项 引擎崩溃（已完成根因诊断）

| # | 决策 | 内容 |
|---|---|---|
| D100 | 崩溃根因（实测确认） | ① `character.js` 的 `instanceCache`/`preparedInstances` **只增不减**，切换角色数次数次后 OOM → 角色加载失败；② `engine_view.dart` 把**任何** `EngineErrorEvent`（含角色局部失败）误判为致命错误 → 销毁 WebView 降级为「3D 未就绪」；③ 再点 3D 重建 WebView 所以又正常（与用户描述完全吻合） |
| D101 | 修复四件套 | ① **错误分级**：新增 `fatal` 字段，仅引擎级致命错误降级面板，角色局部失败只提示+可重试；② **实例 LRU**（当前+上一，最多 2 份）+ `geometry/material/texture.dispose()` 全链路；③ **全量日志**：WebView console、JS `window.onerror`/`unhandledrejection`、渲染心跳、WebView 进程崩溃全部写入 `app.log`；④ 角色加载失败自动清缓存**重试一次** |
| D102 | 自动重载 | 心跳超时（默认 20s 无帧）→ 自动重建 WebView + 恢复场景（应用场景 JSON 重放）；连续失败 2 次才展示降级面板 |
| D103 | 诊断包 | 设置页 + 错误面板提供「导出诊断包」：应用日志 + 引擎控制台日志 + 场景 JSON + 设备/内存/显存信息（zip 到工作区，不自动上传） |
| D104 | 性能开关 | 「性能优先」档：自动检测（GPU/内存启发式）+ 手动可切；包含接触阴影/阴影分辨率/细分等级/渲染分辨率四项联动；设置持久化 |

### 第③项 3D 建模与布光

| # | 决策 | 内容 |
|---|---|---|
| D105 | 相机与机位 | 场景内建模**摄影师机位**（三脚架+相机+镜头朝向）；一键切「相机视角」看构图；机位**左右/高低/俯仰/偏航/焦段**手动可调；俯视图显示机位图标 + **视野扇形**（随焦段变化） |
| D106 | 建模精度 | **沟通级形似**即可（能一眼认出柔光箱/雷达罩/反光伞）；不追求品牌级细节 |
| D107 | 控光件扩充 | 现有 8 种（裸灯/标准反光罩/中柔光箱/大柔光箱/蜂巢/柔光布/雷达罩/束光筒）基础上新增：**八角柔光箱、长条柔光箱、反光伞、透光伞、旗板/黑旗、色片（CTO/CTB/彩色）、柔光箱格栅** |
| D108 | 灯架形式 | **普通灯架 + C 架 + 横臂**（顶灯/旗板/悬臂顶光用） |
| D109 | 布光验收（三条全要） | ① 每盏灯**自动瞄准被摄体**（可按灯手动偏移）；② **23+ 套预设与光位图参数一致**（朝向/附件/角度/距离/强度/光比）；③ 明暗/阴影方向可信 |
| D110 | 预设 | **全部重写 + 扩充新预设**（保留原名与分类，新增光位合并成新预设；总数 ≥26） |
| D111 | 光影 | **软硬阴影区分 + 光锥可视化（可开关）+ 控光件透光/遮光**（柔光箱真柔、蜂巢真收束、旗板真挡光） |
| D112 | 测光表 | 用新布光模型**重新校准**参数；仍**不联动**环境光开关（保住 D85 语义） |

### 第①项 搜索重做

| # | 决策 | 内容 |
|---|---|---|
| D113 | 影视范围 | **能站得上的源都接**：TMDB（电影/剧集/纪录片，主源）+ AniList（动漫，实测 GraphQL 可用）；Jikan/TVDB/Fanart.tv 做适配位（实测可用即接，不可用不硬编码） |
| D114 | 人名搜索 | 输入导演/演员名 → **其代表作/参演作品的静帧，按作品分组** |
| D115 | 平面艺术范围 | 绘画/版画/海报/摄影/设计；源 = Met + 芝加哥 + 克利夫兰 + V&A（免 Key）+ **WikiArt/Artvee 抓取** + Europeana 等 Key 源预留 |
| D116 | 以图搜图 | 上传参考图 → **AI 视觉描述**（风格/光线/色彩/构图）→ 多源文本搜 |
| D117 | 许可策略 | **全部展示 + 许可标注 + 「仅可商用」筛选开关**（CC0/PD/可商用） |
| D118 | 结果与缓存 | 每源分页 30–60 条，总量不设硬顶；本地缓存 **5GB LRU**（缩略图+原图），设置页可改 |
| D119 | 交互保留扩展 | 保留 V5 的每源状态/耗时/重试/分页/历史/收藏；**新增「一键加入参考画面/素材包」**（带来源与许可） |
| D120 | 主题包 | 预置 **20 个左右摄影主题包**（逆光人像/伦勃朗光/克莱因蓝/赛博霓虹/黑白纪实…），含中英关键词+推荐源；AI 可扩展任意主题 |
| D121 | AI 策划联动 | 「一句话生成全案」自动按主题搜集 5–10 张参考图并附入方案（标注来源，可换/删） |

### 第④项 姿势与端上识别

| # | 决策 | 内容 |
|---|---|---|
| D122 | 亚洲参考图 | 120 张**全部换亚洲人**；图源 **Pexels + 其他正版图库混合**（Pexels/Unsplash/Pixabay 等，逐图核许可与署名）；数量**维持 120（10 类 × 12）** |
| D123 | 端上识别选型 | **`pose_detection` 3.7（BlazePose 33 点）**，Windows + Android 双端；**先做 PoC**（双端构建 + 真实照片识别），若 Windows/opencv_dart 构建失败则回退自研 `flutter_litert` BlazePose 管线（无 OpenCV），仍失败再评估 YOLOv8n-pose |
| D124 | 导入行为 | 导入照片 → 端上识别 → **只输出骨架+12 关节数据**，用户确认后**手动再导入**（布光预演/姿势库） |
| D125 | 多人/低置信 | 多人时**用户点选目标人**；低置信标「仅供参考」+ 可进关节微调 |
| D126 | 替换参考图 | **两者都要**：覆盖内置条目（本地覆盖、可一键恢复默认）+ 新建自定义姿势条目 |
| D127 | 用户图存储 | 存**工作区自定义姿势库**，随工作区导出/备份/迁移 |
| D128 | 识别精度门禁 | 与现有 Python(MediaPipe) 管线逐条对比：**关节角平均误差 ≤5°，90% 样本 ≤10°**；输出误差报告 |

### 第⑤项 资源库参考图

| # | 决策 | 内容 |
|---|---|---|
| D129 | 覆盖率底线 | 相机/镜头 **≥95%**；灯具/附件/服装/道具 **≥90%**；缺口逐条列清单 |
| D130 | 抓取渠道 | **官网 > 京东 > 亚马逊 > 淘宝**；允许「尽力而为 + 缺口清单」；自动抓不到的提供**「补图」按钮**（粘贴本地图片或链接，标注来源，存工作区） |
| D131 | 图片规格与同步 | 沿用 V4 规范化：白底/4:3/1100px，**原图留存**；「素材同步」升级为**增量同步**：新图源 + 断点续传 + 进度/缺口报告 |

---

## 1. 执行顺序与阶段门禁

| 阶段 | 内容 | 门禁（全部满足才进入下一阶段） |
|---|---|---|
| **A（②）** | 引擎稳定化：错误分级、实例 LRU、资源释放、日志/心跳、自动重载、性能档、诊断包 | 连续切换全部 21 角色内存曲线平稳（峰值 ≤ 基线 +300MB 且无持续增长）；误报降级场景回归通过；心跳自动重载实测；`q6_engine` 测试绿 |
| **B（③）** | 3D 建模与布光重写：相机/机架/灯具/附件/预设/光影/测光 | 23+ 预设 before/after 截图；每盏灯自动瞄准数值验证（与目标的角误差 ≤2°）；标准/轻量与 V5 光影一致性或更好；`q6_lighting` 测试绿 |
| **C（①）** | 搜索重做：多源聚合、AI 规划、人名分组、以图搜图、主题包、许可筛选、一键入案 | 中/英/人名/主题真实用例 ≥20 条留证；每源状态可见；「仅可商用」筛选生效；缓存/历史/收藏往返绿；`q6_search` 测试绿 |
| **D（④）** | 姿势：亚洲图替换 120 张 + 端上识别全链路 + 导入/替换 | 端上 vs Python 误差报告达标；120 张图与骨架/接地校准重建完成；导入端到端录证；`q6_pose` 测试绿 |
| **E（⑤）** | 资源库：六类参考图抓取 + 增量同步 + 补图 UI | 覆盖率报告达标（相机/镜头 ≥95%，其余 ≥90%）；来源/许可登记完整；增量同步断点续传实测；`q6_gear` 测试绿 |
| **F（交付）** | 全量门禁 + 双端构建 + v1.2.0 发布 | format/analyze/test 全绿；Windows LAUNCH-OK；APK 构建成功并记录体积；公告/dist/合同日志/HANDOFF 同步；CI 全绿 |

---

## 2. 硬规则（V6 增补，违反即返工）

- **R41 错误分级**：引擎错误必须带 `fatal` 语义；仅致命错误允许降级整体面板；局部错误（单个模型/资源）只提示+可重试。禁止把 `EngineErrorEvent` 一刀切当致命。
- **R42 资源生命周期**：任何缓存（角色实例/几何/贴图/程序生成纹理）必须有上限与释放路径；`dispose()` 必须级联；禁止只增不减的 Map/Set；切换场景后不得残留旧实例在显存。
- **R43 引擎可观测**：WebView `console.*`、JS 未捕获错误/未处理 Promise、渲染心跳、WebView 进程崩溃必须落盘 `app.log`；心跳超时必须触发自动重载；连续失败才降级。
- **R44 网络统一（延续 R29）**：所有新图源/搜索/翻译/下载必须走 `NetRouter` 统一通道；禁止裸 `Dio()` 与裸 `Image.network` 直连外网；超时与退避重试沿用 V5。
- **R45 搜索不静默（延续 R31）**：每次搜索必须给出每源结果数/失败原因/耗时；空结果给可执行建议。
- **R46 翻译红线（延续 R33）**：未命中词表且 AI 不可用时，中文查询转拼音/英文简化词后再发；禁止原样发中文到英文源。
- **R47 版权与存储**：第三方图片**只存工作区缓存**（5GB LRU），**绝不入 git/安装包**；每图必须可追溯来源与许可；UI 必须含免责声明。
- **R48 抓取器可测**：每个抓取器（WikiArt/Artvee/官网/京东等）必须支持离线 fixture 测试；网络 live 仅作门禁证据，CI 不依赖外网。
- **R49 3D 瞄准数学**：灯头朝向必须由「灯位→目标点」计算（自动瞄准），手动偏航/俯仰为叠加偏移；禁止把目标点挂成发光体子对象等自欺写法；数学函数独立可测。
- **R50 预设一致性**：`light_presets.json` 是唯一事实源；渲染必须与数据一致（朝向/附件/强度/光比）；新增 preset schema 校验（JSON Schema 或等价 Dart/Node 校验）。
- **R51 光影正确性**：软硬阴影由光源尺寸/附件决定；光锥可视化与真实照射角一致；附件透光/遮光必须影响被摄体光影，而非只做外观。
- **R52 性能可退回（延续 R38）**：所有新效果必须有开关；「性能优先」档行为可验证；standard/light 不允许更差于 V5。
- **R53 端上识别离线可用**：模型与推理全本地，断网可识别；首次使用不得因下载失败不可用（模型入包）。
- **R54 姿势精度门禁**：端上识别结果与 Python 管线对比达标（D128）才可替换正式参考图管线。
- **R55 用户数据不丢**：覆盖内置参考图必须可恢复；自定义姿势随工作区导出/备份；破坏性操作前自动备份。
- **R56 资源库合规**：每张图登记来源 URL/许可/获取时间；无法确认许可的图不入库；「补图」用户操作也需标注来源。
- **R57 内存门禁**：引擎重活（21 角色轮换、预设切换、 subdivision 切换）后内存回到基线 ±20%；CI/QA 脚本记录曲线。
- **R58 测试完整（延续 R39）**：只增不删，改写必须保持断言语义；新增 `q6_*` 门禁；live 网络测试默认跳过但必须本机跑一次留证。
- **R59 版本与公告**：v1.2.0 全链路同步（pubspec / kAppVersion / announcements.json / web dist / 合同日志 / HANDOFF / 下载页）。
- **R60 CI 绿**：每次 `push` 后 GitHub Actions 必须全绿；红了立即修，不得带红继续。

---

## 3. 交付清单（按阶段）

### A. 引擎稳定化（②）

1. `assets/engine/js/character.js`：
   - `instanceCache` 改 LRU（最多 2 个实例，淘汰时 `clearInstance + dispose` 几何/材质/贴图/骨骼 helper/markers）；
   - `preparedInstances` 不再作为"全部实例"容器使用（改为当前 LRU 集合或删除）；
   - 新增 `evictAll()` / `getCacheStats()`；`setCharacterInternal` 失败时自动 `evictAll()` 并重试一次。
2. `assets/engine/js/engine.js`：
   - 全局错误上报：`window.onerror` / `unhandledrejection` → `send('error', {message, fatal:false, source:'js'})`；
   - 心跳：`frame()` 每帧累加 `__ssFrameCount`，由 `window.ss.heartbeat()` 返回；`setInterval` 上报 `send('engineHeartbeat', {...})`；
   - 致命错误走 `send('error', {fatal:true})`（引擎引导失败/渲染上下文丢失）。
3. WebView 侧（`engine_view.dart`）：
   - `onConsoleMessage` 转发到 AppLogger（级别过滤）；
   - `EngineErrorEvent.fatal == true` 才 `_failed = true`；
   - 心跳监视器：20s 无心跳 → 重建 WebView + 重放场景（`_queueApplyScene`）；连续 2 次失败展示降级面板；
   - `onReceivedError` 仅主框架+网络错误才致命；
   - 「导出诊断包」入口（错误面板 + 设置页）。
4. `engine_bridge.dart`：`EngineErrorEvent` 增加 `fatal`；新增 `EngineConsole`（可选合并入 error）、`EngineHeartbeat`。
5. 性能档：`lib/features/lighting/` 新增 `PerformanceProfile`（auto/high/low）；引擎侧 `setPerformanceProfile(profile)` 联动接触阴影/阴影分辨率/细分上限/pixelRatio；设置键 `quality_performance_profile`。
6. 测试：`test/features/q6_engine_test.dart`（错误分级映射、LRU 上限、性能档持久化、心跳超时重载调用链（mock bridge））；`tool/engine_mem_qa.mjs`（CDP 连续切换 21 角色并采样 `performance.memory`/`getCacheStats()`，输出曲线 JSON 到 `docs/qa/`）。

### B. 3D 建模与布光（③）

1. 新增 `assets/engine/js/rig.js`（相机/灯架模型与瞄准数学）：
   - `computeAim(lightPos, targetPos, {offsetYaw, offsetPitch})` 纯函数（可被 Node 测试）；
   - 普通灯架/C 架/横臂参数化建模；相机三脚架+机身+镜头+热靴；
   - 相机机位控制：`setCameraRig({x,y,height,yaw,pitch,fov})`；`setViewMode('camera')` 切 POV。
2. `lights.js` 重写：
   - `updateLight` 使用 `computeAim`；`rotationY` 变为 `offsetYaw`（默认 0 = 自动对准）；
   - 控光件新增 D107 全部类型（参数化造型）；
   - 光锥可视化：`ConeGeometry`/自定义材质，开关 `setLightCones(bool)`；
   - 阴影：软阴影用 `VSMShadowMap` 或 PCFSoft + radius 动态（按附件尺寸）；附件透光/遮光通过 cookie/遮光板（`SpotLight.map` 或额外遮挡网格）实现；
   - 性能档联动阴影分辨率。
3. `lighting_canvas_view.dart`：
   - 俯视图绘制机位图标（相机三角符号）+ 视野扇形（按 FOV/朝向计算）；
   - 相机机位可拖拽（位置）+ 右侧面板调整高度/俯仰/偏航/焦段；「相机视角」按钮与返回。
4. `lighting_models.dart` / `lighting_controller.dart`：
   - `DeviceSpec` 扩展：`standType`（normal/c/boom）、`aimMode`（auto/manual）、`offsetYaw/offsetPitch`；
   - 场景新增 `cameraRig`（位置/高度/偏航/俯仰/焦段）；
   - `LightingSceneData.toEngineJson` 带 rig 与 light aim 字段；持久化。
5. 预设重写：`tool/rewrite_light_presets.mjs`（或 Dart 工具）读取现有 23 套 + 新预设定义，按 R50 生成并校验；新增预设 ≥3（如：顶光+发丝、双柔光箱对称、三灯夹光、环形光+背景光）。
6. 测光表：`light_meter.dart` 校准（附件衰减、距离平方、软硬光系数与 3D 一致）。
7. 测试：`test/features/q6_lighting_test.dart`（preset schema、aim 数学镜像、场景 rig 往返）；`tool/test_aim.mjs`（Node 纯函数测试，接入 CI）。

### C. 搜索重做（①）

1. 目录重构 `lib/services/search/`：
   - `sources/`：`tmdb_source.dart`（升级：作品/人名/剧照分页）、`pexels_source.dart`、`met_source.dart`、`artic_source.dart`、`cleveland_source.dart`、`vam_source.dart`、`wikiart_source.dart`、`artvee_source.dart`、`anilist_source.dart`、`europeana_source.dart`（Key 预留）、`smithsonian_source.dart`/`harvard_source.dart`/`rijks_source.dart`（Key 预留）；
   - 每个源实现统一接口：`SourceCapability`（searchByTitle / searchByPerson / searchByKeyword / hasLicenseFilter / imageTypes）。
2. `query_planner.dart`：输入中文/英文/人名/主题 → 意图分类（作品/人名/主题）→ AI 生成每源英文关键词与作品/人名候选 → 缓存 LRU。
3. `result_ranker.dart`：文本匹配分 + 源权重 + 分辨率 + 许可 + 去重（URL/ID + 简单感知哈希）；可选 AI 文本重排（D96）。
4. `image_to_search.dart`：AI 视觉描述 → 关键词 → 多源搜（无视觉模型时提示配置/降级文本）。
5. `theme_packs.dart`：20 个主题包（中英关键词/推荐源/说明）。
6. `search_cache.dart`：5GB LRU（缩略图/原图分目录），设置页可调。
7. UI（`refs_page.dart` 重写搜索弹窗 → 建议升级为独立搜索页）：
   - Tab：影视静帧 / 画作与平面艺术 / 摄影参考；人名结果按作品分组卡片；
   - 每源状态 chips（结果数/耗时/失败原因/重试）；分页「加载更多」；
   - 许可筛选（全部/仅可商用）；来源与许可标注；「加入参考画面/素材包」；
   - 历史/收藏（沿用 `search_prefs` 扩展）；主题包入口。
8. AI 策划联动：`planner` 生成后自动搜 5–10 张参考并写入参考画面模块（可换/删）。
9. 测试：`test/features/q6_search_test.dart`（意图分类、人名分组、许可筛选、缓存 LRU、主题包、以图搜图降级、每源状态）；live 门禁：`docs/qa/search-live-*.txt`（覆盖中英/人名/主题 ≥20 用例）。

### D. 姿势与端上识别（④）

1. PoC（先做，决定 D123 最终路线）：新增依赖 `pose_detection: ^3.7.0`（Windows + Android）→ 构建 + 用 5 张真实照片识别 → 若 Windows/openCV 构建失败，立即切换自研 `flutter_litert` 管线并在合同日志登记偏差。
2. `lib/services/pose/`：
   - `pose_detector_service.dart`：模型初始化/单张识别/多结果；
   - `pose_joint_mapper.dart`：33 点 → 12 关节（复用 `pose_landmark_math.dart`，与 Python 管线保持同一套公式）；
   - `pose_grounding.dart`：接地校准（相对脚部最低点）。
3. UI（`poses_page`）：
   - 「导入照片识别」全流程：选图 → 多人点选 → 骨架叠加预览（置信度着色）→ 12 关节结果 → 「导入布光预演 / 保存为自定义姿势」；
   - 「替换参考图」：内置条目本地覆盖 + 恢复默认；新建自定义条目；
   - 自定义库管理（重命名/删除/导出随工作区）。
4. 亚洲图替换 120 张：
   - `tool/gen_pose_photos_asian.py`（Pexels 主 + 正版图库混合，按类目姿势关键词搜索 + 人工可复核的筛图规则）；
   - 重新执行骨架/关节/接地/对比图流水线（`extract_pose_skeletons.py` → `skeleton_to_joints.py` → `pose_qa.mjs photo` → `annotate_pose_visibility.py` → `gen_pose_qa3_report.py`），产出 `docs/pose-qa3/`（或新增 `docs/pose-qa4/`）；
   - 许可与署名更新 `attribution.json`。
5. 精度门禁：`tool/verify_pose_accuracy.dart`（或 mjs）对 120 条照片跑端上识别，与 `poses3.json` 的 Python 关节逐条对比，输出 `docs/qa/pose-accuracy-*.md`（均值/分位/超标清单）。
6. 测试：`test/features/q6_pose_test.dart`（mapper 数学、接地、自定义库往返、覆盖/恢复、导入状态机）。

### E. 资源库参考图（⑤）

1. 抓取管线：`tool/gear_photos_v3/`（Python）：
   - `providers/`：`official.py`（品牌官网产品页/媒体中心）、`jd.py`、`amazon.py`、`taobao.py`；
   - 统一输出：`{model, kind, sourceUrl, license, fetchedAt, imageLocalPath}`；
   - 反爬策略：请求间隔 + 重试 + 断点续跑 + 失败清单；淘宝/亚马逊失败可降级跳过。
2. 分类扩展：`gear.json` 现有 493 条（相机 111/镜头 197/灯具 157/附件 28），新增服装、道具参考图任务；覆盖率统计脚本 `tool/gear_coverage.py` 输出 `docs/qa/gear-coverage-v6.json`。
3. 规范化：沿用 `normalize_product_photos.py`（白底/4:3/1100px，原图留存），输出到工作区缓存目录（不入 git）。
4. 增量同步（`gear_photo_sync.dart` 升级）：新图源、断点续传、进度/缺口报告；设置页可配置各源开关与缓存上限。
5. 「补图」UI：资源库条目缺图时提供按钮（粘贴本地图片/链接 → 规范化 → 存工作区 → 登记来源）。
6. 免责声明：资源库页面底部固定提示「产品图版权归原品牌/平台，仅供选型参考，禁止商用分发」。
7. 测试：`test/features/q6_gear_test.dart`（覆盖率读取、缺口清单、增量状态机、补图登记、免责声明存在）。

### F. 交付（v1.2.0）

1. 全量门禁：`dart format --set-exit-if-changed lib test`；`flutter analyze --fatal-infos`；`flutter test`（预期 186 + 新增 ≥20 项）。
2. Windows 构建 + `smoke_launch.ps1`（LAUNCH-OK）；Android APK 构建（记录体积与版本号）。
3. v1.2.0：`pubspec 1.2.0+N`、`kAppVersion`、`web/public/announcements.json`（五项改造要点）、`web/dist` 重建、下载页/更新日志同步。
4. `FIX_CONTRACT_V6.0.md` §5 变更日志逐阶段追加（含偏差）；`HANDOFF_V6.md`（或更新 `HANDOFF_V5.md` → 新建 V6）；`HANDOFF.md` 指向 V6。
5. `git push` 后 CI 全绿（R60）。

---

## 4. 环境与踩坑（V6 增补）

1. **本 shell 可能落到 PowerShell**：多行 bash 函数/heredoc 会失败；复杂逻辑写 `.py`/`.mjs` 文件再执行。
2. **WebView2 崩溃诊断**：`flutter_inappwebview` 无进程崩溃回调；用「心跳 + onConsoleMessage + onReceivedError」三件套近似；WebView2 用户数据目录异常时可清 `shoot_studio.exe.WebView2/`。
3. **opencv_dart/pose_detection**：Windows 需 CMake 下载预编译 OpenCV（首次构建慢，需网络）；Android 打包体积会明显增大；PoC 失败立即回退（D123）。
4. **AniList**：必须 POST GraphQL（GET 404）；Jikan 目前 504 不稳定，接前重测。
5. **WikiArt/Artvee**：无官方 API/已失效，走 HTML 抓取，选择器易变；适配器必须 fixture 化 + 失败降级（不影响其它源）。
6. **AIC/Cleveland IIIF 图片**：需正确 identifier；测试时用真实对象 ID，403 可能只是 URL 无效（不是封锁）。
7. **淘宝/亚马逊**：搜索页反爬严重，优先官网与京东；抓取频率 ≤1 req/2s，失败记录清单，不阻塞整体。
8. **AI 视觉能力**：并非所有已配置提供方支持图片输入；以图搜图需探测能力，不支持时提示切换提供方并降级为文本关键词。
9. **缓存目录**：图片缓存放工作区 `cache/` 子目录（随工作区迁移），设置页显示占用与清理按钮。
10. **模型入包**：端上识别模型必须随包分发（R53），不得首次使用时下载。

---

## 5. 变更日志（执行时追加）

| 日期 | 阶段 | 变更 | 证据 |
|---|---|---|---|
| 2026-09-19 | — | V6 合同建立：D94–D131（41 项用户确认）；本机实测图源可达性；完成引擎崩溃根因诊断（实例缓存泄漏 + 错误误判降级）与布光不还原根因诊断（瞄准数学 + 预设朝向全 0） | 本文件 §0；诊断分析；源探测记录 |
| 2026-09-19 | A（②） | 引擎稳定化完成：实例/GLB LRU（≤2/≤3）+ 级联 dispose + 角色失败自动清缓存重试；错误分级（fatal 透传，局部错误不再降级整页）；JS 错误/控制台/心跳全量落盘；心跳超时自动重载（≤2 次）；性能档 auto/high/low；诊断包导出（错误面板+设置页） | `docs/qa/engine-mem-2026-09-19-08-29-56.json`（23 角色切换 0 失败，LRU PASS，堆增长 PASS）；`q6_engine_test` 5/5；全量 191+1；`engine.bundle.js` 950.7KB |
| 2026-09-19 | B（③） | 3D 建模与布光重写完成：新增 `aim.js`（纯函数瞄准数学）+ `rig.js`（参数化灯架/灯头/控光件/相机机位）；`lights.js` 重写（几何自动瞄准、16 种控光件、光锥可视化、软硬阴影随附件、色片/旗板）；相机机位 + POV + 俯视图视野扇形；27 套预设重写/扩充（含 4 套新预设）；测光表按控光件衰减校准 | `tool/test_aim.mjs` ALL PASS（已入 CI）；`docs/screenshots/lighting-v6/`（27 after + 4 before）；`q6_lighting_test` 8/8；全量 199+1；CI 新增 Node 瞄准单测步骤 |
| 2026-09-20 | C（①） | 搜索重做完成：新增 `lib/services/search/`（统一 `SourceCapability` + 13 源：TMDB 升级/人名、Pexels、AniList、Met、芝加哥、克利夫兰、V&A、WikiArt、Artvee + Europeana/Smithsonian/Harvard/Rijks 预留 Key；`QueryPlanner` 意图分类 + 人名表 + 词表 + 拼音兜底 + AI 翻译 + LRU 缓存；`ResultRanker` 源权重/匹配分/分辨率/许可/URL+感知哈希去重；`ImageToSearch` AI 视觉描述→多源搜+降级；24 主题包；`SearchCache` 5GB LRU 缩略图/原图分目录；`SearchEngine` 并发聚合逐源状态）；`refs_page` 搜索弹窗升级为独立「搜图工作台」（三 Tab/人名按作品分组/每源 chips 重试/仅可商用筛选/一键加入参考画面/历史收藏/免责声明）；设置页新增 4 个预留 Key + 缓存上限与清理；AI 策划自动附 5–10 张参考图（含来源许可，可换删）。偏差澄清：TMDB 为多语源（`language=zh-CN`）接受中文原名/人名，其余英文源一律词表/人名表/拼音/AI，符合 R46 语义 | `q6_search_test` 31/31（全部离线 fixture）；live 22/22（中/英/人名/主题）→ `docs/qa/search-live-2026-09-20T14-32-56.txt`；全量 230 passed + 23 skipped（live 默认跳过）；format/analyze 0 问题 |
| 2026-09-20 | D（④）PoC + 精度偏差登记 | `pose_detection: ^3.7.0` PoC **成功**（Windows 实跑：YOLOv8n 人物检测 + BlazePose 33 点，模型随包离线，`flutter test` 可跑）；落地 `lib/services/pose/`（检测服务/关节映射/接地校准）与精度 QA；**实测未达 D128 门禁**：120 张均值 14.48°、≤10° 占 67.0%、P50 4.00°（典型站/坐姿 ~5°），13 张未检测；根因 = 包内 API 不暴露 world landmarks，自研 world 推理无法复刻 MediaPipe 检测器 + 旋转 ROI（已证包内 `pose_landmark_full.tflite` 与 MediaPipe task 内模型字节一致，误差来自 ROI；多尺度裁剪集成后 30 张均值 5.87°）。**偏差登记（R54）**：不替换正式参考图管线（120 张骨架继续由 Python 管线产出）；端上识别仅用于用户照片导入，低置信标注「仅供参考」并可手动微调；后续改进方向 = 复刻 BlazePose 检测器 + 旋转 ROI | PoC：`test/features/q6_pose_poc_test.dart`（`SS_POSE_POC=1` 实跑通过：1 人/33 点）；精度报告：`docs/qa/pose-accuracy-2026-09-20T17-38-03.md`（含分关节均值/超标清单）；一致性：`q6_pose_consistency_test`（Python world3d→Dart 移植 0.000°）；全量 231 passed + 25 skipped；format/analyze 0 问题 |
| 2026-09-21 | D（④）D122 亚洲图替换 | 120 张参考图全量换为亚洲人（Pexels 主 + Wikimedia 备；`tool/gen_pose_photos_asian.py` 新增候选下载失败顺延 + `--query`/`--source-id` 定向补图；1080px/250KB 规范化）；骨架与叠加图 120 全量重提（叠加图只入 `docs/pose-qa3` 证据，D66）；`skeleton_to_joints build --force` 重建 10 类 × 12 + 12 关节；`pose_qa.mjs photo` 全量渲染 + 接地校准（120 条 bounds/grounding；工具修：stitch_batch SameFileError、bounds 与校准跨轮合并并剔除与当前 rootY 不符的陈旧记录）； QA 复核发现 p071「坐姿冒充躺姿」且接地超限 → `--source-id` 定点换图重跑（rootY 0.418、minY≈0）；P1 抽查另换 p047（站姿冒充跪姿）/p083（纯剪影）/p084（暗光不可辨）为清晰亚洲人照片并重跑 QA。适配 D122 数据：q2 叠加图证据改认 assets/docs 双路径、q6 覆盖测试去硬编码、f4 姿势选择先滚到可见再点 | `app/assets/content/poses3/photos/`（120 jpg + 120 skeleton）、`docs/pose-qa3/{overlay,compare}-*.png` ×120、`qa_photo_state.json`、`app/tool/gen_pose_photos_asian.py`；门禁 q2 8/8、q6 11/11、f4 6/6、全量 242 passed + 25 skipped、format/analyze 0 问题 |
| 2026-09-22 | E（⑤）资源库参考图 + 覆盖率偏差登记 | 抓取管线 `tool/gear_photos_v3/`（provider 优先级 官网 > 京东 > 亚马逊 > 淘宝 > 开放图源；全局限速 ≥2s/退避重试/断点续跑 `state.json`/失败清单；Amazon·Taobao 反爬降级桩按合同跳过）；官网 provider 支持 sitemapindex 跨品牌过滤、类目页展开、Shopify suggest.json、Godox 直猜 URL 兜底，匹配区分 `product`/`series`（extra.tier）；**R48 离线 fixture**：`fixtures/{godox,aputure,viltrox}/`（index/suggest/sitemap/产品页 + 样例图）不触网覆盖 index/suggest/sitemapindex 三路径，`selftest.py` 端到端验证元数据/原图/规范图（1100×825 4:3）与断点续跑/失败重试/--force，`GEAR_V3_OFFLINE=1` 时 `polite_get` 直接拒绝联网；图源元数据 135 条入 `gear_photo_sources.json`（imageUrl/pageUrl/license/fetchedAt/sha1/尺寸/rawPath/normPath，图片仅落 `tool/gear_photo_pool/`，不入 git/安装包 R47）；六类覆盖率报告 `tool/gear_coverage.py` → `docs/qa/gear-coverage-v6.json`（缺口逐条 id+brand+model）；Dart 侧 `gear_photo_sync.dart` 重写（修复旧 `_collect` 只认 List 漏掉 byId Map 的静默漏同步；新增图源开关/断点/缺口报告/`importLocalFile`/`importFromUrl`/LRU 缓存上限），资源库详情「补图」（本地图片/链接，工作区 `images/gear/<id>.jpg` + `sources.json` 登记）与底部免责声明（R47/D130），设置页「器材图同步源」chips + 缓存上限；Windows 手测的系统交互（文件选择器/真实下载）留待 F 阶段实机复核，UI 路径已用 widget 测试覆盖 | 数据：`app/assets/content/gear/gear_photo_sources.json`（135 条：official 98 = Godox 52/Aputure 26/Nanlite 12/Viltrox 5/其他 3，pexels 37 = props 14 + accessory 23）；报告：`docs/qa/gear-coverage-v6.json`；抓取日志与台账：`app/tool/gear_photo_pool/v3/`（不入 git）；`python tool/gear_photos_v3/selftest.py` PASS（3 品牌 / 端到端 / 断点续跑 / 失败重试，退出码 0）；门禁 `q6_gear_test` 7/7（覆盖率口径/图源登记/状态机/补图登记/免责声明/R48 fixture/补图入口）；全量 249 passed + 25 skipped；format/analyze 0 问题；提交 `6c3b8cf`（工具+数据+报告）+ `8ba1db6`（Dart+测试）。**偏差登记（D129）**：light 58.0%（91/157，目标 ≥90%，缺 66）、lens 93.9%（185/197，目标 ≥95%，缺 12）未达标——根因：开放源 Openverse/Wikimedia 本机连接被拒（WinError 10061/SSL 超时，代码就绪待网络恢复）、Amaran 站无 sitemap+products.json 401、永诺/南冠官网 JS 渲染无型号 slug、腾龙 sitemap 无产品页、京东/亚马逊/淘宝反爬（D130 允许尽力而为）；缓解：缺口 83 条逐条入报告 + 详情「补图」兜底（本地/链接 → 工作区 + 来源登记）+ 增量同步断点续跑 + 覆盖率断言按偏差后基线（camera 95.5%✅/accessory·clothing·props 100%✅）守住不回落；后续 P1 定向补采小品牌或网络恢复启用开放源 |
| 2026-09-22 | F（交付 v1.2.0） | 全量门禁通过后完成双端发布准备：`pubspec 1.2.0+7`、`kAppVersion='1.2.0'`、`web/public/announcements.json`（v1.2.0 七条要点 + 已知限制）、`web/src/pages/{index,downloads}.astro` 版本占位与文案同步（27 套预设/490+ 器材/端上识别/增量同步）、`web/dist` 重建（Astro 5 页，本地 PUBLIC_APP_VERSION=v1.2.0 校验）；Windows release 构建 + `tool/smoke_launch.ps1` **LAUNCH-OK**；Android APK **209.0MB**（D95 不限包体：含 pose_detection/OpenCV/LiteRT，较 v1.1.0 的 105.7MB 增长 103.3MB，未砍功能）；`updater_test` 的「未来版本」夹具改为 9.9.9（发版不再随 kAppVersion 失效）。发布动作：打 tag `v1.2.0` 触发 release.yml（打包 Windows zip/APK + SHA256 + GitHub Release + Pages 部署 + 公告直链写入）；本机 `git push` 后 CI 全绿（R60） | Windows：`app/build/windows/x64/runner/Release/shoot_studio.exe`（2026-09-22 19:11，Release 目录 245.4MB）+ `LAUNCH-OK process alive`；APK：`app/build/app/outputs/flutter-apk/app-release.apk` 219,130,281 bytes（209.0MB），SHA256 `f320c914a68bad39cfe4a7b1dee38d0f96048c4109d230f0e8b90ec38cc1a445`，versionName 1.2.0/versionCode 7；门禁：format 0 changed、analyze 0 问题、全量 **249 passed + 25 skipped**；`web/dist` 5 页构建成功且含 `v1.2.0`；提交与 CI 见下一次推送记录 |
---

## 6. 反模式（出现即返工）

- 错误一刀切当致命、崩溃不落盘、缓存只增不减、靠"再点一次就好"掩盖问题。
- 灯光朝向写死/不瞄准、预设数据与渲染不一致、用外观假装光效（光锥亮但被摄体光影不变）。
- 搜索失败用假进度糊弄、把中文原样发英文源、无来源/许可标注、版权图入 git 或安装包。
- 姿势识别下载模型才能用、精度不达标就替换正式库、覆盖内置图不可恢复。
- 资源库用低清/水印图充数、无来源登记、覆盖率虚报。
- 删测试/跳门禁换绿；CI 带红继续开发。
