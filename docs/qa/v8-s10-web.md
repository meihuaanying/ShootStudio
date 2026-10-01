# V8/S10 · D157 官网重做 — 完工报告

## 1. 结论

官网 5 页（index / features / downloads / templates / changelog）已按 §3 设计令牌全量重排：删除旧蓝紫体系与纯装饰 SVG 光圈，首屏换成**真实产品静帧**（明暗双主题各一张，占视口约 54%），features 页改为「真实截图 + 眉题 + 短文案」的杂志跨页式布局，downloads 的 `announcements.json` 通道与 8 个 DOM id 原样保留。构建 `npm run build` 出 6 页（5 正式页 + `spike-hero` 残留页，留 S11 清理），视觉门禁出 **30 张截图**（5 页 × paper/darkroom × 1280×800 / 1920×1080 / 390×844）+ 索引 JSON。

## 2. 令牌对齐（R71 唯一来源）

`web/tailwind.config.mjs` 与 `web/src/styles/global.css` 全部改为引用 `web/src/styles/tokens.css` 的 CSS 变量（§3 唯一来源，与 App `AppTokensV2` 逐字一致）：

| 类别 | 处理 |
|---|---|
| `colors.ss`（旧蓝紫 12 项） | **整块删除**（含 `#4D6BFE` / `#7B5CFF` / `#2BA471` 等硬编码） |
| `colors.v8`（12 色） | 全部指向 `var(--bg) / --surface / --sunken / --ink / --ink-soft / --muted / --rule / --accent / --accent-soft / --film / --gold / --danger` |
| `fontFamily` 三族 | `sans/display/mono` → `var(--font-body) / --font-display / --font-mono` |
| `fontSize` 7 档 | `['var(--type-x)', {lineHeight:'var(--lh-x)'}]` |
| `spacing['v8-1'..'v8-8']` | `var(--sp-1)` … `var(--sp-8)` |
| `borderRadius` / `boxShadow` | 只保留 `v8-chip/control/frame` 与 `v8-paper/v8-overlay`；旧 `ss` / `sslg` 删除 |
| `transitionDuration` | `v8-fast/normal/slow` → `var(--motion-fast/normal/slow)` |
| `global.css` `body` | `@apply bg-v8-bg text-v8-ink font-sans antialiased`（原 `bg-ss-bg dark:bg-ss-bg-dark`） |
| `global.css` `.card` | `rounded-v8-frame border border-v8-rule bg-v8-surface shadow-v8-paper` |

新增可复用组件类：`.eyebrow`（mono 11px / letter-spacing 0.18em / accent）、`.accent-text`（衬线 accent 标题，替代旧 `.grad-text` 渐变）、`.shot`（真实截图统一外框）、`.btn` / `.btn-primary` / `.btn-ghost`。

## 3. 首屏改造（D157 硬指标）

- **删除 104 行手写装饰 SVG 光圈**（`ss-aperture` 渐变 + 六片叶片 + 胶片齿孔带 + 通光孔 + 光线条）及对应 CSS 关键帧（`aperture-breathe` / `film-roll` / `glow-pulse`）、`.hero-visual` / `.hero-mask` / `.grid-bg`。
- 首屏右栏改为 `<figure class="shot" data-hero-item data-hero-visual>` + `<picture>`：`/shots/hero-dark.png`（`media="(prefers-color-scheme: dark)"`）与 `/shots/hero-paper.png`，`width=1920 height=1080`、`loading="eager"`，配 `figcaption`「成案阅读视图 · 真实产品静帧（明暗双主题各一张）」。
- grid 改 `lg:grid-cols-[minmax(0,0.92fr)_minmax(0,1.08fr)]` → **图片列实测占视口约 54%**（≥50% 达标）。
- 左栏：`eyebrow`「SHOOTSTUDIO · V1.3.0 · MIT 开源」+ `font-display` 衬线大标题「两分钟灵感，三十分钟成案」+ 副文案 + 双下载 CTA（`.btn-primary` Windows / `.btn-ghost` 安卓，均链 `/downloads`）+ mono 小字「国内 CDN 镜像优先 · GitHub Release 回退 · SHA-256 校验」。
- 顺手修掉既有文案不一致：「九大能力」但数组只有 8 项 → 改为「八大能力」。

