import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_detection/pose_detection.dart';

/// D 阶段 PoC（D123）：`pose_detection` 3.7 BlazePose 33 点在 Windows 上
/// 对真实照片识别的可行性验证。默认跳过；本机 `SS_POSE_POC=1` 运行。
///
/// 测试环境不经 rootBundle（flutter test 不含依赖包 asset），
/// 改为从 pub 缓存中的包目录直接读模型字节（正式 App 走 rootBundle）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bool poc = Platform.environment['SS_POSE_POC'] == '1';

  Future<Uint8List> modelBytes(String fileName) async {
    final String pubCache =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache';
    final Directory hosted = Directory('$pubCache\\hosted\\pub.dev');
    Directory? pkg;
    for (final FileSystemEntity entity in hosted.listSync()) {
      if (entity is Directory && entity.path.contains('pose_detection-')) {
        pkg = entity;
        break;
      }
    }
    expect(pkg, isNotNull, reason: 'pub 缓存中找不到 pose_detection');
    final File model = File('${pkg!.path}\\assets\\models\\$fileName');
    expect(model.existsSync(), isTrue, reason: '模型缺失：${model.path}');
    return model.readAsBytes();
  }

  test(
    'PoC：真实照片识别出 33 点骨架',
    () async {
      final File photo = File('assets/content/poses3/photos/p001.jpg');
      expect(photo.existsSync(), isTrue, reason: '缺少内置参考照片');
      final Uint8List yolo = await modelBytes('yolov8n_float32.tflite');
      final Uint8List landmark = await modelBytes('pose_landmark_lite.tflite');
      final PoseDetector detector = PoseDetector();
      await detector.initializeFromBuffers(
        yoloBytes: yolo,
        landmarkBytes: landmark,
        mode: PoseMode.boxesAndLandmarks,
        landmarkModel: PoseLandmarkModel.lite,
      );
      try {
        final List<Pose> poses = await detector.detect(
          await photo.readAsBytes(),
        );
        // ignore: avoid_print
        print('PoC 检测到 ${poses.length} 人');
        expect(poses, isNotEmpty, reason: '未检测到人物');
        final Pose first = poses.first;
        expect(first.hasLandmarks, isTrue);
        expect(first.landmarks.length, 33);
        final PoseLandmark? nose = first.getLandmark(PoseLandmarkType.nose);
        expect(nose, isNotNull);
        // ignore: avoid_print
        print(
          '鼻尖：(${nose!.x.toStringAsFixed(3)}, '
          '${nose.y.toStringAsFixed(3)}, ${nose.z.toStringAsFixed(3)}) '
          'visibility=${nose.visibility.toStringAsFixed(2)}',
        );
        // ignore: avoid_print
        print(
          'POCOK poses=${poses.length} landmarks=${first.landmarks.length}',
        );
      } finally {
        await detector.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: poc ? false : 'SS_POSE_POC=1',
  );
}
