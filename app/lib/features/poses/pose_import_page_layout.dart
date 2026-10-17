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
    // V8.9/R74：原为 showDialog + StatefulBuilder + AlertDialog。分类选中态是
    // 本弹层唯一的可变状态，故把它交给弹层体自己的 State（见文件末
    // `_NameCategoryBody`），而不是像原先那样由弹层外的 setState 灌进来；
    // 顺带把 TextEditingController 的释放从「await 之后手工 dispose」改为
    // 该 State 的 dispose()，弹层被销毁时必定释放。
    //
    // 返回值语义不变：遮罩关闭时 result 为 null → 调用方按「取消」处理。
    final (String?, String?)? result = await showDialog<(String?, String?)>(
      context: context,
      builder: (BuildContext ctx) => _NameCategoryBody(
        title: title,
        defaultName: defaultName,
        defaultCategory: defaultCategory,
      ),
    );
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

/// V8.9/R74：命名 + 分类弹层的弹层体。
///
/// 分类选中态（`_category`）是本弹层唯一的可变状态，因此本体必须是
/// StatefulWidget —— 这也是 V8.8 报告里判定「本处不能靠替换调用点直接迁移」
/// 的那个点：状态归属先定下来（归弹层体自己），迁移才有意义。
///
/// 宽度对齐沿用 sanctioned API 的公式：`maxWidth = 原 SizedBox.width + 48`
/// （`SsDialog` 两侧 padding 是 `AppSpace.block` = 24），原为 360 → 408。
class _NameCategoryBody extends StatefulWidget {
  const _NameCategoryBody({
    required this.title,
    required this.defaultName,
    required this.defaultCategory,
  });

  final String title;
  final String defaultName;
  final String defaultCategory;

  @override
  State<_NameCategoryBody> createState() => _NameCategoryBodyState();
}

class _NameCategoryBodyState extends State<_NameCategoryBody> {
  late final TextEditingController _name = TextEditingController(
    text: widget.defaultName,
  );
  late String _category = widget.defaultCategory;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // showDialog 默认 useRootNavigator: true，而本 State 的 context 就在该
    // 弹层路由内部，所以 Navigator.of(context) 直接指向弹层自身 ——
    // 不需要像 V8.8 的 template picker 那样再套一层 Builder。
    return SsDialog(
      title: widget.title,
      maxWidth: 408,
      actions: <Widget>[
        // 与 V8.7/V8.8 的迁移保持一致：取消是次要按钮（TextButton），
        // 保存是主按钮（FilledButton）；「取消」显式 pop() 而不依赖
        // SsDialogAction 的 onPressed 空值兜底（该兜底只 pop 不返回值，
        // 这里返回值必须是 null 才能表达「取消」，两者语义相同但显式更清楚）。
        SsDialogAction(
          label: '取消',
          primary: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SsDialogAction(
          label: '保存',
          onPressed: () => Navigator.of(context).pop((_name.text, _category)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SsTextInput(controller: _name, label: '姿势名称', dense: true),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final String c in poseCategories)
                if (c != '全部')
                  SsChip(
                    label: c,
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  ),
            ],
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