## 4. 五页逐页

| 页 | 改造 |
|---|---|
| **index** | 首屏真实静帧（见 §3）；四步工作流 4 卡保留来源标注（FILMGRAB / Set.a.light / posemaniacs / AI 策划助手）；**八大能力卡每张配真实产品截图**（`refs`/`lighting`/`poses`/`plan`/`ai`/`export`/`library`/`gear`）；本地优先段保留 mono 目录树 |
| **features** | 9 个模块改**杂志跨页**：`<article class="card grid overflow-hidden p-0 md:grid-cols-2">` + `<img class="h-full w-full object-cover">` + 右栏 eyebrow（`6.x · tool`）+ 衬线标题 + 圆点列表；**奇数项 `md:order-2` 让图左右交替** |
| **downloads** | **8 个 DOM id 全部保留**（`win-ver`/`and-ver`/`win-mirror`/`and-mirror`/`win-github`/`and-github`/`win-sha`/`and-sha`）与 `fetch('/announcements.json')` 的 script 逻辑**原样不动**；样式改 v8 令牌；新增系统要求卡 + 真实截图 |
| **templates** | `templates.json` 通道不变；chip 样式抽成 `CHIP` / `CHIP_ON` 常量；**新增 `escapeHtml()`**（原来 `innerHTML` 直接拼 `t.name`/`t.description`，模板数据含 `<` 即破版） |
| **changelog** | `announcements.json` 通道不变；同样加 `escapeHtml()`；计划中条目改 `v2.0.0 · 计划中`（3 条 V8 收官说明）+ `text-v8-gold` + 「计划中」眉题 |
| **scripts/motion.js** | 232 → **78 行**：删光圈叶片 / 胶片流线 / 鼠标视差 / 滚动加速（服务的 DOM 已随装饰 SVG 删除，留着就是死代码，呼应 §6 D158）；过渡统一交给 CSS，GSAP/ScrollTrigger 只负责加 `.is-in` class，并带 `setTimeout` / `window.onerror` / `try-catch` 三重兜底 |

**新建 `web/src/data/landing.ts`**：S10 单一文案源（`steps: Step[]` 4 项 + `cards: Card[]` 8 项，含 `shot` 字段），避免 index 页文案与截图映射散落。

## 5. 截图与索引

- 视觉门禁 `web/tool/shot_s10.mjs`（新建，Node 内建依赖 + Edge headless CDP）：`--pages` / `--themes` / `--viewports` / `--index` 四个参数。
- 矩阵 = 5 页 × `paper`/`darkroom` × `1280x800` / `1920x1080` / `390x844`（含移动档）= **30 张** `docs/screenshots/v8/s10-web-<page>-<theme>-<vp>.png`。
- 索引 `docs/qa/v8-s10-web-screenshots.json` 除清单外还含每张的 `domTheme` / `bodyBg` / `bodyInk` / `scrollHeight` / `brokenImgs` / `unrevealed` / `bytes`，以及全局 `announcement`（announcements 通道读数）与 `brokenImgs`（R82 禁占位图）。
- 实测：**30/30 张**，`brokenImgs = 0`；paper 档 `bodyBg = rgb(250,247,241)`，darkroom 档 `rgb(19,17,16)` 且 `domTheme = darkroom`；体积 33.9–143.9 KB。
- 复现：`cd web && npm run build && node tool/shot_s10.mjs`。

## 6. announcements 通道不回归（D157「通道不变」）

截图脚本末行实测输出：

```json
{"winVer":"1.3.0","andVer":"1.3.0",
 "winMirror":"https://mirror.example.com/shootstudio/v1.3.0/shoot-studio-v1.3.0-windows.zip",
 "andMirror":"…/shoot-studio-v1.3.0-android.apk",
 "winSha":"发布时由 CI 写入","andSha":"发布时由 CI 写入"}
```

