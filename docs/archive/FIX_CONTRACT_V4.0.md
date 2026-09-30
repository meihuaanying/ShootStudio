# FIX_CONTRACT_V4.0 —— 摄影真实性升级约束（高面数 3D / 照片姿势库 / 产品图）

> 生效：2026-09-13
> 关系：在 V1/V2/V3 之上，用户逐项确认的 V4 决策**优先**；未冲突条款继续有效。
> 执行：按 §4 顺序**一口气修完、中途不停**；每阶段有硬门禁，失败修复重跑。
> 证据：完成声明必须附测试输出 / 截图 / 文件路径 / 数量统计。

---

## 0. 用户确认决策（D61–D77，不可再改）

| # | 决策 | 内容 |
|---|---|---|
| D61 | 3D 高面数路线 | **两条都要**：① 构建期对现有 Quaternius 网格做 Loop 细分（1–2 次）+ 平滑着色 + PBR 调参；② 接入 MakeHuman（CC0）写实管线作为「写实模式」。环境无法搭建 MakeHuman 时，须以等价 CC0/CC-BY 写实资产替代并在日志记录偏差 |
| D62 | 面数目标 | 每个内置角色 **40k–60k 三角面**（细分 1 次）；写实模式可 ≥80k。测试逐模型断言 |
| D63 | 材质升级 | 允许全面调参：皮肤（粗糙度/高光/轻量次表面近似）、布料（粗糙度/法线扰动）、金属与场景反射、色调映射 |
| D64 | 3D 资源包体 | **精选 2–4 个角色内置**（男女各 1–2，高面数）；其余角色首次使用联网下载并缓存到工作区；离线仅精选可用（UI 明示） |
| D65 | 姿势照片来源 | Pexels + Wikimedia 精选实拍：**10 类目 × 12 = 120 张**；许可可商用；逐图署名 |
| D66 | 骨架提取 | 构建期 **MediaPipe BlazePose**（33 关键点 + 3D world landmarks），产出：骨架叠加图 + JSON（2D/3D 关键点、派生 12 关节角、置信度） |
| D67 | 端上识别 | 接入 `pose_detection`（LiteRT+BlazePose，Windows+Android）：用户导入照片可就地识别骨架；失败/不支持时给出可读提示 |
| D68 | 骨架→3D 验收 | 每张照片：骨架叠加图 + 与 3D 渲染**并排对比图** + 关节限位校验；置信度低于阈值（0.6）标注「仅供构图参考」，不得宣称可复现 |
| D69 | 姿势页交互 | **照片为主**：网格（含骨架缩略图）→ 详情（大图 + 骨架 + 镜头/机位/要领）→「导入到布光预演」；关节微调移至布光页 |
| D70 | 旧姿势处置 | 现有 256 条程序化姿势**全部替换**为照片姿势库（含骨架与元数据） |
| D71 | 产品图来源 | Wikimedia/Openverse 的 CC0/CC-BY 产品图 + 构建期规范化（白底/中性底、主体居中 ≥70%、长边 ≥800px、无水印、统一 4:3、允许轻裁切与白平衡校正）+ 用户目录（`品牌 型号.jpg` 自动匹配）+ 缺图用 Pexels 氛围实拍并标注 |
| D72 | 覆盖率目标 | 相机/镜头 **≥90%** 有规范化照片；未覆盖项明确标注「缺图/插画」 |
| D73 | 产品图分发 | **混合**：热门 Top100 内置压缩版（长边 ≤1200、q80）；其余运行时「素材同步」抓取并缓存到工作区 |
| D74 | 硬门禁新增 | ① 3D：面数断言 + 三点光渲染截图；② 姿势：叠加图 + 3D 对比截图 + 关节限位；③ 资源：覆盖率 ≥90% + 规范校验 + 署名覆盖 |
| D75 | 执行顺序 | ① 3D 高面数+材质 → ② 照片姿势库+骨架+导入布光 → ③ 产品图抓取规范化+用户目录 → ④ 全量测试+双端构建；中途不停 |
| D76 | 许可红线 | 仅 CC0/CC-BY/PD/Pexels/用户自有；**ABO（CC BY-NC）等禁商用数据集一律排除**；署名页全量登记 |
| D77 | 网络策略 | 所有抓取脚本：代理感知 + 重试(429/超时退避) + 幂等；**Wikimedia 可达性不稳**，必须 fallback（Openverse/Pexels/用户目录）且 UI 明示来源 |

---

## 1. 硬规则（V4 增补，违反即返工）

