# FIX_CONTRACT_V5.0 —— 搜索可用性 + 布光真实性 + 手部动作（v1.1.0）

> 生效：2026-09-16
> 关系：在 V1/V2/V3/V4 之上，用户逐项确认的 V5 决策**优先**；未冲突条款继续有效。
> 执行：按 §2 顺序（Q1 → Q2 → Q3 → Q4）**一口气跑完、中途不停**；每阶段有硬门禁，失败修复重跑。
> 证据：完成声明必须附测试输出 / 截图 / 文件路径 / 数量统计 / 实测网络数据。

---

## 0. 用户确认决策（D78–D93，不可再改）

| # | 决策 | 内容 |
|---|---|---|
| D78 | 搜索范围 | **修好现有三个入口**：① PD 静帧库本地搜索（多字段+别名）；② 智能搜图（网络多源）；③ TMDB 剧照/动漫弹窗。不做独立“搜片”新页 |
| D79 | 网络通道 | **DoH 本地隧道 + 代理感知，两者都要，默认自动**。优先级：用户代理 > DoH 隧道（仅被污染域名）> 直连；隧道透明（端到端 TLS，不换证书不注入）；主端点 doh.pub（实测可用），回退顺序 AliDNS/Cloudflare/Google；被污染域名走隧道，失败回退系统 DNS；设置页展示通道状态（直连/隧道/代理）并可手动切换与测速 |
| D80 | 数据源 | **Pexels 主**（实测直连 200/0.6s）+ **TMDB 影片**（内置 Key + 隧道）+ **Openverse 标为实验性**（保留但 UI 明示“当前网络可能不可用”，排在最后） |
| D81 | 检索词翻译 | 词表扩至 **200+ 场景词**；无命中的中文查询调用**已配置的默认 AI 提供方**翻译（异步、5s 超时、结果缓存本地 DB、LRU 200）；未配置 AI 时用词表+拼音兜底；**禁止把未翻译中文原样发往仅支持英文的源** |
| D82 | 内置 Key | 智能搜图与 TMDB 弹窗**默认使用内置 Key**（`assets/config/image_sources.json`），用户可覆盖/清空；清空即禁用该源并提示 |
| D83 | 搜索体验 | 分页加载更多（18/页，最多 5 页）；**每源状态+耗时+重试按钮**；缩略图与下载同走统一网络通道；搜索历史与收藏；跨源去重 + 许可/作者标注 |
| D84 | 降级 | TMDB 不可用（无 Key/无网/隧道阻断）**自动降级本地 PD 静帧库 + 明确提示**与配置引导 |
| D85 | 环境光开关 | **默认开**；关闭 = 半球光隐藏 + 环境贴图贡献置 0（**含金属反射，全部关掉**）；位置：布光页右栏「画质」区；**持久化**（`quality_ambient_enabled`）；虚拟测光表**不联动** |
| D86 | 手部动作 | 布光页右栏新增**「手部动作」面板**；左右手独立；预设 = 基础四式 + 标志手势 + 情绪与互动 + **双手组合**；**预设 + 每指微调**（拇指/食指/中指/无名指/小指弯曲 + 张开度）；腕部与手指分工（预设默认不动腕，托腮/合十等可含腕部组件） |
| D87 | 手部骨架 | **两套骨骼都支持**：MakeHuman（每手 1 掌 + 5 指×3 节）与 Quaternius（4 指×3 节 + 拇指×2 节）；旧版轻量假人**禁用面板并提示**“切到 GLB 人物可用” |
| D88 | 手部持久化 | **随布光场景保存/恢复**；**「另存为自定义姿势」包含手部**，导入时恢复；pose JSON 扩展可选 `hands` 字段，旧数据无该字段行为不变 |
| D89 | 写实材质 | 范围 = **程序化写实升级**（不加 CC0 贴图重映射、不加写实角色）：默认 realistic；修复写实模型分类（`Human.body/lips/fingernails/ears/teeth/tongue`→skin、`Human.eyelashes01/eyebrow001/short01`→hair、`Human.high-poly`→eye）；**保护 authored 贴图**（normalMap 不得被预设清空）；肤色接口兼容 `Human.*`；皮肤 = **预积分皮肤 BRDF LUT（运行时生成）+ wrap/back-scatter 近似**；布料 = 程序噪声法线 + sheen；金属反射增强 |
| D90 | 环境反射 | 内置 **1K CC0 影棚 HDRI**（Poly Haven `studio_small_03_1k.hdr`，实测下载 200）用于 realistic 模式；加载失败回退 RoomEnvironment；顺带修掉现有 PMREM 重复创建与未释放 |
| D91 | 细节 | **接触阴影**（脚下柔和接地阴影）+ **阴影参数调优**（bias/normalBias/radius/分辨率）；仅 realistic 预设生效，提供开关（性能退路） |
| D92 | 版本 | **v1.1.0**（pubspec/kAppVersion/公告/dist/下载页/更新器同步） |
| D93 | 硬门禁 | 四类全要：**搜索门禁 / 手部渲染门禁 / 环境光门禁 / 材质门禁** + 既有 156+1 全绿 + 双端构建冒烟 + APK ≤150MB |

