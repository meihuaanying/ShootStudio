/// V7/D141：RTMPose/RTMW3D 端上识别引擎（onnxruntime FFI，CPU EP）。
///
/// 流程（与 `app/tool/rtmpose_spike.py` / rtmlib 逐字对齐）：
/// 1. 检测：letterbox（pad=114）→ YOLOX（tiny 416×416）→ `decodeYolox`；
/// 2. 姿态：bbox → `Pose3dCropSpec`（1.25 padding + 3:4）→ warp（BGR/归一化）→
///    RTMW3D-x（fp16，288×384）→ `decodeSimcc3d` → `toWorld33` → `deriveJoints()`。
///
/// Windows 上 onnxruntime.dll 由插件随构建拷贝到 exe 旁；`flutter test` 场景需
/// 先用绝对路径 `DynamicLibrary.open` 预加载（见一致性测试）。
library;

import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import '../../features/poses/pose_landmark_math.dart';
import 'pose3d_decode.dart';
import 'pose3d_geometry.dart';
import 'pose3d_mapping.dart';

/// 引擎初始化/推理失败（调用方按 R69 回退旧后端）。
class Pose3dEngineException implements Exception {
  const Pose3dEngineException(this.message);

  final String message;

  @override
  String toString() => 'Pose3dEngineException: $message';
}

/// 单个人物的识别结果。
class Pose3dPerson {
  const Pose3dPerson({
    required this.box,
    required this.score,
    required this.keypoints,
    required this.world,
    required this.derived,
  });

  final Pose3dBox box;
  final double score;
  final Pose3dKeypoints keypoints;
  final Pose3dWorld33 world;
  final DerivedPose derived;
}

/// 识别引擎接口（门面依赖抽象，测试可注入假实现，R62）。
abstract class Pose3dDetector {
  Future<List<Pose3dPerson>> detect({
    required Uint8List rgba,
    required int width,
    required int height,
    String category = '',
    double scoreThr = 0.5,
    int maxPersons = 1,
  });

  void close();
}

/// 引擎（检测 + 姿态）。
class Pose3dEngine implements Pose3dDetector {
  Pose3dEngine._(this._det, this._pose);

  final OrtSession _det;
  final OrtSession _pose;

  /// YOLOX tiny 输入尺寸（416）。
  static const int kDetInputSize = 416;

  /// RTMW3D 输入（288×384）。
  static const int kPoseInputW = 288;
  static const int kPoseInputH = 384;

  /// RTMW3D 关键点数（133）。
  static const int kPoseKeypoints = 133;

  /// 从模型字节加载（`fromBuffer`：Windows 上 `fromFile` 有 wchar 路径 bug；
  /// 资源侧用 rootBundle，测试侧读文件）。
  static Future<Pose3dEngine> load({
    required Uint8List detBytes,
    required Uint8List poseBytes,
    int intraOpThreads = 2,
  }) async {
    final OrtSessionOptions detOpts = OrtSessionOptions()
      ..setIntraOpNumThreads(intraOpThreads);
    final OrtSessionOptions poseOpts = OrtSessionOptions()
      ..setIntraOpNumThreads(intraOpThreads);
    try {
      final OrtSession det = OrtSession.fromBuffer(detBytes, detOpts);
      final OrtSession pose = OrtSession.fromBuffer(poseBytes, poseOpts);
      return Pose3dEngine._(det, pose);
    } catch (e) {
      throw Pose3dEngineException('模型加载失败：$e');
    } finally {
      detOpts.release();
      poseOpts.release();
    }
  }

  /// 检测 + 姿态（[rgba] 为 RGBA8888；按 bbox 面积降序返回，最多 [maxPersons] 人）。
  @override
  Future<List<Pose3dPerson>> detect({
    required Uint8List rgba,
    required int width,
    required int height,
    String category = '',
    double scoreThr = 0.5,
    int maxPersons = 1,
  }) async {
    final List<Pose3dDetection> dets = _detectBoxes(
      rgba,
      width,
      height,
      scoreThr,
    );
    if (dets.isEmpty) return const <Pose3dPerson>[];
    dets.sort(
      (Pose3dDetection a, Pose3dDetection b) =>
          b.box.area.compareTo(a.box.area),
    );
    final List<Pose3dPerson> persons = <Pose3dPerson>[];
    for (final Pose3dDetection d in dets.take(maxPersons)) {
      persons.add(_poseForBox(rgba, width, height, d, category: category));
    }
    return persons;
  }

