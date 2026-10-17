# V8.24 / 批次 C4 收尾：残余「行内空文案」10 处逐处复核（2 处收口 + 黄金基线更新）

## 0. 为什么会有这一批

V8.22 复核把 C4（空态层）判为「实为已收口」（`SsEmpty` 早已 18 处 / 13 文件在用），
但**如实登记**了 10 处「行内手写空提示」未走 sanctioned 组件，并标注
「P3 可选 / 逐处设计判断，**不机械替换**」（见 `docs/qa/v8-22-empty-layer-verification.md` §7）。

本批把那份清单**逐处看代码**，区分「真实区块空态」与「行内提示 / toast / 加载态」：
前者收口，后者逐条登记「为什么保持原样」，不留模糊结论。

## 1. 一句话结论

10 处中 **8 处并非空态缺口**（字段级占位 / 编辑器提示 / `ssToast` / 缩略图回退 /
本身就是 `SsEmpty` / 加载指示），**仅 2 处是真实区块空态**，已收口到 sanctioned 组件：

- `home/home_recent.dart`（首屏「最近的策划案」区块空态）
- `planner/planner_page_layout.dart`（版本历史抽屉内的列表空态）

全量 test **551 passed + 34 skipped** 零回归；黄金基线 `test/features/goldens/home_empty.png`
随空态收口更新（差异**仅限该卡片区块**，已人工比对 master / test 图确认）。

## 2. 逐处复核表（V8.22 §7 的 10 项）

| # | 位置 | 现写法 | 判定 | 处置 |
|---|---|---|---|---|
| 1 | `home/home_recent.dart:58-77` | `SsCard(child: Row(Expanded(Column(Text h3 + Text body))))` | **真实区块空态**（首屏「最近的策划案」，API 与 `SsEmpty` 的 `title`/`hint` 一一对应） | ✅ **收口**为 `SsCard(child: SsEmpty(art: SsArt.film, …))` |
| 2 | `planner/module_content_view.dart:96` / `:279` | `if (colors.isEmpty) return const Text('（暂无色卡）')` / `if (rows.isEmpty) return const Text('（暂无明细）')` | 字段级占位（`Wrap` / 行表内一行小字） | 保留（换 `SsEmpty` 会破坏紧凑语义） |
| 3 | `planner/planner_page_layout.dart:272` | `const Padding(padding: EdgeInsets.all(AppSpaceFine.n20), child: Text('暂无快照'))` | **真实列表空态**（版本历史抽屉内） | ✅ **收口**为 `SsEmpty(art: SsArt.compass, …)` |
| 4 | `planner/planner_module_editors_a.dart:17` / `:266` / `:481` | `Text('还没有已保存的布光方案：去…')` / `Text('去「动作摆姿库」收藏姿势 → 加入策划案')` / `Text('分镜为空：可让 AI 生成 8–12 镜…')` | 编辑器内提示（:17 还带「刷新」`SsButton`，属表单行） | 保留 |
| 5 | `planner/planner_module_editors_b.dart:261-265` | `Text('${module.type.label}：资源库还没有条目（去「资源库」新建）')` | `FutureBuilder` 列表内提示 | 保留 |
| 6 | `planner/planner_module_editor.dart:302` / `:449` / `:464` | `Text('可本地上传图片，或去「画面参考库」…')` / `ssToast(context, '待插入样片为空：先去画面参考库收帧')` / `ssToast(context, '画板为空')` | :302 编辑器提示；:449/:464 **是 toast，不是空态** | 保留 |
| 7 | `refs/refs_page.dart:491` / `:496` | `if (_searching && _hits.isEmpty) return const Center(child: CircularProgressIndicator(...))` / `if (_hits.isEmpty) return const SsEmpty(...)` | :491 是**加载态**；:496 **本来就是 `SsEmpty`** | 无需处理（§7 已注「未必是空态」） |
| 8 | `libraries/gear_browser_card.dart:110` | `if (chain.isEmpty) return SizedBox(54×54, Column(Expanded(_illustration), Text(label)))` | 缩略图**图片回退**，与空态无关 | 保留 |
| 9 | `libraries/libraries_page.dart:53` | `'暂无备注'` | 字段级占位 | 保留 |
| 10 | `lighting/widgets/lighting_inspector.dart:4` / `:107` | :4 注释「未选中时显示空态」；:107 **已经是 `SsEmpty(icon:…, art: SsArt.light, title:'未选中对象', hint:…)`** | 无缺口（注释被误当缺口登记） | 无需处理 |

