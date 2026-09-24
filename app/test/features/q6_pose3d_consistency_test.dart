/// V7/D141：RTMPose/RTMW3D 端上一致性（Dart 引擎 vs Python 参考）。
///
/// 门控：`SS_POSE_ACCURACY=1`（本机运行；CI 跳过，R62）。
/// 参考：`docs/qa/pose3d-consistency-reference.json`
///       （`python tool/rtmpose_spike.py reference`，含 clamp_joint 与生产管线一致）。
/// 证据：`docs/qa/pose3d-consistency-report.json`（本测试写出）。
///
/// 口径说明（重要）：
/// - 几何指标（IoU/关键点/尺度/rootY/rootPitch）严格断言；
/// - 关节角以**中位数**断言：`solve_limb` 的离散扫描 + 限位罚项存在多个近等价值，
///   输入 0.4° 的方向差异即可切换最小值（Python 自对自亦如此，见
///   `docs/qa/pose3d-consistency-report.json` 的 instability 字段），
///   因此均值/最大值仅作记录（D141 偏差登记）。
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shoot_studio/services/pose3d/pose3d_assembly.dart';
import 'package:shoot_studio/services/pose3d/pose3d_engine.dart';

void main() {
  final bool run = Platform.environment['SS_POSE_ACCURACY'] == '1';
  group('Q6 pose3d 一致性（D141 / R62）', () {
    test('Dart 引擎 vs Python 参考：8 图几何严格 / 关节中位数', () async {
      _preloadOrtLibrary();
      final File refFile = File('../docs/qa/pose3d-consistency-reference.json');
      expect(refFile.existsSync(), isTrue, reason: '参考 JSON 缺失（先跑 reference）');
      final Map<String, dynamic> ref =
          jsonDecode(await refFile.readAsString()) as Map<String, dynamic>;
      final List<dynamic> rows = ref['rows'] as List<dynamic>;

      final Directory tmp = await Directory.systemTemp.createTemp('ss_p3d_');
      final Pose3dAssembledModel model = await ensurePose3dModel(
        spec: Pose3dAssemblySpec.rtmw3dFp16,
        target: File('${tmp.path}/rtmw3d-x-fp16.onnx'),
        readAsset: (String key) => File(key).readAsBytes(),
      );
      final Pose3dEngine engine = await Pose3dEngine.load(
        detBytes: await File(
          'assets/models/pose3d/yolox_tiny.onnx',
        ).readAsBytes(),
        poseBytes: await model.file.readAsBytes(),
      );
      final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
      final List<double> allJointDeltas = <double>[];
      double worstIou = 1;
      double worstKpXy = 0;
      double worstKpZ = 0;
      double worstScaleRel = 0;
      double worstRootY = 0;
      double worstRootPitch = 0;
      try {
        for (final dynamic raw in rows) {
          final Map<String, dynamic> row = raw as Map<String, dynamic>;
          final String id = row['id'] as String;
          final img.Image? decoded = img.decodeImage(
            await File('assets/content/poses3/photos/$id.jpg').readAsBytes(),
          );
          expect(decoded, isNotNull, reason: '$id 解码失败');
          final List<Pose3dPerson> persons = await engine.detect(
            rgba: decoded!.getBytes(order: img.ChannelOrder.rgba),
            width: decoded.width,
            height: decoded.height,
            category: row['category'] as String? ?? '',
            maxPersons: 1,
          );
          expect(persons, isNotEmpty, reason: '$id 未检测到人物');
          final Pose3dPerson p = persons.first;
          final List<dynamic> rb = row['box'] as List<dynamic>;
          final double iou = _iou(
            p.box.x1,
            p.box.y1,
            p.box.x2,
            p.box.y2,
            (rb[0] as num).toDouble(),
            (rb[1] as num).toDouble(),
            (rb[2] as num).toDouble(),
            (rb[3] as num).toDouble(),
          );
          final List<dynamic> rk = row['keypoints'] as List<dynamic>;
          double kpXySum = 0;
          double kpZSum = 0;
          for (int i = 0; i < rk.length; i++) {
            final List<dynamic> r = rk[i] as List<dynamic>;
            kpXySum += (p.keypoints.x[i] - (r[0] as num)).abs();
            kpXySum += (p.keypoints.y[i] - (r[1] as num)).abs();
            kpZSum += (p.keypoints.z[i] - (r[2] as num)).abs();
          }
          final double kpXyMean = kpXySum / (rk.length * 2);
          final double kpZMean = kpZSum / rk.length;
          final double scaleRel =
              ((p.world.scale - (row['scale'] as num).toDouble()) /
                      (row['scale'] as num).toDouble())
                  .abs();
          final Map<String, dynamic> rj = row['joints'] as Map<String, dynamic>;
          final List<double> deltas = <double>[];
          for (final String name in rj.keys) {
            final List<dynamic> r = rj[name] as List<dynamic>;
            final List<double> d = p.derived.joints[name]!;
            for (int a = 0; a < 3; a++) {
              deltas.add((d[a] - (r[a] as num).toDouble()).abs());
            }
          }
          allJointDeltas.addAll(deltas);
          final List<double> sorted = List<double>.of(deltas)..sort();
          final double jMedian = sorted[sorted.length ~/ 2];
          final double jMean =
              deltas.reduce((double a, double b) => a + b) / deltas.length;
          final double jMax = sorted.last;
          final double rootYDelta =
              (p.derived.rootY - (row['rootY'] as num).toDouble()).abs();
          final double rootPitchDelta =
              (p.derived.rootPitch - (row['rootPitch'] as num).toDouble())
                  .abs();
          worstIou = iou < worstIou ? iou : worstIou;
          worstKpXy = kpXyMean > worstKpXy ? kpXyMean : worstKpXy;
          worstKpZ = kpZMean > worstKpZ ? kpZMean : worstKpZ;
          worstScaleRel = scaleRel > worstScaleRel ? scaleRel : worstScaleRel;
          worstRootY = rootYDelta > worstRootY ? rootYDelta : worstRootY;
          worstRootPitch = rootPitchDelta > worstRootPitch
              ? rootPitchDelta
              : worstRootPitch;
          results.add(<String, dynamic>{
            'id': id,
            'iou': _r(iou, 4),
            'kpXyMeanPx': _r(kpXyMean, 3),
            'kpZMeanM': _r(kpZMean, 4),
            'scaleRel': _r(scaleRel, 5),
            'rootYDelta': _r(rootYDelta, 4),
            'rootPitchDeltaDeg': _r(rootPitchDelta, 2),
            'jointMedianDeg': _r(jMedian, 2),
            'jointMeanDeg': _r(jMean, 2),
            'jointMaxDeg': _r(jMax, 2),
          });
        }
      } finally {
        engine.close();
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      }
      final List<double> allSorted = List<double>.of(allJointDeltas)..sort();
      final double overallMedian = allSorted[allSorted.length ~/ 2];
      final double overallMean =
          allSorted.reduce((double a, double b) => a + b) / allSorted.length;
      final Map<String, dynamic> report = <String, dynamic>{
        'at': DateTime.now().toUtc().toIso8601String(),
        'reference': 'docs/qa/pose3d-consistency-reference.json',
        'model': 'rtmw3d-x-fp16.onnx + yolox_tiny.onnx',
        'images': results.length,
        'results': results,
        'aggregate': <String, dynamic>{
          'worstIou': _r(worstIou, 4),
          'worstKpXyMeanPx': _r(worstKpXy, 3),
          'worstKpZMeanM': _r(worstKpZ, 4),
          'worstScaleRel': _r(worstScaleRel, 5),
          'worstRootYDelta': _r(worstRootY, 4),
          'worstRootPitchDeltaDeg': _r(worstRootPitch, 2),
          'jointMedianDeg': _r(overallMedian, 2),
          'jointMeanDeg': _r(overallMean, 2),
          'jointMaxDeg': _r(allSorted.last, 2),
          'jointP90Deg': _r(allSorted[(allSorted.length * 0.9).floor()], 2),
        },
        'criteria': <String, dynamic>{
          'iouMin': 0.98,
          'kpXyMeanPxMax': 1.5,
          'kpZMeanMMax': 0.02,
          // 尺度为骨长中位数估计：cv2 与 Dart `image` 的 JPEG 解码差异会引入
          // 约 1px 关键点偏移 → 短骨 dxy 敏感（实测最大 2.8%）；对关节角影响
          // 极小（全体中位数 0.32°），故取 5%。
          'scaleRelMax': 0.05,
          'rootYDeltaMax': 0.01,
          'rootPitchDeltaDegMax': 3.0,
          'jointMedianDegMax': 5.0,
          'jointMeanDegMax': 5.0,
          'jointP90DegMax': 10.0,
        },
        'instability':
            'solve_limb 的离散扫描 + 限位罚项存在多个近等价值：输入方向差 0.4° 即可切换'
            '最小值（Python 自对自复现 shoulder_r.ry Δ43.3°），故关节以中位数断言，'
            '均值/最大值仅记录（D141 偏差登记）。',
      };
      final File out = File('../docs/qa/pose3d-consistency-report.json');
      await out.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      );
      for (final Map<String, dynamic> r in results) {
        // ignore: avoid_print
        print(
          '[pose3d] ${r['id']} IoU ${r['iou']} kpXY ${r['kpXyMeanPx']}px '
          'kpZ ${r['kpZMeanM']}m scale ${r['scaleRel']} '
          'rootY Δ${r['rootYDelta']} rootPitch Δ${r['rootPitchDeltaDeg']}° '
          'joint ${r['jointMedianDeg']}/${r['jointMeanDeg']}/${r['jointMaxDeg']}°(med/mean/max)',
        );
      }
      // ignore: avoid_print
      print('[pose3d] 汇总 ${report['aggregate']}');
      expect(worstIou, greaterThanOrEqualTo(0.98));
      expect(worstKpXy, lessThanOrEqualTo(1.5));
      expect(worstKpZ, lessThanOrEqualTo(0.02));
      expect(worstScaleRel, lessThanOrEqualTo(0.05));
      expect(worstRootY, lessThanOrEqualTo(0.01));
      expect(worstRootPitch, lessThanOrEqualTo(3.0));
      expect(overallMedian, lessThanOrEqualTo(5.0));
      // D141 门禁口径：均值 ≤5°、90% ≤10°（对 solve_limb 离散翻转鲁棒）。
      expect(overallMean, lessThanOrEqualTo(5.0));
      expect(
        allSorted[(allSorted.length * 0.9).floor()],
        lessThanOrEqualTo(10.0),
      );
    }, skip: run ? false : 'SS_POSE_ACCURACY=1 本机运行');
  });
}

