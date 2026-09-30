# V8 · S5 画面参考搜索重构（D154）验收报告

> 门禁：format 0 changed ｜ analyze 0 问题 ｜ 全量 **384 passed + 39 skipped** ｜ 专项 14 + 视觉 16 张 ｜ `check_file_size` PASS
> 纪律：R78 证据入 git；R79 不删测试（`q6_search_test` 41/41、其余既有测试全绿）；R80 许可逐图可见；R71 只用设计令牌；R73 页面 ≤600 行。

## 1. 做了什么（一句话）

把「画面参考」从「搜索结果列表」重做成杂志画册：**首屏居中检索 + 8 张主题画报**、**保留纵横比的瀑布流 + 悬停浮层**、**详情抽屉（大图 + 五色色卡 + 来源许可 + 相似参考）**、**我的画板（4:5 竖幅画册块 + 拖拽排序 + 导出长图）**；检索管线（QueryPlanner → 13 源 SearchEngine → SearchCache）一行未动。

## 2. 文件与行数（R73）

| 文件 | 行数 | 职责 |
|---|---|---|
| `app/lib/features/refs/refs_home.dart` | 312 | 首屏/紧凑头（`RefsHomeHeader` + `RefsThemeCard`） |
| `app/lib/features/refs/refs_masonry.dart` | 134 | `RefsMasonryGrid`（按列排布）+ `RefsMasonryImage`（比例锁 + 占位 + 失败回落） |
| `app/lib/features/refs/refs_hit_card.dart` | 208 | 结果图卡 + 悬停浮层（来源/许可/可商用 + 三枚动作） |
| `app/lib/features/refs/refs_hit_drawer.dart` | 212 | 详情抽屉（大图 + 五色色卡 + 来源许可 + 相似参考） |
| `app/lib/features/refs/refs_board.dart` | 311 | 我的画板（4:5 画册块 + 拖拽排序 + 导出长图） |
| `app/lib/features/refs/refs_palette.dart` | 166 | 五色色卡 + 提取服务 + `refsPaletteServiceProvider` 注入点 |
| `app/lib/features/refs/refs_page_chrome.dart` | 133 | 拖拽落画板 + Ctrl/Cmd+V + 图卡详情弹窗 |
| `app/lib/features/refs/refs_page.dart` | **567** | 页面编排（≤600；重构前 849 行单文件） |

- `app/tool/file_size_baseline.json`：`lib/features/refs/refs_page.dart` 白名单**整条删除**（12 → 11 项），`node tool/check_file_size.mjs --json=../docs/qa/v8-file-size.json` → **PASS**。
- `refs_controller.dart` 新增 `boardOrderKey = 'refs_board_order'` + `setBoardOrder()`：画板顺序存 `settings`，**不改表结构**（避免迁移风险）。

## 3. 版面要点（D154 逐条对照）

| 合同要求 | 实现 | 证据 |
|---|---|---|
| 首屏：搜索框居中 | 眉题 `REFERENCE · 画面参考` + 衬线 Display 标题 + 720px 居中检索行（搜索框 + 搜索按钮 + 以图搜图/粘贴截图/本地导入） | 截图 `s5-refs-home-*` |
| 首屏：主题画报入口 | **8 张主题画报**（3:2 版面块 + 衬线首字占位 + mono id，水平横滑）+「全部 48 个主题」 | 截图 + 用例 1/2 |
| 结果：保留纵横比瀑布流 | `RefsMasonryGrid` 4 列，列内堆叠；卡片图块按 hit 自身 w/h 比例锁（0.6–2.4 夹取） | 截图 `s5-refs-results-*` + 用例 3 |
| 结果：悬停浮层 | 来源 / 许可 / 可商用 + 详情·收画板·以图搜图；浮层**只盖图区**，标题与许可常驻图下（R80 逐图标注不被遮） | 用例 5/6 + 截图 |
| 详情：大图 + 色卡 + 相似 | 大图（flex 5）+ 信息栏（flex 4：来源/许可/可商用/尺寸/来源页 + 五色色卡 + 双按钮）+ 相似参考横滑（同 group 优先、≤6、不含自己） | 截图 `s5-refs-detail-*` + 用例 7/8 |
| 我的画板 | 4:5 竖幅画册块（列宽按可用宽度算，160–236px，宽屏不留空白）+ 长按拖拽排序 + 导出画板长图 | 截图 `s5-refs-board-*` + 用例 9–11 |
| 以图搜图收口 | 保留 D116 链路（`ImageToSearch` → 视觉关键词 → 多源检索），并把 `AI 视觉关键词：…` 单独一行显示 | 用例 3 |

