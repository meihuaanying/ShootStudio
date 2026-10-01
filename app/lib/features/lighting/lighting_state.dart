// V8/S6 · D152：布光状态（场景 + 选中 + 引擎同步用的序号 + 撤销标记）。
// 从 lighting_controller.dart 拆出（R73 行数门禁）；controller 通过 export 继续对外暴露，
// 因此既有 `import 'lighting_controller.dart'` 的调用方无需改动。

import '../../services/content_packs.dart';
import 'lighting_models.dart';

class LightingState {
  const LightingState({
    required this.scene,
    this.selectedId,
    this.linkage = true,
    this.viewMode = 'split',
    this.dirty = false,
    this.status = '',
    this.pendingPose,
    this.basePose,
    this.poseInjectionSeq = 0,
    this.captureSeq = 0,
    this.initialized = false,
    this.subdivisionLevel = 1,
    this.materialPreset = 'standard',
    this.envIntensity = 1.0,
    this.ambientEnabled = true,
    this.contactShadow = true,
    this.performanceProfile = 'auto',
    this.cameraView = false,
    this.lightCones = false,
    this.softShadows = true,
    this.cameraSeq = 0,
    this.handL = const HandPoseState(),
    this.handR = const HandPoseState(),
    this.undoSeq = 0,
    this.canUndo = false,
    this.canRedo = false,
  });

  final LightingSceneData scene;
  final String? selectedId;

  /// 俯视图 ↔ 3D 双向联动开关（D5：可解耦）。
  final bool linkage;

  /// top | scene3d | split。
  final String viewMode;
  final bool dirty;
  final String status;

  /// 从姿势库注入的姿势（关节角 JSON + 名称）。
  final Map<String, Object?>? pendingPose;

  /// 注入时的原始关节（用于「恢复注入姿势」）。
  final Map<String, Object?>? basePose;
  final int poseInjectionSeq;

  /// 请求截图（序号变化触发）。
  final int captureSeq;

  final bool initialized;

  /// V4/Q1 画质：细分等级（0 轻量 / 1 标准 / 2 高）。
  final int subdivisionLevel;

  /// V4/Q1 材质预设：standard | realistic | light。
  final String materialPreset;

  /// V4/Q1 环境反射强度。
  final double envIntensity;

  /// V5/D85 环境光开关（关 = 半球光 + 环境贴图贡献全部关闭）。
  final bool ambientEnabled;

  /// V5/D91 接触阴影开关（仅 realistic 预设生效；默认开）。
  final bool contactShadow;

  /// V6/D104 性能档：auto（自动探测）| high | low。
  final String performanceProfile;

  /// V6/D105：相机 POV 预览开关（瞬态，不持久化）。
  final bool cameraView;

  /// V6/D111：光锥可视化开关（持久化）。
  final bool lightCones;

  /// V7/D137：软阴影（VSM）开关（持久化；低配档引擎自动回退 PCF）。
  final bool softShadows;

  /// V6/D105：机位变更序号（触发引擎即时同步）。
  final int cameraSeq;

  /// V5/D86 手部姿态（左右独立）。
  final HandPoseState handL;
  final HandPoseState handR;

  /// V8/D152：撤销/重做序号（变化 → 页面重新下发 applyScene）与可用状态。
  final int undoSeq;
  final bool canUndo;
  final bool canRedo;

  DeviceSpec? get selected {
    final id = selectedId;
    if (id == null) return null;
    for (final DeviceSpec d in scene.devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  LightingState copyWith({
    LightingSceneData? scene,
    Object? selectedId = _sentinel,
    bool? linkage,
    String? viewMode,
    bool? dirty,
    String? status,
    Object? pendingPose = _sentinel,
    Object? basePose = _sentinel,
    int? poseInjectionSeq,
    int? captureSeq,
    bool? initialized,
    int? subdivisionLevel,
    String? materialPreset,
    double? envIntensity,
    bool? ambientEnabled,
    bool? contactShadow,
    String? performanceProfile,
    bool? cameraView,
    bool? lightCones,
    bool? softShadows,
    int? cameraSeq,
    HandPoseState? handL,
    HandPoseState? handR,
    int? undoSeq,
    bool? canUndo,
    bool? canRedo,
  }) {
    return LightingState(
      scene: scene ?? this.scene,
      selectedId: selectedId == _sentinel
          ? this.selectedId
          : selectedId as String?,
      linkage: linkage ?? this.linkage,
      viewMode: viewMode ?? this.viewMode,
      dirty: dirty ?? this.dirty,
      status: status ?? this.status,
      pendingPose: pendingPose == _sentinel
          ? this.pendingPose
          : pendingPose as Map<String, Object?>?,
      basePose: basePose == _sentinel
          ? this.basePose
          : basePose as Map<String, Object?>?,
      poseInjectionSeq: poseInjectionSeq ?? this.poseInjectionSeq,
      captureSeq: captureSeq ?? this.captureSeq,
      initialized: initialized ?? this.initialized,
      subdivisionLevel: subdivisionLevel ?? this.subdivisionLevel,
      materialPreset: materialPreset ?? this.materialPreset,
      envIntensity: envIntensity ?? this.envIntensity,
      ambientEnabled: ambientEnabled ?? this.ambientEnabled,
      contactShadow: contactShadow ?? this.contactShadow,
      performanceProfile: performanceProfile ?? this.performanceProfile,
      cameraView: cameraView ?? this.cameraView,
      lightCones: lightCones ?? this.lightCones,
      softShadows: softShadows ?? this.softShadows,
      cameraSeq: cameraSeq ?? this.cameraSeq,
      handL: handL ?? this.handL,
      handR: handR ?? this.handR,
      undoSeq: undoSeq ?? this.undoSeq,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }

  static const Object _sentinel = Object();
}

/// 撤销栈容量（D152：≥20 步，留出余量）。
const int kLightingUndoCapacity = 64;
