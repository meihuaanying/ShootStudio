# ShootStudio V6 交接文档（进行中）—— 搜索重做 + 3D 稳定/建模 + 端上识别 + 资源库图

> 更新：2026-09-22 ｜ 版本基线 `1.1.0+6`（目标 `1.2.0`）｜ 约束文件：`FIX_CONTRACT_V6.0.md`（**开工前必读**）
> 进度：**A（②引擎稳定化）✅ ｜ B（③3D 建模与布光）✅ ｜ C（①搜索重做）✅ ｜ D（④姿势/端上识别）✅（120 张亚洲参考图 + 导入 UI 落地；D128 精度偏差保留登记） ｜ E（⑤资源库图）✅（抓取管线/增量同步/补图/覆盖率报告落地；D129 light·lens 偏差保留登记） ｜ F（交付 v1.2.0）⏳**
> 本机状态：全量 **249 passed + 25 skipped**（live/PoC/精度默认跳过）；`flutter analyze --fatal-infos` 0 问题；format 通过；引擎包 950.7KB
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter `app/`，官网 `web/`，证据 `docs/`）

---

## 0. 30 秒速览：下一步做什么

1. **F 阶段（交付 v1.2.0）**：
   - 全量门禁（format/analyze/`flutter test`）→ Windows release 构建 + `tool/smoke_launch.ps1`（LAUNCH-OK）+ Android APK（记录体积）；
   - 版本/公告/dist/合同日志/HANDOFF/下载页同步；`git push` 后 CI 全绿（R60）；
   - Windows 手测补做（E 遗留）：资源库「补图」文件选择器真实路径、设置页同步源/缓存上限保存生效。
2. **可选项（不阻塞交付）**：E 覆盖率 P1 定向补采（Amaran/永诺/腾龙等）；D128 精度改进（BlazePose 检测器 + 旋转 ROI）；网络恢复后启用 Openverse/Commons 开放源。
3. **E 阶段已完成**（详见 §3.E）：`tool/gear_photos_v3/` + R48 离线自测 + 增量同步 + 补图 UI + 覆盖率报告（提交 `6c3b8cf` / `8ba1db6`）。

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

## 2.5 已完成：C 阶段（①搜索重做）

**新增目录 `app/lib/services/search/`**（旧 `image_sources.dart` 保留兼容，g6/q5 测试继续绿）：
- `search_models.dart`：`ImageDomain`（影视/画作/摄影）、`SearchIntent`、`SourceCapability`、`SearchHit`（来源/许可/可商用/作品分组）、`SearchQuery`（perSource 覆盖）、`SearchSource`、`SourceStatus`、`AggregatedResult`（`groupedByWork`）。
- `sources/`：`tmdb_source.dart`（多语源，作品/人名 combined_credits/分集 stills，无作品时自动人名兜底）、`pexels_source.dart`、`anilist_source.dart`（GraphQL POST，media/staff）、`met_source.dart`（objectID + 并发 6 + PD 标记）、`artic_source.dart`（IIIF + 分页）、`cleveland_source.dart`（CC0）、`vam_source.dart`（IIIF base）、`wikiart_source.dart`（JSON 容错）、`artvee_source.dart`（HTML 抓取）、`europeana/smithsonian/harvard/rijks_source.dart`（Key 预留）；`source_utils.dart`（NetRouter Dio / 并发限流 / 许可判定 / fixture 解析工具）。
- `query_planner.dart`：意图分类（人名/作品/主题）→ 人名表（60+ 创作者）→ 画面词表 → AI 翻译 → 拼音兜底；`search_plan_cache_v6` LRU 300；**英文源绝不收中文**（TMDB 为多语源 `language=zh-CN`，偏差已登记）。
- `result_ranker.dart`：源权重 + 文本匹配分 + 分辨率 + 许可加分 + URL/标题去重 + dHash 64 位感知哈希去重 + 汉明距离。
- `image_to_search.dart`：AI 视觉描述（新增 `AiClient.chatWithImage`，OpenAI/Anthropic 双协议）→ KEYWORDS 解析 → 多源搜；未配置/不支持图片时给出可执行降级提示。
- `theme_packs.dart`：24 个主题包（中英关键词 + 推荐源）。
- `search_cache.dart`：工作区 `cache/search/{thumb,orig}/`，sha1 索引 + atime LRU，默认 5120MB（`search_cache_limit_mb` 可调，设置页可清空）。
- `search_engine.dart`：多源并发、逐源状态（结果数/耗时/失败原因）、跳过未启用源并给提示。
- `search_keys.dart`：内置默认（Pexels/TMDB）+ 用户覆盖 + 4 个预留 Key 读取。
- `planner_refs.dart`：AI 策划联动，按主题自动下载 5–10 张参考图 → 工作区 `images/refs/` → 写入参考样片模块（含来源/许可）。
- `pinyin_data.dart`（1407 字，`tool/gen_pinyin_dict.py` 生成）+ `keywords.dart`（人名表 + 兜底链）。

