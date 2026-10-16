# V8.10 / R74 收口终章：最后 2 处迁完，`lib/` 内 AlertDialog 归零

> **⚠️ 2026-10-16 更正（审计发现）：标题的「归零」是错的。** 本报告第 20 行的 `AlertDialog sites left=0` 来自一个**口径有缺陷**的复核脚本 —— 它只在 `showDialog<` 之后的 1500 字符窗口内匹配 `AlertDialog`，因此**漏掉了「widget `build()` 直接 `return AlertDialog(`」这种形态**。实测 `lib/`（排除 `core/design/`）仍有 **5 处** feature 侧 `AlertDialog`：
> `library_resource_editor.dart:97`（`ResourceEditorDialogState.build`）、`planner_page_dialogs.dart:220`（`_ColorPickerDialogState.build`）、`planner_page_pose_dialogs.dart:22`（`_PoseInfoDialog.build`）/ `:117`（`_PoseReplaceDialogState.build`）/ `:217`（`_BudgetEstimateDialogState.build`）。
> **偏差 10 已重新开放**（`docs/qa/v8-r71-deviations.md`），修复排入 `docs/audit/V8-COMPLIANCE-AUDIT.md` 批次 C1。本报告其余内容（V8.10 实际迁移的 2 处 + 测试写法）仍然有效。

> 合同依据：R74「弹层一律走 sanctioned API，feature 侧不得裸写
> `showDialog` + `AlertDialog`」。本阶段是这条收口的最后一步。

## 1. 计数终局：11 → 0

| 阶段 | 迁移数 | 做法 |
|---|---|---|
| V8.2 | 3 | `showSsConfirm`（bool 语义） |
| V8.7 | 4 | 新增 `showSsDialog<T>` + `SsDialogAction` |
| V8.8 | 4 | void 型 + 纯展示 / 单按钮 |
| V8.9 | 1 | 状态归属先拆件（`_NameCategoryBody`） |
| V8.10 | 2 | 本阶段，见 §2 |
| **合计** | **11** | |

复核脚本（排除 `core/design/` 自身，扫 170 个 Dart 文件）：

```
files=170  AlertDialog sites left=0
```

## 2. 本阶段两处迁移

### 2.1 `gear_browser_add.dart`：`_showAddDialog`（104 行，返回 `bool`）

原 `showDialog<bool>` + `StatefulBuilder` + `AlertDialog`（`SizedBox(width: 360)`）。

**拆件**：`_AddGearBody extends StatefulWidget`（`{super.key, required WidgetRef ref}`），
`_AddGearBodyState` 持 4 个 `TextEditingController`（brand/model/mount/price）
+ `String kind`，`dispose()` 统一释放。

**GlobalKey 设计**：「保存」在 `actions` 行（在弹层体之外），但校验与写库要读弹层体
内部状态，故用 `GlobalKey<_AddGearBodyState> bodyKey` 触达 `submit()`：

```dart
actions: (ctx) => <Widget>[
  SsDialogAction(
    label: '取消',
    primary: false,
    onPressed: () => Navigator.of(ctx).pop(false),
  ),
  SsDialogAction(
    label: '保存',
    onPressed: () => bodyKey.currentState?.submit(),
  ),
],
```

`maxWidth: 408`（原 `SizedBox.width` 360 + 两侧 padding 48 的既有换算公式）。

**顺带修掉一个真 bug**：原实现 4 个 `TextEditingController` **从不释放**
（真内存泄漏），现由 `_AddGearBodyState.dispose()` 释放。

### 2.2 `gear_browser_card.dart`：`_showDetail`（203 行，返回 `void`，4 个动作）

**这一处刻意不拆成 StatefulWidget**：弹层内**没有可变状态**（纯展示 + 动作），
所以只把内容提取成方法 `_detailBody(context, p, photo2, userPhoto)`，
把原 `children:` 原样搬入 —— 注释里写明了「不是为了拆而拆」。

