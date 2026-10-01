# V8/S7 · D153 动作摆姿与识别重做 — 完工报告

## 1. 结论

D153 四项要求全部落地：姿势库改**大图瀑布流 + 分类眉题**、详情改**半屏抽屉**、识别链路收口 **≤4 步**（导入 → 识别中 → 校正 → 送入布光/存库）、骨架校正支持**关节点拖拽**（命中 14px、角度读数、复位单关节/全部）。既有能力不回退：120 条姿势、10 类、R69 回退链、导入/覆盖/恢复内置全部保留。

## 2. 姿势库（浏览侧）

| 合同要求 | 实现 | 证据 |
|---|---|---|
| 大图瀑布流 | `PoseGalleryGrid` 复用画面参考页的 `RefsMasonryGrid` / `RefsMasonryImage`（4:5 竖幅、按图片自身比例撑高、无图衬线首字占位） | 截图 `s7-pose-gallery-*.png` 16 张中的 4 张 |
| 图卡 + 分类眉题 | `PoseGalleryCard`（名称 + `分类 · 难度` mono + 选中描边）；`PoseCategoryEyebrow`（分类名 + 数量 + hairline），按分类变化处插入 | 同上 |
| 分类 10 类保留 | `poseCategories` 未动，`g5_poses_test` / `q2_pose_photos_test` 继续守 10 类 × 12 | 两专项全绿 |
| 搜索（名称/关键词） | `_matchesKeyword` 扩到 9 字段：名称/分类/难度/重心/手部/常见错误/镜头/机位/半身说明 | 专项「检索命中类别 / 难度 / 镜头 / 重心等字段」 |
| 详情半屏抽屉 | `showPoseDetailSheet`：大图（contain）+ 骨架开关 + 镜头建议/机位建议/重心 + 收藏 + **「送入布光」主行动** + 可选加入策划案 | 截图 `s7-pose-sheet-*.png` 4 张 |

## 3. 识别链路（≤4 步）

1. **导入**：选文件（FilePicker）、**粘贴截图**（`Pasteboard.image`）、**拖入**（DropTarget，正则 `jpe?g|png|webp|bmp`）。
2. **识别中**：`SsSkeleton` 骨架屏（替掉 `CircularProgressIndicator`）+ **后端标签 chip**（`RTMPose/RTMW3D（ONNX CPU）` 或 `MediaPipe BlazePose（回退）`，点开显示 `backendNote`）。R69 回退链未改。
3. **校正**：`PoseJointTuner` = 照片 + 骨架并排；关节点命中半径 **14px**（≥12px 合同要求），拖拽时用 `applyPosePointEdits` 把像素位移按「世界跨度/像素跨度」折算成米制位移叠加到 world 副本，再用 `PoseJointMapper.map` **实时重算 12 关节**；拖拽中显示 **mono 角度读数**；`PoseTunerResetBar` 支持**复位单关节 / 复位全部**（未改动时禁用）。
4. **送入布光 / 存库**：沿用原「送入布光预演」「另存为自定义姿势」「覆盖内置参考图」「加入策划案」。

角度读数语义：`_chainOf` 反查「谁把它当父 / 谁把它当子」，只有同时存在两侧才算关节（肩/肘/髋/膝）；手腕与踝是链末端，读数退化为与竖直方向的夹角。

## 4. 文件拆分（R73）

| 文件 | 拆分前 | 拆分后 | 手法 |
|---|---|---|---|
| `poses_page.dart` | 591 | **135** | 新增 `poses_page_layout.dart`（`part of` + `extension _PosesPageLayout on _PosesPageState`） |
| `pose_import_page.dart` | 773（白名单 812） | **413** | 新增 `pose_import_page_layout.dart`（part + extension + 顶层私有类） |
| `tool/file_size_baseline.json` | 10 条 | **9 条**（删 pose_import_page 812） | `check_file_size.mjs` PASS |

## 5. 偏差与限制登记

- **难度取值与 UI 不一致**：`assets/content/poses3/poses3.json` 的 `difficulty` 实际只有 `进阶` 20 条 + `高难度` 100 条（S4 重建后已变，V6 审计里的「新手友好 20」是旧数据），但 `poseDifficulties` chips 仍列「新手友好」→ 点该 chip 会得到空列表。S8 按实际数据校正或补数据。
- **校正器精度依赖关键点质量**：拖拽折算用「世界 y 跨度 / 像素 y 跨度」，当人物接近水平姿态或关键点缺失时比例会退化，此时回退 `0.005 m/px`（`applyPosePointEdits` 的 `fallbackMetersPerPixel`）。
- **保留的既有行为**：导入页仍保留多人框选（`_PersonBoxPainter`）与按 bbox 点选换人；`PoseImportPage` 的保存/覆盖路径未改。

## 6. 测试与门禁

| 项 | 结果 |
|---|---|
| `s7_pose_ui_test.dart`（新增专项） | **14 / 14 全绿** |
| `q2_pose_photos_test` | 8 passed（不回归） |
| `q6_pose_test` / `q6_pose3d_test` / `q6_pose_recognition_test` / `g5_poses_test` / `g5b_poses_page_test` | 11 / 10 / 2 / 5 / 1 passed（不回归） |
| `flutter test --no-pub`（全量） | **441 passed + 40 skipped**，All tests passed |
| `dart format lib test` | 0 changed |
| `flutter analyze --no-pub --fatal-infos` | No issues found |
| `node tool/check_file_size.mjs` | PASS（报告 `docs/qa/v8-file-size.json`） |

## 7. 视觉证据

`docs/screenshots/v8/s7-pose-<scene>-<theme>-<size>.png` 共 **16 张**（scene ∈ gallery / tuner / sheet / import；theme ∈ paper / darkroom；size ∈ 1280x800 / 1920x1080）+ 索引 `docs/qa/v8-s7-pose-screenshots.json`。视觉门禁：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub --update-goldens test/visual/s7_pose_capture_test.dart` 出图（17 项全绿），`SS_V8_VISUAL=1` 比对，默认只冒烟。

## 8. 修复的真实缺陷（测试逼出来的）

1. `poseTunableJoints` 里 `shoulder_l/shoulder_r` 的父点误写为髋（23/24），破坏 `parent < child`，并让关节角度读数取错三点 → 改为肩 11/12。
2. `PoseSkeletonPainter` 缺交互几何 → 新增 `layoutRect` / `offsetOf` / `toNormalized` / `hitTestJoint`。
3. `PoseTunerResetBar` 用 `Row` 导致窄栏溢出 50px、「复位全部」被挤出视口 → 改 `Wrap` 并把「复位全部」前置。
4. 详情抽屉：`SsSectionTitle` 放在非 flex 位 + `Column(mainAxisSize.min)` 里用 `Expanded` + 缺少显式宽度 → 三处修正（`constraints` 定界 + `ConstrainedBox` + `Expanded` 包标题）。