---

## 1. 硬规则（V5 增补，违反即返工）

- **R29 网络统一**：所有外网请求（搜索 API、图片下载、缩略图、TMDB、AI 翻译）必须走统一网络通道（用户代理 / DoH 隧道 / 直连三态）；**禁止裸 `Dio()` 与裸 `Image.network` 直连外网**（统一通过 `HttpOverrides` 注入）。`connectTimeout`/`receiveTimeout` 必设（默认 15s/20s）；对 429/5xx/超时做退避重试 ≥2 次（指数退避 + jitter）；错误文案必须含域名、原因与建议。
- **R30 隧道安全**：只做 CONNECT 盲转发，不替换证书、不注入/篡改内容；仅监听 `127.0.0.1` 随机端口；进程退出释放；设置页可一键关闭；隧道失败自动回退直连并记日志。
- **R31 搜索不静默**：每次搜索必须展示每源结果数/失败原因/耗时；空结果给出可执行建议（换关键词/配代理/用本地库）；禁止用动画或模糊文案掩盖失败。
- **R32 内置 Key 优先**：内置 Key 存在即启用；用户清空后禁用并提示；Key 不写入日志。
- **R33 翻译红线**：未命中词表且 AI 不可用时，中文查询必须转拼音/英文简化词后再发（或直接提示“请用英文关键词”），不得原样发送。
- **R34 环境光语义**：关闭后场景光照贡献只剩摄影灯具（判定：关闭环境光且所有灯关闭时主体应为纯黑/仅背景）；开关与强度互相独立（关→滑杆置灰但记忆强度，开→恢复原强度）；状态随设置持久化。
- **R35 手部不破姿势**：手指驱动不得改变 12 关节角与 rootY/rootPitch（数值断言）；未导入姿势时手部预设独立生效；切换人物后手部预设自动重应用。
- **R36 手部数据兼容**：pose JSON 的 `hands` 为可选字段；旧场景/旧自定义姿势无该字段时行为与 V4 一致；新数据往返（场景保存/自定义姿势/导入布光）保持一致。
- **R37 材质不丢贴图**：写实模型 authored 的 normal/roughness/metalness/baseColor 贴图不得被任何预设删除或覆盖；预设切换可逆（恢复基线）。
- **R38 性能可退回**：SSS/HDRI/接触阴影/布料 sheen 仅在 realistic 预设生效；standard/light 行为与 V4 一致；接触阴影提供 UI 开关；Android 中端若掉帧默认关接触阴影（记录偏差）。
- **R39 测试完整**：新增门禁测试 + 既有 156 项全绿 + 1 skipped；网络 live 测试默认跳过（`live_provider` 同款守卫），但门禁证据须含**本机实测输出**（Pexels 200；TMDB 经隧道 200）。
- **R40 版本与公告**：v1.1.0；公告/dist/合同日志/HANDOFF 同步。

---

## 2. 交付清单

### Q1 搜索可用性（D78–D84、R29–R33）

