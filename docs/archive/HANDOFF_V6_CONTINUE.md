# ShootStudio V6 续作交接（环境 / 成功管线 / 待办）

> 生成：2026-09-21 ｜ 用途：新开对话直接接着干 ｜ 配套：`FIX_CONTRACT_V6.0.md`（D94–D131 + R41–R60）、`HANDOFF_V6.md`（阶段总览）
> 仓库：`D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio`（Flutter 在 `app/`，官网 `web/`，证据 `docs/`）
>
> **2026-09-21 收尾执行完毕**：§5 的 P0 全绿（详见 §8），下一站 P1 抽查 / E 阶段。

---

## 0. 一分钟速览

- **已推送且 CI 绿**：`51e44aa`（V6-D PoC：pose_detection 端上识别落地 + 精度偏差登记）；前序 `3497d03`（V6-C 搜索重做，CI 绿）。
- **本地已提交、尚未推送**：`23ab506`（V6-D：导入照片识别 UI + 覆盖/恢复/自定义 + q6_pose_test 11 项）。
- **工作区未提交**：607 项改动 = D122 亚洲图替换全套产物（120 张照片、120 份 skeleton、manifest/attribution/poses3/rejects、新脚本、QA 状态等）。
- **执行结果（2026-09-21）**：P0 全部完成——stitch 修复 + compare ×120 生成；q2/q6/f4 门禁去硬编码；p071 定点换图并重跑 QA（120 bounds/grounding、校准与 rootY 全一致）；`dart format`/`flutter analyze --fatal-infos`/`flutter test` 全绿（242 passed + 25 skipped）；D122 产物与适配修复分两个提交。
- **下一步**：推送（§1.3 直连命令）→ 确认 CI 全绿（R60）→ P1 抽查 → 进入 E 阶段（§5 P2）。

---

## 1. 仓库与 Git / CI 状态

### 1.1 提交历史（`git log --oneline -3`）

```
23ab506  V6-D：导入照片识别全流程 + 参考图覆盖/恢复/自定义库（D124–D127）+ q6_pose_test 11 项   [本地，未推送]
51e44aa  V6-D PoC：pose_detection 3.7 端上识别落地（检测/12关节/接地/多尺度 world）+ 精度报告与偏差登记；SDK 升至 3.10 并全仓 tall-style format   [已推送，CI 绿]
3497d03  V6-C 搜索重做：13 源聚合 + 查询规划（人名表/拼音兜底）+ 感知哈希重排 + 以图搜图 + 24 主题包 + 5GB LRU 缓存 + 独立搜图工作台 + AI 策划自动参考图   [已推送，CI 绿]
```

### 1.2 未提交改动（607 项，分类）

| 类别 | 内容 |
|---|---|
| 照片 | `app/assets/content/poses3/photos/p001..p120.jpg`（全部换为亚洲人） |
| 骨架 | `app/assets/content/poses3/photos/*.skeleton.json`（MediaPipe 重提取 120 份） |
| 删除 | `app/assets/content/poses3/photos/*.overlay.png`（旧叠加图，待 QA 重新生成） |
| 元数据 | `photos_manifest.json`（author/license/source/alt/fetchedAt/imageSize 更新）、`attribution.json`（120 条姿势登记重写）、`poses3.json`（关节/rootY/难度/referenceOnly 重建）、`rejects.json`（已清空） |
| QA | `docs/pose-qa3/qa_photo_state.json`（渲染接地测量，应已更新；需确认 120 条 bounds） |
| 新脚本 | `app/tool/gen_pose_photos_asian.py` |

### 1.3 推送方式与网络

本机 git 配置了 github.com 代理 `http://127.0.0.1:7890`（**当前未监听**）。之前可用直连覆盖推送：

```powershell
git -c http.https://github.com/.proxy= -c http.https://codeload.github.com/.proxy= -c http.https://api.github.com/.proxy= -c http.version=HTTP/1.1 push
```

最近一次失败：`Failed to connect to github.com port 443`（连接被重置/超时）；`Invoke-WebRequest https://api.github.com` 返回 200。建议：先重试直连推送 2–3 次（间隔 30s）；仍失败则等网络恢复或启动本机代理后再推。**推送后必须确认 CI 全绿（R60）。**