- **R18 面数断言**：内置角色三角面 ≥40k（写实包 ≥80k）；`tri_count` 写入 manifest，测试逐条断言。
- **R19 真实性**：姿势库必须真实实拍照片；产品图必须照片（或明确标注「插画/氛围参考」）；禁止渐变冒充。
- **R20 骨架可信**：姿势的 12 关节角必须**由 3D world landmarks 推导**（可追溯 JSON），禁止手编；低置信度姿势必须标注「仅供构图参考」。
- **R21 不静默降级**：3D 加载/识别失败必须可读报错；轻量假人仅显式启用。
- **R22 包体预算**：APK ≤150MB；内置高面数模型总量 ≤30MB；内置产品图 ≤15MB；细分工件缓存到工作区不打包。
- **R23 端上识别不阻塞**：`pose_detection` 失败时提示并允许改用内置姿势或手动输入。
- **R24 署名与许可**：每张照片/产品图/模型在 `attribution.json` 可查；ABO 等 NC 数据禁用。
- **R25 导出一致**：长图/PDF 的姿势模块可选择「照片」或「骨架示意」渲染（默认照片，带出处）。
- **R26 兼容退回**：细分模型必须保留原 GLB 作为「轻量模式」资源，不删除老管线能力。
- **R27 测试完整**：新增三项硬门禁外，既有 133 项测试必须全绿。
- **R28 版本与公告**：完成后 v1.0.4；公告/dist/合同日志同步。

---

## 2. 交付清单

### Q1 3D 高面数与材质（D61–D64、R18/R21/R26）
- 工具 `tool/subdivide_characters.mjs`（Node + three-subdivide，MIT）：
  - 读取 `assets/models/characters/manifest.json`，对每个 GLB 网格做 Loop 细分（默认 1 次）+ 平滑法线；
  - 输出 `assets/models/characters/hq/<file>`，写入 `triCount`、`source`、`license` 到 manifest（保留原文件为轻量模式）；
  - 目标：每角色 40k–60k 面；对超过 120k 面的结果自动降级细分参数。
- 材质升级：统一 PBR（皮肤 roughness/specular 调参 + 轻量 SSS 近似；布料 roughness/normal 扰动；环境反射 intensity），在引擎 `character.js` 提供材质预设（`标准/写实/轻量`）。
- 写实模式：MakeHuman（CC0）管线脚本 `tool/gen_makehuman.dart|py`（尽力而为）：下载便携版→脚本导出→转 GLB→登记；若环境不可达，改用等价 CC0/CC-BY 写实 GLB（记录来源与偏差）。
- 精选内置：manifest 标记 `bundled: true` 的 2–4 个角色随包；其余 `downloadUrl`（poly.pizza/自建镜像）运行时下载到工作区并缓存。
- 验收：面数断言；三点光渲染截图（正/侧/背）目检通过。

### Q2 照片姿势库（D65–D70、R19/R20/R23/R25）
- 抓取：`tool/gen_pose_photos.dart`（Pexels 主 + Wikimedia 备，10 类目 × 12），压缩（长边 ≤1080、≤250KB），逐图署名；失败类目记录并补抓。
- 骨架：`tool/extract_pose_skeletons.py`（pip install mediapipe）：
  - 输入照片 → 33 关键点 + world landmarks；输出 `assets/content/poses3/photos/<id>.jpg`、`<id>.skeleton.json`、`<id>.overlay.png`；
  - JSON：`{landmarks2d[33], world3d[33], joints12{...}, rootY, rootPitch, confidence, params{lens,camera,category,name}}`。
- 关节推导：`tool/skeleton_to_joints.py`（IK/方向向量→12 关节角），带关节限位（肘 rx ∈ [-150,5]、膝 ∈ [0,140] 等）；置信度 <0.6 标记 `referenceOnly: true`。
- 3D 对比：`tool/pose_qa.mjs` 扩展 `--photo <id>` 模式：渲染 3D 同姿态并排图 → `docs/pose-qa/photo-<id>.png`。
- 数据：`assets/content/poses3/poses.json`（120 条，替换旧 poses.json 引用；旧文件保留归档）。
- 应用：姿势页改版（照片网格+骨架缩略图、详情、导入布光）；移除姿势页 3D 查看器；布光页提供关节微调。
- 导入布光：`lightingController.injectPose` 接入照片姿势（照常走引擎 setPose）；入口：「导入到布光预演」。
- 端上识别：`pose_detection` 接入（platform 守卫；Windows+Android），导入照片 → 骨架 → 可导入布光；失败提示。
- 验收：120 张全覆盖（叠加图 + 3D 对比 + 限位）；测试断言数量与字段完整。

