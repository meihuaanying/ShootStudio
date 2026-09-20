import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_litert/native.dart' as litert;
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:pose_detection/pose_detection.dart';

import '../../features/poses/pose_landmark_math.dart';

/// 端上姿势识别结果（单人）。
class DetectedPerson {
  const DetectedPerson({
    required this.index,
    required this.landmarks2d,
    required this.world,
    required this.derived,
    required this.jointConfidence,
    required this.bbox,
    required this.score,
  });

  /// 帧内序号（多人点选用）。
  final int index;

  /// 33 个 2D 关键点（原图像素坐标，BlazePose 顺序）。
  final List<PoseLandmark> landmarks2d;

  /// 33 个世界坐标（米制，hip 中心，y 向下）。
  final List<List<double>> world;

  /// 12 关节角（引擎口径）。
  final DerivedPose derived;

  /// 关节级置信度（由构成关键点的 visibility 取最小值）。
  final Map<String, double> jointConfidence;

  /// 人体框（原图像素，来自人物检测）。
  final Rect bbox;

  /// 检测得分。
  final double score;

  bool get lowConfidence => jointConfidence.values.any((double v) => v < 0.5);
}

/// D 阶段端上识别服务（D123/D124）：
/// 人物检测（YOLOv8n）→ 2D 关键点（BlazePose lite，用于框选与叠加预览）
/// → 多尺度人物裁剪 → BlazePose full 世界坐标（米制，逐坐标中位数）
/// → 12 关节角。
///
/// 模型全部随包分发（R53），离线可用；测试可注入模型字节（pub 缓存）。
class PoseDetectorService {
  PoseDetectorService({Uint8List? worldModelBytes})
    : _worldModelBytes = worldModelBytes;

  final Uint8List? _worldModelBytes;
  PoseDetector? _detector;
  litert.Interpreter? _worldInterpreter;
  List<int> _worldOutSizes = <int>[];
  int _worldIdx = -1;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  static const String yoloAsset =
      'packages/pose_detection/assets/models/yolov8n_float32.tflite';
  static const String liteAsset =
      'packages/pose_detection/assets/models/pose_landmark_lite.tflite';
  static const String worldAsset =
      'packages/pose_detection/assets/models/pose_landmark_full.tflite';

  /// 世界坐标推理的裁剪尺度集成（多 ROI 取均值，降低单次裁剪噪声）。
  static const List<double> worldCropScales = <double>[1.2, 1.3, 1.4];

  /// 初始化：人物/2D 用 lite（快），世界坐标用 full（准）。
  Future<void> initialize() async {
    if (_initialized) return;
    final Uint8List yolo = (await rootBundle.load(
      yoloAsset,
    )).buffer.asUint8List();
    final Uint8List lite = (await rootBundle.load(
      liteAsset,
    )).buffer.asUint8List();
    final Uint8List world =
        _worldModelBytes ??
        (await rootBundle.load(worldAsset)).buffer.asUint8List();
    await _initWithBuffers(yoloBytes: yolo, liteBytes: lite, worldBytes: world);
  }

  /// 测试/QA 用：绕过 rootBundle 直接注入模型字节。
  Future<void> initializeWithBuffers({
    required Uint8List yoloBytes,
    required Uint8List liteBytes,
    required Uint8List worldBytes,
  }) async {
    if (_initialized) return;
    await _initWithBuffers(
      yoloBytes: yoloBytes,
      liteBytes: liteBytes,
      worldBytes: worldBytes,
    );
  }

  Future<void> _initWithBuffers({
    required Uint8List yoloBytes,
    required Uint8List liteBytes,
    required Uint8List worldBytes,
  }) async {
    final PoseDetector detector = PoseDetector();
    await detector.initializeFromBuffers(
      yoloBytes: yoloBytes,
      landmarkBytes: liteBytes,
      mode: PoseMode.boxesAndLandmarks,
      landmarkModel: PoseLandmarkModel.lite,
    );
    _detector = detector;
    final litert.Interpreter interpreter = litert.Interpreter.fromBuffer(
      worldBytes,
    );
    interpreter.resizeInputTensor(0, <int>[1, 256, 256, 3]);
    interpreter.allocateTensors();
    _worldInterpreter = interpreter;
    _worldOutSizes = <int>[
      for (int i = 0; i < 5; i++) interpreter.getOutputTensor(i).numElements(),
    ];
    _worldIdx = _worldOutSizes.indexOf(117);
    if (_worldIdx < 0) {
      throw StateError('BlazePose 模型缺少 world landmarks 输出（117）');
    }
    _initialized = true;
  }