**UI / 联动**
- 新增 `lib/features/refs/search_page.dart`「搜图工作台」：三 Tab、自动/作品/人名/主题意图、仅可商用开关、每源 chips 单源重试、加载更多、人名按作品分组、详情弹窗（打开来源页/加入参考画面）、历史/收藏、主题包底部弹层、以图搜图、底部免责声明 + 缓存占用。
- `refs_page.dart`：删除旧 `_SmartSearchDialog`/`_TmdbDialog`；「智能搜图」「TMDB 剧照/动漫」→ 搜图工作台（影视分类）；其余功能保留。
- 设置页：Europeana/Smithsonian/Harvard/Rijksmuseum Key 预留 + 搜图缓存上限/占用/清空。
- `planner_page.dart`：AI 整体插入后自动 `_autoCollectRefs`（5–10 张，可换/删）。

**证据**：`q6_search_test` 31/31（离线 fixture 覆盖 13 源解析/排序/许可/缓存 LRU/主题包/降级）；live 22/22 → `docs/qa/search-live-2026-09-20T14-32-56.txt`（星际穿越→TMDB 真实剧照；新海诚→《你的名字。》等；梵高 向日葵→5 源 57 条）；全量 230 passed + 23 skipped；format/analyze 0 问题。

---

## 3. D / E 阶段状态（按合同 §3 执行）

### E（⑤资源库图）—— 已完成（2026-09-22）

- **抓取管线** `app/tool/gear_photos_v3/`：provider 优先级 官网 > 京东 > 亚马逊 > 淘宝 > 开放图源；全局限速 ≥2s + 退避重试 + `state.json` 断点续跑 + 失败清单；Amazon/Taobao 反爬按合同降级跳过（记录原因）。
- **官网 provider**：sitemapindex（跨品牌过滤）/类目页展开/Shopify `suggest.json`/Godox 直猜 URL 兜底；匹配分 `product`/`series`（`extra.tier`，系列页标注「同系列示意」）。
- **R48 离线 fixture**：`fixtures/{godox,aputure,viltrox}/`（index/suggest/sitemap/产品页 + 样例图，不触网）；`python tool/gear_photos_v3/selftest.py` 验证 offline 守卫、三品牌解析、端到端 fetch（元数据/原图/规范图 1100×825）、断点续跑/`--retry-failed`/`--force`；`GEAR_V3_OFFLINE=1` 时 `polite_get` 直接拒绝联网。
- **图源与报告**：`assets/content/gear/gear_photo_sources.json` 135 条（official 98：Godox 52/Aputure 26/Nanlite 12/Viltrox 5/其他 3；pexels 37：props 14 + accessory 23）；`docs/qa/gear-coverage-v6.json` 六类覆盖率（camera 95.5%✅ / lens 93.9%❌ / light 58.0%❌ / accessory·clothing·props 100%✅，缺口 83 条逐条可追溯）。图片只落 `tool/gear_photo_pool/`（.gitignore，R47）。
- **Dart 侧**：`gear_photo_sync.dart` 重写（修复旧 `_collect` 只认 List 导致 `byId` Map 漏同步；图源开关/断点/缺口报告/`importLocalFile`/`importFromUrl`/LRU 缓存上限）；资源库详情「补图」（本地/链接 → 工作区 `images/gear/<id>.jpg` + `sources.json` 登记）+ 底部免责声明；设置页「器材图同步源」chips + 缓存上限。
- **门禁**：`q6_gear_test` 7/7（覆盖率口径/图源登记/状态机/补图登记/免责声明/R48 fixture/补图入口）；全量 249 passed + 25 skipped。
- **偏差登记（D129）**：light 58.0%、lens 93.9% 未达标；根因 = 开放源本机不可达（Openverse 连接被拒/Wikimedia SSL 超时）、Amaran 无 sitemap、永诺/南冠 JS 渲染无型号 slug、腾龙 sitemap 无产品页、京东/亚马逊/淘宝反爬；缓解 = 缺口清单 + 补图 UI + 增量同步，断言按偏差后基线守住不回落。
- **遗留（F 阶段补做）**：Windows 手测的文件选择器真实路径与设置页保存生效（UI 逻辑已测，系统交互需实机）。