**Q1.1 网络通道（新增）**
- `lib/services/net_router.dart`：
  - 三态通道：`direct` / `doh_tunnel` / `user_proxy`；状态可查询、可手动覆盖；
  - DoH 客户端（JSON API，无新依赖）：端点顺序 `doh.pub` → `223.5.5.5`（AliDNS，格式待校准）→ Cloudflare/Google（仅当可达）；TTL 缓存 + 并发去重；
  - 本地 CONNECT 隧道：`ServerSocket.bind(loopbackIPv4, 0)`，解析 `CONNECT host:port` → DoH 解析 → `Socket.connect(ip, port)` → 双向 pipe；仅对“需隧道域名”生效；
  - `HttpOverrides.global`：按域名返回 `PROXY 127.0.0.1:<port>` 或 `DIRECT`（覆盖 Dio / Image.network / 一切 dart:io HttpClient）；
  - 域名表（可配置）：tmdb / openverse / wikimedia / archive.org / film-grab 走隧道；pexels / image.tmdb.org / 国内域名直连；
  - 所有请求入口：`netRouter.dio(host, {timeout, retry})`。
- 设置页：显示当前通道与端点、开关（自动/强制直连/强制代理）、对 `api.pexels.com`、`api.themoviedb.org`、`image.tmdb.org` 三个目标测速（状态+耗时）。
- **不做**：WebView（FILMGRAB）不走 Dart HttpClient，隧道对其无效（文档说明即可）。

**Q1.2 智能搜图重写（`lib/services/image_sources.dart`）**
- 源顺序：Pexels（主，分页）→ TMDB（影片/海报，分页）→ Openverse（实验性，仅在可达时）。
- 分页：`page` 参数、18/页、最多 5 页；“加载更多”按钮；结果跨源去重（URL/ID）；标注来源与许可/作者。
- 每源状态对象：`{source, ok, count, elapsedMs, error, page, hasMore}`；UI 展示 + 单源重试。
- 内置 Key 默认启用（D82）；缩略图走统一 HttpClient；下载用统一 dio（重试+超时）。
- 搜索历史（最近 20）与收藏（不限）存 `settings` 键 `search_history` / `search_favorites`（JSON）。

**Q1.3 词表与 AI 翻译**
- `kSceneKeywordMap` 扩到 ≥200 词（场景/光线/情绪/器材/构图/服装）；英文查询直通；
- 未命中：读取已配置 AI 提供方（复用现有 AI 管道）翻译 → 缓存 `settings.query_translation_cache`（LRU 200，键=原文）；5s 超时；失败→拼音/去中文兜底（R33）。

**Q1.4 PD 静帧库搜索**
- 字段扩展：`title`/`year`/`film`（含年份）/帧标题/`author` + 中文别名表（≥30 部常见 PD 影片：Nosferatu/大都会/摩登时代/卡里加里博士…）；
- token 匹配（空格分词，全部命中即匹配），不再单串 `contains`；
- 加载失败捕获并提示（现为无限转圈）。

**Q1.5 TMDB 弹窗**
- 走统一通道 + 内置 Key + 用户 Key 覆盖；搜索分页；剧照按类型（backdrop/still）分页；
- 不可用时自动降级本地 PD 库（按钮“改看本地 PD 静帧”）+ 明确提示（D84）。

**Q1.6 测试**
- `q5_net_router_test`：域名判定、CONNECT 隧道（本机 mock 上游）、DoH 缓存/回退、超时/退避、HttpOverrides 注入；
- `q5_search_test`：分页/去重/状态/内置 Key/翻译缓存/降级；UI 弹窗（状态行、加载更多、重试）；
- live gate（默认跳过）：Pexels 实网 200；TMDB 经隧道 200（内置 Key）。
- 既有搜索测试（g6/g7）按新行为改写，**不得删测试换绿**（R39）。

### Q2 环境光开关 + 手部动作（D85–D88、R34–R36）

