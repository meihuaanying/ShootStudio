/// V7/D141：识别门面测试（RTMPose 优先 / MediaPipe 回退，R62 离线 fixture）。
library;

import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pose_detection/pose_detection.dart';
import 'package:shoot_studio/features/poses/pose_landmark_math.dart';
import 'package:shoot_studio/services/pose/pose_detector_service.dart';
import 'package:shoot_studio/services/pose/pose_recognition_service.dart';
import 'package:shoot_studio/services/pose3d/pose3d_decode.dart';
import 'package:shoot_studio/services/pose3d/pose3d_engine.dart';
import 'package:shoot_studio/services/pose3d/pose3d_geometry.dart';
import 'package:shoot_studio/services/pose3d/pose3d_mapping.dart';

class _FakeDetector implements Pose3dDetector {
  bool closed = false;

  @override
  Future<List<Pose3dPerson>> detect({
    required Uint8List rgba,
    required int width,
    required int height,
    String category = '',
    double scoreThr = 0.5,
    int maxPersons = 1,
  }) async => <Pose3dPerson>[_fakePerson()];

  @override
  void close() => closed = true;
}

class _FakeMediaPipe extends PoseDetectorService {
  _FakeMediaPipe();

  bool initialized = false;
  bool disposed = false;
  int detectCalls = 0;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<List<DetectedPerson>> detect(
    Uint8List imageBytes, {
    String category = '',
    bool withWorld = true,
  }) async {
    detectCalls++;
    return <DetectedPerson>[
      DetectedPerson(
        index: 0,
        landmarks2d: <PoseLandmark>[
          for (int i = 0; i < PoseLandmarkType.values.length; i++)
            PoseLandmark(
              type: PoseLandmarkType.values[i],
              x: 1,
              y: 2,
              z: 3,
              visibility: 0.7,
            ),
        ],
        world: <List<double>>[
          for (int i = 0; i < 33; i++) <double>[0, 0, 0],
        ],
        derived: _fakeDerived(),
        jointConfidence: <String, double>{'spine': 0.7},
        bbox: Rect.fromLTRB(0, 0, 10, 20),
        score: 0.42,
      ),
    ];
  }

  @override
  Future<void> dispose() async => disposed = true;
}

Pose3dPerson _fakePerson() {
  final Float32List x = Float32List(133);
  final Float32List y = Float32List(133);
  final Float32List z = Float32List(133);
  final Float32List scores = Float32List(133);
  final Float32List x2d = Float32List(133);
  final Float32List y2d = Float32List(133);
  for (int i = 0; i < 133; i++) {
    x[i] = (10 + i).toDouble();
    y[i] = (20 + i).toDouble();
    z[i] = -0.5;
    scores[i] = 0.9;
    x2d[i] = (100 + i).toDouble();
    y2d[i] = (200 + i).toDouble();
  }
  return Pose3dPerson(
    box: const Pose3dBox(1, 2, 30, 40),
    score: 0.88,
    keypoints: Pose3dKeypoints(
      count: 133,
      x: x,
      y: y,
      z: z,
      scores: scores,
      x2d: x2d,
      y2d: y2d,
    ),
    world: Pose3dWorld33(
      world: <List<double>>[
        for (int i = 0; i < 33; i++) <double>[i * 0.01, i * 0.02, -0.1],
      ],
      confidence: List<double>.filled(33, 0.9),
      scale: 0.005,
      bonesUsed: 10,
    ),
    derived: _fakeDerived(),
  );
}

DerivedPose _fakeDerived() => DerivedPose(
  joints: <String, List<double>>{
    for (final String j in engineJoints) j: <double>[1, 2, 3],
  },
  rootY: 0.1,
  rootPitch: 5,
);

Uint8List _pngBytes() {
  final img.Image image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(120, 60, 30));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('Q6 识别门面（D141 / R69）', () {
    test(
      'RTMPose 后端：DetectedPerson 映射（landmarks 33、未映射点 visibility=0）',
      () async {
        final _FakeDetector detector = _FakeDetector();
        final PoseRecognitionService service = PoseRecognitionService(
          engineFactory: () async => detector,
          fallbackFactory: _FakeMediaPipe.new,
        );
        await service.initialize();
        expect(service.backend, PoseRecognitionBackend.rtmpose);
        expect(service.backendLabel, contains('RTMPose'));
        expect(service.backendNote, isEmpty);
        final List<DetectedPerson> persons = await service.detect(_pngBytes());
        expect(persons, hasLength(1));
        final DetectedPerson p = persons.first;
        expect(p.landmarks2d, hasLength(33));
        // 映射点：左踝（BlazePose 27 ← RTMW3D 15）
        final PoseLandmark ankle = p.landmarks2d[27];
        expect(ankle.x, 115);
        expect(ankle.y, 215);
        expect(ankle.z, -0.1);
        expect(ankle.visibility, closeTo(0.9, 1e-6));
        // 未映射点（左眼内角）visibility=0（绘制时跳过）
        expect(p.landmarks2d[1].visibility, 0);
        expect(p.bbox.left, 1);
        expect(p.bbox.top, 2);
        expect(p.score, 0.88);
        // jointConfidence：12 关节由组成点 visibility 最小值计算
        expect(p.jointConfidence.keys, containsAll(engineJoints));
        expect(p.jointConfidence['spine'], closeTo(0.9, 1e-6));
        expect(detector.closed, isFalse);
        service.dispose();
        expect(detector.closed, isTrue);
      },
    );

    test('引擎加载失败 → MediaPipe 回退（R69）：note/label 与路由', () async {
      final _FakeMediaPipe mp = _FakeMediaPipe();
      final PoseRecognitionService service = PoseRecognitionService(
        engineFactory: () async => throw StateError('模型缺失'),
        fallbackFactory: () => mp,
      );
      await service.initialize();
      expect(service.backend, PoseRecognitionBackend.mediapipe);
      expect(service.backendLabel, contains('回退'));
      expect(service.backendNote, contains('已回退 MediaPipe'));
      expect(service.backendNote, contains('模型缺失'));
      expect(mp.initialized, isTrue);
      final List<DetectedPerson> persons = await service.detect(_pngBytes());
      expect(mp.detectCalls, 1);
      expect(persons.single.score, 0.42);
      service.dispose();
      expect(mp.disposed, isTrue);
    });
  });
}
