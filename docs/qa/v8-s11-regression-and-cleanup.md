# V8/S11 · D158 全量回归 + 视觉验收 + 死代码清理 — 完工报告

## 1. 结论

S11 三项要求全部落地：**全量门禁全绿**（format 0 changed / analyze 0 问题 / test 517 passed + 43 skipped / 行数门禁 PASS / 官网 5 页构建 + 30 张截图不回归）、**7 页 App 截图总表**（明暗 × 两档分辨率 = 28 张，缺失 0）、**死代码删除清单**（App 侧两维度扫描均零死代码；Web 侧删除 2 个 V1/S1 残留文件共 656 行，删除后官网精确回到 5 页、截图与 announcements 通道零回归）。

## 2. 全量门禁输出（本段实测）

| 门禁 | 命令 | 结果 |
|---|---|---|
| 格式 | `dart format lib test` | Formatted 247 files (**0 changed**) |
| 静态分析 | `flutter analyze --no-pub --fatal-infos` | **No issues found!**（8.2s） |
| 全量测试 | `flutter test --no-pub` | **517 passed + 43 skipped**，`00:34 +517 ~43: All tests passed!` |
| 行数门禁（R73） | `node tool/check_file_size.mjs --json=../docs/qa/v8-file-size.json` | **PASS**（白名单 4 条：lighting_controller 760 / ai_panel 747 / libraries_page 808 / ai_client 779） |
| 官网构建 | `cd web && npm run build` | **5 page(s) built in 1.11s**（删除前为 6 页） |
| 官网视觉 | `cd web && node tool/shot_s10.mjs` | **写出 30/30**，索引 `docs/qa/v8-s10-web-screenshots.json`；`brokenImgs` 全 0；暗色档 `domTheme=darkroom` + `body bg=rgb(19,17,16)` |

`lib/features/**` 超过 600 行的文件数已从 S8 开始的 **10 个降到 4 个**（全部在白名单内且只降不升）。

## 3. 7 页 App 截图总表（28 张）

对照表见 `docs/qa/v8-s11-overview-table.md`（Markdown 三列表：页面 / 亮色纸面 / 暗色暗房，每格含两个分辨率的相对链接与体积）；机器可读索引见 `docs/qa/v8-s11-screenshots.json`（`count=28`、`missing=[]`）。

| 页面 | 证据 stem | 阶段 |
|---|---|---|
| 首页 | `s4-shell-home` | S4 |
| 画面参考 | `s5-refs-results` | S5 |
| 布光预演 | `s6-lighting-workspace` | S6 |
| 动作摆姿 | `s7-pose-gallery` | S7 |
| 策划案 / AI 成案 | `s8-plan-stage-reading` | S8 |
| 资源库 | `s9-libraries` | S9 |
| 设置 | `s9-settings` | S9 |

每页 = `paper` + `darkroom` × `1280x800` + `1920x1080`，合计 7 × 2 × 2 = **28 张，缺失 0**。官网另有 `s10-web-*.png` 30 张（5 页 × 明暗 × 三档视口含移动 390×844）。

## 4. 死代码扫描与删除清单

### 4.1 App 侧（两个维度均零死代码）

- **按符号维度**（扫 `app/lib` 全文，lib 引用计数 ≤1 且 test 引用为 0）：仅 3 条命中，**全部是 extension 误报**——`core/design/tokens.dart :: AppPaletteContext`、`ai/ai_controller_generate.dart :: AiControllerGenerate`、`ai/ai_controller_revise.dart :: AiControllerRevise`。extension 靠成员访问使用（`context.palette` / `controller.generatePlan(...)`），名字本身只出现一次。
- **按文件维度**（扫 `app/lib/**/*.dart` 共 **179 个文件**，用 `import|part|part of` 正则统计 basename 引用）：**未被引用 = 0**（仅 `main.dart` 与 `env.dart` 属天然 0 引用，已排除）。

→ **App 侧无死代码可删。**

### 4.2 Web 侧（删除 2 个文件，共 656 行）

| 文件 | 行数 | 删除理由 | grep 证据 |
|---|---|---|---|
| `web/src/pages/spike-hero.astro` | 462 | V1/S1 设计 spike 残留页，不在 D157 规定的 5 页内，`Layout.astro` 的 nav 无入口，CI 不构建它 | 全部命中均为注释或历史报告叙述（`shot_s10.mjs` 注释、`docs/qa/v8-s1-design-spike.md`、`docs/qa/v8-s10-web.md`），**无任何功能性引用** |
| `web/tool/shot.mjs` | 194 | S1 截图工具，已被 `web/tool/shot_s10.mjs`（334 行，支持明暗双主题 + 移动视口 + announcements 通道校验 + R82 占位图检查）完全取代 | 其唯一「功能引用」是对已删 spike-hero 的默认 `--path=/spike-hero` 参数；`package.json` 无 shot script，无 CI 调用 |

### 4.3 零回归实证（删后立刻验证）

- `npm run build`：**6 页 → 5 页**（`dist/` 下只剩 `index.html` + `changelog` / `downloads` / `features` / `templates`），精确满足 S10 门禁「`npm run build` 5 页全出」。
- `node tool/shot_s10.mjs`：**30/30 全绿**，`brokenImgs` 全 0，暗色主题仍生效。
- **announcements 通道不回归**：`{"winVer":"1.3.0","andVer":"1.3.0","winMirror":"https://mirror.example.com/shootstudio/v1.3.0/shoot-studio-v1.3.0-windows.zip","andMirror":"…/shoot-studio-v1.3.0-android.apk","winSha":"发布时由 CI 写入","andSha":"发布时由 CI 写入"}`。
- App 全量测试与基线一致（517 + 43），无回归。

## 5. 偏差与限制登记

- **保留 S1 历史证据**：`docs/screenshots/v8/s1-web-hero-*.png`（4 张）与 `docs/qa/v8-s1-web-screenshots.json` 继续保留在库里，作为 S1 设计 spike 的历史记录（它们只被报告文字引用，不被任何代码引用；删它们不影响构建，故按「历史证据不删」处理）。
- **`web/dist` 仍 gitignore**，不入库（契约 §6 D158 line 205）。
- **App 侧仍有 4 个白名单文件未拆**：`lighting_controller 760` / `ai_panel 747` / `libraries_page 808` / `ai_client 779`。它们都不在 D158 的强制拆分清单（`lighting_page` / `planner_page` / `gear_browser` / `settings_page` / `exporter`）里，且拆分风险高于收益；白名单只降不升的约束已满足（`lib/features/**` 超限数 10 → 4）。
- **`docs/qa/gear-coverage-v7.json` 不入库**：它是 `app/tool/gear_coverage.py` 的生成物（未被 git 跟踪），由 CI line 67 每次重新生成并守门；S9 的 Dart 侧复刻测试另有独立守门。
- **官网不支持手动锁定主题**：`Layout.astro` 支持 `?t=paper|darkroom` 供截图工具与手动调试，但 UI 上没有主题切换控件（D157 未要求）。

## 6. 下一步

S12 v2.0.0 交付（D160）：版本同步（`pubspec` 2.0.0+N / `kAppVersion` / 公告 / `web/dist`）、双端构建 + LAUNCH-OK + 体积记录、tag `v2.0.0`、CI 全绿、§7 交付清单逐项打勾。
