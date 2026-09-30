# V8 / S1 设计 spike 报告（D147 · R77 先行报告）

> 结论先行：**设计方向通过，可进入 S3 落地。** 本步只做「样板 + 令牌 + 截图」三件事，不改任何既有业务页面（R75：不擅动数据管线；R79：V7 界面行为未变）。
> 报告口径：先报告后实施（R77）——本文件在 S3 动工前定稿，§3 令牌值自此锁定；S3 只允许「把本表变成代码」，不允许改值；如需改值先写偏差登记。

---

## 1. 目标与范围

| 项 | 内容 |
| --- | --- |
| 决策 | D147：全应用 + 官网视觉重做，风格 = 暗房印相 + 编辑排版（衬线大标题 + 无衬线正文 + mono 读数 + 印相红点缀） |
| 依据 | `FIX_CONTRACT_V8.0.md` §3（设计系统唯一来源）、§4（四大模块）、D145–D160 |
| 本步产出 | 3 张样板页（App 首页 / App 布光预演 / 官网首屏）+ 12 张截图（明暗 × 1280×800 / 1920×1080）+ 本报告 |
| 明确不做 | 不接入业务数据、不改 `core/theme/` 现状、不删 V7 页面与测试 |

三张样板覆盖 §4 的三类关键版式密度：内容流（首页）、三栏工作台（布光）、营销首屏（官网）。

---

## 2. 样板页清单

| # | 样板 | 位置 | 承载的设计决策 |
| --- | --- | --- | --- |
| 1 | App 首页（7+5 不对称） | `app/lib/design_spike/spike_pages.dart` → `spikeHomePage()` | 首屏叙事：眉题（mono + 字距 1.5）→ 衬线 Display 40 → 无衬线 lede 14/1.6 → 双按钮（实心/描边）→ mono 读数三列 → 4:5 衬线首字占位图框 |
| 2 | App 布光预演（三栏工作台） | 同文件 → `spikeLightingPage()` | 185px 左清单 / ≥60% 中视口 / 右检查器；工具条 chip；底部出片进度与 A/B；mono 显示 `P95 12.4MS` 帧耗时与 `Ctrl+Z` 提示 |
| 3 | 官网首屏 | `web/src/pages/spike-hero.astro` | 与 App 首页同一语言：顶栏 + 7/5 hero + 8/4 strip（功能三联 + 最近更新 + 12 令牌色板）+ 3:2 / 4:5 / 16:9 比例样张 |

---

## 3. 令牌锁定记录（§3 唯一来源，R71）

### 3.1 色彩 12 令牌 × 2 主题

| 令牌 | paper（纸面亮） | darkroom（暗房暗） | 用途 |
| --- | --- | --- | --- |
| `--bg` | `#FAF7F1` | `#131110` | 页面底 |
| `--surface` | `#FFFFFF` | `#1B1815` | 卡片/面板 |
| `--surface-sunken` | `#F3EFE7` | `#100E0C` | 图框凹槽/输入槽 |
| `--ink` | `#1C1917` | `#F0EBE3` | 主文字 |
| `--ink-soft` | `#57534E` | `#A8A29A` | 次级文字 |
| `--muted` | `#8A857C` | `#78716B` | 弱化/标注 |
| `--rule` | `#E4DECF` | `#2E2A24` | hairline 分隔 |
| `--accent` | `#B43A2B` | `#D9563F` | 印相红（主行动/眉题） |
| `--accent-soft` | `#B43A2B14` | `#D9563F1F` | 选中/弱背景 |
| `--film` | `#2F5D50` | `#4E8A77` | 次强调（胶片绿） |
| `--gold` | `#A97E2F` | `#C9A24B` | 提示/评分 |
| `--danger` | `#B3261E` | `#E06C60` | 危险/删除 |

### 3.2 字号阶梯 / 字族 / 眉题

| 档 | 字号 | 行高 | 默认字族 |
| --- | --- | --- | --- |
| Display | 40 | 1.2 | 衬线 NotoSerifSC |
| H1 | 28 | 1.3 | 衬线 |
| H2 | 22 | 1.35 | 衬线 |
| H3 | 17 | 1.4 | 衬线 |
| Body | 14 | 1.6 | 无衬线 Microsoft YaHei |
| Small | 12.5 | 1.5 | 无衬线 |
| Caption | 11 | 1.4 | 无衬线 |