**结论**：§7 的 10 项里，真正需要动的只有 2 项；其余 8 项若强行替换，正是 R82 反对的
「为凑引用数而替换」方向，故逐条保留并在此写明理由。

## 3. 两处收口详情

### 3.1 `home/home_recent.dart`（首屏区块空态）

```dart
// 之前（手拼：SsCard + Row + Column + 两行 Text，左对齐、无插画）
return SsCard(
  child: Row(
    children: <Widget>[
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('还没有策划案', style: AppType.h3.style(p.ink)),
        const SizedBox(height: AppSpace.s1),
        Text('在上面输入想法，或从模板库开始。', style: AppType.body.style(p.inkSoft)),
      ])),
    ],
  ),
);

// 之后（sanctioned 空态；与 planner_page_canvas / lighting_inspector 的
// `SsCard + SsEmpty` 写法一致，策划域用 SsArt.film）
return const SsCard(
  child: SsEmpty(
    icon: Icons.movie_creation_outlined,
    art: SsArt.film,
    title: '还没有策划案',
    hint: '在上面输入想法，或从模板库开始。',
  ),
);
```

保留 `SsCard` 外壳，是为了**尽量小地改变外观**（只把内部由「左对齐两行小字」换成
「线稿插画 + 居中大字 + 一行指引」），并沿用同族写法。

### 3.2 `planner/planner_page_layout.dart:272`（版本历史抽屉空态）

```dart
// 之前
child: latest.snapshots.isEmpty
    ? const Padding(
        padding: EdgeInsets.all(AppSpaceFine.n20),
        child: Text('暂无快照'),
      )
    : ListView.builder(…),

// 之后（弹层自身即容器，故不再套 SsCard）
child: latest.snapshots.isEmpty
    ? const SsEmpty(
        icon: Icons.history_toggle_off_rounded,
        art: SsArt.compass,
        title: '暂无快照',
        hint: '编辑器保存后会自动留档，也可用右上角「创建里程碑」手动存档',
      )
    : ListView.builder(…),
```

**为什么这里不套 `SsCard`**：该空态位于 `showSsSheet` 的 child 内，弹层自身已有
surface + hairline + 圆角（V8.21 收口成果），再套一层卡片会重复框线。同文件的
`SsArt.compass` 用法（`:174`）也为对齐提供了先例。

## 4. ★如实登记

1. **黄金基线被更新**：`test/features/goldens/home_empty.png` 由 **15894 → 17580 bytes**。
   成因是 §3.1 的空态收口改变了首屏「最近的策划案」卡片渲染。已用 `flutter test
   --update-goldens`（仅 `test/features/golden_screens_test.dart`）重生成，并**人工比对**
   失败产物 `test/features/failures/home_empty_masterImage.png`（旧）与
   `home_empty_testImage.png`（新）：**差异仅限该卡片区块**，其余像素（侧栏、标题、输入框、
   灵感区）完全一致；同批另两张基线 `onboarding.png` / `planner_empty.png` 字节未变。
   （该 golden 受 `goldenSkip = !Platform.isWindows` 约束，非 Windows 平台/CI 会跳过。）
2. **未为版本历史抽屉新增测试**：`_showHistory` 是 `part of 'planner_page.dart'` 内的私有
   扩展方法，直达它需要重 UI 路径（真实按钮 → provider → DB）；本次改动是**纯渲染替换**
   （同一 `isEmpty` 分支，文案保留），故按「不为收口而造重测试」处理，并在此如实登记。
