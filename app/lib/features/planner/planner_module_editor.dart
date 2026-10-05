// V8/S8 · D158：模块编辑器主体（太阳 / 参考图 / 色板三组面板）；
// 布光 / 姿势 / 分镜在 _a，预算 / 表格 / 富文本 / 绑定在 _b（extension 承载）。
part of 'planner_page.dart';

class _ModuleEditor extends ConsumerWidget {
  const _ModuleEditor({required this.module, required this.controller});

  final PlanModuleData module;
  final PlannerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SsCard(
      child: ListView(
        children: <Widget>[
          SsSectionTitle('编辑 · ${module.type.label}'),
          const SizedBox(height: AppSpace.s2),
          TextField(
            controller: TextEditingController(text: module.title),
            decoration: const InputDecoration(hintText: '模块标题', isDense: true),
            onChanged: (String v) => controller.updateModule(
              module.id,
              (PlanModuleData m) => m.title = v,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          ..._body(context, ref),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref) {
    switch (module.type) {
      case PlanModuleType.theme:
      case PlanModuleType.richText:
        return _richTextEditor(context, ref);
      case PlanModuleType.sun:
        return _sunEditor(context, ref);
      case PlanModuleType.refs:
        return _refsEditor(context, ref);
      case PlanModuleType.palette:
        return _paletteEditor(context, ref);
      case PlanModuleType.lighting:
        return _lightingEditor(context, ref);
      case PlanModuleType.poses:
        return _posesEditor(context, ref);
      case PlanModuleType.storyboard:
        return _storyboardEditor(context, ref);
      case PlanModuleType.crew:
        return _rowsEditor(
          context,
          <String>['role', 'who', 'time'],
          <String>['角色', '成员', '时间'],
        );
      case PlanModuleType.budget:
        return _budgetEditor(context, ref);
      default:
        return _bindingEditor(context, ref);
    }
  }

  List<Widget> _sunEditor(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;

    final place = module.data['place'] as String? ?? '';
    final date = module.data['date'] as String? ?? '';
    final lat = (module.data['lat'] as num?)?.toDouble() ?? 31.23;
    final lon = (module.data['lon'] as num?)?.toDouble() ?? 121.47;
    SolarDay? solar;
    final parts = date.split('-');
    if (date.isNotEmpty && parts.length == 3) {
      solar = SolarCalculator.compute(
        year: int.tryParse(parts[0]) ?? DateTime.now().year,
        month: int.tryParse(parts[1]) ?? 1,
        day: int.tryParse(parts[2]) ?? 1,
        latitude: lat,
        longitude: lon,
      );
    }
    return <Widget>[
      _CitySearchField(
        initial: place,
        onPick: (String name, double la, double lo) {
          controller.updateModule(module.id, (PlanModuleData m) {
            m.data['place'] = name;
            m.data['lat'] = la;
            m.data['lon'] = lo;
          });
        },
      ),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: TextEditingController(text: lat.toStringAsFixed(4)),
              decoration: const InputDecoration(labelText: '纬度', isDense: true),
              onChanged: (String v) => controller.updateModule(
                module.id,
                (PlanModuleData m) =>
                    m.data['lat'] = double.tryParse(v) ?? m.data['lat'],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: lon.toStringAsFixed(4)),
              decoration: const InputDecoration(labelText: '经度', isDense: true),
              onChanged: (String v) => controller.updateModule(
                module.id,
                (PlanModuleData m) =>
                    m.data['lon'] = double.tryParse(v) ?? m.data['lon'],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: TextEditingController(text: date),
        decoration: const InputDecoration(
          hintText: '日期 yyyy-MM-dd',
          isDense: true,
        ),
        onChanged: (String v) => controller.updateModule(
          module.id,
          (PlanModuleData m) => m.data['date'] = v,
        ),
      ),
      const SizedBox(height: 10),
      if (solar != null)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '日出 ${SolarCalculator.fmt(solar.sunrise)} · 日落 ${SolarCalculator.fmt(solar.sunset)}',
                style: const TextStyle(
                  fontSize: AppFontSize.small,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final SolarWindow? w in <SolarWindow?>[
                solar.goldenMorning,
                solar.goldenEvening,
                solar.blueMorning,
                solar.blueEvening,
              ])
                if (w != null)
                  Text(
                    '${w.label} ${SolarCalculator.fmt(w.startMin)} – ${SolarCalculator.fmt(w.endMin)}',
                    style: TextStyle(
                      fontSize: AppFontSize.captionLg,
                      color: p.film,
                    ),
                  ),
            ],
          ),
        )
      else
        const Text(
          '输入日期后自动计算黄金时刻 / 蓝调时刻',
          style: TextStyle(fontSize: AppFontSize.captionLg),
        ),
    ];
  }

  List<Widget> _refsEditor(BuildContext context, WidgetRef ref) {
    final refs = (module.data['refs'] as List? ?? <Object?>[])
        .cast<Map<String, Object?>>();
    final pending = ref.watch(pendingFramesProvider);
    final workspace = ref.watch(workspaceProvider);

    Future<void> upload() async {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final String? filePath = result?.files.single.path;
      if (filePath == null) return;
      final store = ImageStore(workspace.root.path);
      final (String fileName, PaletteResult palette) = await store.importFile(
        filePath,
        category: 'refs',
      );
      controller.updateModule(module.id, (PlanModuleData m) {
        final list = <Object?>[...(m.data['refs'] as List? ?? <Object?>[])];
        list.add(<String, Object?>{
          'name': path.basenameWithoutExtension(filePath),
          'palette': palette.colors,
          'gradient': palette.colors.take(2).toList(),
          'sourceUrl': '',
          'imageRef': fileName,
        });
        m.data['refs'] = list;
      });
    }

    return <Widget>[
      Row(
        children: <Widget>[
          Text(
            '已插入 ${refs.length} 张',
            style: const TextStyle(fontSize: AppFontSize.small),
          ),
          const Spacer(),
          SsButton(
            label: '上传图片',
            dense: true,
            kind: SsButtonKind.text,
            onPressed: upload,
          ),
          const SizedBox(width: 6),
          SsButton(
            label: '插入待选（${pending.length}）',
            dense: true,
            kind: SsButtonKind.outline,
            onPressed: pending.isEmpty
                ? null
                : () {
                    controller.updateModule(module.id, (PlanModuleData m) {
                      final list = <Object?>[
                        ...(m.data['refs'] as List? ?? <Object?>[]),
                      ];
                      for (final PendingFrame f in pending) {
                        list.add(<String, Object?>{
                          'name': f.name,
                          'palette': f.palette,
                          'gradient': f.gradient,
                          'sourceUrl': f.sourceUrl,
                          'imageRef': f.imagePath,
                        });
                      }
                      m.data['refs'] = list;
                    });
                  },
          ),
        ],
      ),
      const SizedBox(height: 6),
      for (var i = 0; i < refs.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Row(
            children: <Widget>[
              _refThumb(context, workspace.root.path, refs[i]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      refs[i]['name'] as String? ?? '',
                      style: const TextStyle(fontSize: AppFontSize.smallSm),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (((refs[i]['imageRef'] as String?) ?? '').isNotEmpty)
                      const Text(
                        '真实图片 · 导出随附',
                        style: TextStyle(fontSize: AppFontSize.tiny),
                      )
                    else if (((refs[i]['sourceUrl'] as String?) ?? '')
                        .isNotEmpty)
                      Text(
                        '出处保留 · 导出时附带',
                        style: TextStyle(
                          fontSize: AppFontSize.tiny,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 14),
                onPressed: () =>
                    controller.updateModule(module.id, (PlanModuleData m) {
                      final list = <Object?>[
                        ...(m.data['refs'] as List? ?? <Object?>[]),
                      ]..removeAt(i);
                      m.data['refs'] = list;
                    }),
              ),
            ],
          ),
        ),
      if (refs.isEmpty && pending.isEmpty)
        const Text(
          '可本地上传图片，或去「画面参考库」选静帧 →「插入策划案样片」',
          style: TextStyle(fontSize: AppFontSize.captionLg),
        ),
    ];
  }

  Widget _refThumb(
    BuildContext context,
    String workspaceRoot,
    Map<String, Object?> item,
  ) {
    final palette = (item['palette'] as List? ?? <Object?>[]).cast<String>();
    final imageRef = item['imageRef'] as String? ?? '';
    Widget fallback = Container(
      width: 42,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            _hexColor(palette.isNotEmpty ? palette[0] : '#888888'),
            _hexColor(palette.length > 1 ? palette[1] : '#333333'),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    if (imageRef.isEmpty) return fallback;
    final file = File(path.join(workspaceRoot, 'images', 'refs', imageRef));
    if (!file.existsSync()) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(file, width: 42, height: 30, fit: BoxFit.cover),
    );
  }

  Color _hexColor(String hex) => Color(
    0xFF000000 |
        (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x888888),
  );

  List<Widget> _paletteEditor(BuildContext context, WidgetRef ref) {
    final colors = (module.data['colors'] as List? ?? <Object?>[])
        .cast<String>();

    void setColors(List<String> next) => controller.updateModule(
      module.id,
      (PlanModuleData m) => m.data['colors'] = next,
    );

    return <Widget>[
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (var i = 0; i < colors.length; i++)
            Tooltip(
              message: '${colors[i]} · 点击复制',
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: colors[i]));
                  ssToast(context, '已复制 ${colors[i]}');
                },
                onLongPress: () {
                  final next = <String>[...colors]..removeAt(i);
                  setColors(next);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _hexColor(colors[i]),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: InkWell(
                        onTap: () {
                          final next = <String>[...colors]..removeAt(i);
                          setColors(next);
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xCC1F2329),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          SsButton(
            label: '添加颜色',
            kind: SsButtonKind.text,
            dense: true,
            onPressed: () async {
              final String? hex = await showDialog<String>(
                context: context,
                builder: (_) => const _ColorPickerDialog(),
              );
              if (hex == null) return;
              setColors(<String>[...colors, hex]);
            },
          ),
          SsButton(
            label: '从图片提取',
            kind: SsButtonKind.text,
            dense: true,
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              final String? path = result?.files.single.path;
              if (path == null) return;
              final bytes = await File(path).readAsBytes();
              final PaletteResult palette = PaletteExtractor.extract(bytes);
              setColors(palette.colors.take(5).toList());
              if (context.mounted) ssToast(context, '已提取 5 色');
            },
          ),
          SsButton(
            label: '从待插入样片取色',
            kind: SsButtonKind.text,
            dense: true,
            onPressed: () {
              final pending = ref.read(pendingFramesProvider);
              if (pending.isEmpty) {
                ssToast(context, '待插入样片为空：先去画面参考库收帧');
                return;
              }
              setColors(
                pending.expand((PendingFrame f) => f.palette).take(5).toList(),
              );
            },
          ),
          SsButton(
            label: '取画板最近一帧',
            kind: SsButtonKind.text,
            dense: true,
            onPressed: () {
              final board = ref.read(refsControllerProvider).board;
              if (board.isEmpty) {
                ssToast(context, '画板为空');
                return;
              }
              setColors(board.first.palette);
            },
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        '长按色块或点右上角 × 删除；导出长图取前 5 色',
        style: TextStyle(
          fontSize: AppFontSize.caption,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }
}
