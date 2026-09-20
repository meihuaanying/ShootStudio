import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/services/pose/pose_detector_service.dart';
import 'package:shoot_studio/services/pose/pose_joint_mapper.dart';

/// D128 精度门禁（本机运行，CI 跳过）：
/// 端上 `pose_detection`+BlazePose full 识别 120 张参考图，
/// 与 Python(MediaPipe) 管线 `poses3.json` 逐关节对比。
/// 达标线：均值 ≤5°，90% 关节角样本 ≤10°。
/// 运行：`SS_POSE_ACCURACY=1 flutter test test/features/q6_pose_accuracy_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bool run = Platform.environment['SS_POSE_ACCURACY'] == '1';

  test(
    'D128：120 张参考图端上 vs Python 关节角误差',
    () async {
      final Map<String, Object?> poses3 =
          (jsonDecode(
                    File(
                      'assets/content/poses3/poses3.json',
                    ).readAsStringSync(),
                  )
                  as Map)
              .cast<String, Object?>();
      final List<Map<String, Object?>> poses =
          (poses3['poses'] as List<Object?>)
              .map((Object? p) => (p as Map).cast<String, Object?>())
              .take(
                int.tryParse(Platform.environment['SS_POSE_N'] ?? '') ?? 1000,
              )
              .toList();

      final ({Uint8List yolo, Uint8List lite, Uint8List full}) models =
          await PoseDetectorService.debugModelsFromPubCache();
      final PoseDetectorService service = PoseDetectorService();
      await service.initializeWithBuffers(
        yoloBytes: models.yolo,
        liteBytes: models.lite,
        worldBytes: models.full,
      );

      final List<double> errors = <double>[];
      final List<double> photoMeans = <double>[];
      final Map<String, List<double>> jointErrors = <String, List<double>>{};
      final List<String> badRows = <String>[];
      var rootPitchErrors = <double>[];
      var rootYErrors = <double>[];
      var skipped = 0;

      try {
        for (final Map<String, Object?> pose in poses) {
          final String id = '${pose['id']}';
          final File file = File('${pose['photo']}');
          if (!file.existsSync()) {
            skipped++;
            continue;
          }
          final Map<String, Object?> expected =
              (pose['joints'] as Map? ?? <String, Object?>{}).cast();
          final List<DetectedPerson> people = await service.detect(
            await file.readAsBytes(),
            category: '${pose['category'] ?? ''}',
          );
          if (people.isEmpty) {
            skipped++;
            badRows.add('$id：未检测到人物');
            continue;
          }
          // 多人时取人体框最大者。
          people.sort(
            (DetectedPerson a, DetectedPerson b) =>
                (b.bbox.width * b.bbox.height).compareTo(
                  a.bbox.width * a.bbox.height,
                ),
          );
          final DetectedPerson person = people.first;
          if (person.world.length < 33) {
            skipped++;
            badRows.add('$id：无世界坐标');
            continue;
          }
          final MappedPose mapped = PoseJointMapper.map(
            person.world,
            jointConfidence: person.jointConfidence,
            category: '${pose['category'] ?? ''}',
          );
          final List<double> photoErrors = <double>[];
          var photoMax = 0.0;
          for (final MapEntry<String, Object?> entry in expected.entries) {
            final List<double> exp = (entry.value as List)
                .map((Object? v) => (v as num).toDouble())
                .toList();
            final List<double> act =
                mapped.joints[entry.key] ?? <double>[0, 0, 0];
            for (int axis = 0; axis < 3; axis++) {
              final double err = (exp[axis] - act[axis]).abs();
              errors.add(err);
              photoErrors.add(err);
              jointErrors.putIfAbsent(entry.key, () => <double>[]).add(err);
              if (err > photoMax) photoMax = err;
            }
          }
          if (photoErrors.isNotEmpty) {
            photoMeans.add(
              photoErrors.reduce((double a, double b) => a + b) /
                  photoErrors.length,
            );
          }
          rootPitchErrors.add(
            ((pose['rootPitch'] as num?)?.toDouble() ?? 0 - mapped.rootPitch)
                .abs(),
          );
          rootYErrors.add(
            (((pose['rootY'] as num?)?.toDouble() ?? 0) - mapped.rootY).abs(),
          );
          if (photoMax > 10) {
            badRows.add('$id：最大关节误差 ${photoMax.toStringAsFixed(1)}°');
          }
        }
      } finally {
        await service.dispose();
      }

      errors.sort();
      final double mean = errors.isEmpty
          ? 0
          : errors.reduce((double a, double b) => a + b) / errors.length;
      final double p50 = errors.isEmpty ? 0 : errors[errors.length ~/ 2];
      final double p90 = errors.isEmpty
          ? 0
          : errors[(errors.length * 0.9).floor()];
      final double p95 = errors.isEmpty
          ? 0
          : errors[(errors.length * 0.95).floor()];
      final double within10 = errors.isEmpty
          ? 0
          : errors.where((double e) => e <= 10).length / errors.length;
      final int worstCount = badRows
          .where((String r) => r.contains('最大关节误差'))
          .length;
      photoMeans.sort();
      final double photoP90 = photoMeans.isEmpty
          ? 0
          : photoMeans[(photoMeans.length * 0.9).floor().clamp(
              0,
              photoMeans.length - 1,
            )];
      final double photoWithin = photoMeans.isEmpty
          ? 0
          : photoMeans.where((double e) => e <= 10).length / photoMeans.length;

      final StringBuffer report = StringBuffer()
        ..writeln('# D128 端上姿势识别精度报告')
        ..writeln()
        ..writeln('- 时间：${DateTime.now().toIso8601String()}')
        ..writeln(
          '- 样本：${poses.length} 张（成功 ${poses.length - skipped}，跳过 $skipped）',
        )
        ..writeln('- 关节角样本数：${errors.length}（12 关节 × 3 轴 × 图）')
        ..writeln('- 平均误差：${mean.toStringAsFixed(2)}°')
        ..writeln(
          '- P50/P90/P95：${p50.toStringAsFixed(2)}° / '
          '${p90.toStringAsFixed(2)}° / ${p95.toStringAsFixed(2)}°',
        )
        ..writeln('- ≤10° 占比：${(within10 * 100).toStringAsFixed(1)}%')
        ..writeln(
          '- 逐图均值 P90：${photoP90.toStringAsFixed(2)}°；'
          '逐图均值 ≤10° 的图占比：${(photoWithin * 100).toStringAsFixed(1)}%',
        )
        ..writeln(
          '- rootPitch 平均误差：'
          '${_avg(rootPitchErrors).toStringAsFixed(2)}°',
        )
        ..writeln('- rootY 平均误差：${_avg(rootYErrors).toStringAsFixed(3)}')
        ..writeln()
        ..writeln('## 分关节平均误差（度）')
        ..writeln();
      final List<MapEntry<String, List<double>>> sortedJoints =
          jointErrors.entries.toList()..sort(
            (
              MapEntry<String, List<double>> a,
              MapEntry<String, List<double>> b,
            ) => _avg(b.value).compareTo(_avg(a.value)),
          );
      for (final MapEntry<String, List<double>> entry in sortedJoints) {
        report.writeln(
          '- ${entry.key}：${_avg(entry.value).toStringAsFixed(2)}° '
          '（n=${entry.value.length}）',
        );
      }
      report
        ..writeln()
        ..writeln('## 超标样本（单图最大误差 >10°：$worstCount）')
        ..writeln();
      for (final String row in badRows.take(60)) {
        report.writeln('- $row');
      }
      final Directory dir = Directory('../docs/qa');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final String stamp = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-');
      final File out = File('${dir.path}/pose-accuracy-$stamp.md');
      out.writeAsStringSync(report.toString());
      // ignore: avoid_print
      print(report.toString());
      // ignore: avoid_print
      print('报告：${out.path}');

      expect(
        mean,
        lessThanOrEqualTo(5.0),
        reason: '平均误差 ${mean.toStringAsFixed(2)}° > 5°',
      );
      expect(
        within10,
        greaterThanOrEqualTo(0.9),
        reason: '≤10° 占比 ${(within10 * 100).toStringAsFixed(1)}% < 90%',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
    skip: run ? false : 'SS_POSE_ACCURACY=1 本机运行',
  );
}

double _avg(List<double> values) => values.isEmpty
    ? 0
    : values.reduce((double a, double b) => a + b) / values.length;
