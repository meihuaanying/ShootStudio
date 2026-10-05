part of 'lighting_controller.dart';

/// V5/D86–D88 手部动作：预设 / 曲指 / 展开度 / 从姿势反填。
///
/// 从 lighting_controller.dart 拆出（R73 600 行红线）。混淀而不用 extension：
/// riverpod 的 `state` 标了 @protected，extension 访问会报
/// invalid_use_of_protected_member（--fatal-infos 下直接抦门禁），
/// 而 mixin 在类的继承链上、方法原样归属于 LightingController。
mixin _LightingHands on Notifier<LightingState> {
  // ---------------- V5/D86–D88 手部动作 ----------------

  void _syncSceneHands() {
    state.scene.hands = handsToJson(state.handL, state.handR);
  }

  /// 应用手部预设；[side] 取 'l' | 'r' | 'both'；双手组合预设会同时写入左右手并叠加手臂。
  void setHandPreset(String side, String presetId) {
    final HandPresetInfo? preset = handPresetById(presetId);
    if (preset == null) return;
    if (preset.dual) {
      final HandPoseState next = HandPoseState(
        preset: preset.id,
        curls: preset.curls,
        spread: preset.spread,
        wrist: preset.wrist,
      );
      Map<String, Object?>? pose = state.pendingPose;
      final Map<String, Map<String, List<double>>>? arms = preset.arms;
      if (arms != null) {
        final Map<String, Object?> base = Map<String, Object?>.of(
          pose ?? state.basePose ?? <String, Object?>{},
        );
        arms.forEach((String s, Map<String, List<double>> joints) {
          joints.forEach((String joint, List<double> value) {
            base['${joint}_$s'] = List<double>.of(value);
          });
        });
        pose = base;
      }
      state = state.copyWith(
        handL: next,
        handR: next.copyWith(wrist: preset.wrist),
        pendingPose: pose,
        basePose: state.basePose ?? pose,
        poseInjectionSeq: pose == null
            ? state.poseInjectionSeq
            : state.poseInjectionSeq + 1,
        dirty: true,
        status: '手部预设：${preset.label}',
      );
    } else {
      final HandPoseState next = HandPoseState(
        preset: preset.id,
        curls: preset.curls,
        spread: preset.spread,
        wrist: preset.wrist,
      );
      state = side == 'r'
          ? state.copyWith(
              handR: next,
              dirty: true,
              status: '手部预设：${preset.label}',
            )
          : state.copyWith(
              handL: next,
              dirty: true,
              status: '手部预设：${preset.label}',
            );
    }
    _syncSceneHands();
  }

  /// 每指微调（finger: thumb/index/middle/ring/pinky；value 0..1）。
  void setHandCurl(String side, String finger, double value) {
    final HandPoseState current = side == 'r' ? state.handR : state.handL;
    final Map<String, double> curls = Map<String, double>.of(current.curls);
    curls[finger] = value.clamp(0, 1);
    final HandPoseState next = current.copyWith(preset: 'custom', curls: curls);
    state = side == 'r'
        ? state.copyWith(handR: next, dirty: true, status: '手部微调：$finger')
        : state.copyWith(handL: next, dirty: true, status: '手部微调：$finger');
    _syncSceneHands();
  }

  /// 张开度（0..1）。
  void setHandSpread(String side, double value) {
    final HandPoseState current = side == 'r' ? state.handR : state.handL;
    final HandPoseState next = current.copyWith(
      preset: 'custom',
      spread: value.clamp(0, 1),
    );
    state = side == 'r'
        ? state.copyWith(handR: next, dirty: true)
        : state.copyWith(handL: next, dirty: true);
    _syncSceneHands();
  }

  /// 重置双手为自然放松。
  void resetHands() {
    state = state.copyWith(
      handL: const HandPoseState(),
      handR: const HandPoseState(),
      dirty: true,
      status: '手部已重置',
    );
    _syncSceneHands();
  }

  /// 从姿势条目携带的手部状态写入（导入姿势/载入场景）。
  void applyHandsFromPose(HandPoseState? l, HandPoseState? r) {
    if (l == null && r == null) return;
    state = state.copyWith(
      handL: l ?? state.handL,
      handR: r ?? state.handR,
      dirty: true,
    );
    _syncSceneHands();
  }
}