---

## 2. 环境配置（本机）

### 2.1 工具链

| 工具 | 版本/位置 | 备注 |
|---|---|---|
| Flutter | 3.47.2 stable（Dart ≥3.10） | `pubspec.yaml` SDK 约束已升 `>=3.10.0`，全仓按 **tall-style** 格式化 |
| Dart/Flutter 转发脚本 | `C:\Users\Lenovo\AppData\Local\Temp\opencode\dart.cmd`、`...\flutter.cmd` | shell 不稳定时统一用它们；重定向用 `cmd /c "... > file"` |
| Python | 3.12（Windows Store） | 已装 `mediapipe 1.0.1`、`pillow 11.0.0`、`pypinyin` |
| Node.js | v24.20.0 | 跑 `pose_qa.mjs`、`engine_build/bundle.mjs`、`test_aim.mjs` |
| Edge | `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe` | QA 渲染用 headless；**重跑前先杀掉遗留 headless 进程** |

### 2.2 插件 symlink（无 Developer Mode）

`flutter pub get` 若报 "Building with plugins requires symlink support"：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool\setup_symlinks.ps1
flutter pub get
```

### 2.3 依赖与模型位置

- `app/pubspec.yaml` 新增：`pose_detection: ^3.7.0`、`flutter_litert: ^3.8.0`、`opencv_dart: ^2.2.1+4`（Native Assets，CI 的 Windows/Android 构建已验证可过）。
- pose_detection 包（含模型）在 pub 缓存：`C:\Users\Lenovo\AppData\Local\Pub\Cache\hosted\pub.dev\pose_detection-3.7.0\assets\models\`：
  - `pose_landmark_lite/full/heavy.tflite`、`yolov8n_float32.tflite`
  - **实测**：包内 `pose_landmark_full.tflite` 与 MediaPipe `pose_landmarker_full.task` 内 `pose_landmarks_detector.tflite` SHA1 完全一致。
- MediaPipe Python 模型缓存：`~/ShootStudio/pose_models/pose_landmarker_full.task`（extract 脚本自动下载）。
- 测试环境 rootBundle 读不到依赖包 asset，端上测试用 `PoseDetectorService.debugModelsFromPubCache()`。

### 2.4 网络与 Key

- 统一网络通道：`NetRouter`（用户代理 > DoH 隧道 > 直连）；TMDB 走隧道。
- Pexels/TMDB Key：`app/assets/config/image_sources.json`（内置，可被设置页覆盖）。
- 搜索源 Key 预留（设置页）：Europeana / Smithsonian / Harvard / Rijksmuseum。

### 2.5 常用命令

```powershell
# 门禁
cd app; <dart.cmd> format lib test
cd app; <flutter.cmd> analyze --fatal-infos
cd app; <flutter.cmd> test

# 搜索 live（默认 skip）
cd app; $env:SS_SEARCH_LIVE='1'; <flutter.cmd> test test/features/q6_search_live_test.dart

# 端上姿势 PoC / 精度
cd app; $env:SS_POSE_POC='1'; <flutter.cmd> test test/features/q6_pose_poc_test.dart
cd app; $env:SS_POSE_ACCURACY='1'; <flutter.cmd> test test/features/q6_pose_accuracy_test.dart   # 可加 $env:SS_POSE_N='30'

# 引擎
cd app; node tool/engine_build/bundle.mjs
cd app; node tool/test_aim.mjs
cd app; node tool/light_preset_qa.mjs --cones 1
cd app; node tool/engine_mem_qa.mjs

