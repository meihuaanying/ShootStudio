# V8 / S4 · App 外壳 + 首页重构报告（D151 · R71–R74 / R79 / R82）

- 步骤：S4 App 外壳 + 首页重构（`FIX_CONTRACT_V8.0.md` §1 S4 行）
- 日期：2026-09-30
- 基线：S3 全量 333 passed + 37 skipped
- 结论：**通过**。信息架构重建为三段式（工作流/成案/系统），更新横幅改为公告式双行动，首页改为衬线大标题首屏；全部走 `core/design` 组件，零渐变紫蓝、零硬编码色，页面文件全部 ≤600 行（R73）。

---

## 1. 交付文件与行数（R73）

| 文件 | 行数 | 职责 |
|---|---|---|
| `lib/features/shell/shell_nav.dart` | 321 | 信息架构（3 分组 + 7 入口 + 品牌方章 + 侧边导航） |
| `lib/features/shell/app_shell.dart` | 134 | 外壳组装（左导航 + 1px hairline + 懒建内容区） |
| `lib/features/shell/shell_update_banner.dart` | 94 | 更新公告横幅（眉题 + 版本 + 要点 + 双行动） |
| `lib/features/home/home_page.dart` | 171 | 开案页编排（hero + 生成态 + 灵感条 + 最近策划案） |
| `lib/features/home/home_hero.dart` | 178 | 衬线大标题 hero + 输入 + 生成 + 灵感横滑 + 生成态推理 |
| `lib/features/home/home_recent.dart` | 119 | 最近策划案（loading/error/空态/列表） |

重构前：`app_shell.dart` 343 行（含紫蓝渐变方章 + 纯红底横幅）、`home_page.dart` 365 行。重构后**两页拆为 6 个文件，最大 321 行**。

---

## 2. 信息架构（R151 / R76 迁移明示）

```
工作流 WORKFLOW  开案(0) 画面参考(1) 布光预演(2) 动作摆姿(3)
成案 DELIVERY    资源库(4) 策划案(5)
系统 SYSTEM      设置(6)
```

- `kShellNavSections` 三组起点 `0 / 4 / 6`，严格递增并覆盖全部 7 个下标；`shellTabProvider` 下标语义在 `app_shell.dart` 与 `shell_nav.dart` 双处注释（R76 迁移明示）。
- 每个入口带 mono 小标（IDEA / REF / LIGHT / POSE / GEAR / PLAN / SET），选中态 = `accentSoft` 底 + 1px `accent` 左边框 + `accent` 文字（非 Material 默认脸，R82）。
- 首页跳转策划案统一用 `kShellTabPlanner = 5`（与 `kShellNavItems[5].label == '策划案'` 互为断言）。
- 品牌区由「渐变方章」改为 `accent` 实色方章 + 衬线「正」；侧栏底部固定 `v1.3.0 · MIT 开源`（`kAppVersion` 单一来源）。

## 3. 更新横幅（公告式）

- 形态：`surfaceSunken` 底 + 1px `rule` 收边；`Icon(system_update)` + `appEyebrow('更新公告')` + `SsMonoBadge('v<version>')` + 要点 chip（**只取前 2 条**，`maxLines: 1` ellipsis，避免长文撑高）+ `SsButton(text '下次再说')` + `SsButton(primary '立即更新')`。
- 下载通道：`announcement.downloadFor(platform)`（windows/android 按 `Theme.of(context).platform` 判定）→ `mirror` 优先、否则 `github`；两者皆空时 `ssToast('请前往官网下载 v<version>')`（不静默）。
- 横幅显隐仍由 `UpdaterState.showBanner`（`announcement != null && lastState == hasUpdate && !dismissed`）决定，行为与 V7 一致。

## 4. 首页

- 首屏：`SsEyebrow('OPENING · 开案')` + **Display 衬线「说说你想拍什么」**（既有测试依赖文案，R79 保留）+ lede（maxWidth 620）+ 输入框 + `SsButton(primary '生成策划案')` + 「数据都在本地工作区 · 模型随包 · 无需联网」说明行。
- 灵感：6 张 `SsCard` 横滑（208 宽），点击回填输入；`kHomeInspirations` 提到模块级常量（6 条标题/提示词与重构前逐字一致）。
- 最近策划案：loading（`CircularProgressIndicator`）/ error（`SsBanner`）/ 空态（`SsCard`「还没有策划案 · 在上面输入想法，或从模板库开始」）/ 列表（模块数 `homeModuleCount` + chevron）。

---

## 5. 视觉证据（R72）

| 场景 | 文件（明暗 × 1280×800 / 1920×1080） | 字节 |
|---|---|---|
| 外壳 + 首页 | `s4-shell-home-{paper,darkroom}-{1280x800,1920x1080}.png` | 77,394 / 84,846 / 76,845 / 84,319 |
| 外壳 + 更新横幅 | `s4-shell-banner-{paper,darkroom}-{1280x800,1920x1080}.png` | 90,216 / 97,480 / 89,805 / 96,828 |

