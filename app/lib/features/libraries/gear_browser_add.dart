// V8/S9 · D158：新增器材条目对话框（顶层函数 _showAddDialog）。
// 从 gear_browser.dart 拆出（R73 行数门禁）；part 同库，私有成员无需公开化。
//
// V8.10 / R74：弹层体拆成 _AddGearBody（StatefulWidget），统一走
// sanctioned `showSsDialog<bool>` + `SsDialogAction`。详见
// docs/qa/v8-10-r74-batch3.md。
part of 'gear_browser.dart';

Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
  // 「保存」在 actions 行（在弹层体之外），而校验与写库要读弹层体的内部状态，
  // 故用 GlobalKey 触达 submit()。备选是把保存钮塞进 child 里，但那样就绕开了
  // 统一动作按钮，得不偿失 —— 这与 V8.9 的结论一致（行为要守住设计系统）。
  final GlobalKey<_AddGearBodyState> bodyKey = GlobalKey<_AddGearBodyState>();
  final bool? saved = await showSsDialog<bool>(
    context: context,
    title: '添加自定义设备',
    // 原 `SizedBox(width: 360)` → 360 + 48（SsDialog 两侧 padding = AppSpace.block）。
    maxWidth: 408,
    child: _AddGearBody(key: bodyKey, ref: ref),
    actions: (BuildContext ctx) => <Widget>[
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
  );
  if (saved == true) {
    ref.invalidate(gearListProvider);
    if (context.mounted) ssToast(context, '已添加自定义设备');
  }
}

/// 「添加自定义设备」表单体。
///
/// 状态归属：原先 4 个 `TextEditingController` 与 `kind` 都挂在
/// `_showAddDialog` 的闭包里、靠 `StatefulBuilder` 触发重建，而且**从不释放**
/// （真内存泄漏）。拆件后由本 State 持有，`dispose()` 统一释放。
class _AddGearBody extends StatefulWidget {
  const _AddGearBody({super.key, required this.ref});

  final WidgetRef ref;

  @override
  State<_AddGearBody> createState() => _AddGearBodyState();
}

class _AddGearBodyState extends State<_AddGearBody> {
  final TextEditingController brand = TextEditingController();
  final TextEditingController model = TextEditingController();
  final TextEditingController mount = TextEditingController();
  final TextEditingController price = TextEditingController();
  String kind = 'camera';

  @override
  void dispose() {
    brand.dispose();
    model.dispose();
    mount.dispose();
    price.dispose();
    super.dispose();
  }

  /// 由 actions 行的「保存」经 GlobalKey 调起。
  ///
  /// 校验失败只提示、不关闭（与原实现一致）；写库成功才 `pop(true)`。
  /// `Navigator.of(context)` 取到的是本弹层路由的 Navigator，不需要 Builder。
  Future<void> submit() async {
    if (brand.text.trim().isEmpty || model.text.trim().isEmpty) {
      ssToast(context, '品牌与型号必填');
      return;
    }
    final AppDatabase db = widget.ref.read(databaseProvider);
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.gearItems)
        .insertOnConflictUpdate(
          GearItemsCompanion.insert(
            id: 'custom-$now',
            kind: kind,
            brand: brand.text.trim(),
            model: model.text.trim(),
            mount: Value(mount.text.trim()),
            specsJson: const Value('{"type":"自定义"}'),
            priceRef: Value(double.tryParse(price.text.trim()) ?? 0),
            builtin: const Value(false),
          ),
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: kind,
          decoration: const InputDecoration(labelText: '类型', isDense: true),
          items: <DropdownMenuItem<String>>[
            for (final (String k, String label) in <(String, String)>[
              ('camera', '相机机身'),
              ('lens', '镜头'),
              ('light', '灯具'),
              ('accessory', '附件'),
            ])
              DropdownMenuItem<String>(
                value: k,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: AppFontSize.smallLg),
                ),
              ),
          ],
          onChanged: (String? v) => setState(() => kind = v ?? kind),
        ),
        SsTextInput(label: '品牌', controller: brand, dense: true),
        SsTextInput(label: '型号', controller: model, dense: true),
        SsTextInput(label: '卡口（可空）', controller: mount, dense: true),
        SsTextInput(
          label: '参考价（可空）',
          controller: price,
          dense: true,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