  /// 单张图片识别（多人）；[withWorld] 为 false 时仅 2D（选择阶段提速）。
  Future<List<DetectedPerson>> detect(
    Uint8List imageBytes, {
    String category = '',
    bool withWorld = true,
  }) async {
    if (!_initialized) {
      throw StateError('PoseDetectorService 未初始化');
    }
    final List<Pose> poses = await _detector!.detect(imageBytes);
    if (poses.isEmpty) return <DetectedPerson>[];
    final cv.Mat image = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
    final List<DetectedPerson> out = <DetectedPerson>[];
    try {
      for (var i = 0; i < poses.length; i++) {
        final Pose pose = poses[i];
        if (!pose.hasLandmarks) continue;
        final Rect bbox = _bboxOfPose(pose, image.cols, image.rows);
        List<List<double>> world = const <List<double>>[];
        DerivedPose derived = const DerivedPose(
          joints: <String, List<double>>{},
          rootY: 0,
          rootPitch: 0,
        );
        if (withWorld) {
          world = _inferWorld(image, bbox);
          if (world.length >= 33) {
            derived = deriveJoints(world, category: category);
          }
        }
        out.add(
          DetectedPerson(
            index: i,
            landmarks2d: pose.landmarks,
            world: world,
            derived: derived,
            jointConfidence: jointVisibility(pose.landmarks),
            bbox: bbox,
            score: pose.score,
          ),
        );
      }
    } finally {
      image.dispose();
    }
    return out;
  }

  /// 人物检测框（原图像素；无效时回退 landmark 外接框）。
  static Rect _bboxOfPose(Pose pose, int width, int height) {
    final BoundingBox box = pose.boundingBox;
    final double x1 = math.min(box.topLeft.x, box.bottomRight.x);
    final double y1 = math.min(box.topLeft.y, box.bottomRight.y);
    final double x2 = math.max(box.topLeft.x, box.bottomRight.x);
    final double y2 = math.max(box.topLeft.y, box.bottomRight.y);
    if (x2 - x1 < 2 || y2 - y1 < 2) {
      return _landmarkBbox(pose.landmarks, width, height);
    }
    return Rect.fromLTRB(
      x1.clamp(0, width.toDouble()),
      y1.clamp(0, height.toDouble()),
      x2.clamp(0, width.toDouble()),
      y2.clamp(0, height.toDouble()),
    );
  }