double _r(double v, int digits) => double.parse(v.toStringAsFixed(digits));

/// Windows 上预加载 pub cache 的 onnxruntime.dll（插件构建时随 exe 拷贝）。
void _preloadOrtLibrary() {
  if (!Platform.isWindows) return;
  final String? localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData == null) return;
  final File dll = File(
    '$localAppData\\Pub\\Cache\\hosted\\pub.dev\\onnxruntime-1.4.1\\windows\\onnxruntime.dll',
  );
  if (dll.existsSync()) {
    DynamicLibrary.open(dll.path);
  }
}

double _iou(
  double ax1,
  double ay1,
  double ax2,
  double ay2,
  double bx1,
  double by1,
  double bx2,
  double by2,
) {
  final double xx1 = ax1 > bx1 ? ax1 : bx1;
  final double yy1 = ay1 > by1 ? ay1 : by1;
  final double xx2 = ax2 < bx2 ? ax2 : bx2;
  final double yy2 = ay2 < by2 ? ay2 : by2;
  final double w = (xx2 - xx1).clamp(0, double.infinity);
  final double h = (yy2 - yy1).clamp(0, double.infinity);
  final double inter = w * h;
  final double areaA = (ax2 - ax1) * (ay2 - ay1);
  final double areaB = (bx2 - bx1) * (by2 - by1);
  return inter / (areaA + areaB - inter);
}
