import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../services/content_packs.dart';
import '../../services/image_store.dart';
import '../../services/pose/pose_detector_service.dart';
import '../../services/pose/pose_grounding.dart';
import '../../services/pose/pose_joint_mapper.dart';
import '../lighting/lighting_controller.dart';
import '../planner/planner_pending.dart';
import '../shell/app_shell.dart';
import 'pose_landmark_math.dart';
import 'pose_skeleton.dart';
import 'poses_controller.dart';

/// D 阶段：导入照片 → 端上识别 → 骨架/12 关节预览 → 手动确认后导入
/// （D124：只输出骨架+关节数据；D125：多人点选 + 低置信标注；
///  D126：可保存自定义或覆盖内置参考图，覆盖可一键恢复）。
class PoseImportPage extends ConsumerStatefulWidget {
  const PoseImportPage({super.key, this.overridePose});

  /// 非空时进入「覆盖内置参考图」模式。
  final PoseEntry? overridePose;

  @override
  ConsumerState<PoseImportPage> createState() => _PoseImportPageState();
}

class _PoseImportPageState extends ConsumerState<PoseImportPage> {
  PoseDetectorService? _service;
  bool _serviceReady = false;
  bool _busy = false;
  String _status = '选择一张照片开始识别（照片与结果仅存本地）';