**Q2.1 引擎（`assets/engine/js/**` + bundle 重打包）**
- 环境光：`window.ss.setAmbientEnabled(bool)` / `getAmbientEnabled()`；保存 `hemiLight` 与 `envTexture` 引用；关闭→`hemi.visible=false` + `scene.environmentIntensity=0`（记忆原强度）；修复 PMREM 重复创建/未释放（统一在 studio 创建一次，dispose generator/环境）；
- 手部：
  - 骨骼映射表（按骨架家族）：MH `hand_l/index_01_l…/thumb_03_l`；Quaternius `Hand.L/Index2.L…/Thumb3.L`；含每指屈伸轴/符号/最大角，**经 QA 渲染标定**并写入源码常量；
  - `window.ss.setHandPose(side, presetId)`、`setHandCurls(side, {thumb,index,middle,ring,pinky,spread,wrist?})`、`getHandState()`、`listHandPresets()`；
  - 预设语义数据（15 个）：`relax/open/fist/halfGrip | thumbsUp/peace/ok/point | heart/pinch/wave/chinRest | gongshou(抱拳)/qigong(拱手)/prayer(合十)`；双手组合预设一次写入左右手；
  - 手指驱动与 12 关节解耦（R35）；`applyScene` 支持 `subject.hands`；切人物后自动重应用；
- QA 渲染：qa.html 支持 `&handL=<preset>&handR=<preset>`，供门禁截图。

**Q2.2 Flutter**
- 状态与持久化：`LightingState.ambientEnabled`（设置键 `quality_ambient_enabled`）；`LightingState.handL/handR`（`HandPoseState{preset, curls, wrist}`）；
- 场景往返：`LightingSceneData.toJson/fromJson` 增加 `hands`；保存/载入/预设切换保持一致；
- 自定义姿势：`PosesController.saveCustom` 将手部写入 `jointsJson` 保留键 `_hands`；`PoseEntry` 解析可选 `hands`（内置 poses3 数据也可携带）；
- UI：
  - 「画质」区：环境光开关（关→强度滑杆置灰）+ 接触阴影开关（default 开，仅 realistic 生效）；
  - 「手部动作」面板：左右手分段（左/右/双手组合）；预设 chips（15 个，缩略图用文字+icon）；每指滑杆（5 弯曲 + 张开度）；重置；假人时禁用+提示；
  - 导入照片姿势/切人物/载入场景后手部面板同步实际状态（`getHandState`）。

**Q2.3 测试与证据**
- `q5_hands_test`：预设表完整性（15）、骨骼映射命中（MH/Quaternius 断言手指骨数）、12 关节不受影响（数值断言）、场景/自定义姿势往返、假人降级；
- 手部渲染门禁：**15 预设 × 左右手 × 2 骨骼 = 60 张**（`docs/screenshots/hands-*.png`）逐张目检 + 数量统计；
- 环境光门禁：开/关对比（含金属反射灭掉）+ 持久化往返测试 + “关环境光+关灯=纯黑”数值探针。

### Q3 写实材质与环境反射（D89–D91、R37–R38）

- 材质分类修复（D89 名单）+ authored 贴图保护（快照/恢复，R37）+ 肤色 `Human.*` 兼容；
- 皮肤：预积分 BRDF LUT（运行时生成 256×256 HalfFloat，公式为 Penner 预积分皮肤的解析拟合）+ wrap/back 近似注入（`onBeforeCompile`，含 LUT uniform）；LUT 生成失败回退 wrap-only；
- 布料：噪声法线（V4 已有）保留 + sheen（`MeshPhysicalMaterial.sheen`，realistic 生效；失败回退 Standard 注入式 rim）；
- 金属：envMapIntensity/roughness 调优；
- HDRI：`assets/engine/env/studio_small_03_1k.hdr`（Poly Haven CC0，实测可达）+ attribution 登记；RGBELoader → PMREM；失败回退 RoomEnvironment；
- 接触阴影：程序化椭圆软阴影贴地（随人物包围盒缩放），realistic + 开关；阴影调优（bias/normalBias/radius/mapSize）；
- 性能：standard/light 路径与 V4 完全一致；Android 中端若接触阴影掉帧→默认关（记录偏差）；
- 证据：`docs/screenshots/material-*.png`（皮肤近景/布料/金属，realistic vs standard）+ R37 贴图保护断言 + 性能探针（可选）。

### Q4 测试与发布（D92/D93、R39/R40）