### Q3 产品图规范化（D71–D73、R19/R22/R24）
- 抓取：`tool/gen_product_photos.dart`：
  - 目标：相机/镜头（≥90% 覆盖，含热门 Top100 内置）、灯具/附件尽力；
  - 来源顺序：用户目录 → Wikimedia（CC0/CC-BY，重试+代理）→ Openverse → Pexels（仅氛围兜底，标注）；
  - 规范化：白/中性底检测与合成、主体居中、统一 4:3、长边 ≥800（内置 ≤1200）、去噪、白平衡轻校正；保留原图 URL 与许可；
  - 输出：`assets/content/gear/photo2/<id>.jpg`（内置 Top100 压缩）+ `gear_photos2.json`（byModel/byKind/内置标记/来源/许可）；
  - 运行时同步：应用内「素材同步」按钮抓取剩余项，缓存到工作区 `images/gear/`，离线回退插画并标注。
- 用户目录：设置页「器材图目录」，`品牌 型号.jpg` 自动匹配（优先级最高）。
- 验收：覆盖率统计（相机/镜头 ≥90%）；规范校验（白底比例、分辨率、无水印、署名）测试；缺图项在 UI 明确标注。

### Q4 测试与发布（D74、R27/R28）
- 新增测试：
  - `q1_3d_fidelity_test`：面数断言（≥40k）、manifest 字段、精选内置存在、下载 URL 可解析；
  - `q2_pose_photos_test`：120 条照片+骨架+叠加图存在、confidence 字段、12 关节在限位内、referenceOnly 规则；
  - `q3_product_photos_test`：覆盖率 ≥90%、白底/分辨率校验、署名覆盖、内置 Top100 数量。
- 双端构建 + 冒烟；回归全部既有测试；v1.0.4 公告/dist/日志。

---

## 3. 阶段门禁

| 阶段 | 门禁 |
|---|---|
| Q1 | 面数断言绿；三点光截图 3 角色 × 3 视角；模型加载失败路径测试绿；APK 体积预测 ≤150MB |
| Q2 | 120 张叠加+对比截图；限位测试绿；导入布光 e2e 截图；端上识别失败降级测试绿 |
| Q3 | 覆盖率 ≥90%；规范校验绿；署名完整；运行时同步 mock 测试绿 |
| Q4 | 全量测试绿；Windows 冒烟 OK；APK ≤150MB；公告/dist/日志更新 |

---

## 4. 环境与踩坑（执行时优先规避）

1. **Wikimedia 可达性不稳**（本次实测 000，此前 200/404）：脚本必须重试 + 代理 + fallback；不得因单源失败中断。
2. **MakeHuman 官方直链可能不可达**（本次 000）：先尝试 `static.makehumancommunity.org` 与镜像；不可达则用等价 CC0/CC-BY 写实 GLB 替代并记录偏差（D61 允许）。
3. **MediaPipe 安装**：`pip install mediapipe`（PyPI 可达）；模型首次运行自动下载，若被墙需代理；建议离线缓存模型文件。
4. **pose_detection 插件构建风险**：加入后必须立即跑 Windows+Android 构建；若插件导致构建失败，改用「构建期内置骨架 + 桌面端提示」并记录偏差。
5. **细分耗时**：20+ 角色 × Loop 细分可能耗时数分钟、内存较高；脚本需分批并打印进度。
6. **包体**：细分后模型总量超 30MB 时，减少内置数量而不是突破预算（R22）。
7. **姿势页改版**：移除 3D 查看器会影响现有测试（poses 相关 widget 测试需同步更新，不得删测试换绿）。
8. **导出**：姿势照片进入长图/PDF 时注意图片体积与排版（照片缩略图 ≤ 400px 宽）。

---

## 5. 变更日志（执行时追加）

