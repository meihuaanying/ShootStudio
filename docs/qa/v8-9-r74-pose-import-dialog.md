# V8.9 / R74 第三批：命名分类弹层（含 StatefulBuilder → StatefulWidget 归属重构）

> 接续 `docs/qa/v8-8-r74-batch2.md`。该报告把 R74 剩余判为 3 处，并指出第 3 处
> （`pose_import_page_layout.dart`）**「不是替换调用即可」**，因为
> `StatefulBuilder` 让状态活在弹层内部、归属未定。本报告就是把这处做完。

## 1. 计数

| 阶段 | 迁走 | 剩余 |
|---|---|---|
| V8.2 | 3 | 8 |
| V8.7 | 4 | 4 |
| V8.8 | 4 | 3 |
| **V8.9** | **1** | **2** |

累计 **11 − 9 = 2**。剩余 2 处见 §4。

## 2. 本处迁移：`pose_import_page_layout.dart` 的 `_askNameCategory`

### 2.1 迁移前的样子（`part of 'pose_import_page.dart'` 里的 extension 方法）
```dart
final TextEditingController name = TextEditingController(text: defaultName);
String category = defaultCategory;
final (String?, String?)? result = await showDialog<(String?, String?)>(
  context: context,
  builder: (BuildContext ctx) => StatefulBuilder(
    builder: (BuildContext ctx, StateSetter setStateDialog) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: AppFontSize.bodyXl)),
      content: SizedBox(width: 360, child: Column(... TextField(controller: name) ...
        SsChip(selected: category == c, onTap: () => setStateDialog(() => category = c)) ...)),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        SsButton(label: '保存', dense: true,
                 onPressed: () => Navigator.pop(ctx, (name.text, category))),
      ],
    ),
  ),
);
name.dispose();
return result ?? (null, null);
```

### 2.2 状态归属的决断
本弹层里**唯一的可变状态是分类选中态 `category`**（输入框文本由
`TextEditingController` 自己持有，不需要 `setState`）。

`StatefulBuilder` 的用法把 `setState` **从弹层外**灌进来，代价是三件事：
1. 状态变量与 `TextEditingController` 的生命周期由 `await` 之后的代码负责
   （`name.dispose()` 写在 `await` 后面）；
2. 弹层体无法复用、无法单独测试；
3. 弹层外观仍由 feature 侧自拼（R74 违规点）。

**决断：状态归弹层体自己。** 把弹层体提成 `_NameCategoryBody extends StatefulWidget`
（`{title, defaultName, defaultCategory}`），分类选中态与输入框控制器都归它的
`State`；`StatefulBuilder` 整个消失。

```dart
class _NameCategoryBodyState extends State<_NameCategoryBody> {
  late final TextEditingController _name =
      TextEditingController(text: widget.defaultName);
  late String _category = widget.defaultCategory;

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SsDialog(
    title: widget.title,
    maxWidth: 408,
    actions: <Widget>[
      SsDialogAction(label: '取消', primary: false,
                     onPressed: () => Navigator.of(context).pop()),
      SsDialogAction(label: '保存',
                     onPressed: () => Navigator.of(context).pop((_name.text, _category))),
    ],
    child: Column(... TextField(controller: _name) ... Wrap(SsChip(onTap: () => setState(() => _category = c))) ...),
  );
}
```

调用方退化成常规替换：
```dart
final (String?, String?)? result = await showDialog<(String?, String?)>(
  context: context,
  builder: (BuildContext ctx) => _NameCategoryBody(
    title: title, defaultName: defaultName, defaultCategory: defaultCategory,
  ),
);
return result ?? (null, null);   // 遮罩关闭 → null → 按「取消」处理，语义不变
```

### 2.3 三处需要点明的细节
1. **不需要 `Builder` 取 ctx**（与 V8.8 的 template picker 不同）：`_NameCategoryBody`
   是**独立 widget**，它的 `context` 本就位于弹层路由内部，`Navigator.of(context)`
   直接指向弹层自身。V8.8 需要 `Builder` 是因为那里的 `child:` 是构造期参数、
   拿不到弹层 ctx；本处用「独立 StatefulWidget」天然绕开了这个问题。
   结论：**「弹层内需要 pop」有两条正解 —— 独立 StatefulWidget，或 `Builder`；
   后者只在 child 是闭包常量时才必需。**
