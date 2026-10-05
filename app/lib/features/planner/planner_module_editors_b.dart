// V8/S8 · D158：预算 / 表格 / 富文本 / 资源绑定面板。
part of 'planner_page.dart';

extension _ModuleEditorPanelsB on _ModuleEditor {
  List<Widget> _budgetEditor(BuildContext context, WidgetRef ref) {
    final rows = (module.data['rows'] as List? ?? <Object?>[])
        .cast<Map<String, Object?>>();
    final double total = BudgetEstimator.total(rows);

    void setRows(List<Object?> next) => controller.updateModule(
      module.id,
      (PlanModuleData m) => m.data['rows'] = next,
    );

    return <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpaceFine.n10,
          vertical: AppSpace.s2,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          children: <Widget>[
            const Text('自动合计', style: TextStyle(fontSize: AppFontSize.smallSm)),
            const Spacer(),
            Text(
              '¥${total.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: AppFontSize.bodyLg,
                fontWeight: AppFontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            SsButton(
              label: 'AI 估算',
              dense: true,
              kind: SsButtonKind.outline,
              onPressed: () async {
                final result =
                    await showDialog<
                      ({
                        String city,
                        String tier,
                        double multiplier,
                        int people,
                      })
                    >(
                      context: context,
                      builder: (_) => const _BudgetEstimateDialog(),
                    );
                if (result == null) return;
                final items = await ContentPacks.budgetRefs();
                final List<Map<String, Object?>> estimated =
                    BudgetEstimator.estimate(
                      items: items,
                      multiplier: result.multiplier,
                      tier: result.tier,
                      people: result.people,
                    );
                setRows(
                  estimated
                      .map((Map<String, Object?> r) => r as Object?)
                      .toList(),
                );
                if (context.mounted) {
                  ssToast(
                    context,
                    '已按 ${result.city}（${result.tier}）估算 ${estimated.length} 项，可继续手动微调',
                  );
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpaceFine.n6),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(
                    text: '${rows[i]['item'] ?? ''}',
                  ),
                  decoration: const InputDecoration(
                    hintText: '项目',
                    isDense: true,
                  ),
                  onChanged: (String v) =>
                      controller.updateModule(module.id, (PlanModuleData m) {
                        final list = (m.data['rows'] as List? ?? <Object?>[]);
                        (list[i] as Map)['item'] = v;
                        m.data['rows'] = list;
                      }),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                    text: '${rows[i]['price'] ?? 0}',
                  ),
                  decoration: const InputDecoration(
                    hintText: '金额',
                    isDense: true,
                  ),
                  onChanged: (String v) =>
                      controller.updateModule(module.id, (PlanModuleData m) {
                        final list = (m.data['rows'] as List? ?? <Object?>[]);
                        (list[i] as Map)['price'] = double.tryParse(v) ?? 0;
                        m.data['rows'] = list;
                      }),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(
                    text: '${rows[i]['note'] ?? ''}',
                  ),
                  decoration: const InputDecoration(
                    hintText: '备注',
                    isDense: true,
                  ),
                  onChanged: (String v) =>
                      controller.updateModule(module.id, (PlanModuleData m) {
                        final list = (m.data['rows'] as List? ?? <Object?>[]);
                        (list[i] as Map)['note'] = v;
                        m.data['rows'] = list;
                      }),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 14),
                onPressed: () {
                  final list = <Object?>[...rows]..removeAt(i);
                  setRows(list);
                },
              ),
            ],
          ),
        ),
      SsButton(
        label: '添加一行',
        kind: SsButtonKind.text,
        dense: true,
        onPressed: () => setRows(<Object?>[
          ...rows,
          <String, Object?>{'item': '', 'price': 0, 'note': ''},
        ]),
      ),
    ];
  }

  List<Widget> _rowsEditor(
    BuildContext context,
    List<String> fields,
    List<String> labels,
  ) {
    final rows = (module.data['rows'] as List? ?? <Object?>[])
        .cast<Map<String, Object?>>();
    return <Widget>[
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpaceFine.n6),
          child: Row(
            children: <Widget>[
              for (var f = 0; f < fields.length; f++) ...<Widget>[
                Expanded(
                  flex: f == 1 ? 1 : 2,
                  child: TextField(
                    controller: TextEditingController(
                      text: '${rows[i][fields[f]] ?? ''}',
                    ),
                    decoration: InputDecoration(
                      hintText: labels[f],
                      isDense: true,
                    ),
                    onChanged: (String v) =>
                        controller.updateModule(module.id, (PlanModuleData m) {
                          final list = (m.data['rows'] as List? ?? <Object?>[]);
                          (list[i] as Map)[fields[f]] = fields[f] == 'price'
                              ? (double.tryParse(v) ?? 0)
                              : v;
                          m.data['rows'] = list;
                        }),
                  ),
                ),
                if (f != fields.length - 1) const SizedBox(width: 4),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 14),
                onPressed: () =>
                    controller.updateModule(module.id, (PlanModuleData m) {
                      final list = <Object?>[
                        ...(m.data['rows'] as List? ?? <Object?>[]),
                      ]..removeAt(i);
                      m.data['rows'] = list;
                    }),
              ),
            ],
          ),
        ),
      SsButton(
        label: '添加一行',
        kind: SsButtonKind.text,
        dense: true,
        onPressed: () => controller.updateModule(module.id, (PlanModuleData m) {
          final list = <Object?>[...(m.data['rows'] as List? ?? <Object?>[])];
          list.add(<String, Object?>{
            for (final String f in fields) f: f == 'price' ? 0 : '',
          });
          m.data['rows'] = list;
        }),
      ),
    ];
  }

  List<Widget> _richTextEditor(BuildContext context, WidgetRef ref) {
    return <Widget>[
      _RichTextInput(
        key: ValueKey<String>('rich-${module.id}'),
        initial: module.data['text'] as String? ?? '',
        hint: module.type == PlanModuleType.theme
            ? '拍摄主题、氛围与表达目标…（支持 **加粗** 与 - 列表）'
            : '自由文本…（支持 **加粗** 与 - 列表）',
        onChanged: (String v) => controller.updateModule(
          module.id,
          (PlanModuleData m) => m.data['text'] = v,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '导出长图 / PDF 将同步渲染格式',
        style: TextStyle(
          fontSize: AppFontSize.caption,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  Future<List<Option>> _resourcesOf(WidgetRef ref, String kind) async {
    final db = ref.watch(databaseProvider);
    final rows = await (db.select(
      db.resources,
    )..where((t) => t.type.equals(kind))).get();
    return rows.map((Resource r) => Option(r.id, r.name)).toList();
  }

  List<Widget> _bindingEditor(BuildContext context, WidgetRef ref) {
    final kind = module.type.resourceKind;
    if (kind == null) return <Widget>[];
    final ids = (module.data['ids'] as List? ?? <Object?>[]).cast<String>();
    return <Widget>[
      FutureBuilder<List<Option>>(
        future: _resourcesOf(ref, kind),
        builder: (BuildContext context, AsyncSnapshot<List<Option>> snap) {
          final list = snap.data ?? <Option>[];
          if (list.isEmpty) {
            return Text(
              '${module.type.label}：资源库还没有条目（去「资源库」新建）',
              style: const TextStyle(fontSize: AppFontSize.captionLg),
            );
          }
          return Column(
            children: <Widget>[
              for (final Option item in list)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: ids.contains(item.id),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontSize: AppFontSize.small),
                  ),
                  onChanged: (bool? v) => controller.updateModule(module.id, (
                    PlanModuleData m,
                  ) {
                    final list2 = <String>[
                      ...(m.data['ids'] as List? ?? <Object?>[]).cast<String>(),
                    ];
                    if (v == true) {
                      list2.add(item.id);
                    } else {
                      list2.remove(item.id);
                    }
                    m.data['ids'] = list2;
                    m.data['placeholder'] = list2.isEmpty;
                  }),
                ),
              TextField(
                controller: TextEditingController(
                  text: module.data['note'] as String? ?? '',
                ),
                decoration: const InputDecoration(
                  hintText: '补充说明（可空）',
                  isDense: true,
                ),
                onChanged: (String v) => controller.updateModule(
                  module.id,
                  (PlanModuleData m) => m.data['note'] = v,
                ),
              ),
            ],
          );
        },
      ),
    ];
  }
}
