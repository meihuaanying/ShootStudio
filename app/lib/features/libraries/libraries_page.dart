import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/json_utils.dart';
import '../../services/image_store.dart';
import 'gear_browser.dart';

/// 五大资源库定义（D2/PRD 6.4）。
const List<({String type, String label})> libraryKinds =
    <({String type, String label})>[
  (type: 'models', label: '模特库'),
  (type: 'locations', label: '场地库'),
  (type: 'clothing', label: '服装库'),
  (type: 'props', label: '道具库'),
  (type: 'makeup', label: '妆面库'),
];

/// 资源库条目视图模型。
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.type,
    required this.name,
    required this.fields,
    required this.cover,
    required this.images,
    required this.updatedAt,
  });

  final String id;
  final String type;
  final String name;
  final Map<String, Object?> fields;
  final String? cover;
  final List<String> images;
  final int updatedAt;

  String get summary {
    final parts = <String>[
      fields['region'] as String? ?? '',
      fields['price'] as String? ?? '',
      fields['height'] as String? ?? '',
    ].where((String s) => s.isNotEmpty).toList();
    return parts.isEmpty
        ? (fields['note'] as String? ?? '暂无备注')
        : parts.join(' · ');
  }
}

final libraryControllerProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

class LibraryState {
  const LibraryState({
    this.type = 'models',
    this.items = const <LibraryItem>[],
    this.keyword = '',
    this.loaded = false,
    this.status = '',
  });

  final String type;
  final List<LibraryItem> items;
  final String keyword;
  final bool loaded;
  final String status;

  List<LibraryItem> get filtered => items
      .where(
        (LibraryItem item) =>
            keyword.isEmpty ||
            item.name.toLowerCase().contains(keyword.toLowerCase()) ||
            item.summary.toLowerCase().contains(keyword.toLowerCase()),
      )
      .toList();

  LibraryState copyWith({
    String? type,
    List<LibraryItem>? items,
    String? keyword,
    bool? loaded,
    String? status,
  }) {
    return LibraryState(
      type: type ?? this.type,
      items: items ?? this.items,
      keyword: keyword ?? this.keyword,
      loaded: loaded ?? this.loaded,
      status: status ?? this.status,
    );
  }
}

class LibraryController extends Notifier<LibraryState> {
  static const Uuid _uuid = Uuid();
  late final AppDatabase _db = ref.read(databaseProvider);

  @override
  LibraryState build() => const LibraryState();