| 日期 | 变更 | 证据 |
|---|---|---|
| 2026-09-13 | V4 合同建立：D61–D77；可行性实测（mediapipe/pose_detection/Pexels 可达；Wikimedia/MakeHuman 直链不稳） | 本文件 §0/§4 |
| 2026-09-15 | Q1 执行完成：21 角色运行时 Loop 细分 40,000–49,576 面（manifest 21/21 一致）；材质预设 standard/realistic/light + PMREM 环境反射；三点光 ×3 视角截图；轻量模式（原 6,206 面）保留 | `docs/screenshots/3d-fidelity-*.png`、`3d-fidelity-report.json`；q1 测试 5/5 |
| 2026-09-15 | Q1.5 写实模式走通（最高标准路线，未降级）：MakeHuman CC0 系统资产 + MPFB2 / Blender 4.5.13 无头导出 `mh-men-01.glb`（84,550 面 / 53 骨骸 / 12-12 关节映射）；附 CC-BY 等价资产兜底 | `docs/screenshots/realistic-build-report.json`、`realistic-*.png`；q1b 测试 4/4 |
| 2026-09-15 | Q2 数据管线完成：120 条实拍照片（10 类目 × 12，Pexels/Wikimedia）+ BlazePose 骨架 33 点 + 12 关节角程序推导（限位夹取 50 处）；数据重建并从骨架重跑接地校准（compare/overlay ×120，0 失败）；新增 `partialBody` 标注 35 条（半身/特写，3D 复现仅参考） | `assets/content/poses3/poses3.json`、`docs/pose-qa3/{compare,overlay}-*.png`、`qa_photo_state.json`、`QA_REPORT.md`；q2 测试 8/8 |
| 2026-09-15 | Q2 应用接入（D69/R25）：照片姿势页（网格骨架缩略图 / 详情 / 镜头机位要领 / 出处链接）、「导入到布光预演」、布光页 12 关节微调（bridge.setJoint 实时反馈）+ 画质面板（细分/材质/环境反射）；导出台支持「照片 | 骨架示意」双模式（默认照片带署名）；引擎级导入布光 e2e 截图 | `lib/features/poses/**`、`lighting_page.dart`、`exporter.dart`、`planner_page.dart`；`docs/screenshots/pose-lighting-p001.png`、`p013.png`；g5/s5/s4/f4/ai_and_export 全绿 |
| 2026-09-15 | Q2 端上识别偏差（§4.4 降级 + 登记）：`pose_detection` 传递依赖 `opencv_dart`（构建期源码编译 OpenCV，Android 体积 +100MB 量级）将突破 R22；降级为「内置骨架 + 导入照片识别可读提示」，Dart 端推导实现保留并以等价性测试守护 | `pubspec.lock` 无 pose_detection；q2 降级提示 widget 测试；偏差说明见 §4.4-1 |
| 2026-09-15 | Q3 产品图完成：相机 95.5%（106/111）、镜头 92.9%（183/197，含系列图标注）；内置 96 张（7.0MB，4:3 / 长边 1100 / 白底 255 / q84）；非内置 197 张运行时素材同步；内置外文件移出包体（`tool/gear_photo_pool/`）；用户目录匹配优先 | `assets/content/gear/gear_photos2.json`、`photo2/`；q3 测试 5/5 |
| 2026-09-15 | Q4 验证与发布：全量测试 156 passed + 1 skipped（0 失败）；Windows 构建 + 冒烟 LAUNCH-OK；APK 104.1MB（R22 ≤150MB）；v1.0.4 公告与官网 dist 同步 | 测试/构建输出（本机）；`web/dist/announcements.json`；`lib/features/updater/updater.dart` kAppVersion=1.0.4 |
| 2026-09-16 | 严格复核与清理：全仓 `dart format` 对齐 CI 门禁（35 文件）；删除死代码/未用参数（`onJointClicked/selectedJoint/showPoints/placeholderIcon`）与过期文件（根 `content/` 副本、旧 Dart 抓取脚本、IDE/失败缓存、临时截图、third_party 示例）；抽取 `tripleOf` 去重三处关节解析；修正姿势信息弹窗（展示照片与署名）、导出照片排版与降级提示文案；README/HANDOFF 同步现状 | `dart format --set-exit-if-changed` 通过；`flutter analyze --fatal-infos` 0 问题；156 passed + 1 skipped；Windows 重建 + 冒烟 LAUNCH-OK；APK 重建 104.1MB |

### §4.4-1 端上识别偏差说明（D67）

- **决策依据**：`pose_detection`（Apache-2.0）→ `flutter_litert` + `opencv_dart`；`opencv_dart` 在构建期由 `dartcv4` 从源码编译全量 OpenCV，上游实测同类应用 APK +100MB 量级（参考 opencv_dart issue #282/#348：195.5MB → 136.2MB 仅限 ABI）。本版 APK 已达 104.1MB（含 poses3 14MB 照片/骨架、photo2 7MB、写实 GLB 5.3MB），接入后必然突破 R22 的 150MB 上限。
- **降级实现**：保留构建期 120 条骨架与 12 关节（D66/R20）；「导入照片识别」入口显示可读提示（R21/R23），引导改用内置照片姿势或布光页手动微调；`pose_landmark_math.dart`（BlazePose world landmarks → 12 关节，与 Python 管线同口径）保留并由 `q2_pose_photos_test` 的 120 条等价性断言守护，未来若打包策略变化可无痛启用。
- **验证**：全量测试含降级提示 widget 测试；APK 104.1MB ≤150MB。

## 6. 反模式（出现即返工）

- 用插画/渐变冒充姿势照片或产品照片；产品图不标注来源与「示意图」。
- 手编 12 关节角冒充骨架推导结果；低置信度姿势不标注。
- 高面数模型超包体预算仍全量内置；细分后删除轻量模式资源。
- 因单一数据源（Wikimedia/MakeHuman）不可达而停工或降级宣称完成。
- 移除既有测试以换绿；golden 不更新即宣称通过。