`maxWidth: 468`（420 + 48）。四个动作映射：`放入布光场景` → primary（对应原
`SsButton`）；`删除` / `补图` / `关闭` → `primary: false`（对应原 `TextButton`，
**刻意不给 `danger: true`**，保持外观不变）。

pop 一律 `Navigator.of(ctx).pop()` —— `actions` 的 `ctx` 就是弹层路由自己的
context，**不需要 `Builder`**（与 V8.8 的 template picker 不同：那里 `child` 是
构造期闭包常量，拿不到弹层 ctx）。

## 3. 新增端到端用例（`test/features/q6_gear_test.dart`）

标题：`「添加设备」弹层走 sanctioned 外观且必填校验生效（R74 收口）`。

覆盖：弹层打开 → 字段齐（品牌 / 型号 / 卡口（可空）/ 参考价（可空）/ 保存 / 取消）
→ 空字段点「保存」只提示、不关闭 → 填齐后保存 → 弹层关闭 +
`已添加自定义设备` + **查库确有该行**。本文件已有 `uiDb`
（`AppDatabase.forTesting(NativeDatabase.memory())`）夹具，故查库断言是真实写库，
不是 mock。

### 调试过程中定位到的两个真实测试写法问题（都写进了用例注释）

1. **drift 的真实异步在 `testWidgets` 的 FakeAsync 下不推进**：`submit()` 里的
   `await 写库` 永不返回 → `pop(true)` 永不执行 → 表现为「保存后弹层关不掉」。
   修法：**把点击放进 `tester.runAsync`**（`runAsync` 内不能再 pump，故其后单独补帧）。
   该判断的排除依据：`takeException()` 为 null（排除「抛异常」）、`tap` 无
   miss 警告（排除「点偏」）、`find.text('TestBrand')` 命中（排除「输入没进去」）。
2. **`ssToast` 是 SnackBar，退场分三步**（duration 计时器
   `AppMotion.slow = 420ms` → 退场动画 → 移除），**每步都要单独一帧**。
   只 `pump(5s)` 一次只会让计时器触发、退场动画停在第 0 帧，toast 仍在屏幕上并可能
   挡住后续点击。修法：先 `pump(500ms)` 再逐帧 `pump(300ms) × 6`，
   并断言 toast 确实消失后再继续。
   另注：诊断时用 `find.byType(Text)` 收集可见文本**看不到 `EditableText`**，
   故中途「输入没进去」的结论是错的（实际是 tap 被 toast 挡住），此坑记此备查。

## 4. 影响面自查

- 本阶段改动全部落在 `lib/features/libraries/` 两个文件 + 一个测试文件，
  未触及设计令牌，未新增色值 / 字号 / 间距裸数字（`check_tokens` 四类全 0）。
- 既有三处弹层链路（`q6_gear_test.dart` 的「缺图条目提供「补图」入口」用例串联
  `_detailBody` → 重拍弹层 → 粘贴链接弹层）**仍全过**，该文件 9/9。
- `gear_browser_card.dart` 486 → 498 行（仍在 600 行上限内）。

## 5. 门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 256 files（1 changed → 复跑 **0 changed**） |
| `flutter analyze --no-pub --fatal-infos` | **No issues found**（10.6s） |
| `flutter test --no-pub` | **543 passed + 34 skipped，EXIT=0**（基线 542 + 1 新用例） |
| `node tool/check_file_size.mjs` | **PASS**（最大 589 行 `lib/features/ai/ai_client.dart`） |
| `node tool/check_tokens.mjs` | **PASS**（186 文件 / 豁免 14；四类全 0） |

## 6. 一句话总结

R74 收口从「11 处待迁」走到 **0**；最后 2 处的经验是「**先看有没有可变状态，
再决定拆件粒度**」—— 有状态才拆 `StatefulWidget`（并顺带修掉 controller 泄漏），
无状态只提方法即可。