3. **新增了一行指引文案**（`hint`）。合同 §3.5 对空态的定义就是「衬线大字 + **一行指引** +
   主行动」，原实现只有一句标题；新增的 hint 为事实性说明，未引入新功能。
4. **细阶用量下降**：`AppSpaceFine` 由 **73 → 72 处**（删掉了 `:272` 的 `AppSpaceFine.n20`）。
   门禁为「只降不升」，`tool/token_baseline.json` 的上限**保持不变**（仍 73），无需重新锁定。

## 5. 六件门禁（本批实测）

| 门禁 | 命令（cwd = `app/`） | 实测 |
|---|---|---|
| 格式化 | `dart format lib test` | `Formatted 258 files (0 changed)` |
| 静态分析 | `flutter analyze --no-pub --fatal-infos` | **No issues found!**（28.0s） |
| 测试 | `flutter test --no-pub` | **551 passed + 34 skipped**，exit 0 |
| 文件行数 | `node tool/check_file_size.mjs` | **PASS**（116 文件，limits 600/300，白名单 0） |
| 令牌 | `node tool/check_tokens.mjs` | **PASS**（187 文件 / 豁免 14；四类裸字面量 **0**；Fine 细阶 `AppSpaceFine 72（基线 73，↓）` / `AppFontSize 240（持平）` / `AppRadiusFine 9（持平）`） |
| 组件 | `node tool/check_components.mjs` | **PASS**（99 文件；`textField 0` / `textFormField 0` / `bottomSheet 0` / `alertDialog 0`） |

## 6. 基线

- `app/tool/component_baseline.json`：**不变**（空态不在这四类指标内）。
- `app/tool/token_baseline.json`：**不变**（`AppSpaceFine` 上限仍 73；实测 72 属「↓ 降」，门禁只降不升）。
- `test/features/goldens/home_empty.png`：**更新**（见 §4.1）。

## 7. 复核方法与证据

- 逐处打开源文件确认上下文（非仅 grep 行号），判定「该 Text 是否处于一个『区域为空』的分支」。
- `SsArt` 取值先例：`SsArt.film` → `planner/planner_page_canvas.dart:11`；`SsArt.compass` →
  `planner/planner_page_layout.dart:174`；`SsArt.light` → `lighting/widgets/lighting_inspector.dart:109`；
  `SsArt.pose` → `poses/poses_page_layout.dart:73`、`poses/pose_gallery.dart:149`。
- 测试锚点核实：`test/features/s4_shell_home_test.dart:235` 断言 `find.text('还没有策划案')`
  （收口后仍由 `SsEmpty` 的 `title` 渲染，断言不变）；无任何测试引用 `暂无快照` / `版本历史` / `创建里程碑`。
- `edit` 后交叉验证（沿用 R82 的教训：edit 成功 ≠ 文件已改）：`grep` 确认新增
  `art: SsArt.film` / `art: SsArt.compass` 已落盘，且 `Text('暂无快照')` 与 `AppSpaceFine.n20` 已消失。

## 8. 后续

- V8.22 §7 的 P3 清单**已逐处复核完毕**，无剩余可动项（8 项经判定保持原样）。
- 仍登记在案的非阻塞项（本批未动）：`build()` 内现建 `TextEditingController(text: …)` 预存反模式；
  偏差 5 的 `@Deprecated` 待调用点清零（现为软门禁 + 基线）；**V9 尚无合同**。

## 9. 一句话总结

**C4 的「残余 10 处」经逐处看代码后收敛为「8 处本就不该动 + 2 处真区块空态已收口」；
首屏空态换了渲染故 golden `home_empty.png` 随之更新（差异已人工比对确认仅限该卡片），
六件门禁全绿、test 551 + 34 零回归。**