- 眉题（Eyebrow）：Caption 11 / 1.4，**mono 字族**，字重 500，**字距 1.5px**，大写英文。
- mono 只用于：读数、日期、快捷键、令牌名、眉题 —— **不得放中文正文**（见 §6 缺陷 3）。

### 3.3 间距 / 圆角 / 栅格 / 阴影 / 动效

| 项 | 值 |
| --- | --- |
| 8pt 间距 | 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64（`--sp-1..8`） |
| 圆角 | 2（chip）/ 4（控件）/ 8（图框） |
| 栅格 | 最大内容宽 1280 · 12 列 · 列距 24 · 页边距 24（≥1600px 时 32） |
| 阴影 | 仅两级：`--shadow-paper` `0 1px 4px rgba(0,0,0,.08)`、`--shadow-overlay` `0 8px 24px rgba(0,0,0,.12)` |
| 动效 | 160 / 280 / 420ms，缓动 `cubic-bezier(.22,1,.36,1)`；`prefers-reduced-motion` 时全部降为 1ms |

### 3.4 字体资产

| 文件 | 大小 | 许可 |
| --- | --- | --- |
| `app/assets/fonts/NotoSerifSC-ShootStudio.otf` | 566,132 B（0.54MB） | OFL 1.1（`NotoSerifSC-OFL.txt`） |
| `web/public/fonts/NotoSerifSC-ShootStudio.otf` | 同上（官网共用） | 同上 |

- 子集：pyftsubset 4.54.1，从 `notofonts/noto-cjk` 的 `Serif/SubsetOTF/SC/NotoSerifSC-Regular.otf`（11,625,800 B）按 `app/lib` + `app/test` 字符串字面量取 1,663 个 CJK + 411 个基础字符 = 2,074 字符。
- 复现命令与来源记录见 `app/assets/fonts/README.md`（R80 许可红线：字体入库已附许可全文）。

---

## 4. 截图证据（R72 明暗 × 1280×800 / 1920×1080）

生成方式与索引：
- App 样板：`SS_V8_CAPTURE=1 flutter test --no-pub --update-goldens test/visual/s1_spike_capture_test.dart`（9 用例）→ 索引 `docs/qa/v8-s1-screenshots.json`
- 官网样板：`npm run build`（Astro 6 页）→ `node web/tool/shot.mjs`（headless Edge + CDP `Emulation.setDeviceMetricsOverride`，主题用 `?t=darkroom`）→ 索引 `docs/qa/v8-s1-web-screenshots.json`

| 截图 | 尺寸 | 字节 |
| --- | --- | --- |
| `s1-home-paper-1280x800.png` | 1280×800 | 53,410 B |
| `s1-home-paper-1920x1080.png` | 1920×1080 | 63,500 B |
| `s1-home-darkroom-1280x800.png` | 1280×800 | 53,529 B |
| `s1-home-darkroom-1920x1080.png` | 1920×1080 | 63,380 B |
| `s1-lighting-paper-1280x800.png` | 1280×800 | 49,103 B |
| `s1-lighting-paper-1920x1080.png` | 1920×1080 | 54,896 B |
| `s1-lighting-darkroom-1280x800.png` | 1280×800 | 48,039 B |
| `s1-lighting-darkroom-1920x1080.png` | 1920×1080 | 53,795 B |
| `s1-web-hero-paper-1280x800.png` | 1280×800 | 64,049 B |
| `s1-web-hero-paper-1920x1080.png` | 1920×1080 | 86,020 B |
| `s1-web-hero-darkroom-1280x800.png` | 1280×800 | 63,702 B |
| `s1-web-hero-darkroom-1920x1080.png` | 1920×1080 | 85,482 B |

合计 12 张 / 738,905 B，全部落在 `docs/screenshots/v8/`。**目视结论**：双主题、四分辨率下无豆腐块、无重叠、留白均衡；1920 下内容居中于 1280 栅格（页边距自动放大到 32）。

---

## 5. 实现清单