索引：`docs/qa/v8-s4-shell-home-screenshots.json`（2 场景 × 2 主题 × 2 分辨率 = 8 张）。
产出：`$env:SS_V8_CAPTURE='1'; flutter test --no-pub --update-goldens test/visual/s4_shell_home_capture_test.dart`；比对：`$env:SS_V8_VISUAL='1'`；CI 默认只跑渲染冒烟 + `takeException()` 溢出断言。
渲染说明：截图为 `AppShell` 的**真实组件组合**（`ShellSideNav` + `VerticalHairline` + `ShellUpdateBanner` + 真实 `HomePage`）；`AppShell` 本身仅 40 行组装层且 `initState` 会触发联网 `silentCheck()`，故按真实布局组合渲染以保证可复现。
目视结论（`s4-shell-banner-paper-1280x800.png`）：三段式导航分组清晰、选中态为红调 + 左边框、公告横幅双行动齐整、衬线大标题与 hairline 留白均衡、无豆腐块/无溢出；1280 与 1920 下内容均落在 1280 栅格内。

---

## 6. 测试（R79 只增不减）

### 6.1 新增 `app/test/features/s4_shell_home_test.dart`（13 用例，全绿）
1. 三分组连续覆盖 7 个入口（label/eyebrow/startIndex `[0,4,6]`、严格递增）
2. 7 入口 label/caption 齐全唯一 + `kShellTabPlanner == 5` 且与导航顺序一致
3. 侧边导航渲染 + 点击回调下标（点「布光预演」→ 2、点「设置」→ 6）
4. 选中态渲染无重复高亮 + `ShellSideNav.width ≥ 200`
5. 更新横幅：眉题 + 版本 + 前 2 条要点 + 第 3 条不显示 + 双行动
6. 无公告时横幅不渲染任何内容
7. 公告按平台取直链，mirror 优先、`android.mirror` 为空回落 github、未知平台为 null
8. 首页 hero：eyebrow + 衬线标题 + 生成按钮 + 输入回填 + 回调计数
9. 灵感条：6 条常量 + 首屏卡片 + 点击回传条目
10. 最近策划案空态（`recentPlansProvider` override → 空列表）
11. **R74**：6 个 S4 文件均 `import core/design/widgets.dart`
12. **R71 + R82**：6 个 S4 文件无 `LinearGradient` / `Colors.` / `0x` / `fontSize:`
13. **R73**：6 个 S4 文件均 ≤600 行

### 6.2 新增 `app/test/visual/s4_shell_home_capture_test.dart`（8 截图 + 1 索引）

### 6.3 既有测试（不回归）
`home_flow_test` / `golden_flow_test` / `golden_screens_test`（开案页 golden 因设计系统换代用 `--update-goldens` 重生成，**未删测试**，R79 合规）→ 10 passed。

---

## 7. 门禁数据（R81）

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 193 files，**0 changed** |
| `flutter analyze --no-pub --fatal-infos` | **No issues found!**（12.0s） |
| `flutter test --no-pub` | **354 passed + 38 skipped，All tests passed!**（S3 基线 333 + 37；新增 13 专项 + 8 视觉；skip +1 = 截图索引） |
| 专项：`test/features/s4_shell_home_test.dart` | **13 passed** |
| 专项：`test/visual/s4_shell_home_capture_test.dart` | 8 截图 + 1 索引，All tests passed |
| CI | 见 `HANDOFF_V8.md`（提交后复核） |

---

## 8. 缺陷复盘

| # | 现象 | 根因 | 修法 |
|---|---|---|---|
| 1 | `golden · 开案页` 像素不一致 | 设计系统换代后视觉变化 | `--update-goldens` 重生成（R79） |
| 2 | 专项测试编译失败 `'Plan' isn't a type` | `Plan` 是 drift 生成类，经 `core/db/database.dart` 导出 | 测试改 import `core/db/database.dart`（不需 `hide Column`） |
| 3 | 分组连续性断言写错（期望相等） | 分组起点本就不同（0/4/6），应断言严格递增 | 改正断言 |
| 4 | 灵感条断言「婚纱旅拍」找不到 | 横向 `ListView` 懒构建，屏外卡片未构建 | 只断言首屏可见卡片 + 常量长度 |
| 5 | 门禁测试报 `shell_nav.dart 出现 Colors.` | 选中态左边框用 `Colors.transparent` | 改 `p.rule.withValues(alpha: 0)`（令牌色透明，R71） |
| 6 | 门禁测试仍报同样错误 | 注释里写了 `Colors.transparent` 字样 | 改写注释措辞（源码级门禁要连注释一起干净） |

---

## 9. 对 S5 的输入

1. `ShellSideNav`/`AppShell` 不再改动下标语义；S5 画面参考页只需替换 `refs_page.dart` 内部结构，`AppShell._pages[1]` 顺序保持。
2. 页面统一用 `SsPage` + `SsSectionTitle`/`SsEyebrow` 骨架；色/字号/间距一律 `context.palette` + `AppType`。
3. 视觉门禁复用 `test/visual/s4_*_capture_test.dart` 模板（改 page 与 key 即可），索引 JSON 命名 `v8-s5-*.json`。
4. 文字面量收敛：S4 六个文件已 0 残留（测试守护），S5 起对 `refs/**` 做同样收敛。