  List<Pose3dDetection> _detectBoxes(
    Uint8List rgba,
    int width,
    int height,
    double scoreThr,
  ) {
    final Pose3dLetterbox lb = letterboxChw(
      rgba,
      width,
      height,
      kDetInputSize,
      kDetInputSize,
    );
    final OrtValueTensor input = OrtValueTensor.createTensorWithDataList(
      lb.tensor,
      <int>[1, 3, kDetInputSize, kDetInputSize],
    );
    final OrtRunOptions ro = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = _det.run(ro, <String, OrtValue>{_det.inputNames.first: input});
    } finally {
      input.release();
      ro.release();
    }
    final OrtValue? raw = outputs.isEmpty ? null : outputs.first;
    if (raw is! OrtValueTensor) {
      if (raw != null) raw.release();
      throw const Pose3dEngineException('检测输出类型异常');
    }
    try {
      final List<List<double>> rows = _rows2d(raw.value);
      final int cols = rows.isEmpty ? 0 : rows.first.length;
      final Float32List flat = Float32List(rows.length * cols);
      int i = 0;
      for (final List<double> row in rows) {
        for (final double v in row) {
          flat[i++] = v;
        }
      }
      return decodeYolox(
        output: flat,
        rows: rows.length,
        cols: cols,
        inH: kDetInputSize,
        inW: kDetInputSize,
        ratio: lb.ratio,
        scoreThr: scoreThr,
      );
    } finally {
      raw.release();
    }
  }

  Pose3dPerson _poseForBox(
    Uint8List rgba,
    int width,
    int height,
    Pose3dDetection det, {
    required String category,
  }) {
    final Pose3dCropSpec spec = Pose3dCropSpec.fromBox(
      det.box,
      outW: kPoseInputW,
      outH: kPoseInputH,
    );
    final Float32List tensor = warpCropBgrNormalized(rgba, width, height, spec);
    final OrtValueTensor input = OrtValueTensor.createTensorWithDataList(
      tensor,
      <int>[1, 3, kPoseInputH, kPoseInputW],
    );
    final OrtRunOptions ro = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = _pose.run(ro, <String, OrtValue>{
        _pose.inputNames.first: input,
      });
    } finally {
      input.release();
      ro.release();
    }
    if (outputs.length < 3) {
      for (final OrtValue? o in outputs) {
        o?.release();
      }
      throw const Pose3dEngineException('姿态输出数量异常');
    }
    try {
      final Float32List simccX = _flatten(outputs[0]);
      final Float32List simccY = _flatten(outputs[1]);
      final Float32List simccZ = _flatten(outputs[2]);
      final Pose3dKeypoints kp = decodeSimcc3d(
        simccX: simccX,
        simccY: simccY,
        simccZ: simccZ,
        numKeypoints: kPoseKeypoints,
        simccW: simccX.length ~/ kPoseKeypoints,
        simccH: simccY.length ~/ kPoseKeypoints,
        simccZLen: simccZ.length ~/ kPoseKeypoints,
        spec: spec,
      );
      final Pose3dWorld33 world = toWorld33(kp);
      final DerivedPose derived = deriveJoints(world.world, category: category);
      return Pose3dPerson(
        box: det.box,
        score: det.score,
        keypoints: kp,
        world: world,
        derived: derived,
      );
    } finally {
      for (final OrtValue? o in outputs) {
        o?.release();
      }
    }
  }

  @override
  void close() {
    _det.release();
    _pose.release();
  }
}

/// `[1, rows, cols]` 嵌套 → `List<List<double>>`。
List<List<double>> _rows2d(dynamic value) {
  final List<List<double>> rows = <List<double>>[];
  if (value is! List) return rows;
  for (final dynamic batch in value) {
    if (batch is! List) continue;
    for (final dynamic row in batch) {
      if (row is! List) continue;
      rows.add(<double>[for (final dynamic v in row) (v as num).toDouble()]);
    }
  }
  return rows;
}

/// 任意嵌套数字张量 → 扁平 `Float32List`。
Float32List _flatten(OrtValue? value) {
  if (value is! OrtValueTensor) {
    value?.release();
    throw const Pose3dEngineException('姿态输出类型异常');
  }
  final dynamic raw = value.value;
  final List<double> out = <double>[];
  void walk(dynamic node) {
    if (node is num) {
      out.add(node.toDouble());
    } else if (node is List) {
      for (final dynamic c in node) {
        walk(c);
      }
    }
  }

  walk(raw);
  return Float32List.fromList(out);
}
