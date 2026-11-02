# V8 R71/R84 偏差登记

> 本文件登记**明知存在、但本次刻意不修或只做部分处理**的项，每条都要写清
> 「为什么现在不修」，避免被当成漏做。修复条件一并写明，便于后续接手。

本轮（V8 R71 令牌化 + R84 安全收口）共 3 条偏差，全部为**刻意保留原值/原行为**，
没有任何一条是「没看见」。

第 1 轮 V8.1 收尾扩充 5 条（偏差 4–8），来自对任务书的逐项走查：这些项在
V8 收尾时**只写在代码注释里、没有进中央登记**，等于「知道但没入账」，已补齐。

**V8.25 清账轮**：偏差 1（圆角降档）/ 偏差 2（updater 摘要闭环）/ 偏差 3（KeyVault
写入前拦截）/ 偏差 4（pill 合同豁免）四条已闭环，标题带 ✅ 标记；
偏差 5 / 7 / 8 / 9 / 11 仍是**登记在案的刻意保留**，未动。同轮顺带修掉一个真 bug
（`build()` 内现建 `TextEditingController`，15 处），见文末「V8.25 顺带修掉的真 bug」。

---

## 偏差 1：圆角 10 / 20 超出合同刻度（`lib/features/libraries/gear_browser_card.dart`）—— ✅ 已修（V8.25）

- **合同条款**：D147 §3.3「圆角 2/4/8，禁止 >8」。
- **原现状**：器材卡三处用 `AppRadiusFine.oversizeSoft10`（两处大图缩略图）与
  `AppRadiusFine.oversizeSoft20`（tag chip）。
- **V8.25 处置**：按 2/4/8 档统一降档 —— 大图缩略图 `oversizeSoft10` →
  `AppRadius.frame`（8），tag chip `oversizeSoft20` → `AppRadius.chip`（2）。
  `oversizeSoft10/20` 常量保留（历史快照/回滚比对用），注释已改为
  「已降档（§3.3 合规）… 新代码禁用」。
- **门禁**：`check_tokens.mjs` 的 `AppRadiusFine` 细阶计数 9 → 6（↓，只降不升）。
  `test/visual/s9_library_capture_test.dart`（16 passed + 1 skipped）覆盖
  s9-gear-paper / s9-gear-darkroom 的 1280x800 与 1920x1080 渲染，圆角降档后仍通过；
  该卡片无 golden 引用，无需重录基线。

## 偏差 2：updater 的 `sha256` 仍不闭环（`lib/features/updater/updater.dart`）—— ✅ 已闭环（V8.25）

- **原现状**：`DownloadEntry.sha256` 被解析并对外暴露，两个消费方 ——
  `settings_page.dart` 与 `shell_update_banner.dart` —— 只读 `url` / `mirror` /
  `github` 并用 `launchUrl` 打开浏览器，校验字段从头到尾没有参与判断。
- **闭环做了什么**：新增 `lib/features/updater/updater_downloader.dart`：
  `UpdaterDownloader.download()` 走「应用内下载（`Dio.download`，带进度/取消）
  → `sha256OfFile` 逐块流式计算 → 与公告摘要比对」，
  结论收敛为 `UpdateVerifyState` 四态：`verified` / `mismatch` /
  `digestMissing` / `downloadFailed`；**只有 `verified` 的
  `UpdateDownloadResult.canInstall` 为 true**，其余三态一律
  `_tryDelete()` 删掉半成品文件。`UpdaterController.downloadUpdate()` 负责落盘路径
  （`getApplicationSupportDirectory()/updates/<文件名>`），
  `UpdaterController.installVerified()` 在 `canInstall == false` 时直接拒绝启动安装器。
  `confirmDownload()`（`updater_download_sheets.dart`）改为「确认 → 下载并校验 →
  通过才安装」，校验失败弹 danger toast 且不调用安装器。