# 拼音兜底词表（改人名表/主题包后）
cd app; python tool/gen_pinyin_dict.py
```

---

## 3. 已完成阶段与关键代码

### 3.1 A（②引擎稳定化）✅ / B（③3D 建模与布光）✅

见 `HANDOFF_V6.md` §1–2；证据：`docs/qa/engine-mem-2026-09-19-08-29-56.json`、`docs/screenshots/lighting-v6/`。

### 3.2 C（①搜索重做）✅（`3497d03`，CI 绿）

- 新增 `app/lib/services/search/`：
  - `search_models.dart`（ImageDomain / SearchIntent / SourceCapability / SearchHit / SearchQuery / SearchSource / SourceStatus / AggregatedResult）
  - `sources/`：`tmdb_source.dart`（作品/人名 combined_credits/分集 stills/无作品时人名兜底）、`pexels_source.dart`、`anilist_source.dart`（GraphQL POST）、`met_source.dart`、`artic_source.dart`、`cleveland_source.dart`、`vam_source.dart`、`wikiart_source.dart`、`artvee_source.dart`、`europeana/smithsonian/harvard/rijks_source.dart`（Key 预留）、`source_utils.dart`
  - `query_planner.dart`（意图分类 + 人名表 60+ + 词表 + 拼音兜底 + AI 翻译 + `search_plan_cache_v6` LRU 300；TMDB 多语源可收中文，其余英文源绝不收中文）
  - `result_ranker.dart`（源权重/匹配分/分辨率/许可 + URL/标题去重 + dHash 64 位感知哈希）
  - `image_to_search.dart`（AI 视觉描述 → KEYWORDS → 多源搜；未配置 AI 时给出可执行降级）
  - `theme_packs.dart`（24 主题包）、`search_cache.dart`（工作区 `cache/search/{thumb,orig}`，5GB LRU，`search_cache_limit_mb` 可调）、`search_engine.dart`、`search_keys.dart`、`keywords.dart` + `pinyin_data.dart`（1407 字，生成器 `tool/gen_pinyin_dict.py`）、`planner_refs.dart`（AI 策划自动附 5–10 张参考图）
- UI：`app/lib/features/refs/search_page.dart`（独立搜图工作台：三 Tab / 人名分组 / 每源状态重试 / 仅可商用 / 一键入案 / 历史收藏 / 以图搜图 / 主题包 / 免责声明）；`refs_page.dart` 旧弹窗删除；设置页 4 个预留 Key + 缓存管理。
- 测试/证据：`q6_search_test` 31/31；live 22/22 → `docs/qa/search-live-2026-09-20T14-32-56.txt`。

### 3.3 D（④姿势/端上识别）进行中

**已完成**
- 依赖与 PoC（`51e44aa`）：`pose_detection` 在 Windows `flutter test` 实跑通过（YOLOv8n + BlazePose 33 点）；证据 `test/features/q6_pose_poc_test.dart`（`SS_POSE_POC=1`）。
- 服务层：`app/lib/services/pose/`
  - `pose_detector_service.dart`：检测（lite）→ 多尺度 ROI（[1.2,1.3,1.4]）world 推理（full）→ 逐坐标均值；`jointVisibility`；`debugModelsFromPubCache`。
  - `pose_joint_mapper.dart`：33 → 12 关节（复用 `pose_landmark_math.deriveJoints`，与 Python 同公式）；低置信标注「仅供参考」。
  - `pose_grounding.dart`：脚部可见性接地校准（脚不可见时 rootY=0 并提示）。
- 精度 QA：`test/features/q6_pose_accuracy_test.dart`（`SS_POSE_ACCURACY=1`）→ `docs/qa/pose-accuracy-2026-09-20T17-38-03.md`：120 张均值 14.48°、≤10° 67.0%、P50 4.00°、13 张未检测。**未达 D128（≤5°/90%≤10°）**，已按 R54 登记偏差：不替换 Python 正式参考图管线，端上结果仅用于导入参考。
- 一致性：`q6_pose_consistency_test`（Python world3d → Dart 移植误差 0.000°）。
- 导入 UI（`23ab506`）：
  - `app/lib/features/poses/pose_import_page.dart`（选图 → 懒加载模型 → 多人点选 → 骨架叠加 → 12 关节/置信度 → 导入布光预演 / 加入策划案 / 保存自定义 / 覆盖内置；照片与骨架 JSON 存工作区 `images/poses/`）
  - `poses_controller.dart`：`saveOverride` / `restoreBuiltin` / `deleteCustom` / 自定义照片字段 `_photo`/`_skeleton`；收藏切换只更新收藏位不再覆盖数据
  - `poses_page.dart`：替换参考图 / 恢复默认 / 删除自定义入口；删除旧 `pose_recognize_notice.dart`
  - `pose_skeleton.dart`：支持工作区文件路径（`PoseSkeletonData.load` 与 `PosePhotoView`）
  - 测试：`q6_pose_test.dart` 11 项（mapper/接地/覆盖恢复/自定义往返/骨架契约）；`q2_pose_photos_test.dart` 中 R23 用例改为导入页 smoke。

**D122 亚洲图替换（工作区未提交）执行记录**
1. `python tool/gen_pose_photos_asian.py --force` → 120 张全部替换（Pexels 主，亚洲向查询；alt 命中 asian 优先；manifest/attribution 更新；删除旧骨架/叠加）。
2. 4 张首次提取未检出人体（p054/p079/p083/p117）→ `--ids ...` 二次换图 → 重提取后 `rejects.json` 清空。
3. `python tool/extract_pose_skeletons.py extract --force` → 116 + 4 = 120 份 skeleton。
4. `python tool/skeleton_to_joints.py build --force` → `poses3.json` 重建（10 类 × 12；referenceOnly 12 条）。
5. `node tool/pose_qa.mjs photo` → 120 渲染完成、接地校准（首轮 120 条 rootY 修正已写回 poses3）、写 `qa_photo_state.json`；**在拼接阶段报 `SameFileError`（overlay 源=目标）中断**。
6. 随后 q2 测试 2 项失败、q6 覆盖测试 1 项失败（见 §5 P0）。

---

## 4. 成功管线（可直接复制执行）

### 4.1 搜索 live 证据

```powershell
cd app
$env:SS_SEARCH_LIVE='1'
<flutter.cmd> test test/features/q6_search_live_test.dart
# 产物：docs/qa/search-live-<时间戳>.txt（保留成功那一份）
```

### 4.2 端上姿势 PoC / 精度

```powershell
cd app
$env:SS_POSE_POC='1';      <flutter.cmd> test test/features/q6_pose_poc_test.dart
$env:SS_POSE_ACCURACY='1'; <flutter.cmd> test test/features/q6_pose_accuracy_test.dart
# 产物：docs/qa/pose-accuracy-<时间戳>.md
```

### 4.3 亚洲参考图替换（D122）

```powershell
cd app
python tool/gen_pose_photos_asian.py --force                 # 全量替换（亚洲向 Pexels 查询）
python tool/gen_pose_photos_asian.py --ids p054,p079 --force # 单点补图（未检出人体时）
python tool/gen_pose_photos_asian.py --dry-run               # 预览候选（不下载）
python tool/extract_pose_skeletons.py extract --force        # MediaPipe 骨架（120）
python tool/extract_pose_skeletons.py extract --ids p054 --force
python tool/skeleton_to_joints.py build --force              # 重建 poses3.json（12 关节/rootY/难度）
```

### 4.4 QA 渲染 / 接地校准 / 对比图（当前需先修一处）

```powershell
# 先杀遗留 headless Edge（避免 "Edge headless 启动失败"）
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" |
  Where-Object { $_.CommandLine -match 'headless|remote-debugging-port' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

cd app
node tool/pose_qa.mjs photo
# 产物：docs/pose-qa3/compare-<id>.png、overlay-<id>.png、qa_photo_state.json
```

**已知 bug（P0-1）**：`tool/extract_pose_skeletons.py` 的 `stitch_batch()`（约 370 行）在 `overlay` 路径与输出目录相同时 `shutil.copyfile` 抛 `SameFileError`。修复：拷贝前判断 `os.path.abspath(src) != os.path.abspath(dst)`，相同则跳过。

**快速补救**：若上一轮渲染临时目录仍在（`%TEMP%\ss-p3-render-*`，含 `<id>__<char>.png`），修完 stitch 后可直接：

```powershell
cd app
python tool/extract_pose_skeletons.py stitch-batch --renders "$env:TEMP\ss-p3-render-<最新>" --out ../docs/pose-qa3
```

否则重跑 `node tool/pose_qa.mjs photo`（约 10–20 分钟；rootY 已校准，本轮应只需一次渲染）。

### 4.5 其他管线

```powershell
cd app
python tool/gen_pinyin_dict.py                       # 拼音兜底词表（需 pypinyin）
node tool/engine_build/bundle.mjs                    # 改引擎 JS 必跑
node tool/test_aim.mjs                               # 瞄准数学单测（CI 已接）
node tool/light_preset_qa.mjs --cones 1              # 27 套预设渲染
node tool/engine_mem_qa.mjs                          # 角色 LRU/内存门禁
```

---

## 5. 待办清单（按优先级）

### P0：恢复到全绿并推送（阻塞项）

1. **修 `stitch_batch` SameFileError**（`app/tool/extract_pose_skeletons.py`），重跑 QA 拼接/photo，确认：
   - `docs/pose-qa3/overlay-p001..p120.png`、`compare-*.png` 齐全；
   - `docs/pose-qa3/qa_photo_state.json` 的 `photo.bounds` 覆盖 120 条、`calibrations` 与 `poses3.json` 的 rootY 一致。
2. **修 `q6_pose_test.dart` 覆盖测试期望**：`p001` 关节已随换图变化，测试里硬编码的 `-32.74` 必须改为从 `ContentPacks.poses()` 读取原始值（保存前取值 → 覆盖 → 恢复后比对相等）。
3. **全量门禁**：`dart format lib test` → `flutter analyze --fatal-infos` → `flutter test`（预期 242 passed + 25 skipped；q2 的 2 项与 q6 的 1 项应随 P0-1/P0-2 转绿）。
4. **提交 + 推送**：
   - `23ab506`（导入 UI + q6 测试）与新的 D122 产物分开两个提交更清晰；
   - 推送用 §1.3 的直连覆盖命令；**CI 必须全绿**。
5. **文档同步**：`FIX_CONTRACT_V6.0.md` §5 追加 D122 完成日志（含 QA 证据路径）；`HANDOFF_V6.md` 更新进度与基线。

### P1：D 阶段收尾

6. **亚洲图人工抽查**：少量 `alt` 未含 asian 的图（如 p079/p083 等）目视复核；必要时 `--ids` 再换。
7. **D128 精度改进（可选）**：复刻 BlazePose 检测器（`pose_detector.tflite`，在 task 内，2.96 MB）+ MediaPipe 旋转 ROI；达标前维持偏差登记（R54）。
8. **Windows 手测导入 UI**：选图 → 多人点选 → 保存自定义 → 覆盖/恢复 → 导入布光预演，确认端上链路可用。

### P2：E 阶段（⑤资源库图）

9. `tool/gear_photos_v3/`（官网 > 京东 > 亚马逊 > 淘宝，尽力而为 + 缺口清单）；覆盖率报告 `docs/qa/gear-coverage-v6.json`（相机/镜头 ≥95%，其余 ≥90%）。
10. 增量同步（断点续传 + 缺口报告）+「补图」UI + 免责声明；`q6_gear_test`。

### P3：F 阶段（交付 v1.2.0）

11. 全量门禁 + Windows/Android 双端构建（记录 APK 体积）+ 冒烟 `tool/smoke_launch.ps1`（LAUNCH-OK）。
12. 版本/公告/dist/合同日志/HANDOFF/下载页全链路同步；CI 全绿（R60）。

---

## 6. 已知坑与注意事项

1. **format 是 tall-style**：SDK 约束 3.10 后必须 `dart format lib test`，否则 CI 第一步红。
2. **Edge 僵尸进程**：QA 渲染第二轮常因遗留 headless Edge 失败；每次重跑前按 §4.4 清理。
3. **stitch SameFileError**：见 P0-1；这是 QA 工具缺陷，不是数据问题。
4. **不要硬编码姿势关节值**：换图后 `poses3.json` 全量变化；测试应动态读取。
5. **测试环境读不到依赖包 asset**：端上测试用 `debugModelsFromPubCache()`；正式 App 走 rootBundle 的 `packages/pose_detection/...`。
6. **无 Developer Mode**：`flutter pub get` 前跑 `tool/setup_symlinks.ps1`。
7. **GitHub 推送**：本机代理常离线；直连可用时用 §1.3 命令；失败就稍后重试。
8. **精度偏差仍在**：D128 未达标是已知结论，不要在未达标前替换正式参考图管线（R54）；端上结果一律标注低置信「仅供参考」。
9. **4 张二次换图**：p054/p079/p083/p117 为第二轮候选，如复核不满意可再换。
10. **`docs/pose-qa3/` 是 D 阶段正式证据目录**（overlay/compare/qa_photo_state），勿清。
11. **CI 会跑 Android/Windows 原生构建**（opencv/litert），耗时约 20 分钟；新增依赖后务必看构建任务。
12. **`SS_*` 环境变量门禁默认跳过**：live/pose 精度/PoC 用例在 CI 不跑，本机留证后写入 `docs/qa/`。

---

## 7. 新对话开场提示词（可直接粘贴）

> 继续 `D:\trae\6aa175d7786dd07d04fe3d2e\ShootStudio` 的 V6 收尾：先读根目录 `HANDOFF_V6_CONTINUE.md`（本文件）、`FIX_CONTRACT_V6.0.md`、`HANDOFF_V6.md`。
> D 阶段（含 D122 亚洲图替换）已收尾，P0 全绿；如需复核请看 §8 执行记录与 §5 P1/P2/P3。
> 下一站：P1 抽查（`alt` 未含 asian 的少量图）/ D128 精度改进（可选）/ E 阶段（gear 资源库图）。
> 基线：全量 242 passed + 25 skipped；format/analyze 0 问题；CI 需绿到 D122 提交（R60）。

---

## 8. 2026-09-21 收尾执行记录（P0 全绿）

**代码/工具修复**
1. `tool/extract_pose_skeletons.py stitch_batch`：overlay 源=目标时跳过 `shutil.copyfile`（SameFileError）；`--renders` 复用临时渲染目录，补出 compare ×120。
2. `tool/pose_qa.mjs`：`photo` 的 bounds 跨轮合并（`--ids` 单点重跑不再清空其余测量）；calibrations 合并前剔除与当前 `rootY` 不符的陈旧记录；`count` 改为被 bounds 覆盖的姿势数（新增 `renderedThisRun`）。
3. `tool/gen_pose_photos_asian.py`：候选下载失败顺延下一个候选；新增 `--query` / `--source-id` 定向补图；用法注释同步。
4. p071：QA 复核发现「坐姿照片标躺姿·侧卧」+ 接地超限（minY=-0.231）→ 用 `--source-id 8484012` 换成真躺姿亚洲女性（partialBody/仅供参考），重跑 extract + build 定点替换 + `pose_qa photo --ids p071` → rootY 0.418、minY≈0，120 条接地全达标。
5. `.gitignore`：忽略 `__pycache__/`、`*.pyc`。

**门禁适配**
- `q2_pose_photos_test`：叠加图证据改认 `assets`（旧位）或 `../docs/pose-qa3/overlay-*.png`（D66 正式位）任一存在。
- `q6_pose_test`：覆盖/恢复用例的内置关节期望改为保存前动态读取，不再硬编码 `-32.74`。
- `f4_editors_test`：姿势选择先 `ensureVisible` 再 `tap`（换图重建后列表位置变化）。
- 结果：`dart format` 0 changed、`flutter analyze --fatal-infos` 无问题、`flutter test` **242 passed + 25 skipped**。

**证据**
- 数据：`app/assets/content/poses3/photos/`（120 jpg + 120 skeleton）、`poses3.json`、`photos_manifest.json`、`attribution.json`、`rejects.json`（空）。
- QA：`docs/pose-qa3/{overlay,compare}-*.png` ×120、`qa_photo_state.json`（bounds/grounding 120、calibrations 5 条全部与当前 rootY 一致）。

**P1 抽查（同日晚）**
- `alt` 未含 asian 的 14 张逐图目视：p079（抱头跳跃，可辨）等保留；p047（跪姿用了起跑蹲 → 换为单膝跪地亚洲女性）、p083（纯剪影 → 换为亮部清晰的空中舞者）、p084（暗光不可辨 → 换为聚光亮相亚洲舞者）三张定向换图并重跑 extract/build 定点替换/QA；全量 242 passed + 25 skipped 复验通过。
