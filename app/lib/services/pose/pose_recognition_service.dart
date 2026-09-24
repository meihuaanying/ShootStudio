/// V7/D141：识别门面 —— RTMPose/RTMW3D（ONNX，CPU EP）优先，MediaPipe 回退（R69）。
///
/// - 首选：`assets/models/pose3d/`（fp16 分片 + yolox_tiny）→ `Pose3dEngine`；
/// - 回退：模型缺失/拼装失败/加载失败 → 现有 `PoseDetectorService`（MediaPipe），
///   `backendNote` 记录回退原因（供 UI 与日志）。
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pose_detection/pose_detection.dart';
import 'package:shoot_studio/services/pose3d/pose3d_assembly.dart';
import 'package:shoot_studio/services/pose3d/pose3d_engine.dart';
import 'package:shoot_studio/services/pose3d/pose3d_mapping.dart';

import 'pose_detector_service.dart';

/// 识别后端。
enum PoseRecognitionBackend { rtmpose, mediapipe }

/// 识别门面（RTMPose 优先 + MediaPipe 回退）。
class PoseRecognitionService {
  PoseRecognitionService({
    Pose3dAssetReader? assetReader,
    Future<Directory> Function()? cacheDir,
    Future<Pose3dDetector> Function()? engineFactory,
    PoseDetectorService Function()? fallbackFactory,
  }) : _readAsset = assetReader ?? _rootBundleReader,
       _cacheDir = cacheDir ?? _supportDirectory,
       _engineFactory = engineFactory,
       _fallbackFactory = fallbackFactory ?? PoseDetectorService.new;

  /// 模型资产（随包，R64）。
  static const String modelDir = 'assets/models/pose3d';
  static const String detModelAsset = '$modelDir/yolox_tiny.onnx';

  final Pose3dAssetReader _readAsset;
  final Future<Directory> Function() _cacheDir;
  final Future<Pose3dDetector> Function()? _engineFactory;
  final PoseDetectorService Function() _fallbackFactory;

  PoseRecognitionBackend _backend = PoseRecognitionBackend.mediapipe;
  bool _ready = false;
  String _backendNote = '';
  Pose3dDetector? _engine;
  PoseDetectorService? _fallback;

  PoseRecognitionBackend get backend => _backend;
  bool get ready => _ready;

  /// 回退/降级原因（空 = 未发生）。
  String get backendNote => _backendNote;

  String get backendLabel => _backend == PoseRecognitionBackend.rtmpose
      ? 'RTMPose/RTMW3D（ONNX CPU）'
      : 'MediaPipe BlazePose（回退）';

  /// 初始化（优先 RTMPose；失败自动回退 MediaPipe，R69）。
  Future<void> initialize() async {
    if (_ready) return;
    try {
      final Pose3dDetector engine =
          await (_engineFactory?.call() ?? _loadRtmpose());
      _engine = engine;
      _backend = PoseRecognitionBackend.rtmpose;
      _ready = true;
      return;
    } catch (e) {
      _engineNote(e);
    }
    final PoseDetectorService mp = _fallbackFactory();
    await mp.initialize();
    _fallback = mp;
    _backend = PoseRecognitionBackend.mediapipe;
    _ready = true;
  }

  void _engineNote(Object e) {
    _backendNote = 'RTMPose 不可用，已回退 MediaPipe：$e';
    _engine?.close();
    _engine = null;
  }

  Future<Pose3dEngine> _loadRtmpose() async {
    final Directory dir = await _cacheDir();
    final Pose3dAssembledModel model = await ensurePose3dModel(
      spec: Pose3dAssemblySpec.rtmw3dFp16,
      target: File('${dir.path}${Platform.pathSeparator}rtmw3d-x-fp16.onnx'),
      readAsset: _readAsset,
    );
    return Pose3dEngine.load(
      detBytes: await _readAsset(detModelAsset),
      poseBytes: await model.file.readAsBytes(),
    );
  }

  /// 识别（与 `PoseDetectorService.detect` 同契约）。
  Future<List<DetectedPerson>> detect(
    Uint8List imageBytes, {
    String category = '',
    bool withWorld = true,
  }) async {
    if (!_ready) await initialize();
    if (_backend == PoseRecognitionBackend.mediapipe) {
      return _fallback!.detect(
        imageBytes,
        category: category,
        withWorld: withWorld,
      );
    }
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('图片解码失败');
    }
    final List<Pose3dPerson> persons = await _engine!.detect(
      rgba: decoded.getBytes(order: img.ChannelOrder.rgba),
      width: decoded.width,
      height: decoded.height,
      category: category,
      maxPersons: 5,
    );
    return <DetectedPerson>[
      for (int i = 0; i < persons.length; i++) _toDetected(persons[i], i),
    ];
  }

  /// `Pose3dPerson` → `DetectedPerson`（未映射的面部点 visibility=0，绘制时跳过）。
  static DetectedPerson _toDetected(Pose3dPerson p, int index) {
    final List<PoseLandmark> marks = <PoseLandmark>[
      for (int i = 0; i < PoseLandmarkType.values.length; i++) _landmark(i, p),
    ];
    return DetectedPerson(
      index: index,
      landmarks2d: marks,
      world: p.world.world,
      derived: p.derived,
      jointConfidence: PoseDetectorService.jointVisibility(marks),
      bbox: Rect.fromLTRB(p.box.x1, p.box.y1, p.box.x2, p.box.y2),
      score: p.score,
    );
  }

  static PoseLandmark _landmark(int blazeIndex, Pose3dPerson p) {
    final int? rtmw = kPose3dMap33[blazeIndex];
    if (rtmw == null) {
      return PoseLandmark(
        type: PoseLandmarkType.values[blazeIndex],
        x: 0,
        y: 0,
        z: 0,
        visibility: 0,
      );
    }
    return PoseLandmark(
      type: PoseLandmarkType.values[blazeIndex],
      x: p.keypoints.x2d[rtmw],
      y: p.keypoints.y2d[rtmw],
      z: p.world.world[blazeIndex][2],
      visibility: p.keypoints.scores[rtmw],
    );
  }

  void dispose() {
    _engine?.close();
    _engine = null;
    _fallback?.dispose();
    _fallback = null;
    _ready = false;
  }
}

Future<Uint8List> _rootBundleReader(String assetKey) async {
  final ByteData data = await rootBundle.load(assetKey);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<Directory> _supportDirectory() => getApplicationSupportDirectory();