- **摘要口径**：`normalizeSha256()` 只认**正好 64 位十六进制**；线上公告目前
  `web/public/announcements.json` 里是占位串「发布时由 CI 写入」，
  归一化后为 null，因此**当前发版形态下不会自动安装**，而是走「前往下载页」的人工路径。
  这是刻意的：无法校验的包不该由应用替用户装。
- **测试**：`app/test/features/updater_test.dart` 新增 7 条，
  含关键的「校验失败必须拒绝安装：不匹配 → mismatch + 删文件 + 不启动安装器」、
  「公告未公布可校验摘要 → digestMissing + 拒绝安装 + 删文件」、
  「下载失败 → downloadFailed，不留残包」。
- **残留（如实登记）**：闭环覆盖的是「应用内下载」这条路径；
  `announcements.json` 的 `sha256` 仍需发版时由 CI 写入真实摘要，
  否则永远走人工下载页。跨设备断点续传未做（失败即重下整包）。

## 偏差 3：`KeyVault.storageAvailable` 只做了 UI 提示，不做写入拦截 —— ✅ 已闭环（V8.25）

- **原现状**：secure storage 不可用时降级为进程内临时主密钥
  （`key_vault.dart:46-51`），`storageAvailable` 只驱动一条警示条，
  Key 仍会被「加密」成重启后再也解不开的密文。
- **产品决策**：采用**写入前拦截**（拒绝写入并提示先修复系统钥匙串），
  不再接受「静默降级 + 事后提示」。
- **实现**：
  - `key_vault.dart:56-69` 新增 `Future<bool> probeStorage()`——先真实读一次
    主密钥，返回 `_storageAvailable`；一旦探测失败即保守返回 `false` 直到进程重启。
  - `ai_controller.dart` 新增 `enum AiKeyPersist { stored, notProvided, blockedNoStorage }`，
    `saveProvider` 改为返回该枚举：`apiKey` 非空时先 `probeStorage()`，
    不可用则**不写任何密文**、保留原 `encryptedKey`、其余字段照常 upsert、
    返回 `blockedNoStorage`；Key 为空则保留原密文返回 `notProvided`；
    正常加密入库返回 `stored`。全程 try/catch，DB 写失败同样回落为
    `blockedNoStorage`（状态文案「保存失败，请重试」），不向 UI 抛异常。
  - 两个保存入口按返回值分支：`ai_provider_card.dart:135-162`、
    `settings_page_cards.dart:190-222`。`blockedNoStorage` 时给 warning toast
    「系统钥匙串不可用，已拒绝保存 Key（重启后会丢失），请先修复系统钥匙串」，
    且**不清空输入框**（让用户重试而不是丢失已输入内容）。
  - 原 `bool get keyStorageAvailable` getter 已删除（全仓无残留引用）。
- **测试**：`app/test/features/key_vault_block_test.dart` 6 条——
  内存版钥匙串下 `probeStorage` 为 true / 异常钥匙串下为 false；
  `saveProvider` 三分支各一条；钥匙串不可用时 `encryptedKey` 保持空串且不抛；
  已有 Key 时被拦截也**保留原密文**。
- **副作用（预期内，非回归）**：钥匙串不可用时不再有「本次会话可用的临时 Key」，
  该 provider 会因 `hasKey == false` 走本地引擎。
- **测试环境适配**：`ai_pipeline_test.dart` / `g2_ai_pipeline_test.dart` 里补了
  `FlutterSecureStorage.setMockInitialValues(<String, String>{})`。
  这两个用例此前**正是靠「静默写入不可解密文」这个 bug 才绿的**：无插件环境下
  Key 写不进去 → `hasKey == false` → 走本地引擎，断言刚好成立。装上内存版
  平台实现是把测试环境恢复到真机语义，没有改任何断言。

## 偏差 4：`AppRadius.pill = 999` 超出合同刻度（胶囊形）—— ✅ 已豁免（V8.25）