### D（④姿势/端上识别）—— 已完成与剩余

**已完成（2026-09-20）**
- 依赖：`pose_detection: ^3.7.0`（含 `flutter_litert 3.8` + `opencv_dart 2.2`，均为 Native Assets）；`pubspec` SDK 约束升至 `>=3.10.0`（触发 Dart 3.10 tall-style 全仓 format，属预期）。
- PoC：`test/features/q6_pose_poc_test.dart`（`SS_POSE_POC=1` 实跑）：Windows 上 `flutter test` 即可跑通，YOLOv8n 检测 + BlazePose lite 33 点（`POCOK poses=1 landmarks=33`）。模型在 pub 包内（`packages/pose_detection/assets/models/*.tflite`），随包离线（R53）。
- 服务：`lib/services/pose/pose_detector_service.dart`（检测/2D/多尺度 ROI 集成 world 推理/关节置信度）、`pose_joint_mapper.dart`（33→12 关节，复用 `pose_landmark_math`）、`pose_grounding.dart`（脚部可见性接地校准）。
- 关键实测：包内 `pose_landmark_full.tflite` 与 MediaPipe `pose_landmarker_full.task` 内 `pose_landmarks_detector.tflite` **SHA1 完全一致**；Python `world3d → Dart deriveJoints` 复现 `poses3.json` 误差 **0.000°**（`q6_pose_consistency_test`）。误差全部来自 world 估计。
- 精度：`test/features/q6_pose_accuracy_test.dart`（`SS_POSE_ACCURACY=1`，120 张）：均值 14.48°、≤10° 67.0%、P50 4.00°、13 张未检测 → `docs/qa/pose-accuracy-2026-09-20T17-38-03.md`。**未达 D128（≤5°/90%≤10°）**，偏差已登记（R54：不替换正式参考图管线）。
- 诊断工具：`tool/pose_diag_compare.py`（同一裁剪图上 MediaPipe vs Dart world 对比）。

**已完成（2026-09-21 收尾）**
- D122 亚洲参考图：120 张全量替换（Pexels 主 + Wikimedia 备，逐图许可登记）；`tool/gen_pose_photos_asian.py` 增候选顺延下载 + `--query`/`--source-id` 定向补图；MediaPipe 骨架/叠加图 120 全量重提，`skeleton_to_joints build --force` 重建 12 关节；`pose_qa.mjs photo` 全量渲染 + 接地校准（120 条 bounds/grounding；工具修 stitch SameFileError、bounds/校准跨轮合并剔陈旧）。QA 复核 p071 换图重跑（坐姿冒充躺姿 + 接地超限 → rootY 0.418）。证据：`app/assets/content/poses3/photos/`、`docs/pose-qa3/`。
- 导入 UI（D124–D127）：`poses_page` 替换参考图/恢复默认/删除自定义 + 照片导入识别全流程；`q6_pose_test` 11 项。
- 适配 D122 数据：q2 叠加图证据改认 assets/docs 双路径、q6 覆盖测试去硬编码、f4 姿势选择先滚到可见再点；全量 242 passed + 25 skipped。

