import '../../features/poses/pose_landmark_math.dart';

/// 接地校准结果。
class GroundedPose {
  const GroundedPose({
    required this.rootY,
    required this.rootPitch,
    required this.feetVisible,
    required this.note,
  });

  final double rootY;
  final double rootPitch;
  final bool feetVisible;
  final String note;
}

/// 接地校准（合同 §3.D.2）：rootY 相对脚部最低点；
/// 脚部不可见（遮挡/裁切）时退化为站立基准并在结果中标注（不静默）。
class PoseGrounding {
  PoseGrounding._();

  /// BlazePose 脚部关键点（ankle/heel/foot）。
  static const List<int> footLandmarkIndices = <int>[27, 28, 29, 30, 31, 32];

  static const double feetVisibilityThreshold = 0.5;

  static GroundedPose ground({
    required DerivedPose derived,
    required List<double> landmarkVisibility,
    String category = '',
  }) {
    var maxFoot = 0.0;
    for (final int idx in footLandmarkIndices) {
      if (idx >= landmarkVisibility.length) continue;
      if (landmarkVisibility[idx] > maxFoot) maxFoot = landmarkVisibility[idx];
    }
    final bool feetVisible = maxFoot >= feetVisibilityThreshold;
    if (!feetVisible) {
      return GroundedPose(
        rootY: 0,
        rootPitch: derived.rootPitch,
        feetVisible: false,
        note:
            '脚部不可见（visibility ${maxFoot.toStringAsFixed(2)}）：'
            '按站立基准接地（rootY=0），可手动微调',
      );
    }
    if (category == '躺姿') {
      return GroundedPose(
        rootY: derived.rootY,
        rootPitch: derived.rootPitch,
        feetVisible: true,
        note: '躺姿：rootPitch 由面部朝向收敛',
      );
    }
    return GroundedPose(
      rootY: derived.rootY,
      rootPitch: derived.rootPitch,
      feetVisible: true,
      note: '',
    );
  }
}