- **合同条款**：D147 §3.3「圆角 2/4/8，禁止 >8」。
- **现状**：`spacing.dart` 定义 `AppRadius.pill = 999`（+ `pillBorder`），
  实际使用 2 处：`ai_panel.dart:186`、`export_panel.dart:233`。
- **处置**：走「合同显式豁免」这条路（而非降档）。`FIX_CONTRACT_V8.0.md` §3.3
  圆角条款末尾已追加：

  > 例外：胶囊（pill）允许 `AppRadius.pill = 999`，仅用于标签/筛选胶囊类控件；
  > 其余任何圆角禁止 >8。

- **理由**：999 是「胶囊形」的固定 idiom（半径大于半宽即得到完全圆头），
  不是随意的超大圆角；改成 ≤8 会把胶囊变成普通圆角矩形，属视觉决策而非合规问题。
  豁免限定在「标签/筛选胶囊类控件」，不构成对其他圆角的开口。
- **残留**：无代码改动；`check_tokens.mjs` 不校验圆角数值合法性，豁免靠合同文本约束。

## 偏差 5：`AppSpaceFine` 九档 / `AppFontSize` 十九档细阶不在合同刻度上

- **合同条款**：D147 §3.3 只定义 8pt 间距刻度 `4/8/12/16/24/32/48/64`；
  §3.2 只定义七档字号。
- **现状**：`AppSpaceFine`（n1/n2/n3/n5/n6/n7/n9/n10/n20）与 `AppFontSize`
  的 19 个档间细阶（h1Lg 26 / h2Lg 24 / bodyXl 16 … micro2 8.5）都不在刻度上。
- **为什么不修**：两者都是 R71 清零时的**等值收编** —— 每个常量都等于一个
  既存字面量的原值，收编后渲染逐像素不变（三个 golden 的通过即为证据）。
  强行把 6px 改成 8px 会改变所有间距，等于重做一遍视觉。
  代码注释已写明「不在刻度内，为保持渲染不变而原样收编，新增代码不应使用」。
- **残留影响**：新代码若图省事引用 `AppSpaceFine`，会让「8pt 体系」名存实亡。
- **修复条件**：把两类 Fine 细阶标注 `@Deprecated('仅在历史收编中使用')`，
  并给 `check_tokens.mjs` 加一条「Fine 细阶计数只降不升」的软门禁。

## 偏差 6：R74 组件收口未落实（设计组件库零引用）—— **V8.23 复核：已收口**

> **V8.23 复核：已收口。** C1（弹层 AlertDialog 5→0，V8.13）、C2（输入框 TextField 60→0，V8.14–V8.20）、C3（底部抽屉 showModalBottomSheet 4→0，V8.21）、空态层（`SsEmpty` 实测 18 处/13 文件，V8.22 复核前提即已成立）四层均已收口。证据见 `docs/audit/V8-COMPLIANCE-AUDIT.md` §2.1–§2.3 与 `docs/qa/v8-21-r74-bottomsheet-final.md`、`docs/qa/v8-22-empty-layer-verification.md`。下文的原始观察保留留档。

- **合同条款**：R74「按钮/输入框/卡片/对话框/标签/空态/加载态/Toast 一律走
  `lib/core/design/`；feature 内禁止新造同名基础组件」。
- **现状**（`lib/` 全树 grep 实测，`core/design/` 自身除外）：
  - `SsDialog` / `SsSheet` / `showSsConfirm` / `showSsSheet` **零引用** ——
     sanctioned 的弹层 API 从未被任何 feature 使用过，实质是死代码。
  - `SsTextInput` / `SsSearchField` **仅 demo 页引用**，feature 内 60 处直接用
    裸 `TextField`。
  - feature 内 **26 处 `showDialog`** + 20 处 `AlertDialog`（覆盖 16 个文件），
    全部自带 builder，绕开了 `SsDialog`。