  Uint8List? _bytes;
  Size _imageSize = Size.zero;
  List<DetectedPerson> _persons = <DetectedPerson>[];
  int _selected = 0;
  MappedPose? _mapped;
  GroundedPose? _grounded;

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  Future<void> _ensureService() async {
    if (_serviceReady) return;
    final PoseDetectorService service = PoseDetectorService();
    await service.initialize();
    _service = service;
    _serviceReady = true;
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: '选择要识别姿势的照片',
    );
    final String? path = result?.files.single.path;
    if (path == null || !mounted) return;
    final Uint8List bytes = await File(path).readAsBytes();
    await _runDetect(bytes);
  }

  Future<void> _runDetect(Uint8List bytes) async {
    setState(() {
      _busy = true;
      _status = '正在初始化端上模型（首次较慢）…';
      _bytes = bytes;
      _persons = <DetectedPerson>[];
      _mapped = null;
      _grounded = null;
    });
    try {
      await _ensureService();
      if (!mounted) return;
      setState(() => _status = '正在识别人物与 33 点骨架…');
      final ui.Image image = await _decodeImage(bytes);
      final List<DetectedPerson> persons = await _service!.detect(bytes);
      if (!mounted) return;
      if (persons.isEmpty) {
        setState(() {
          _busy = false;
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
          _status = '未检测到人物：请换一张全身、光线充足、人物完整的照片';
        });
        image.dispose();
        return;
      }
      // 默认选人体框最大者。
      persons.sort(
        (DetectedPerson a, DetectedPerson b) => (b.bbox.width * b.bbox.height)
            .compareTo(a.bbox.width * a.bbox.height),
      );
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        _persons = persons;
        _selected = 0;
        _busy = false;
      });
      image.dispose();
      _computeResult();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '识别失败：$e';
      });
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  void _computeResult() {
    if (_persons.isEmpty) return;
    final DetectedPerson person = _persons[_selected];
    if (person.world.length < 33) {
      setState(() {
        _mapped = null;
        _grounded = null;
        _status = '该人物未得到 3D 世界坐标：可换一张照片或改选他人';
      });
      return;
    }
    final MappedPose mapped = PoseJointMapper.map(
      person.world,
      jointConfidence: person.jointConfidence,
      category: '',
    );
    final GroundedPose grounded = PoseGrounding.ground(
      derived: person.derived,
      landmarkVisibility: <double>[
        for (final l in person.landmarks2d) l.visibility,
      ],
    );
    setState(() {
      _mapped = mapped;
      _grounded = grounded;
      _status =
          '识别完成：${_persons.length} 人 · 检测分 ${(person.score * 100).toStringAsFixed(0)}%'
          '${mapped.lowConfidence ? ' · 存在低置信关节（仅供参考）' : ''}';
    });
  }

  void _selectPerson(int index) {
    if (index == _selected || index < 0 || index >= _persons.length) return;
    setState(() => _selected = index);
    _computeResult();
  }

  /// 保存导入照片 + 骨架 JSON 到工作区 `images/poses/`（D127）。
  Future<(String, String)> _persistAssets(String title) async {
    final String workspace = ref.read(workspaceProvider).root.path;
    final ImageStore store = ImageStore(workspace);
    final (String fileName, _) = await store.importBytes(
      _bytes!,
      category: 'poses',
      title: title,
    );
    final DetectedPerson person = _persons[_selected];
    final String skeletonName =
        '${p.basenameWithoutExtension(fileName)}.skeleton.json';
    final Directory dir = Directory(p.join(workspace, 'images', 'poses'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, skeletonName)).writeAsString(
      jsonEncode(<String, Object?>{
        'landmarks2d': <List<double>>[
          for (final l in person.landmarks2d)
            <double>[
              l.x / _imageSize.width,
              l.y / _imageSize.height,
              l.z,
              l.visibility,
            ],
        ],
        'imageSize': <double>[_imageSize.width, _imageSize.height],
        'confidence': person.score,
        'model': 'pose_detection-3.7 BlazePose(full) · 端上识别',
        'source': '用户导入',
      }),
    );
    return (fileName, skeletonName);
  }

  Future<void> _saveCustom() async {
    final MappedPose? mapped = _mapped;
    if (mapped == null) return;
    final (String? name, String? category) = await _askNameCategory(
      title: '保存为自定义姿势',
      defaultName: '导入姿势 ${DateTime.now().toString().substring(5, 16)}',
      defaultCategory: '站姿',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final (String photoFile, String skeletonFile) = await _persistAssets(
        name.trim(),
      );
      await ref
          .read(posesControllerProvider.notifier)
          .saveCustomPose(
            name: name.trim(),
            joints: mapped.toPoseJson(),
            category: category ?? '站姿',
            difficulty: '进阶',
            lens: '',
            photoFile: photoFile,
            skeletonFile: skeletonFile,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '已保存自定义姿势「${name.trim()}」（图片与骨架存工作区）';
      });
      ssToast(context, '已保存到姿势库');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '保存失败：$e';
      });
    }
  }

  Future<void> _saveOverride() async {
    final PoseEntry? target = widget.overridePose;
    final MappedPose? mapped = _mapped;
    if (target == null || mapped == null) return;
    setState(() => _busy = true);
    try {
      final (String photoFile, String skeletonFile) = await _persistAssets(
        target.name,
      );
      await ref
          .read(posesControllerProvider.notifier)
          .saveOverride(
            target: target,
            joints: mapped.toPoseJson(),
            photoFile: photoFile,
            skeletonFile: skeletonFile,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '已覆盖「${target.name}」的参考图数据（可一键恢复默认）';
      });
      ssToast(context, '已覆盖内置姿势（可恢复默认）');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '覆盖失败：$e';
      });
    }
  }

  void _injectLighting() {
    final MappedPose? mapped = _mapped;
    if (mapped == null) return;
    final String name = widget.overridePose?.name ?? '导入姿势';
    ref
        .read(lightingControllerProvider.notifier)
        .injectPose(mapped.toPoseJson(), name);
    ref.read(shellTabProvider.notifier).state = 2;
    Navigator.pop(context);
    ssToast(context, '已导入布光预演，可在右栏微调关节');
  }

  Future<void> _addToPending() async {
    final MappedPose? mapped = _mapped;
    if (mapped == null) return;
    String photo = '';
    try {
      final (String file, _) = await _persistAssets('导入姿势');
      photo = file;
    } catch (_) {
      // 图片保存失败不阻塞加入清单。
    }
    if (!mounted) return;
    ref
        .read(pendingPosesProvider.notifier)
        .add(
          PendingPose(
            name: widget.overridePose?.name ?? '导入姿势（端上识别）',
            joints: mapped.toPoseJson(),
            lens: '',
            cameraPosition: '',
            photo: photo,
            author: '用户导入',
            license: '用户自有素材',
            source: '',
          ),
        );
    ssToast(context, '已加入策划案姿势待插入清单');
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
          title: Text(title, style: const TextStyle(fontSize: 16)),
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.overridePose == null
              ? '导入照片识别'
              : '替换参考图：${widget.overridePose!.name}',
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.s16,
              AppTokens.s12,
              AppTokens.s16,
              AppTokens.s8,
            ),
            child: Row(
              children: <Widget>[
                SsButton(
                  label: _bytes == null ? '选择照片' : '重新选择照片',
                  icon: Icons.add_photo_alternate_outlined,
                  dense: true,
                  onPressed: _busy ? null : _pickImage,
                ),
                const SizedBox(width: 8),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _bytes == null
                ? const SsEmpty(
                    icon: Icons.add_a_photo_outlined,
                    title: '还没有照片',
                    hint:
                        '选择一张单人全身照（光线充足、人物完整）；'
                        '识别只输出骨架与 12 关节数据，需你确认后才写入姿势库/布光预演',
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.s12),
                          child: _PersonPreview(
                            bytes: _bytes!,
                            imageSize: _imageSize,
                            persons: _persons,
                            selected: _selected,
                            showSkeleton: true,
                            onSelect: _selectPerson,
                          ),
                        ),
                      ),
                      SizedBox(width: 340, child: _buildResultPanel(theme)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel(ThemeData theme) {
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
        padding: const EdgeInsets.all(AppTokens.s12),
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
                  color: AppTokens.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                  border: Border.all(
                    color: AppTokens.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  warning,
                  style: const TextStyle(fontSize: 11, height: 1.5),
                ),
              ),
          ],
          if (_grounded?.note.isNotEmpty == true)
            Text(
              _grounded!.note,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          for (final String joint in engineJoints)
            _jointRow(joint, mapped, person),
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
            kind: SsButtonKind.soft,
            onPressed: _busy ? null : _addToPending,
          ),
          const SizedBox(height: 6),
          if (widget.overridePose != null)
            SsButton(
              label: '覆盖「${widget.overridePose!.name}」参考图数据',
              icon: Icons.swap_horiz_rounded,
              kind: SsButtonKind.ghost,
              onPressed: _busy ? null : _saveOverride,
            )
          else
            SsButton(
              label: '保存为自定义姿势',
              icon: Icons.bookmark_add_outlined,
              kind: SsButtonKind.ghost,
              onPressed: _busy ? null : _saveCustom,
            ),
          const SizedBox(height: 8),
          Text(
            '照片仅保存在工作区 images/poses/，随工作区备份/迁移；'
            '识别数据不联网、不上传。',
            style: TextStyle(
              fontSize: 10.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jointRow(String joint, MappedPose mapped, DetectedPerson person) {
    final List<double> angles = mapped.joints[joint] ?? <double>[0, 0, 0];
    final double confidence = mapped.jointConfidence[joint] ?? 1;
    final bool low = confidence < PoseJointMapper.confidenceThreshold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(joint, style: const TextStyle(fontSize: 11.5)),
          ),
          Expanded(
            child: Text(
              angles.map((double v) => v.toStringAsFixed(1)).join(' / '),
              style: AppTokens.mono(context, size: 11.5),
            ),
          ),
          Icon(
            low ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 13,
            color: low
                ? AppTokens.warning
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '${(confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              color: low
                  ? AppTokens.warning
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 照片 + 骨架叠加 + 多人框选。
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
                  imageSize: imageSize,
                  boxes: <Rect>[for (final DetectedPerson p in persons) p.bbox],
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
    required this.imageSize,
    required this.boxes,
    required this.selected,
  });

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
              ? AppTokens.accent
              : Colors.white.withValues(alpha: 0.7),
      );
      if (boxes.length > 1) {
        final TextPainter label = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              color: active ? AppTokens.accent : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
