/// 资源条目编辑对话框（五库同构 + 图片上传 D23）。
///
/// 从 libraries_page.dart 拆出以满足 R73 单文件 600 行红线。
/// 类名去掉下划线前缀：跨文件后不再是库私有成员。
library;

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../services/image_store.dart';
import 'libraries_page.dart';

/// 资源条目编辑对话框（五库同构 + 图片上传 D23）。
class ResourceEditorDialog extends ConsumerStatefulWidget {
  const ResourceEditorDialog({super.key, required this.type, this.existing});

  final String type;
  final LibraryItem? existing;

  @override
  ConsumerState<ResourceEditorDialog> createState() =>
      ResourceEditorDialogState();
}

class ResourceEditorDialogState extends ConsumerState<ResourceEditorDialog> {
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
    final AppPalette p = context.palette;

    final isModel = widget.type == 'models';
    // R74 收口：弹层外观改走 sanctioned `SsDialog`（衬线标题 / hairline 分隔 /
    // 统一内边距与阴影）。原 `content: SizedBox(width: 520) + 内层
    // SingleChildScrollView` 由 SsDialog 自带的 `Flexible(SingleChildScrollView)`
    // 承担 —— 保留内层滚动会变成嵌套滚动，故删掉。
    // 宽度公式：maxWidth = 原 SizedBox.width + 48（SsDialog 左右 padding 各 24）。
    return SsDialog(
      title: widget.existing == null
          ? '新建 · ${libraryKinds.firstWhere((k) => k.type == widget.type).label}'
          : '编辑 · ${widget.existing!.name}',
      maxWidth: 568,
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
                    final bool ok = await showSsConfirm(
                      context,
                      title: '删除「${widget.existing!.name}」？',
                      message: hits.isEmpty
                          ? '删除后无法恢复。'
                          : '该条目正被以下策划案引用：\n${hits.map((h) => '· $h').join('\n')}\n删除后策划案内会出现空引用。',
                      confirmLabel: '仍要删除',
                    );
                    if (ok) {
                      await ref
                          .read(libraryControllerProvider.notifier)
                          .delete(widget.existing!.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
            child: Text('删除', style: TextStyle(color: p.danger)),
          ),
        SsDialogAction(
          label: '取消',
          primary: false,
          onPressed: () => Navigator.pop(context),
        ),
        FilledButton(
          onPressed: !_valid || _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await ref
                      .read(libraryControllerProvider.notifier)
                      .save(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SsTextInput(
            label: '名称（2–30 字，必填）',
            controller: _name,
            maxLength: 30,
            onChanged: (_) => setState(() {}),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: SsTextInput(label: '联系方式', controller: _contact),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SsTextInput(label: '地区', controller: _region),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: SsTextInput(label: '合作报价 / 参考价', controller: _price),
              ),
              const SizedBox(width: 8),
              if (isModel)
                Expanded(
                  child: SsTextInput(label: '身高三维', controller: _height),
                ),
            ],
          ),
          SsTextInput(label: '风格 / 标签描述', controller: _style),
          Row(
            children: <Widget>[
              Expanded(
                child: SsTextInput(
                  label: '标签（回车添加，≤10 个）',
                  controller: _tagCtl,
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
                kind: SsButtonKind.text,
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
              padding: const EdgeInsets.symmetric(vertical: AppSpaceFine.n6),
              child: Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final String tag in _tags)
                    Chip(
                      label: Text(
                        tag,
                        style: const TextStyle(fontSize: AppFontSize.caption),
                      ),
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
                kind: SsButtonKind.text,
                dense: true,
                onPressed: () => _pickImages(asCover: true),
              ),
              const SizedBox(width: 6),
              SsButton(
                label: '添加图集',
                icon: Icons.collections_outlined,
                kind: SsButtonKind.text,
                dense: true,
                onPressed: _pickImages,
              ),
              const SizedBox(width: 8),
              if (_cover != null)
                Text(
                  '封面：$_cover',
                  style: const TextStyle(fontSize: AppFontSize.caption),
                ),
            ],
          ),
          if (_images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpaceFine.n6),
              child: Wrap(
                spacing: 4,
                children: <Widget>[
                  for (final String img in _images)
                    Chip(
                      label: Text(
                        img.length > 18 ? '${img.substring(0, 18)}…' : img,
                        style: const TextStyle(fontSize: AppFontSize.tiny),
                      ),
                      onDeleted: () => setState(() => _images.remove(img)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          SsTextInput(label: '备注（≤2000 字）', controller: _note, maxLines: 3),
        ],
      ),
    );
  }
}