- **为什么 V8 没做**：R73 拆文件与 R71 令牌化已把 V8 预算吃満，且这是
  **行为等价但改动面极大**的机械迁移（86 个调用点 × 各自的装饰器/校验器
  需要逐个保留语义），仓促做必然引入回归。
- **残留影响**：设计系统只覆盖了按钮/卡片/Chip/Toast/空态（这些确实收口了），
  弹层与输入框两层仍是两套皮肤并存；R74 只能算「部分达成」。
- **修复条件**：按「先弹层、后输入」分两步迁移，每步带 golden 截图对比 +
  不减少 feature 断言数，作为独立阶段交付。
- **V8.2 进展（已迁 3 处）**：`poses_page_layout.dart`（删除自定义姿势）、
  `library_resource_editor.dart`（删除资源条目）、`export_panel.dart`
  （存在失效模块时是否继续导出）三处改为 `showSsConfirm`。
  三处的原形态都是「静态文案 + 取消/确认两按钮 + 布尔返回值」，且
  `confirmed == true` → `if (confirmed)` 与 `go != true` → `if (!go)`
  均为等价改写（遮罩关闭时 null 与 false 都不执行动作）。
  **剩余 27 处裸 `showDialog` 全部不符合迁移条件**，原因逐处登记在
  `docs/qa/v8-2-r74-dialogs.md`：内容含表单/列表/富媒体（21 处）、
  单按钮提示且 pop<void>（4 处）、返回值非布尔（String / Map / record，6 处，
  迁移会改调用方语义）。这 27 处需要各自的定制方案，不是机械替换。

## 偏差 7：`AppWait.planReveal` 220ms / `cardHover` 260ms 与动效刻度不一致

- **合同条款**：D147 §3.4 只定义 fast 160 / normal 280 / slow 420。
- **现状**：`spacing.dart` 的 `AppWait` 里 `planReveal = 220ms`、
  `cardHover = 260ms`，两个值都不在三档上。
- **为什么不修**：这两处是**本机实测校准值**（卡片悬停反馈 260ms 手感最接近
  normal 280 但更跟手；规划页揭幕 220ms 是避免与页面切换 200ms 叠成 400ms），
  等值收编自原字面量，改动会改变手感。
- **修复条件**：做一次动效手感 A/B 复核，确认后可对齐到 fast 或 normal 档。

## 偏差 8：R76 启动「迁移/重置」对话框未实现（触发条件未发生）

- **合同条款**：R76「破坏旧数据时，启动检测 → 迁移/重置对话框 → 用户选择前
  不写入；迁移脚本幂等且有测试」。
- **现状**：`main.dart` 无任何旧数据检测逻辑，也无该对话框。
- **为什么不算漏做**：V8 **没有破坏** SQLite schema（`database.dart:60`
  `schemaVersion` 仍为 1，与 v1.3.0 一致）与工作区目录结构，R76 的触发条件
  未发生。唯一破坏的格式是 `.sspak`，其路径**有**明示：
  `exporter_sspak.dart:200-214` 的版本分档 —— v1 导入时 toast「已从 v1 自动迁移」
  并回报来源版本，高于当前版本则拒绝并提示升级，不会静默丢数据。
- **残留影响**：若将来 V9 真要改 schema，现在没有现成的对话框可复用，
  需要从零做（含幂等迁移脚本与测试）。
- **修复条件**：V9 若改 schema，在动 schema 的同一提交里补齐
  「检测 → 二选一对话框 → 幂等迁移脚本 + 往返测试」。

## 偏差 9：引擎性能门禁**不再判逐相位帧数**（主动放宽，v8.5.0）

- **合同条款**：D152「拖动灯具 p95 帧耗时 ≤16ms，记录实测；达不到则在 spike
  报告说明并给降档策略」。
- **原状（v8.3.0 交付时）**：`app/tool/engine_perf_gate.mjs` 判 5 类，含
  「每个相位 `engineFrames > 0`」与「帧数 ≥ 入库 SwiftShader 基线的 50%」。