| 文件 | 作用 |
| --- | --- |
| `app/lib/design_spike/spike_tokens.dart` | App 侧令牌（`SpikePalette` / `SpikeType` / `SpikeSpace` / `SpikeRadius` / `spikeShadow*` / `SpikeMotion` / `SpikeGrid` / `SpikeFrameRatio`） |
| `app/lib/design_spike/spike_pages.dart` | 两张 App 样板页 + 私有构件（顶栏/眉题/图框/KV 行/chip/按钮/色板/检查器） |
| `app/test/visual/s1_spike_capture_test.dart` | 截图与 golden 比对工具（`SS_V8_CAPTURE=1` 产出、`SS_V8_VISUAL=1` 比对、默认只冒烟，CI 干净） |
| `web/src/styles/spike_tokens.css` | 官网侧令牌（与 Dart 逐字同值，`:root` + `[data-theme='darkroom']`） |
| `web/src/pages/spike-hero.astro` | 官网样板页（全站只引用 CSS 变量） |
| `web/tool/shot.mjs` | 官网截图工具（静态伺服 `web/dist` + headless Edge CDP） |
| `app/assets/fonts/*` | 衬线子集字体 + OFL 许可 + 来源 README |
| `app/pubspec.yaml` | 新增 `fonts:` 段与 `assets/fonts/` |

---

## 6. 视觉缺陷与根因（复盘，S3 直接规避）

| # | 现象 | 根因 | 修法 |
| --- | --- | --- | --- |
| 1 | 首页 hero 文案被压到底部、标题两行重叠、KV 标签竖排 | `SpikeType.style()` 把 `height` 写成 `lineHeight / size`（≈0.03）→ RenderParagraph 高度塌成 1–2px | `height: lineHeight`（多倍数行高） |
| 2 | 4:5 图框 624px 撑爆行高，把左栏压到底 | `_ImageFrame` 声明了 `height` 却未使用（永远走 AspectRatio） | 支持限高时用 `Container(height:)`；hero Row 改 `CrossAxisAlignment.start` |
| 3 | mono 文本里的中文与 `⌘` 变豆腐块 | Consolas 无 CJK 字形 | mono 只放 ASCII 读数；中文一律走无衬线/衬线 |
| 4 | 按钮图标是豆腐块 | 截图环境未加载 MaterialIcons | `_systemFonts` 追加 `MaterialIcons-Regular.otf`（来自 Flutter SDK） |

定位方法（可复用）：临时 widget 测试里自写 `_walk(RenderObject)` 打印 `RenderParagraph.size/constraints`，把结果写文件再读 —— 比肉眼看图快一个量级。注意本版本 `debugDumpRenderTree()` 无参、`visitChildren` 回调返回 `void`。

---

## 7. 门禁（R81 五件）

| 门禁 | 命令 | 结果 |
| --- | --- | --- |
| format | `dart format lib test` → 复查 `--output=none --set-exit-if-changed` | 170 files，**0 changed**（exit 0） |
| analyze | `flutter analyze --no-pub --fatal-infos` | **No issues found**（9.2s） |
| 全量 test | `flutter test --no-pub` | **303 passed + 36 skipped，All tests passed!** |
| 专项 | `SS_V8_CAPTURE=1 flutter test --no-pub --update-goldens test/visual/s1_spike_capture_test.dart` | **9/9 passed**（产出 8 张 golden） |
| 专项（回归） | `SS_V8_VISUAL=1 flutter test --no-pub test/visual/s1_spike_capture_test.dart` | **8 passed + 1 skipped**（golden 与盘面 PNG 一致，R72 回归可用） |
| CI | push 后 main run | 见 `HANDOFF_V8.md` §0 |

skip 口径：S0 基线 303 passed + 27 skipped；S1 新增 9 个视觉用例**默认跳过**（需 `SS_V8_CAPTURE=1` / `SS_V8_VISUAL=1` 显式开启），故 skipped 27 → 36、passed 不变（R79 无回归，CI 时长不受影响）。

---

## 8. 对 S2 / S3 的输入

1. **S2 引擎架构 spike**：本步不影响引擎；S2 需在同一 `SS_*` 环境变量约定下追加自己的门控（沿用 S1 的「默认不跑、显式开关才跑」模式，避免 CI 变慢）。
2. **S3 落地**：把 §3 表逐字搬进 `lib/core/design/`（单文件 ≤600 行，该目录 ≤300 行，R73），并在 CI 加 `tool/check_file_size.mjs`；既有 `core/theme/` 保留一个版本周期再删（R76 迁移明示）。
3. **R71 校验手段**：`lib/core/design/` 内禁止出现字面量色值/字号（`Colors.x`、`fontSize: n`、`EdgeInsets.all(n)`），由 `test/design/tokens_test.dart` 扫描源码门禁。