  Future<void> load({String? type}) async {
    final currentType = type ?? state.type;
    final resourceRows = await (_db.select(_db.resources)
          ..where((t) => t.type.equals(currentType))
          ..orderBy(<OrderClauseGenerator<$ResourcesTable>>[
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .get();
    final imageRows = await _db.select(_db.resourceImages).get();
    final imagesByResource = <String, List<String>>{};
    for (final ResourceImage img in imageRows) {
      imagesByResource
          .putIfAbsent(img.resourceId, () => <String>[])
          .add(img.filePath);
    }
    final items = resourceRows
        .map(
          (Resource row) => LibraryItem(
            id: row.id,
            type: row.type,
            name: row.name,
            fields: asMap(jsonDecode(row.fieldsJson)),
            cover: row.coverImage,
            images: imagesByResource[row.id] ?? const <String>[],
            updatedAt: row.updatedAt,
          ),
        )
        .toList();
    state = state.copyWith(
      type: currentType,
      items: items,
      loaded: true,
      status:
          '${libraryKinds.firstWhere((k) => k.type == currentType).label} · ${items.length} 条',
    );
  }

  void setKeyword(String keyword) => state = state.copyWith(keyword: keyword);

  Future<void> setType(String type) async {
    state =
        state.copyWith(type: type, items: const <LibraryItem>[], loaded: false);
    await load(type: type);
  }

  Future<void> save({
    String? id,
    required String name,
    required Map<String, Object?> fields,
    String? coverPath,
    List<String> images = const <String>[],
  }) async {
    final resourceId = id ?? _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.resources).insertOnConflictUpdate(
          ResourcesCompanion.insert(
            id: resourceId,
            type: state.type,
            name: name,
            fieldsJson: Value(jsonEncode(fields)),
            coverImage: Value(coverPath),
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (id != null) {
      await (_db.delete(_db.resourceImages)
            ..where((t) => t.resourceId.equals(resourceId)))
          .go();
    }
    for (var i = 0; i < images.length; i++) {
      await _db.into(_db.resourceImages).insert(
            ResourceImagesCompanion.insert(
              id: _uuid.v4(),
              resourceId: resourceId,
              filePath: images[i],
              sort: Value(i),
            ),
          );
    }
    await load();
  }

  /// 被引用检查（PRD 边界：删除弹引用清单二次确认）。
  Future<List<String>> referencesOf(String resourceId) async {
    final plans = await _db.select(_db.plans).get();
    final hits = <String>[];
    for (final Plan plan in plans) {
      if (plan.modulesJson.contains(resourceId)) {
        hits.add(plan.title);
      }
    }
    return hits;
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.resources)..where((t) => t.id.equals(id))).go();
    await load();
  }
}

/// M4 五大资源库 + 设备库入口。
class LibrariesPage extends ConsumerStatefulWidget {
  const LibrariesPage({super.key});

  @override
  ConsumerState<LibrariesPage> createState() => _LibrariesPageState();
}

class _LibrariesPageState extends ConsumerState<LibrariesPage> {
  int _view = 0; // 0 五大库 1 设备库 2 服装目录 3 道具预设

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      ref.read(libraryControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    return SsPage(
      title: '资源库',
      subtitle: '模特 / 场地 / 服装 / 道具 / 妆面 · 自定义上传与引用完整性',
      actions: <Widget>[
        for (final (int index, String label) in <(int, String)>[
          (0, '五大资源库'),
          (1, '设备数据库'),
          (2, '服装目录'),
          (3, '道具预设'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SsChip(
              label: label,
              selected: _view == index,
              onTap: () => setState(() => _view = index),
            ),
          ),
        const SizedBox(width: 8),
        SizedBox(
          width: 220,
          child: TextField(
            decoration:
                const InputDecoration(hintText: '搜索名称 / 地区…', isDense: true),
            onChanged: controller.setKeyword,
          ),
        ),
        const SizedBox(width: 8),
        SsButton(
          label: '新建条目',
          icon: Icons.add_rounded,
          dense: true,
          onPressed: () => _openEditor(),
        ),
      ],
      body: _view != 0
          ? switch (_view) {
              1 => const GearBrowser(),
              2 => ClothingCatalog(onFilterLibrary: (String keyword) {
                  ref
                      .read(libraryControllerProvider.notifier)
                      .setType('clothing');
                  ref
                      .read(libraryControllerProvider.notifier)
                      .setKeyword(keyword);
                  setState(() => _view = 0);
                }),
              _ => const PropsPresetBrowser(),
            }
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 150,
                  child: SsCard(
                    padding: const EdgeInsets.all(AppTokens.s8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final ({String type, String label}) kind
                            in libraryKinds)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SsCard(
                              selected: state.type == kind.type,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              onTap: () => controller.setType(kind.type),
                              child: Text(
                                kind.label,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: state.type == kind.type
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: state.type == kind.type
                                      ? AppTokens.accent
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          state.status,
                          style: TextStyle(
                            fontSize: 10.5,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: !state.loaded
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.4))
                      : state.filtered.isEmpty
                          ? SsEmpty(
                              icon: Icons.grid_view_outlined,
                              title: '还没有条目',
                              hint: '点击「新建条目」添加名称、字段与封面图',
                              action: SsButton(
                                  label: '新建条目',
                                  onPressed: () => _openEditor()),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.95,
                              ),
                              itemCount: state.filtered.length,
                              itemBuilder: (BuildContext context, int i) {
                                final LibraryItem item = state.filtered[i];
                                return SsCard(
                                  padding: EdgeInsets.zero,
                                  onTap: () => _openEditor(existing: item),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      Expanded(child: _cover(item)),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              item.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              item.summary,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _cover(LibraryItem item) {
    if (item.cover == null || item.cover!.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final workspace = ref.read(workspaceProvider);
    final file =
        File('${workspace.root.path}/images/${item.type}/${item.cover}');
    if (!file.existsSync()) {
      return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest);
    }
    return Image.file(file, fit: BoxFit.cover);
  }

  Future<void> _openEditor({LibraryItem? existing}) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => _ResourceEditorDialog(
        type: state.type,
        existing: existing,
      ),
    );
  }

  LibraryState get state => ref.read(libraryControllerProvider);
}

/// 资源条目编辑对话框（五库同构 + 图片上传 D23）。
class _ResourceEditorDialog extends ConsumerStatefulWidget {
  const _ResourceEditorDialog({required this.type, this.existing});

  final String type;
  final LibraryItem? existing;

  @override
  ConsumerState<_ResourceEditorDialog> createState() =>
      _ResourceEditorDialogState();
}

class _ResourceEditorDialogState extends ConsumerState<_ResourceEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _region;
  late final TextEditingController _price;
  late final TextEditingController _height;
  late final TextEditingController _style;
  late final TextEditingController _note;
  late final TextEditingController _tagCtl;
  late List<String> _tags;
  late List<String> _images;
  String? _cover;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final fields = widget.existing?.fields ?? <String, Object?>{};
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _contact = TextEditingController(text: fields['contact'] as String? ?? '');
    _region = TextEditingController(text: fields['region'] as String? ?? '');
    _price = TextEditingController(text: fields['price'] as String? ?? '');
    _height = TextEditingController(text: fields['height'] as String? ?? '');
    _style = TextEditingController(text: fields['style'] as String? ?? '');
    _note = TextEditingController(text: fields['note'] as String? ?? '');
    _tagCtl = TextEditingController();
    _tags = ((fields['tags'] as List?) ?? const <Object?>[])
        .cast<String>()
        .toList();
    _images = List<String>.of(widget.existing?.images ?? const <String>[]);
    _cover = widget.existing?.cover;
  }

  bool get _valid =>
      _name.text.trim().length >= 2 && _name.text.trim().length <= 30;

  Future<void> _pickImages({bool asCover = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: !asCover,
      dialogTitle: asCover ? '选择封面图' : '选择图集（可多选）',
    );
    if (result == null || result.files.isEmpty) return;
    final workspace = ref.read(workspaceProvider);
    final store = ImageStore(workspace.root.path);
    for (final PlatformFile file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final raw = await File(path).readAsBytes();
      final (String fileName, _) = await store.importBytes(
        raw,
        category: widget.type,
        title: _name.text.isEmpty ? file.name : _name.text,
      );
      if (asCover || _cover == null) {
        _cover = fileName;
      } else {
        _images.add(fileName);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isModel = widget.type == 'models';
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? '新建 · ${libraryKinds.firstWhere((k) => k.type == widget.type).label}'
            : '编辑 · ${widget.existing!.name}',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '名称（2–30 字，必填）'),
                maxLength: 30,
                onChanged: (_) => setState(() {}),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                      child: TextField(
                          controller: _contact,
                          decoration:
                              const InputDecoration(labelText: '联系方式'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: _region,
                          decoration: const InputDecoration(labelText: '地区'))),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                      child: TextField(
                          controller: _price,
                          decoration:
                              const InputDecoration(labelText: '合作报价 / 参考价'))),
                  const SizedBox(width: 8),
                  if (isModel)
                    Expanded(
                        child: TextField(
                            controller: _height,
                            decoration:
                                const InputDecoration(labelText: '身高三维'))),
                ],
              ),
              TextField(
                  controller: _style,
                  decoration: const InputDecoration(labelText: '风格 / 标签描述')),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _tagCtl,
                      decoration:
                          const InputDecoration(labelText: '标签（回车添加，≤10 个）'),
                      onSubmitted: (String v) {
                        if (v.trim().isNotEmpty && _tags.length < 10) {
                          setState(() => _tags.add(v.trim()));
                          _tagCtl.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SsButton(
                    label: '加标签',
                    kind: SsButtonKind.ghost,
                    dense: true,
                    onPressed: () {
                      if (_tagCtl.text.trim().isNotEmpty && _tags.length < 10) {
                        setState(() => _tags.add(_tagCtl.text.trim()));
                        _tagCtl.clear();
                      }
                    },
                  ),
                ],
              ),
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final String tag in _tags)
                        Chip(
                          label:
                              Text(tag, style: const TextStyle(fontSize: 11)),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  SsButton(
                    label: '上传封面',
                    icon: Icons.photo_camera_back_outlined,
                    kind: SsButtonKind.ghost,
                    dense: true,
                    onPressed: () => _pickImages(asCover: true),
                  ),
                  const SizedBox(width: 6),
                  SsButton(
                    label: '添加图集',
                    icon: Icons.collections_outlined,
                    kind: SsButtonKind.ghost,
                    dense: true,
                    onPressed: _pickImages,
                  ),
                  const SizedBox(width: 8),
                  if (_cover != null)
                    Text('封面：$_cover', style: const TextStyle(fontSize: 11)),
                ],
              ),
              if (_images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 4,
                    children: <Widget>[
                      for (final String img in _images)
                        Chip(
                          label: Text(
                            img.length > 18 ? '${img.substring(0, 18)}…' : img,
                            style: const TextStyle(fontSize: 10),
                          ),
                          onDeleted: () => setState(() => _images.remove(img)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '备注（≤2000 字）'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (widget.existing != null)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final hits = await ref
                        .read(libraryControllerProvider.notifier)
                        .referencesOf(widget.existing!.id);
                    if (!context.mounted) return;
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext ctx) => AlertDialog(
                        title: Text('删除「${widget.existing!.name}」？'),
                        content: Text(
                          hits.isEmpty
                              ? '删除后无法恢复。'
                              : '该条目正被以下策划案引用：\n${hits.map((h) => '· $h').join('\n')}\n删除后策划案内会出现空引用。',
                        ),
                        actions: <Widget>[
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('仍要删除'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(libraryControllerProvider.notifier)
                          .delete(widget.existing!.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
            child: const Text('删除', style: TextStyle(color: AppTokens.danger)),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: !_valid || _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await ref.read(libraryControllerProvider.notifier).save(
                        id: widget.existing?.id,
                        name: _name.text.trim(),
                        fields: <String, Object?>{
                          'contact': _contact.text.trim(),
                          'region': _region.text.trim(),
                          'price': _price.text.trim(),
                          'height': _height.text.trim(),
                          'style': _style.text.trim(),
                          'note': _note.text,
                          'tags': _tags,
                        },
                        coverPath: _cover,
                        images: _images,
                      );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
          child: Text(widget.existing == null ? '创建' : '保存'),
        ),
      ],
    );
  }
}