- **为什么放宽**：这两条在 GPU-less runner 上不是性能信号而是**二值噪音**。
  v8.4.0 的 CI run `38109551427` 上它们红了 8 项（idle/dolly 的
  `engineFrames=0` 连带 mean/fpsMean 报非数值），但同一次运行 orbit=1、
  lightDrag=1 —— 渲染循环活着。v8.4.0 只加了一个 Dart 测试文件，与引擎无关，
  v8.3.0 上同一条门禁是绿的，故为**随机红**而非回归。
  实测证据（本机，SWiftshader 下 fps≈0.6–1.8）：同一条门禁连续两次尝试的总帧数
  分别是 4 和 5 —— 逐相位帧数在「0 / 1 / 2」之间抛硬币。
  基线本身只有 1~3 帧，与噪音底噪同量级，任何由它导出的硬阈值都是假门禁。
- **同时修掉一个真空判据**：原 `Number.isFinite(Number(v[k]))` 里
  `Number(null) === 0` 是有限数，所以「p50 为数值」对 null **永久通过**
  （v8.4.0 那 4 项 mean/fpsMean 的 FAIL 正是被这个洞放过去后由别的检查兜住的）。
  已改为 `typeof v === 'number' && Number.isFinite(v)`，单独用例验证
  `null` 由 vacuous-PASS 变为 FAIL。
- **现在的门禁判什么**：进程 exit 0、无 error 字段、`warmup.settled`、
  `lightPoint.ok`、**整次测量总帧数 > 0**（渲染循环是否活着）、出了帧的相位
  统计字段为数值。逐相位帧数与基线差距降级为 `NOTE`（打印并入库，不判红）。
  另加最多 5 次尝试（`PERF_GATE_ATTEMPTS`），取第一个「四相位全出帧」的健康运行，
  否则取总帧数最多的一次作代表。
- **反向验证**（证明不是装饰）：把测量替身换成「四相位全 0 帧」→
  `FAIL 渲染循环有出帧（总帧数 > 0）:: 代表运行总帧数=0，全部尝试总帧数=0/0`、
  `FAIL (1)`、`exit 1`，两次尝试都红，与真测量（exit 0）区分明确。
- **残留影响 / 代价（明说）**：门禁比初版松。松在「逐相位帧数」这种在 GPU-less
  下测不准的量上；换来的是不再随机红、不再阻挡合入。**绝对帧耗时与逐相位帧数
  仍是人工判据**，口径见 `app/tool/engine_perf_gate.mjs` 文件头：改渲染路径后
  在独显机手动跑 `node tool/engine_perf_qa.mjs --label <说明>` 并把 JSON 入库。
- **修复条件**：CI 拿到 GPU runner（`runs-on` 支持 GPU 的 label）后，把
  「逐相位 `engineFrames > 0`」与「帧数 ≥ 基线 50%」恢复为硬判，并重录基线。

## 偏差 10：R74 组件收口（16 处 AlertDialog 已全部迁移，v8.13 真正归零）

- **合同条款**：R74「弹层一律走 sanctioned API，feature 侧不得裸写
  `showDialog` + `AlertDialog`」。
- **现状（2026-10-16，v8.13 已迁完）**：**16 处全部迁移，归零**。真实账目是
  `lib/`（`core/design/` 自身除外）共 **16 处** feature 侧 AlertDialog 皮肤：
  - V8.2 迁 3（`showSsConfirm`）、V8.7 迁 4、V8.8 迁 4、V8.9 迁 1、V8.10 迁 2、
    **V8.13 迁最后 5 处**（`library_resource_editor.dart:97` `ResourceEditorDialog`、
    `planner_page_dialogs.dart:220` `_ColorPickerDialog`、
    `planner_page_pose_dialogs.dart:22` `_PoseInfoDialog` / `:117` `_PoseReplaceDialog` /
    `:217` `_BudgetEstimateDialog`）—— 见 `docs/qa/v8-13-r74-alertdialog-final.md`。
  - 准确口径（直接数 `AlertDialog(` 字面量，不再用窗口启发式）：
    ```
    lib/features: AlertDialog( 字面量 = 0 处（99 个 Dart 文件；tool/check_components.mjs）
    ```
    该 `0` 已写进组件基线 `tool/component_baseline.json`（**只降不升**）——
    今后任何新增 `AlertDialog(` 都会让 CI 直接红。
