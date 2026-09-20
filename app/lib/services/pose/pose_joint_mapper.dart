import '../../features/poses/pose_landmark_math.dart';

/// 映射后的姿势数据（12 关节 + 接地变换 + 置信度）。
class MappedPose {
  const MappedPose({
    required this.joints,
    required this.rootY,
    required this.rootPitch,
    required this.jointConfidence,
    required this.lowConfidence,
    required this.warnings,
  });

  final Map<String, List<double>> joints;
  final double rootY;
  final double rootPitch;
  final Map<String, double> jointConfidence;
  final bool lowConfidence;
  final List<String> warnings;

  /// 可存入姿势库的 JSON（与内置 poses3 条目同构）。
  Map<String, Object?> toPoseJson() => <String, Object?>{
    ...joints,
    'rootY': rootY,
    'rootPitch': rootPitch,
  };
}

/// 33 点 world landmarks → 12 关节（D125：低置信标注「仅供参考」）。
///
/// 与 Python 管线共用同一套公式（`pose_landmark_math.deriveJoints`）。
class PoseJointMapper {
  PoseJointMapper._();

  static const double confidenceThreshold = 0.5;

  /// [jointConfidence] 由 `PoseDetectorService.jointVisibility` 生成。
  static MappedPose map(
    List<List<double>> world, {
    Map<String, double> jointConfidence = const <String, double>{},
    String category = '',
  }) {
    if (world.length < 33) {
      throw ArgumentError('world landmarks 不足 33 点（实际 ${world.length}）');
    }
    final DerivedPose derived = deriveJoints(world, category: category);
    final List<String> lowJoints = jointConfidence.entries
        .where((MapEntry<String, double> e) => e.value < confidenceThreshold)
        .map((MapEntry<String, double> e) => e.key)
        .toList();
    return MappedPose(
      joints: derived.joints,
      rootY: derived.rootY,
      rootPitch: derived.rootPitch,
      jointConfidence: jointConfidence,
      lowConfidence: lowJoints.isNotEmpty,
      warnings: lowJoints.isEmpty
          ? const <String>[]
          : <String>['低置信关节：${lowJoints.join('、')}（结果仅供参考，可手动微调）'],
    );
  }
}
