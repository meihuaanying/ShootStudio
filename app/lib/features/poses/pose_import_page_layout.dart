// V8/S7 · D153：识别导入页的版面代码（结果面板 / 12 关节读数 / 命名分类对话框）与
// 人物预览组件。以 part + extension 形式与 PoseImportPage 同一库：保留对 State 私有成员
// 的直接访问（`_PersonBoxPainter` 也直接用 `_PersonPreview._displayRect`），
// 只是把 368 行从 pose_import_page.dart 移出（R73 行数门禁），行为零变化。
part of 'pose_import_page.dart';

extension _PoseImportPageLayout on _PoseImportPageState {
  /// V8/D153：粘贴截图（Win+Shift+S 截图 → Ctrl+V）与拖入文件共用同一条识别链路。
  Future<void> _pasteImage() async {
    final Uint8List? bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) ssToast(context, '剪贴板没有图片（可先 Win+Shift+S 截图再点此）');
      return;
    }
    await _runDetect(bytes);
  }

  /// V8/D153：拖入图片文件（只接收图片扩展名，单文件失败继续试下一个）。
  Future<void> _importDroppedFiles(List<String> filePaths) async {
    final RegExp imageExt = RegExp(
      r'\.(jpe?g|png|webp|bmp)$',
      caseSensitive: false,
    );
    for (final String filePath in filePaths) {
      if (!imageExt.hasMatch(filePath)) continue;
      try {
        final Uint8List bytes = await File(filePath).readAsBytes();
        await _runDetect(bytes);
        return;
      } catch (_) {
        // 单文件失败继续试下一个。
      }
    }
    if (mounted) ssToast(context, '没有可识别的图片文件（jpg/png/webp/bmp）');
  }

  /// V8/D153：整页接收拖入的图片文件（拖入 = 与选文件/粘贴同一条识别链路）。
  Widget _wrapDrop(Widget child) {
    return DropTarget(
      onDragDone: (DropDoneDetails details) => _importDroppedFiles(<String>[
        for (final DropItem f in details.files) f.path,
      ]),
      child: child,
    );
  }

  Future<(String?, String?)> _askNameCategory({
    required String title,
    required String defaultName,
    required String defaultCategory,
  }) async {
    final TextEditingController name = TextEditingController(text: defaultName);
    String category = defaultCategory;
    final (String?, String?)? result = await showDialog<(String?, String?)>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setStateDialog) => AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontSize: AppFontSize.bodyXl),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: '姿势名称',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final String c in poseCategories)
                      if (c != '全部')
                        SsChip(
                          label: c,
                          selected: category == c,
                          onTap: () => setStateDialog(() => category = c),
                        ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            SsButton(
              label: '保存',
              dense: true,
              onPressed: () => Navigator.pop(ctx, (name.text, category)),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    return result ?? (null, null);
  }

  Widget _buildResultPanel(BuildContext context, ThemeData theme) {
    final AppPalette p = context.palette;
    final MappedPose? mapped = _mapped;
    if (mapped == null) {
      return SsCard(
        child: SsEmpty(
          icon: Icons.accessibility_new_outlined,
          title: _busy ? '识别中…' : '等待识别结果',
          hint:
              '识别完成后这里显示 12 关节角与置信度；'
              '低置信关节会标注「仅供参考」，可进布光预演手动微调',
        ),
      );
    }
    final DetectedPerson person = _persons[_selected];
    return SsCard(
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.s3),
        children: <Widget>[
          SsSectionTitle(
            widget.overridePose?.name ?? '识别结果',
            subtitle:
                '检测分 ${(person.score * 100).toStringAsFixed(0)}% · '
                '${_persons.length > 1 ? '多人：点左侧图片选择目标' : '单人'}',
          ),
          if (mapped.lowConfidence) ...<Widget>[
            const SizedBox(height: 6),
            for (final String warning in mapped.warnings)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: p.gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  warning,
                  style: const TextStyle(
                    fontSize: AppFontSize.caption,
                    height: 1.5,
                  ),
                ),
              ),
          ],
          if (_grounded?.note.isNotEmpty == true)
            Text(
              _grounded!.note,
              style: TextStyle(
                fontSize: AppFontSize.caption,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          for (final String joint in engineJoints)
            _jointRow(context, joint, mapped, person),
          const Divider(height: 18),
          SsButton(
            label: '导入到布光预演',
            icon: Icons.wb_incandescent_outlined,
            onPressed: _busy ? null : _injectLighting,
          ),
          const SizedBox(height: 6),
          SsButton(
            label: '加入策划案姿势清单',
            icon: Icons.playlist_add_rounded,
            kind: SsButtonKind.outline,
            onPressed: _busy ? null : _addToPending,
          ),
          const SizedBox(height: 6),
          if (widget.overridePose != null)
            SsButton(
              label: '覆盖「${widget.overridePose!.name}」参考图数据',
              icon: Icons.swap_horiz_rounded,
              kind: SsButtonKind.text,
              onPressed: _busy ? null : _saveOverride,
            )
          else
            SsButton(
              label: '保存为自定义姿势',
              icon: Icons.bookmark_add_outlined,
              kind: SsButtonKind.text,
              onPressed: _busy ? null : _saveCustom,
            ),
          const SizedBox(height: 8),
          Text(
            '照片仅保存在工作区 images/poses/，随工作区备份/迁移；'
            '识别数据不联网、不上传。',
            style: TextStyle(
              fontSize: AppFontSize.tinyLg,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jointRow(
    BuildContext context,
    String joint,
    MappedPose mapped,
    DetectedPerson person,
  ) {
    final AppPalette p = context.palette;
    final List<double> angles = mapped.joints[joint] ?? <double>[0, 0, 0];
    final double confidence = mapped.jointConfidence[joint] ?? 1;
    final bool low = confidence < PoseJointMapper.confidenceThreshold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              joint,
              style: const TextStyle(fontSize: AppFontSize.captionLg),
            ),
          ),
          Expanded(
            child: Text(
              angles.map((double v) => v.toStringAsFixed(1)).join(' / '),
              style: appMono(p.inkSoft),
            ),
          ),
          Icon(
            low ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 13,
            color: low
                ? p.gold
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '${(confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: AppFontSize.tiny,
              color: low
                  ? p.gold
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonPreview extends StatelessWidget {
  const _PersonPreview({
    required this.bytes,
    required this.imageSize,
    required this.persons,
    required this.selected,
    required this.showSkeleton,
    required this.onSelect,
  });

  final Uint8List bytes;
  final Size imageSize;
  final List<DetectedPerson> persons;
  final int selected;
  final bool showSkeleton;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final DetectedPerson? person = (selected >= 0 && selected < persons.length)
        ? persons[selected]
        : null;
    final PoseSkeletonData? skeleton = person == null
        ? null
        : PoseSkeletonData(
            points: <PosePoint?>[
              for (final l in person.landmarks2d)
                PosePoint(
                  imageSize.width == 0 ? 0 : l.x / imageSize.width,
                  imageSize.height == 0 ? 0 : l.y / imageSize.height,
                  l.visibility,
                ),
            ],
            imageSize: imageSize,
            confidence: person.score,
          );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size widgetSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final Rect rect = _displayRect(widgetSize, imageSize);
        return GestureDetector(
          onTapUp: (TapUpDetails details) {
            if (persons.length < 2) return;
            final Offset local = details.localPosition - rect.topLeft;
            final double scale = rect.width / imageSize.width;
            if (scale <= 0) return;
            final Offset imagePoint = local / scale;
            var picked = -1;
            for (var i = 0; i < persons.length; i++) {
              if (persons[i].bbox.contains(imagePoint)) {
                picked = i;
                break;
              }
            }
            if (picked >= 0) onSelect(picked);
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
              if (showSkeleton && skeleton != null)
                CustomPaint(
                  painter: PoseSkeletonPainter(
                    data: skeleton,
                    fit: BoxFit.contain,
                  ),
                  child: const SizedBox.expand(),
                ),
              CustomPaint(
                painter: _PersonBoxPainter(
                  palette: context.palette,
                  imageSize: imageSize,
                  boxes: <Rect>[
                    for (final DetectedPerson person in persons) person.bbox,
                  ],
                  selected: selected,
                ),
                child: const SizedBox.expand(),
              ),
            ],
          ),
        );
      },
    );
  }

  static Rect _displayRect(Size widget, Size image) {
    if (image.isEmpty || widget.isEmpty) return Offset.zero & widget;
    final double scale =
        (widget.width / image.width) < (widget.height / image.height)
        ? widget.width / image.width
        : widget.height / image.height;
    final Size dest = Size(image.width * scale, image.height * scale);
    return Alignment.center.inscribe(dest, Offset.zero & widget);
  }
}

class _PersonBoxPainter extends CustomPainter {
  _PersonBoxPainter({
    required this.palette,
    required this.imageSize,
    required this.boxes,
    required this.selected,
  });

  final AppPalette palette;
  final Size imageSize;
  final List<Rect> boxes;
  final int selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (boxes.isEmpty || imageSize.isEmpty || size.isEmpty) return;
    final Rect rect = _PersonPreview._displayRect(size, imageSize);
    final double scale = rect.width / imageSize.width;
    for (var i = 0; i < boxes.length; i++) {
      final Rect b = boxes[i];
      final Rect target = Rect.fromLTRB(
        rect.left + b.left * scale,
        rect.top + b.top * scale,
        rect.left + b.right * scale,
        rect.top + b.bottom * scale,
      );
      final bool active = i == selected;
      canvas.drawRect(
        target,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2.4 : 1.4
          ..color = active
              ? palette.accent
              : Colors.white.withValues(alpha: 0.7),
      );
      if (boxes.length > 1) {
        final TextPainter label = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              color: active ? palette.accent : AppFeatureColor.onFill,
              fontSize: AppFontSize.smallSm,
              fontWeight: AppFontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, target.topLeft + const Offset(4, 4));
      }
    }
  }

  @override
  bool shouldRepaint(_PersonBoxPainter old) =>
      old.selected != selected ||
      old.imageSize != imageSize ||
      old.boxes.length != boxes.length;
}
