import '../../core/design/feature_colors.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as path;

import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../services/content_packs.dart';
import '../../services/image_store.dart';
import '../../services/pose/pose_detector_service.dart';
import '../../services/pose/pose_grounding.dart';
import '../../services/pose/pose_recognition_service.dart';
import '../../services/pose/pose_joint_mapper.dart';
import '../lighting/lighting_controller.dart';
import '../planner/planner_pending.dart';
import '../shell/app_shell.dart';
import 'pose_joint_tuner.dart';
import 'pose_landmark_math.dart';
import 'pose_skeleton.dart';
import 'poses_controller.dart';

part 'pose_import_page_layout.dart';

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
  PoseRecognitionService? _service;
  bool _serviceReady = false;
  bool _busy = false;
  String _status = '选择一张照片开始识别（照片与结果仅存本地）';

  Uint8List? _bytes;
  Size _imageSize = Size.zero;
  List<DetectedPerson> _persons = <DetectedPerson>[];
  int _selected = 0;
  MappedPose? _mapped;
  GroundedPose? _grounded;

  // D153：关节点拖拽校正（可编辑骨架副本 + 复位基准 + 校正后世界坐标）。
  List<PosePoint?> _points = <PosePoint?>[];
  List<PosePoint?> _pointsBackup = <PosePoint?>[];
  List<List<double>>? _tunedWorld;
  bool _tuned = false;

  /// extension 里不能直接调 protected setState，统一走这层薄封装。
  void refresh(void Function() fn) => setState(fn);

  /// 把选中人物的 2D 关键点按图片尺寸归一化（校正页编辑副本 + 复位基准）。
  void _syncPoints(DetectedPerson person) {
    List<PosePoint?> toPoints() => <PosePoint?>[
      for (final l in person.landmarks2d)
        PosePoint(
          _imageSize.width == 0 ? 0 : l.x / _imageSize.width,
          _imageSize.height == 0 ? 0 : l.y / _imageSize.height,
          l.visibility,
        ),
    ];
    _points = toPoints();
    _pointsBackup = toPoints();
    _tunedWorld = null;
    _tuned = false;
  }

  /// 拖动关键点 → `applyPosePointEdits` 折算世界坐标 → 重算 12 关节（D153：实时更新）。
  void _onPointMoved(int index, double x, double y) {
    if (index < 0 || index >= _points.length || _persons.isEmpty) return;
    final List<PosePoint?> next = <PosePoint?>[
      for (int i = 0; i < _points.length; i++)
        i == index ? PosePoint(x, y, _points[i]?.visibility ?? 1) : _points[i],
    ];
    _applyPoints(next);
  }

  /// 复位单个关节链（只回滚该关节涉及的 parent/child 两个点）。
  void _resetJointChain(String joint) {
    final (int, int)? chain = poseTunableJoints[joint];
    if (chain == null) {
      _resetTuned();
      return;
    }
    _applyPoints(<PosePoint?>[
      for (int i = 0; i < _points.length; i++)
        (i == chain.$1 || i == chain.$2) && i < _pointsBackup.length
            ? _pointsBackup[i]
            : _points[i],
    ]);
  }

  /// 复位全部（回到识别结果）。
  void _resetTuned() => _applyPoints(<PosePoint?>[
    for (int i = 0; i < _pointsBackup.length; i++) _pointsBackup[i],
  ]);

  void _applyPoints(List<PosePoint?> next) {
    if (_persons.isEmpty) return;
    final DetectedPerson person = _persons[_selected];
    final List<List<double>> world = applyPosePointEdits(
      world: person.world,
      pointsBefore: _pointsBackup,
      pointsAfter: next,
      imageSize: _imageSize,
    );
    setState(() {
      _points = next;
      _tunedWorld = world;
      _tuned = true;
      _mapped = PoseJointMapper.map(
        world,
        jointConfidence: person.jointConfidence,
        category: '',
      );
    });
  }

  /// 推导 12 关节用的世界坐标（校正优先于识别原始值）。
  List<List<double>> _worldOf(DetectedPerson person) =>
      _tunedWorld ?? person.world;

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  Future<void> _ensureService() async {
    if (_serviceReady) return;
    // V7/D141：RTMPose/RTMW3D 优先，模型缺失/加载失败自动回退 MediaPipe（R69）。
    final PoseRecognitionService service = PoseRecognitionService();
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
      _worldOf(person),
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
      _syncPoints(person);
      _status =
          '识别完成：${_persons.length} 人 · 检测分 ${(person.score * 100).toStringAsFixed(0)}%'
          ' · ${_service?.backendLabel ?? '端上识别'}'
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
        '${path.basenameWithoutExtension(fileName)}.skeleton.json';
    final Directory dir = Directory(path.join(workspace, 'images', 'poses'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, skeletonName)).writeAsString(
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
        'model': _service?.backend == PoseRecognitionBackend.rtmpose
            ? 'RTMPose/RTMW3D-x(fp16)+YOLOX-tiny · 端上识别（ONNX CPU）'
            : 'pose_detection-3.7 BlazePose(full) · 端上识别（MediaPipe 回退）',
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
      body: _wrapDrop(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s3,
                AppSpace.s4,
                AppSpace.s2,
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
                  // V8/D153：粘贴截图（Win+Shift+S → Ctrl+V），与拖入、选文件并列。
                  SsButton(
                    label: '粘贴截图',
                    icon: Icons.content_paste_go_outlined,
                    kind: SsButtonKind.text,
                    dense: true,
                    onPressed: _busy ? null : _pasteImage,
                  ),
                  const SizedBox(width: 8),
                  // V8/D153：识别后端标签（点击看回退/降级说明，R69）。
                  SsChip(
                    label: _service?.backendLabel ?? '端上识别',
                    selected: _serviceReady,
                    onTap: () => ssToast(
                      context,
                      _service?.backendNote.isNotEmpty ?? false
                          ? _service!.backendNote
                          : '识别后端：${_service?.backendLabel ?? '端上识别'}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_busy)
                    // V8/D153：骨架屏（呼吸微光）替代裸进度圈。
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SsSkeleton(width: 64, height: 12),
                        SizedBox(width: 6),
                        SsSkeleton(width: 40, height: 12),
                      ],
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontSize: AppFontSize.captionLg,
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
                            padding: const EdgeInsets.all(AppSpace.s3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // D125：多人时给人物切换（点框选已由校正器接管）。
                                if (_persons.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: <Widget>[
                                        for (
                                          int i = 0;
                                          i < _persons.length;
                                          i++
                                        )
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: SsChip(
                                              label: '人物 ${i + 1}',
                                              selected: _selected == i,
                                              onTap: () => _selectPerson(i),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                // D153：关节点拖拽校正（命中半径 ≥12px，拖拽时显示角度读数）。
                                Expanded(
                                  child: PoseJointTuner(
                                    image: Image.memory(
                                      _bytes!,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                    ),
                                    points: _points,
                                    imageSize: _imageSize,
                                    onPointMoved: _onPointMoved,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 340,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (_persons.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    8,
                                    0,
                                  ),
                                  child: PoseTunerResetBar(
                                    joints: poseTunableJoints.keys.toList(),
                                    canReset: _tuned,
                                    onResetJoint: _resetJointChain,
                                    onResetAll: _resetTuned,
                                  ),
                                ),
                              Expanded(
                                child: _buildResultPanel(context, theme),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 照片 + 骨架叠加 + 多人框选。
