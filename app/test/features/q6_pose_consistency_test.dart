import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/poses/pose_landmark_math.dart';

/// 纯 Dart 一致性：Python world3d → Dart deriveJoints 是否复现 poses3.json 关节。
void main() {
  test('world3d → deriveJoints 与 poses3 一致', () {
    final Map<String, Object?> poses3 =
        (jsonDecode(
                  File('assets/content/poses3/poses3.json').readAsStringSync(),
                )
                as Map)
            .cast<String, Object?>();
    final List<Object?> poses = poses3['poses'] as List<Object?>;
    final List<double> errors = <double>[];
    var maxErr = 0.0;
    String worst = '';
    for (final Object? raw in poses) {
      final Map<String, Object?> pose = (raw as Map).cast<String, Object?>();
      final String skeleton = '${pose['skeleton']}';
      final File file = File(skeleton);
      if (!file.existsSync()) continue;
      final Map<String, Object?> skel =
          (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
      final List<List<double>> world = (skel['world3d'] as List<Object?>)
          .map(
            (Object? p) => (p as List<Object?>)
                .map((Object? v) => (v as num).toDouble())
                .toList(),
          )
          .toList();
      final DerivedPose derived = deriveJoints(
        world,
        category: '${pose['category'] ?? ''}',
      );
      final Map<String, Object?> expected = (pose['joints'] as Map)
          .cast<String, Object?>();
      for (final MapEntry<String, Object?> entry in expected.entries) {
        final List<double> exp = (entry.value as List)
            .map((Object? v) => (v as num).toDouble())
            .toList();
        final List<double> act = derived.joints[entry.key]!;
        for (int axis = 0; axis < 3; axis++) {
          final double err = (exp[axis] - act[axis]).abs();
          errors.add(err);
          if (err > maxErr) {
            maxErr = err;
            worst =
                '${pose['id']} ${entry.key}[$axis] '
                'exp=${exp[axis]} act=${act[axis]}';
          }
        }
      }
    }
    errors.sort();
    final double mean =
        errors.reduce((double a, double b) => a + b) / errors.length;
    final double p90 = errors[(errors.length * 0.9).floor()];
    // ignore: avoid_print
    print(
      'world3d→Dart：n=${errors.length} mean=${mean.toStringAsFixed(3)} '
      'p90=${p90.toStringAsFixed(3)} max=${maxErr.toStringAsFixed(3)} '
      'worst=$worst',
    );
    expect(mean, lessThan(0.5), reason: 'Dart 移植与 Python 应有数值一致性');
  });
}
