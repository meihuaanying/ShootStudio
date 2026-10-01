// V8/S9 · D158：新增器材条目对话框（顶层函数 _showAddDialog）。
// 从 gear_browser.dart 拆出（R73 行数门禁）；part 同库，私有成员无需公开化。
part of 'gear_browser.dart';

Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
  final TextEditingController brand = TextEditingController();
  final TextEditingController model = TextEditingController();
  final TextEditingController mount = TextEditingController();
  final TextEditingController price = TextEditingController();
  String kind = 'camera';
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
        title: const Text('添加自定义设备', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(
                  labelText: '类型',
                  isDense: true,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final (String k, String label) in <(String, String)>[
                    ('camera', '相机机身'),
                    ('lens', '镜头'),
                    ('light', '灯具'),
                    ('accessory', '附件'),
                  ])
                    DropdownMenuItem<String>(
                      value: k,
                      child: Text(label, style: const TextStyle(fontSize: 13)),
                    ),
                ],
                onChanged: (String? v) => setLocal(() => kind = v ?? kind),
              ),
              TextField(
                controller: brand,
                decoration: const InputDecoration(
                  labelText: '品牌',
                  isDense: true,
                ),
              ),
              TextField(
                controller: model,
                decoration: const InputDecoration(
                  labelText: '型号',
                  isDense: true,
                ),
              ),
              TextField(
                controller: mount,
                decoration: const InputDecoration(
                  labelText: '卡口（可空）',
                  isDense: true,
                ),
              ),
              TextField(
                controller: price,
                decoration: const InputDecoration(
                  labelText: '参考价（可空）',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          SsButton(
            label: '保存',
            onPressed: () async {
              if (brand.text.trim().isEmpty || model.text.trim().isEmpty) {
                ssToast(ctx, '品牌与型号必填');
                return;
              }
              final AppDatabase db = ref.read(databaseProvider);
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
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    ),
  );
  if (saved == true) {
    ref.invalidate(gearListProvider);
    if (context.mounted) ssToast(context, '已添加自定义设备');
  }
}