- **各轮做法与报告**：v8.7 §4（sanctioned API 从「只覆盖 bool」扩到「任意 `T`
  + 统一动作按钮」）、v8.8 §3（void 型 + 纯展示 / 单按钮）、v8.9 §2
  （状态归属先拆件）、v8.10 §2（最后 2 处：先判断有无可变状态再决定拆件粒度 ——
  有状态才拆 `StatefulWidget`，无状态只提方法）。
- **同时更正了审计口径**：v8.2 文档的两条论断不成立 ——
  ① `SsDialog` 本来就是 widget，`showDialog<T>(builder: ... SsDialog(...))`
  一直就能返回任意 `T`，缺的不是能力而是便捷入口；
  ② C 类里 `plan_read_view.dart:32` 用的是 `Dialog.fullscreen`，不是
  AlertDialog 外观，**不属 R74 收口对象**，已从计数中剔除。
  故「48 → 42 / 剩 27」是粗数，**以本条目更正后的 16 处 / 剩 5 处为准**；
  v8.7 / v8.8 / v8.9 / v8.10 报告里的「11 处 / 0 处」是同一个漏计口径的产物，
  其中 v8.7 的「11 处」本身也偏低。
- **代价（明说，不掩饰）**：已迁移的 11 处**视觉上必然变化**（标题改走
  `AppType.h2` 衬线、affirmative 动作变 `FilledButton`），这是收口的目的而非回归，
  已逐条登记在 v8.7 §4 / v8.8 §3 / v8.9 §2 / v8.10 §2。其中
  `updater_download_sheets.dart` 原用 `SsButton(dense: true)`，迁后走
  `SsDialogAction`（`FilledButton`/`TextButton`），按钮高与内边距随之变化。
- **顺带修掉的真 bug ①**：`gear_browser_add.dart` 原实现 4 个
  `TextEditingController` 从不释放（真内存泄漏），V8.10 拆件时由
  `_AddGearBodyState.dispose()` 释放。
- **顺带修掉的真 bug ②（V8.13）**：**`SsDialog` 自身缺 `Material`**。
  `AlertDialog` 内部自带 `Material`，而 `SsDialog` 用
  `Container(color: p.surface)` 直接装内容 → 弹层里的 `ListTile` 会触发
  「background color or ink splashes may be invisible」断言（实测 f4 用例 15 条）。
  已包一层 `Material(type: MaterialType.transparency)` 修掉；
  前 11 处迁移的弹层里没有 `ListTile`，所以一直没暴露。详见 v8.13 §2。
- **状态**：**已消除（v8.13）**。条目保留作为过程记录与视觉差异登记。
- **⚠️ 漏计的成因（2026-10-16 全面审计发现，见 `docs/audit/V8-COMPLIANCE-AUDIT.md` §2.1）**：
  此前宣称的「`AlertDialog sites left=0`」是**假阴性**，根因是**复核脚本的口径缺陷** ——
  它只在 `showDialog<` 调用点之后 1500 字符窗口内匹配 `AlertDialog`，而这 5 处的
  调用点（`builder: (_) => const _XxxDialog()`）与 `return AlertDialog(` **不在同一个
  文件**，窗口里永远看不到那个字面量。同类缺陷还漏计了
  `showModalBottomSheet` 的泛型调用形态（`showModalBottomSheet<void>(`）——
  已在新门禁里修掉（每个模式都允许可选 `<…>`）。
  → 这 5 处已在 **v8.13 迁完**，`tool/check_components.mjs` 实测
  `alertDialog = 0` 且已锁进基线。即：**V8.10 的「归零」是假阴性，
  v8.13 才是真归零** —— 两者必须分开记，否则会把「口径错误的结论」
  当成「已完成的工作」。

