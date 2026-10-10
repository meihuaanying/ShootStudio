# V8.1 收尾：偏差登记补齐 + 门禁入 CI + 图池出 git

> 阶段：P1a（原报告里的「P1 门禁三件 + 偏差登记 + gear_photo_pool」）
> 目标：把 V8 收尾时「只写在代码注释里、没进中央账」的偏差补齐入账，
> 并把三个只在本机跑的门禁挂进 CI，让「本机能过、CI 不管」的分裂状态消失。

---

## 1. 偏差登记补齐（`docs/qa/v8-r71-deviations.md`）

V8 收尾时只登记了 3 条偏差，但对任务书逐项走查时发现 **5 个明知存在、只写在代码注释里
的项没进中央登记**。"知道但没入账"与"没看见"在交接时的后果是一样的，故补齐：

| # | 偏差 | 合同条款 |
|---|---|---|
| 4 | `AppRadius.pill = 999`（胶囊形，2 处实使用）超圆角刻度 | §3.3 禁 >8 |
| 5 | `AppSpaceFine` 九档 + `AppFontSize` 19 档细阶不在 8pt/七档刻度上 | §3.2 / §3.3 |
| 6 | **R74 组件收口未落实**：`SsDialog`/`SsSheet`/`showSsConfirm`/`showSsSheet` 零引用；26 处裸 `showDialog` + 20 处 `AlertDialog` + 60 处裸 `TextField` | R74 |
| 7 | `AppWait.planReveal` 220ms / `cardHover` 260ms 不在 160/280/420 三档上 | §3.4 |
| 8 | R76 启动「迁移/重置」对话框未实现（触发条件未发生） | R76 |

每条都写清「为什么现在不修」+「残留风险」+「修复条件」，与原有 3 条同格式。
偏差 6（R74）是最有价值的一条 —— 它把「组件库齐全但没收口」这个事实写明为
**部分达成**，而不是让读者误以为 R74 已满足。

## 2. 官网截图门禁入 CI（`.github/workflows/ci.yml`）

新增独立 job `website-gate`（D157/R82）：

| 步骤 | 说明 |
|---|---|
| `apt-get install microsoft-edge-stable` | Linux runner 无 Edge，需装 |
| `npm install` + `npm run build` | Astro 产出 `web/dist`（门禁前置） |
| `node tool/shot_s10.mjs` | 5 页 × 明暗 × 3 视口 = **30 张** + announcements 通道 + R82 禁占位图 |
| 证据落地校验 | 断言 `docs/qa/v8-s10-web-screenshots.json` 存在且 `s10-web-*.png` ≥ 30 张 |

放独立 job 而非塞进 `analyze-test` 的 matrix：它需要 Node + Edge + npm install，
与 Flutter 工具链无关，混在一起会拖慢每个 matrix 单元。

**为此改了两处工具的可移植性**（此前只能在本机 Windows 跑）：
- `web/tool/shot_s10.mjs`：Edge 可执行文件改为按平台解析（win32 / darwin / linux
  三组候选路径），并支持 `SS_EDGE` 环境变量覆盖。
- `web/tool/shot_s10.mjs`：Linux 下追加 `--no-sandbox`（容器内无授权进程组，
  headless Edge 起不来）。

本机实测：`node tool/shot_s10.mjs` → **30/30 写出**，`broken=0`，
announcements 通道读 `winVer/andVer = 2.0.0`。

## 3. release.yml 补齐三道门禁

`release.yml` 此前只有 `analyze` + `test`，**format / 行数（R73）/ 令牌（R71）在发版
路径上是空的** —— 即「CI 绿但 release 红」的分裂状态。已在两个构建 target 前补齐：
`dart format --output=none --set-exit-if-changed` → `check_file_size.mjs`
→ `check_tokens.mjs --json=...` → `analyze --fatal-infos` → `flutter test`。

## 4. 图池 197 张 jpg 出 git（R47）

**问题**：`app/tool/gear_photo_pool/` 下 **197 个 `.jpg` 被 git 跟踪**，与
`.gitignore:40`「图片不入 git（R47）」直接矛盾。`.gitignore` 对已跟踪文件无效，
所以一旦误入就永久留在历史里。

**安全性核查（动手前先查谁会读它们）**：
- `gear_photos_v3/common.py:35` 的 `POOL_DIR` 指向 `tool/gear_photo_pool/v3`，
  与这批 `gear_photo_pool/*.jpg`（v2 期产物）**不是同一目录**。
- `prune_gear_photo2.py` 是手动清理脚本，把非 builtin 图从 `assets/.../photo2`
  **移出**到池里，不在 CI 调用链上。
- `gear_coverage.py` / `gear_sources_spotcheck.py` 对 `gear_photo_pool` **零引用**。
- `q6_gear_test.dart:257` 断言的是元数据 JSON 里的 `rawPath` **字符串**含
  `tool/gear_photo_pool/`，从不读文件系统 → 这就是它一直没发现的原因。

**处置**：`git rm --cached`（文件保留在磁盘，仅退出跟踪），已验证
`git check-ignore -v` 命中 `.gitignore:40`。

**补回归守卫**（`q6_gear_test.dart` 新增一条用例）：真正去问 git
（`git ls-files -- tool/gear_photo_pool`），断言为空。

**反向验证**：`git add -f` 强制入索引 1 个文件 → 测试报
```
Expected: empty
Actual: ['tool/gear_photo_pool/cam-13.jpg']
```
即该守卫确实能抓住这个曾在历史上静默存在的回归。

## 5. 门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 254 files（1 changed → 复跑归零） |
| `flutter analyze --no-pub --fatal-infos` | No issues found |
| `flutter test --no-pub` | 529 passed + 34 skipped |
| `node tool/check_file_size.mjs` | PASS |
| `node tool/check_tokens.mjs` | PASS（四类全 0） |
| `node web/tool/shot_s10.mjs` | 30/30，broken=0 |

## 6. 本阶段未做（留给后续阶段）

- **偏差 6 的 R74 组件收口**：86 个调用点的迁移（26 `showDialog` + 60 `TextField`）
  面大且需逐个保留装饰器/校验器语义，**作为独立阶段交付**（V8.2）。
- 删除 4 个零引用的 sanctioned 弹层 export（`SsDialog`/`SsSheet`/`showSsConfirm`/
  `showSsSheet`）：**刻意不删** —— 它们是 feature 本该迁移的目标 API，
  删了就没有迁移目的地了。由 V8.2 迁移完成后自然转为有引用。