## 4. 本步的三个实现改进（非纯换皮）

1. **竖向预算**：`RefsHomeHeader(compact:)` 由「有结果」驱动（`refs_page.dart` 传 `_hits.isNotEmpty`），画报墙换成 30px 单行 chip 行。实测 1280×800 下原本被挤出视口的瀑布流恢复完整可视（对比截图迭代两轮）。
2. **图片失败不留白**：`RefsMasonryImage._resolve()` 给 `Image` 子节点注入兜底 `errorBuilder`，加载/解码失败也回落 surfaceSunken + 衬线首字占位（用例 5 守这条）。
3. **色卡可注入**：`RefsPaletteService` 增加 `extract` 注入点 + `refsPaletteServiceProvider`；真实运行时仍是 SearchCache 下载 + `PaletteExtractor` 提取（R70 只显示真实提取结果），测试/截图覆盖为固定色 → CI 不触网（R62）。

## 5. 视觉证据（R72）

- 16 张：`docs/screenshots/v8/s5-refs-{home,results,detail,board}-{paper,darkroom}-{1280x800,1920x1080}.png`
- 索引：`docs/qa/v8-s5-refs-screenshots.json`（每张含 name/scene/theme/size/bytes；16 张共 39,114–104,403 B）
- 门禁脚本：`app/test/visual/s5_refs_capture_test.dart`
  - `SS_V8_CAPTURE=1 flutter test --no-pub --update-goldens test/visual/s5_refs_capture_test.dart`（产出 + 写索引）
  - `SS_V8_VISUAL=1 flutter test --no-pub test/visual/s5_refs_capture_test.dart`（像素比对）
  - 默认（CI）：只跑 16 个渲染冒烟 + `tester.takeException()` 溢出断言
- 目视：无豆腐块（中文用 NotoSerifSC + 系统 Noto Sans SC）、无 RenderFlex 溢出、无空白图块。

## 6. 测试

`app/test/features/s5_refs_ui_test.dart`（14 用例，全绿）：

| 组 | 用例 |
|---|---|
| 首屏（3） | 眉题/衬线标题/居中搜索框/8 张画报/全部主题入口；三个回调；AI 视觉关键词行（有则显示、无则不显示） |
| 瀑布流（4） | 按列排布且纵向图更高；无图用 surfaceSunken + 衬线首字；图加载失败回落占位；悬停浮层三枚动作 + 来源/许可/可商用 |
| 详情抽屉（2） | `pickSimilar` 同 group 优先/≤6/不含自己；抽屉标题/来源/许可/五色色卡/相似图/三个图位占位标签/加入参考画面 |
| 画板（3） | `applyReorder` 三种情形；空画板衬线空态 + 导入动作 + 有序时来源字段；`setBoardOrder` 持久化并回读（settings） |
| 色卡（2） | `fallbackOf` 补齐 5 色 / 空输入回落常量；渲染 5 段 + hex 文本 + `五色色卡` 语义 |

不回归（R79）：`q6_search_test` 41/41、`q6_lighting_test`、`q2_pose_photos_test`、`golden_flow_test`、`home_flow_test`、`golden_screens_test` 全绿；开案页 golden 因 S4 视觉换代已用 `--update-goldens` 重生成（未删测试）。

## 7. 门禁输出

| 项 | 结果 |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | Formatted 202 files（**0 changed**） |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!**（9.1s） |
| `flutter test --no-pub` | **384 passed + 39 skipped**，All tests passed（24s） |
| `node tool/check_file_size.mjs` | **PASS**（refs_page 白名单已删，11 项） |
| `node tool/test_aim.mjs`（CI 内） | 由 CI 复核 |

## 8. 偏差与限制登记

1. **D149 触控端**：悬停浮层在无 hover 的设备上常驻卡片底部（保留原偏差登记），本步未改变该策略。
2. **截图里的图都是占位**：CI/测试环境 HTTP 被打桩，图块渲染的是「衬线首字占位」——这是 R82 的正确表现（真实运行会显示缩略图）。
3. **色卡为真实提取结果的注入版**：截图与单测用固定色卡（避免触网），真实路径已由 `PaletteExtractor` + `q6_search_test` 侧管线用例覆盖。
