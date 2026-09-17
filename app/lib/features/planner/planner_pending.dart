import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 待插入策划案的姿势（摆姿库 →「加入策划案」暂存区）。
class PendingPose {
  const PendingPose({
    required this.name,
    required this.joints,
    this.lens = '',
    this.cameraPosition = '',
    this.photo = '',
    this.author = '',
    this.license = '',
    this.source = '',
  });

  final String name;
  final Map<String, Object?> joints;
  final String lens;
  final String cameraPosition;

  /// V4/R25：实拍照片与署名（导出默认照片渲染，可切换骨架示意）。
  final String photo;
  final String author;
  final String license;
  final String source;

  Map<String, Object?> toModuleEntry() => <String, Object?>{
        'name': name,
        'joints': joints,
        'lens': lens,
        'cameraPosition': cameraPosition,
        'photo': photo,
        'author': author,
        'license': license,
        'source': source,
      };
}

final pendingPosesProvider =
    StateNotifierProvider<PendingPosesNotifier, List<PendingPose>>(
  (ref) => PendingPosesNotifier(),
);

class PendingPosesNotifier extends StateNotifier<List<PendingPose>> {
  PendingPosesNotifier() : super(const <PendingPose>[]);

  void add(PendingPose pose) {
    if (state.any((PendingPose p) => p.name == pose.name)) return;
    state = <PendingPose>[...state, pose];
  }

  void removeAt(int index) {
    final list = <PendingPose>[...state]..removeAt(index);
    state = list;
  }

  void clear() => state = const <PendingPose>[];
}