**剩余**
1. 精度改进（可选）：复刻 BlazePose 检测器（`pose_detector.tflite` 在 task 内，2.96MB）+ MediaPipe 旋转 ROI；或继续调 ROI 策略。门禁通过前不得用端上结果替换内置参考数据（R54）。
2. 人工抽查 D122 图：已完成（`alt` 未含 asian 的 14 张逐图目视；p047/p083/p084 因姿态不符/剪影/暗光已换并重跑 QA；p079 抱头跳跃可辨、保留）；Windows 手测导入 UI 链路待做（并入 F 阶段实机复核）。

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
10. **搜索 live 证据**：`SS_SEARCH_LIVE=1 flutter test test/features/q6_search_live_test.dart`（默认 skip，CI 不跑）；TMDB 走 DoH 隧道偶发 TLS 握手失败，用例内置 3 次重试；`docs/qa/search-live-*.txt` 只留成功那一份。
11. **拼音词表生成**：`python tool/gen_pinyin_dict.py`（需 `pip install pypinyin`；语料 = 词表/搜索服务/内容资产 + 高频字），改人名表或主题包后可重跑。
12. **pose_detection / Native Assets（D 阶段新增）**：
    - `pubspec` SDK 已升 `>=3.10.0`，全仓按 Dart 3.10 tall-style 格式化（`dart format lib test` 必须跑，否则 CI 红）。
    - 无 Developer Mode 时 `flutter pub get` 会因插件 symlink 报错：先跑 `powershell -File tool/setup_symlinks.ps1` 建 junction，再 `flutter pub get`。
    - 模型字节在 pub 缓存 `pose_detection-3.7.0/assets/models/`；测试环境 rootBundle 读不到依赖包 asset，用 `PoseDetectorService.debugModelsFromPubCache()`（正式 App 走 rootBundle 的 `packages/pose_detection/...`）。
    - `flutter test` 在本机可直接跑端上推理（ffi + XNNPACK），无需起 Windows App；首次运行较慢。
    - 精度：`SS_POSE_ACCURACY=1 flutter test test/features/q6_pose_accuracy_test.dart`（可加 `SS_POSE_N=30` 快跑）；PoC：`SS_POSE_POC=1`。
    - Android CI 构建体积会因 opencv/litert 明显增大（D95：不限包体）；若 CI 构建失败，按 D123 评估回退。
13. **临时诊断文件已清理**（`q6_pose_exp/roi/diag`）；`tool/pose_diag_compare.py` 保留备用（对比同一裁剪图上的 MediaPipe vs Dart world）。

---

## 5. 常用命令

```bash
cd app && node tool/engine_build/bundle.mjs          # 改引擎 JS 必跑
cd app && node tool/test_aim.mjs                      # 瞄准数学单测
cd app && node tool/light_preset_qa.mjs --cones 1     # 27 套预设渲染
cd app && node tool/engine_mem_qa.mjs                 # 角色 LRU/内存门禁
cd app && python tool/gen_pinyin_dict.py              # 重建拼音兜底词表
cd app && <dart.cmd> format lib test
cd app && <flutter.cmd> analyze --fatal-infos
cd app && <flutter.cmd> test
cd app && $env:SS_SEARCH_LIVE='1'; <flutter.cmd> test test/features/q6_search_live_test.dart
cd app && $env:SS_POSE_POC='1'; <flutter.cmd> test test/features/q6_pose_poc_test.dart
cd app && $env:SS_POSE_ACCURACY='1'; <flutter.cmd> test test/features/q6_pose_accuracy_test.dart
cd app && python tool/gear_coverage.py                      # 六类覆盖率报告
cd app && python tool/gear_photos_v3/selftest.py            # R48 离线 fixture 自测（不触网）
cd app && python tool/gear_photos_v3/run.py status          # 抓取进度（断点台账）
```

---

## 6. 新对话开场建议

> 继续 `D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio` 的 **V6 F 阶段（交付 v1.2.0）**：先读 `FIX_CONTRACT_V6.0.md`（D94–D131 + R41–R60）与本文件。
> A/B/C/D/E 已完成并推送（CI 绿）；D128 精度偏差、D129 覆盖率偏差均已登记（见合同 §5）。
> 下一步：全量门禁 → Windows release 构建 + smoke_launch（LAUNCH-OK）+ Android APK 体积 → v1.2.0 版本/公告/dist/日志/下载页同步 → CI 全绿；顺手补 E 遗留的 Windows 手测（补图文件选择器/设置页保存）。
> 基线：全量 **249 passed + 25 skipped**；引擎包 950.7KB；覆盖率 camera 95.5% / lens 93.9% / light 58.0% / 其余 100%。