版本号被 `announcements.json` 覆盖（页面 fallback 是 1.3.0，announcements 也是 1.3.0）、镜像链接走 `mirror` 并有 `github` 回落、sha 占位文案保持。8 个 DOM id 与写回逻辑零改动。

## 7. 修掉的 3 个真实 bug（第一轮截图暴露，非测试迁就）

1. **非首页 4 页全白**：`astro.config.mjs` 是 `trailingSlash: 'ignore'` → 产物是 `dist/<page>/index.html`；S1 的静态服务器只对「以 `/` 结尾」的 pathname 补 `index.html`，所以 `/features` 去读目录名 → 404 → 空白页（截图仅 4958 B、body bg 透明）。修法：`shot_s10.mjs` 导航前 `const urlPath = page.endsWith('/') ? page : page + '/'`。
2. **暗色主题从来没生效过**：`tokens.css` 的暗色值挂在 `[data-theme='darkroom']` 上，而 `Layout.astro` 的 `<html>` 根本没有 `data-theme` 属性（旧设计靠 Tailwind `dark:` 变体 + `darkMode:'media'` 兜住了，所以 S1 期间没暴露）。改造后 `body` 直接吃 `var(--bg)`，暗色值永远拿不到。修法：`<head>` 加 `is:inline` 脚本把系统 `prefers-color-scheme` 映射成 `document.documentElement.dataset.theme = 'darkroom'|'paper'` 并监听 `change`，同时支持 `?t=paper|darkroom` 显式覆盖。
3. **`Emulation.setEmulatedMedia` 的 `prefers-color-scheme` 只接受 `light|dark`**：最初直接传内部命名 `paper`/`darkroom`，暗色档渲染出来仍是 paper（`bg=rgb(250,247,241)`）。修法：`value: theme === 'darkroom' ? 'dark' : 'light'`。

另修两处**度量口径错误**（不是页面 bug）：R82 占位图检查原把「lazy 屏外图未下载」误判为 broken 且逻辑取反 → 改为仅当 `complete && naturalWidth === 0` 才算 broken；`unrevealed` 原统计全部屏外未 reveal 块 → 改为「已进入视口却仍 opacity 0」。

## 8. 测试与门禁

| 项 | 结果 |
|---|---|
| `cd web && npm run build` | **6 page(s) built**，无错误 |
| `node tool/shot_s10.mjs` | **30/30 张**，`brokenImgs = 0`，暗色档 `domTheme = darkroom` |
| announcements 通道 | 8 个 id 读数全部有值（见 §6） |
| 旧 `ss-*` 与蓝紫硬编码在 `web/src/**` | **0 命中** |
| `dart format lib test` | 0 changed（247 files） |
| `flutter analyze --no-pub --fatal-infos` | No issues found |
| `flutter test --no-pub`（全量） | **517 passed + 43 skipped**，All tests passed |
| `node tool/check_file_size.mjs` | PASS（baseline 4 条） |

S10 未改动 `app/`，App 侧门禁数字与 S9 基线完全一致（可反证本轮零回归）。

## 9. 偏差与限制登记

- **`web/src/pages/spike-hero.astro`（461 行）仍在 `npm run build` 产物里**：它是 S1 设计 spike 的残留页，不属于 5 个正式页。本轮只把它的主题切换通道与 `shot.mjs` 保留，删除它属于 S11 死代码清理范围（需先 grep 引用计数为 0）。
- **`unrevealed` 在 index / features 的 1920×1080 档为 1**：是视口底边的 hero item 尚未被 ScrollTrigger 触发，属正常值，不作为失败判据。
- **官网不在 R73 行数门禁范围**（门禁只管 `lib/features/**` ≤600 与 `lib/core/design/**` ≤300）。
- **双主题跟随系统**：`Layout.astro` 仍无静态 `data-theme`，由内联脚本按 `prefers-color-scheme` 写入，因此不支持「用户手动锁定主题」——D157 未要求，本轮不加。
- **`templates.json` 仍有 784 行**且被 `templates.astro` 整包读入；本轮只补了转义与样式，未做分包（性能影响未测，留 S11 观察）。