  /// 由 33 个 2D 点求外接框（像素，含 20% 余量；作兜底）。
  static Rect _landmarkBbox(
    List<PoseLandmark> landmarks,
    int width,
    int height,
  ) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final PoseLandmark lm in landmarks) {
      minX = math.min(minX, lm.x);
      maxX = math.max(maxX, lm.x);
      minY = math.min(minY, lm.y);
      maxY = math.max(maxY, lm.y);
    }
    final double cx = (minX + maxX) / 2;
    final double cy = (minY + maxY) / 2;
    final double side = math.max(maxX - minX, maxY - minY) * 1.2;
    return Rect.fromLTRB(
      (cx - side / 2).clamp(0, width.toDouble()),
      (cy - side / 2).clamp(0, height.toDouble()),
      (cx + side / 2).clamp(0, width.toDouble()),
      (cy + side / 2).clamp(0, height.toDouble()),
    );
  }

  /// 多尺度裁剪集成 → 世界坐标中位数。
  List<List<double>> _inferWorld(cv.Mat image, Rect bbox) {
    final List<List<List<double>>> worlds = <List<List<double>>>[];
    for (final double scale in worldCropScales) {
      final List<List<double>> world = _inferWorldOnce(image, bbox, scale);
      if (world.length == 33) worlds.add(world);
    }
    if (worlds.isEmpty) return const <List<double>>[];
    if (worlds.length == 1) return worlds.first;
    return <List<double>>[
      for (int i = 0; i < 33; i++)
        <double>[
          _mean(worlds.map((List<List<double>> w) => w[i][0]).toList()),
          _mean(worlds.map((List<List<double>> w) => w[i][1]).toList()),
          _mean(worlds.map((List<List<double>> w) => w[i][2]).toList()),
        ],
    ];
  }

  static double _mean(List<double> values) =>
      values.reduce((double a, double b) => a + b) / values.length;

  /// 单次推理：bbox 中心 + [scale]×最长边 的方形裁剪（越界以 114 填充，
  /// 与包内 `extractAlignedSquare` 同款）→ 模型。
  List<List<double>> _inferWorldOnce(cv.Mat image, Rect bbox, double scale) {
    final double cx = bbox.center.dx;
    final double cy = bbox.center.dy;
    final double size = math.max(bbox.width, bbox.height) * scale;
    if (size < 16) return const <List<double>>[];
    final cv.Mat crop = _alignedSquare(image, cx, cy, size, 256);
    cv.Mat? rgb;
    cv.Mat? f32;
    try {
      rgb = cv.cvtColor(crop, cv.COLOR_BGR2RGB);
      f32 = rgb.convertTo(cv.MatType.CV_32FC3, alpha: 1 / 255.0);
      final Float32List input = Float32List(256 * 256 * 3);
      input.setAll(0, f32.data.buffer.asFloat32List(0, 256 * 256 * 3));
      final Map<int, Object> outputs = <int, Object>{
        for (int i = 0; i < 5; i++) i: Float32List(_worldOutSizes[i]).buffer,
      };
      _worldInterpreter!.runForMultipleInputs(<Object>[input.buffer], outputs);
      final Float32List world = (outputs[_worldIdx] as ByteBuffer)
          .asFloat32List();
      return <List<double>>[
        for (int i = 0; i < 33; i++)
          <double>[world[i * 3], world[i * 3 + 1], world[i * 3 + 2]],
      ];
    } finally {
      crop.dispose();
      rgb?.dispose();
      f32?.dispose();
    }
  }

  /// 与包内 `extractAlignedSquare` 等价的方形裁剪（theta=0，越界 114 填充）。
  static cv.Mat _alignedSquare(
    cv.Mat src,
    double cx,
    double cy,
    double size,
    int outDim,
  ) {
    final double scale = outDim / size;
    final cv.Mat rotMat = cv.getRotationMatrix2D(
      cv.Point2f(cx, cy),
      0.0,
      scale,
    );
    final double outCenter = outDim / 2.0;
    final double tx = rotMat.at<double>(0, 2) + outCenter - cx;
    final double ty = rotMat.at<double>(1, 2) + outCenter - cy;
    rotMat.set<double>(0, 2, tx);
    rotMat.set<double>(1, 2, ty);
    final cv.Mat output = cv.warpAffine(
      src,
      rotMat,
      (outDim, outDim),
      borderMode: cv.BORDER_CONSTANT,
      borderValue: cv.Scalar(114, 114, 114, 0),
    );
    rotMat.dispose();
    return output;
  }

  /// 关节点 → 用于推导的 landmark 索引（与 Python/引擎一致）。
  static const Map<String, List<int>> jointLandmarks = <String, List<int>>{
    'spine': <int>[11, 12, 23, 24],
    'neck': <int>[0, 7, 8, 11, 12],
    'shoulder_l': <int>[11, 13],
    'elbow_l': <int>[13, 15],
    'wrist_l': <int>[15, 19],
    'shoulder_r': <int>[12, 14],
    'elbow_r': <int>[14, 16],
    'wrist_r': <int>[16, 20],
    'hip_l': <int>[23, 25],
    'knee_l': <int>[25, 27],
    'hip_r': <int>[24, 26],
    'knee_r': <int>[26, 28],
  };

  /// 关节置信度 = 构成关键点 visibility 最小值。
  static Map<String, double> jointVisibility(List<PoseLandmark> landmarks) {
    final Map<String, double> out = <String, double>{};
    for (final MapEntry<String, List<int>> entry in jointLandmarks.entries) {
      var min = 1.0;
      for (final int idx in entry.value) {
        if (idx >= landmarks.length) continue;
        min = math.min(min, landmarks[idx].visibility);
      }
      out[entry.key] = min;
    }
    return out;
  }

  Future<void> dispose() async {
    await _detector?.dispose();
    _detector = null;
    _worldInterpreter?.close();
    _worldInterpreter = null;
    _initialized = false;
  }

  /// 测试/QA 专用：从 pub 缓存读取模型字节（不随生产代码调用）。
  static Future<({Uint8List yolo, Uint8List lite, Uint8List full})>
  debugModelsFromPubCache() async {
    final String cache =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache';
    final Directory hosted = Directory('$cache\\hosted\\pub.dev');
    Directory? pkg;
    for (final FileSystemEntity entity in hosted.listSync()) {
      if (entity is Directory && entity.path.contains('pose_detection-')) {
        pkg = entity;
        break;
      }
    }
    if (pkg == null) {
      throw StateError('pub 缓存中找不到 pose_detection');
    }
    Uint8List read(String name) =>
        File('${pkg!.path}\\assets\\models\\$name').readAsBytesSync();
    return (
      yolo: read('yolov8n_float32.tflite'),
      lite: read('pose_landmark_lite.tflite'),
      full: read('pose_landmark_full.tflite'),
    );
  }
}