2. **`maxWidth: 408`** 按 sanctioned API 的公式 `maxWidth = 原 SizedBox.width + 48`
   （`SsDialog` 两侧 padding 是 `AppSpace.block` = 24）；原为 `SizedBox(width: 360)`。
3. **「取消」显式 `Navigator.pop()`**，不依赖 `SsDialogAction` 的
   `onPressed == null` 兜底 —— 该兜底只 pop 不返回值（V8.8 §3 已钉住该语义），
   而这里返回 `null` 才是「取消」的表达，显式写更清楚。

### 2.4 顺带修掉的
`TextEditingController` 的释放从「`await` 之后手工 `dispose()`」改为
`_NameCategoryBodyState.dispose()` —— 弹层被销毁时必定释放，不再依赖调用方
记得在 await 后补一句。

### 2.5 归一化差异（需登记，与 V8.7/V8.8 同类）
- 弹层标题由 `TextStyle(fontSize: AppFontSize.bodyXl)` 改走 `SsDialog` 的
  `AppType.h2`（衬线）；
- 「保存」按钮由 `SsButton(dense: true)` 变 `SsDialogAction`（`FilledButton`），
  「取消」由裸 `TextButton` 变 `SsDialogAction(primary: false)`（`TextButton`）。
两者都是 R74 收口的目的，不是回归。

## 3. 测试覆盖（如实说明：本处无法直测）

`_askNameCategory` 只在**识别成功之后**的「保存为自定义姿势 / 覆盖参考图数据」
路径上被调用（`pose_import_page.dart:295`），需要引擎出图才能到达
（`test/features/q2_pose_photos_test.dart:376` 只挂载了 `PoseImportPage` 首屏，
`test/visual/s7_pose_capture_test.dart:179` 是视觉快照），**没有既有的用例会打开这个弹层**。

`_NameCategoryBody` 是库私有件（`part of`），测试侧无法直接引用。因此本处
**没有新增针对性用例**，验证手段是：

| 手段 | 结果 |
|---|---|
| `flutter analyze --no-pub --fatal-infos` | No issues found（含 `lib/features/poses` 单目录复核） |
| 全量 `flutter test --no-pub` | 542 passed + 34 skipped（**与 V8.8 一致，无回归**） |
| `node tool/check_file_size.mjs` | PASS（limits 600/300，基线白名单 0 项） |
| `node tool/check_tokens.mjs` | PASS（四类全 0） |

**这是本阶段最大的诚实的缺口**：本处的正确性目前靠「迁移前后逐行对照 + 静态分析」，
不靠门禁。若要补测，需要先把弹层体提成公开可测件（或给
`PoseImportPage` 注入可跳过识别的假数据），属于独立一轮的工作量，登记在此不做。

## 4. 剩余 2 处

| # | 文件:行 | 跨度 | 返回 | 为何仍需先拆件 |
|---|---|---|---|---|
| 1 | `lib/features/libraries/gear_browser_add.dart:11` | 104 行 | `bool` | 富内容新增表单（多字段 + 校验 + 提交流程 await 链），拆件前先要定状态与提交的归属 |
| 2 | `lib/features/libraries/gear_browser_card.dart:259` | 203 行 | `void`，3 动作 | 富内容 + 图片链（缩略图 / 预览 / 加载态），全树最长，需拆出多个子件 |

本阶段的价值之一，是给这 2 处提供了一个**已验证可行的拆法模板**：
「状态归弹层体自己的 `State` → 弹层体独立成 widget → 调用方退化成常规替换」。
V8.8 判定第 3 处「不是替换调用即可」是对的，但一旦状态归属定下来，
迁移就退化成常规替换 —— 这正是 §2 做的事。

## 5. 门禁实测（全绿）

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 256 files, 1 changed → 复跑 **0 changed** |
| `flutter analyze --no-pub --fatal-infos` | **No issues found**（11.1s） |
| `flutter test --no-pub` | **542 passed + 34 skipped**, `EXITCODE=0` |
| `node tool/check_file_size.mjs` | **PASS** |
| `node tool/check_tokens.mjs` | **PASS**（186 文件、豁免 14、四类全 0） |

测试计数：与 V8.8 相同 **542**（本阶段无新增用例，见 §3 的说明；无删改断言）。