- 全量测试（既有 156+1 + 新增 q5 系列）全绿；`dart format --set-exit-if-changed` + `flutter analyze --fatal-infos` 0 问题；
- 双端构建 + 冒烟；APK ≤150MB（当前 104.1MB，HDRI +~2MB）；
- v1.1.0：`pubspec` `1.1.0+N`、`kAppVersion`、`web/public/announcements.json` + `web/dist` 重建、`FIX_CONTRACT_V5.0.md` 变更日志、`HANDOFF.md` 更新。

---

## 3. 阶段门禁

| 阶段 | 门禁 |
|---|---|
| Q1 | Pexels 实测端到端可用；TMDB 经隧道免代理可用（内置 Key）；每源状态/耗时/分页/重试/历史/收藏；词表+AI 翻译缓存生效；PD 搜索多字段+别名；q5 网络与搜索测试绿；既有 156+1 全绿 |
| Q2 | 环境光开/关对比图 + 持久化 + “纯黑”探针；手部 15 预设 × 左右 × 2 骨架 = 60 张截图；12 关节不受影响断言；场景/自定义姿势往返绿；假人降级绿 |
| Q3 | 材质分类/贴图保护断言绿；皮肤/布料/金属对比图目检；HDRI 入包并可回退；standard/light 与 V4 行为一致；接触阴影开关生效 |
| Q4 | 全量测试绿；Windows 冒烟 LAUNCH-OK；APK ≤150MB；v1.1.0 公告/dist/日志同步 |

---

## 4. 环境与踩坑（V5，含 2026-09-16 实测）

1. **实测网络**（本机）：`api.pexels.com` 200/0.6s 直连可用；`api.openverse.org` 即使 DoH 正确 IP 也 **0.23s 快速失败**（IP/SNI 级封锁）；`api.themoviedb.org` 系统 DNS 被污染（202.160.128.210），**正确 IP（65.9.130.x）可达（401 缺 Key）**；`image.tmdb.org` 直连 404 可达；`commons.wikimedia.org`/`archive.org` 正确 IP 也不可达；**`doh.pub` 可用**，Cloudflare/Google DoH 不可用；`dl.polyhaven.org` 200/5.5s、`ambientcg.com` 200。
2. **DoH 隧道**：Dart `ServerSocket` + CONNECT 盲转发；`HttpOverrides.global` 统一注入（含 Dio 与 Image.network）；仅监听 127.0.0.1；WebView 不走 Dart HttpClient（FILMGRAB 无法受益，文档说明）。
3. **手部骨骼轴**：MH 与 Quaternius 命名/轴向不同（`index_01_l` vs `Index2.L`），需逐骨架标定屈伸轴与最大角，QA 截图迭代校准并写入常量（工具有 `qa_3d_lighting.mjs` 与 `pose_qa.mjs` 可复用）。
4. **写实模型保护**：`realistic:true` 角色装载不套预设；`setMaterialPreset` 必须跳过 authored normalMap 清空逻辑（现 Bug）；`Human.*` 材质名需显式分类。
5. **PMREM 重复创建**：`engine.js` 与 `studio.js` 各建一次（后者覆盖且未释放）——本次修复为一份。
6. **HDRI 下载需网络**：dl.polyhaven.org 可达；若执行时不可达，回退 RoomEnvironment 并**记录偏差**（D90 允许）。
7. **AI 翻译成本**：用已配置默认提供方；缓存 LRU 200；未配置则跳过（R33 兜底）。
8. **搜索测试**：g6/g7 的 mock 用例按新行为改写；live 用例默认跳过但须本机跑一次留证（R39）。
9. **性能**：realistic 下新增效果多，安卓中端需实测；接触阴影默认关时可标记偏差（R38）。
10. **版本与包体**：APK 目前 104.1MB；HDRI +模型微调后仍须 ≤150MB；超预算优先砍接触阴影响应分辨率而非删功能。

---

## 5. 变更日志（执行时追加）