---

## 偏差 11：引擎性能门禁的「逐相位统计量」判据同样是假红（v8.11.0 修正）

- **合同条款**：R81 步进门禁 / R78 证据入 git —— 本仓自设的「引擎性能门禁」
  是 V8.3 起接入 CI 的硬门禁，它的判据必须**要么抓真回归、要么不判**，
  不能随机红（否则等于让人习惯性忽略红灯，门禁失去意义）。
- **现状**：**V8.5 的修订不完整，导致 CI 在 `v8.10.0` 上真红**。
  run `38218304083`（commit `1ba20eb`）6 个 job 中 5 绿，
  **`Engine perf gate` failure**，失败读数：
  ```
  [尝试 1/5] exit=0 逐相位帧数=0/1/1/3 总帧数=5      ← 代表运行
  PASS 渲染循环有出帧（总帧数 > 0）:: 5
  PASS orbit / PASS lightDrag（统计齐全）
  FAIL dolly.p50 为数值 :: null
  FAIL dolly.p95 为数值 :: null
  FAIL dolly.p99 为数值 :: null
  FAIL dolly.max 为数值 :: null
  FAIL dolly.mean 为数值 :: undefined
  FAIL dolly.fpsMean 为数值 :: undefined
  [perf-gate] FAIL (6) → exit 1
  ```
- **根因（与偏差 9 同源，同一个错误的另一半）**：`engine_perf_gate.mjs:184` 写的是
  `if (framesOf(representative, ph) > 0) { for (k of STAT_KEYS) check(...) }` ——
  只要某相位出过帧，就强制要求它 7 项统计量全为数值。但 GPU-less runner 上
  每相位只有 1~3 帧，**帧间隔样本 <2 时工具不产出分位数**（`p50/p95/p99/max=null`、
  `mean/fpsMean=undefined`；只有 `cpuMsPerFrame` 因是「CPU 时间/帧数」仍为数值）。
  在 1~3 个样本上要求分位数，统计上无意义 —— **偏差 9 已经承认「逐相位帧数」
  是噪音并把它降级为 NOTE，但忘了「逐相位统计量」是同一个噪音的另一面。**
- **修正（v8.11.0）**：
  1. 「逐相位统计齐全」硬判 → 改为「**至少一个相位的 7 项统计齐全且为数值**」
     （仍能抓住 `stats()` 被改坏 / `Number(null)===0` 真空判据回归，
     但不再因单相位样本不足而假红）；
  2. 代表运行的选取规则由「总帧数最多」改为「**统计完整相位数最多**（平手比总帧数）」；
  3. 出了帧但统计不完整的相位 → `note`（与帧数对照同源），不判红；
  4. 保留全部既有硬判：`exit === 0` / 无 `error` 字段 / `warmup.settled` /
     `lightPoint.ok` / **整次总帧数 > 0**。
- **反向验证（证明仍非装饰）**：`tool/_deadloop_stub.mjs` 写「四相位全 0 帧」
  JSON → 必须 `FAIL(≥2)` 且 exit 1（总帧数判据 + 聚合统计判据各红一次）；
  而 v8.10.0 那次真实失败（orbit/lightDrag 统计齐全）在新规则下应 PASS。
- **剩余口径（明说）**：修正后本门禁**仍不判绝对帧耗时，也不判逐相位帧数**——
  「lightDrag p95 ≤16ms」（D152）**依旧是人工判据**，需在独显机器上
  `node tool/engine_perf_qa.mjs --label <desc>` 并把 JSON 入库。
  门禁守的是「测量链路可用 + 渲染循环活着 + 统计管线可用」。
- **修复条件（真正闭环）**：CI 拿到 GPU runner 后，恢复绝对帧耗时硬判并重录基线
  （与偏差 9 的修复条件相同）。
- **状态**：**已修正（v8.11.0）**；本条与偏差 9 是同一件事的两轮修订，保留分列以
  记录「第一次只修了一半」这个事实。

---

## V8.25 顺带修掉的真 bug（不算偏差，留档）

### ① `build()` 内现建 `TextEditingController`（15 处）

- **原现状**：`planner_module_editor.dart`（4 处）、`planner_module_editors_a.dart`（4 处）、
  `planner_module_editors_b.dart`（5 处）、`planner_page_canvas.dart`、`lighting_inspector.dart`、
  `settings_page.dart` 共 15 处写成 `controller: TextEditingController(text: …)`。
  每次 rebuild 都新建一个 controller，`EditableText` 拿到新实例即重置光标与 IME 组合态 ——
  在输入框里打字会被打断（输入中文时尤其明显），旧 controller 也不会被释放。
- **为什么以前没被门禁抓到**：`check_components.mjs` 只数裸 `TextField` / `AlertDialog` /
  `showModalBottomSheet`，而这些都是走 `SsTextInput` 的合规调用点；
  `check_file_size.mjs` 只看行数。**没有任何门禁覆盖「controller 生命周期」**。
- **处置**：`SsTextInput` 补 `didUpdateWidget`（`ss_input.dart:91-108`）——
  调用方没传 `controller` 时，`initialValue` 变化会写回同一个 `_own` 实例，
  且用 `own.value = TextEditingValue(…)` 而不是 `own.text = …`
  （后者会把选区重置成 `collapsed(-1)`）。15 处调用点全部改为 `initialValue:`。
  全仓 `controller: TextEditingController(` 已归零。
- **测试**：`app/test/core/ss_input_test.dart` 新增「initialValue 变化后同步进同一个
  controller（不重建）」——断言 `same(first)`、文本更新、选区停在末尾。
- **已知可接受行为**：经纬度字段的 `31.2` 会被 `toStringAsFixed(4)` 规整成 `31.2000`，
  光标跳到末尾 —— 与改造前的可见结果一致（改造前每次 rebuild 也是这个结果）。

### ② 既有测试靠「静默写入不可解密文」的 bug 才绿

见偏差 3 条目末尾。修的是**测试环境缺插件**，不是被测逻辑。

---

## 第 1 轮收尾（V8.1）顺带修掉、不算偏差的项

- **sspak 盘符条目平台分叉**（`exporter_sspak.dart`）：`images/C:/Windows/evil.dll`
  这类条目在 Windows 上被 `path.isAbsolute` 拒绝、在 Linux 上被放行并写出
  垃圾目录后才失败。已改为**先剥离 `images/` 前缀再判定盘符**，与平台无关，
  并抽成公开函数 `hasSspakDriveLetterPrefix` 做平台无关单测。
  这条修的是 R84 安全不变量，不是令牌问题。
- **GraphFlow 本地缓存误入 git**：`dd0ad9e` 卷入了 `.graphflow-cache/` 与
  `graphflow-out/`，已由 `5f6b7e5` `git rm --cached` + `.gitignore` 清掉。

---

## 不算偏差的「已处理」项（留档以免重复排查）

- **R82 蓝紫渐变**：`onboarding_page.dart` 的 `LinearGradient` 曾用
  `Color(0xFF7B5CFF)`，已改为 `[p.accent, p.film]`。因为改的是像素，
  `goldens/onboarding.png` **已重录**（见 `90011bc` 提交说明），
  另两个 golden 逐字节未变。
- **`Color(0xFF000000 | parsed)`**：属扫描器误报（是给用户输入的 24 位 RGB 补
  不透明 alpha，不是纯黑），已改写为 `Color.from(alpha: 1, red: …)` 以便阅读。
- **`BorderRadius.circular(widget.height / 2)`**：运行时派生值（胶囊形），
  刻意不收编成令牌，门禁已按「派生值」放行。