| 日期 | 变更 | 证据 |
|---|---|---|
| 2026-09-16 | V5 合同建立：D78–D93；三轮用户确认 + 本机网络实测（Pexels 可用/Openverse 快速失败/TMDB 需隧道/doh.pub 可用/Poly Haven 可达） | 本文件 §0/§4；实测输出 |
| 2026-09-16 | Q1 完成：网络三态通道（DoH 隧道/代理/直连，`HttpOverrides` 全局注入 + 重试）；搜索三入口重写（PD 多字段+别名 / 智能搜图分页+每源状态+历史收藏 / TMDB 降级）；词表 200+ 与 AI 翻译缓存 | `docs/qa/net-probe-20260916.txt`（Pexels 200/0.6s、TMDB 隧道 200）；`q5_net_router_test`(6) / `q5_search_test`(7) 绿 |
| 2026-09-16 | Q2 代码完成：环境光开关（D85，含金属反射全关 + 持久化 + 场景往返）；手部系统（D86–D88：15 预设/双手组合手臂叠加/每指微调/`_hands` 往返/假人禁用提示） | `q5_hands_test`(8) 绿 |
| 2026-09-17 | Q2 证据补全：手部矩阵 **60/60**（15 预设 × 左右 × MakeHuman/Quaternius）；环境光开/关对比 + R34 纯黑探针（关环境光+关灯：中心区域 avg=15.7/255，仅背景可见） | `docs/screenshots/hands/`（60 张）；`docs/screenshots/env-ambient-{on,off,dark}.png`；`docs/pose-qa/qa_state.json` hands.count=60 |
| 2026-09-17 | Q3 完成（D89–D91）：分类修复（`Human.*` 名单）+ R37 authored 贴图保护 + 预积分皮肤 BRDF LUT/wrap + 布料噪波/sheen + 金属增强；HDRI 接线（`env=hdr` 实测加载成功，失败回退 RoomEnvironment）+ pubspec/attribution 登记；接触阴影（仅 realistic，`quality_contact_shadow` 持久化）；阴影调优（2048²/bias/normalBias/radius） | `docs/screenshots/material-{skin,cloth,metal}-{realistic,standard}.png`、`material-contact-{on,off,standard}.png`（像素 diff 4540 px）；`q5_material_test`(9) 绿 |
| 2026-09-17 | Q4 完成：全量 **186 passed + 1 skipped**；`dart format --set-exit-if-changed` 通过、`flutter analyze --fatal-infos` 0 问题；Windows 构建 + 冒烟 `LAUNCH-OK`；APK **105.7MB**（≤150MB）；v1.1.0（`pubspec 1.1.0+6`、`kAppVersion`、`announcements.json`、`web/dist` 重建） | 各命令输出；`app/build/app/outputs/flutter-apk/app-release.apk` |
| 2026-09-17 | 偏差登记：① Openverse 按 D80 保留但实测不可用 → UI 明示「实验性」并排最后（不谎报可用）；② 手部 QA 首轮 17 张 `CDP 超时` → `--skip-existing --workers 1` 补全 60/60；③ 接触阴影按 R38 仅 realistic 生效（standard/light 与 V4 行为一致）；④ 端上照片识别仍按 V4 §4.4-1 降级（体积约束未变）；⑤ 手部托腮/合十单臂不含抬臂（预设仅腕+指，双手组合含手臂叠加；单臂抬臂归姿势库职责） | `HANDOFF_V5.md` §2–§3；`qa_state.json` |

---

## 6. 反模式（出现即返工）

- 搜索失败用假进度/静默降级糊弄；把未翻译中文原样发往英文源；裸 `Dio()`/裸 `Image.network` 直连外网。
- 隧道替换证书/注入内容；隧道监听非 loopback；失败不提示。
- 关环境光仍保留半球光/反射（或开时环境反射缺失）；测光表与环境光状态打架（D85 已定：不联动，不得擅自联动）。
- 手指骨写死轴向未标定导致反关节；手部改动影响 12 关节数值；旧数据缺 `hands` 字段时报错。
- 为写实效果删除/覆盖 authored 贴图；standard/light 行为发生变化；牺牲安卓帧率且无退回开关。
- 删测试/跳门禁换绿；live 证据缺失仍宣称端到端可用。
