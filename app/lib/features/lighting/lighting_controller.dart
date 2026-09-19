import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/utils/json_utils.dart';
import '../../services/content_packs.dart';
import 'hand_presets.dart';
import 'lighting_models.dart';

/// 布光预演室状态。
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
    this.cameraSeq = 0,
    this.handL = const HandPoseState(),
    this.handR = const HandPoseState(),
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

  /// V6/D105：机位变更序号（触发引擎即时同步）。
  final int cameraSeq;

  /// V5/D86 手部姿态（左右独立）。
  final HandPoseState handL;
  final HandPoseState handR;

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
    int? cameraSeq,
    HandPoseState? handL,
    HandPoseState? handR,
  }) {
    return LightingState(
      scene: scene ?? this.scene,
      selectedId:
          selectedId == _sentinel ? this.selectedId : selectedId as String?,
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
      cameraSeq: cameraSeq ?? this.cameraSeq,
      handL: handL ?? this.handL,
      handR: handR ?? this.handR,
    );
  }

  static const Object _sentinel = Object();
}

final lightingControllerProvider =
    NotifierProvider<LightingController, LightingState>(LightingController.new);

class LightingController extends Notifier<LightingState> {
  static const Uuid _uuid = Uuid();
  late final AppDatabase _db = ref.read(databaseProvider);

  @override
  LightingState build() {
    return LightingState(
      scene: LightingSceneData(
          id: _uuid.v4(), name: '未命名布光方案', devices: <DeviceSpec>[]),
    );
  }

  /// 初始化：优先载入最近保存的方案；否则用三点布光预设起手。
  Future<void> init() async {
    if (state.initialized) return;
    await _loadQualitySettings();
    final rows = await (_db.select(_db.lightingScenes)
          ..orderBy(<OrderClauseGenerator<$LightingScenesTable>>[
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .get();
    LightingSceneData scene;
    if (rows.isNotEmpty) {
      scene = LightingSceneData.fromJson(
        (jsonDecode(rows.first.sceneJson) as Map).cast<String, Object?>(),
      );
      final (HandPoseState?, HandPoseState?) hands = handsFromJson(scene.hands);
      state = state.copyWith(
        scene: scene,
        initialized: true,
        ambientEnabled: scene.ambientEnabled,
        handL: hands.$1 ?? state.handL,
        handR: hands.$2 ?? state.handR,
        status: '已载入「${scene.name}」',
      );
      return;
    }
    final presets = await ContentPacks.lightPresets();
    final threePoint = presets.firstWhere(
      (LightPresetEntry p) => p.id == 'three-point',
      orElse: () => presets.first,
    );
    scene = LightingSceneData(
      id: _uuid.v4(),
      name: '三点布光方案',
      devices: instantiatePresetDevices(threePoint.devices),
    );
    state = state.copyWith(
        scene: scene, initialized: true, dirty: true, status: '已应用预设：三点布光');
  }

  /// D29：从策划案「打开预演」直接载入指定布光场景。
  Future<void> openScene(String sceneId) async {
    final rows = await (_db.select(_db.lightingScenes)
          ..where((t) => t.id.equals(sceneId)))
        .get();
    if (rows.isEmpty) {
      state = state.copyWith(status: '布光场景不存在或已删除');
      return;
    }
    final Map<String, Object?> sceneJson =
        (jsonDecode(rows.first.sceneJson) as Map).cast<String, Object?>();
    final LightingSceneData scene = LightingSceneData.fromJson(sceneJson);
    final (HandPoseState?, HandPoseState?) hands = handsFromJson(scene.hands);
    state = state.copyWith(
      scene: scene,
      initialized: true,
      dirty: false,
      selectedId: null,
      ambientEnabled: scene.ambientEnabled,
      handL: hands.$1 ?? state.handL,
      handR: hands.$2 ?? state.handR,
      status: '已载入「${scene.name}」',
    );
  }

  void setView(String mode) => state = state.copyWith(viewMode: mode);

  void setLinkage(bool on) => state = state.copyWith(linkage: on);

  void select(String? id) => state = state.copyWith(selectedId: id);

  void renameScene(String name) {
    state.scene.name = name;
    state = state.copyWith(dirty: true);
  }

  Future<void> applyPreset(LightPresetEntry preset) async {
    state = state.copyWith(
      scene: LightingSceneData(
        id: state.scene.id,
        name: '${preset.name}方案',
        devices: instantiatePresetDevices(preset.devices),
        width: state.scene.width,
        depth: state.scene.depth,
        height: state.scene.height,
      ),
      selectedId: null,
      dirty: true,
      status: '已应用预设：${preset.name}',
    );
  }

  bool _belowLimit() =>
      state.scene.devices.length < LightingSceneData.maxDevices;

  void addLight({String type = 'hard', String name = ''}) {
    if (!_belowLimit()) return;
    final index = state.scene.lights.length + 1;
    final device = DeviceSpec(
      id: _uuid.v4(),
      kind: 'light',
      name: name.isEmpty ? '灯光 $index' : name,
      type: type,
      x: index.isEven ? 1.4 : -1.4,
      y: index % 3 == 0 ? 0.6 : -1.8,
      height: 1.9,
      intensity: 70,
      kelvin: 5500,
      beamAngle: 45,
      softness: 0.15,
      fixture: 'cob-600d',
      modifier: 'bare',
    );
    state.scene.devices.add(device);
    state = state.copyWith(selectedId: device.id, dirty: true);
  }

  /// 从设备库一键放入布光场景（D20：带真实光型参数）。
  void addLightFromGear({
    required String name,
    required double powerW,
    required String cct,
    required int cri,
    String mount = '',
    String type = '',
  }) {
    if (!_belowLimit()) return;
    final isFlash = type.contains('闪光') || type.contains('环闪');
    final singleCct = RegExp(r'^(\d{4})K').firstMatch(cct);
    final kelvin =
        singleCct != null ? int.tryParse(singleCct.group(1)!) ?? 5500 : 5500;
    final device = DeviceSpec(
      id: _uuid.v4(),
      kind: 'light',
      name: name,
      type: isFlash ? 'hard' : (powerW >= 300 ? 'hard' : 'soft'),
      x: 1.6,
      y: -1.8,
      height: 2.0,
      intensity: powerW >= 300 ? 80 : 65,
      kelvin: kelvin,
      beamAngle: 45,
      softness: isFlash ? 0.1 : 0.2,
      fixture: isFlash ? 'strobe-400' : 'cob-600d',
      modifier: 'standard-reflector',
      note:
          '${powerW.toStringAsFixed(0)}W · $cct · CRI $cri${mount.isEmpty ? '' : ' · $mount'}',
    );
    state.scene.devices.add(device);
    state = state.copyWith(
        selectedId: device.id, dirty: true, status: '已从设备库放入：$name');
  }

  /// 上传道具/灯光贴图（dataURL）。
  void setSelectedTexture(String dataUrl) {
    final d = state.selected;
    if (d == null) return;
    d.texture = dataUrl;
    state = state.copyWith(
        dirty: true, status: dataUrl.isEmpty ? '已移除贴图' : '已应用自定义贴图');
  }

  void addProp({String type = 'crate'}) {
    if (!_belowLimit()) return;
    final device = DeviceSpec(
      id: _uuid.v4(),
      kind: 'prop',
      name: const <String, String>{
            'sofa': '沙发',
            'umbrella': '透明伞',
            'crate': '箱体',
            'backdrop': '背景布',
            'reflector': '反光板',
            'bouquet': '花束',
          }[type] ??
          '道具',
      type: type,
      x: 1.2,
      y: 1.2,
    );
    state.scene.devices.add(device);
    state = state.copyWith(selectedId: device.id, dirty: true);
  }

  void removeSelected() {
    final id = state.selectedId;
    if (id == null) return;
    state.scene.devices.removeWhere((DeviceSpec d) => d.id == id);
    state = state.copyWith(selectedId: null, dirty: true);
  }

  void clearAll() {
    state.scene.devices.clear();
    state = state.copyWith(selectedId: null, dirty: true, status: '已清空为空影棚');
  }

  /// 修改选中设备的字段并标记脏。
  void updateSelected(void Function(DeviceSpec d) mutate) {
    final d = state.selected;
    if (d == null) return;
    mutate(d);
    state = state.copyWith(dirty: true);
  }

  /// 俯视图拖动（画布坐标，米）。
  void moveDevice(String id, double x, double y) {
    for (final DeviceSpec d in state.scene.devices) {
      if (d.id == id) {
        d.x = x;
        d.y = y;
        break;
      }
    }
    state = state.copyWith(dirty: true);
  }

  /// 3D 引擎内拖动回传（联动时调用）。
  void applyEngineMove({
    List<Map<String, Object?>>? lights,
    List<Map<String, Object?>>? props,
  }) {
    if (!state.linkage) return;
    bool changed = false;
    for (final Map<String, Object?> item
        in lights ?? const <Map<String, Object?>>[]) {
      final id = item['id'] as String?;
      for (final DeviceSpec d in state.scene.devices) {
        if (d.id == id) {
          d.x = (item['x'] as num?)?.toDouble() ?? d.x;
          d.y = (item['y'] as num?)?.toDouble() ?? d.y;
          if (item['rotationY'] != null) {
            d.rotation = (item['rotationY'] as num).toDouble();
          }
          changed = true;
        }
      }
    }
    for (final Map<String, Object?> item
        in props ?? const <Map<String, Object?>>[]) {
      final id = item['id'] as String?;
      for (final DeviceSpec d in state.scene.devices) {
        if (d.id == id) {
          d.x = (item['x'] as num?)?.toDouble() ?? d.x;
          d.y = (item['y'] as num?)?.toDouble() ?? d.y;
          changed = true;
        }
      }
    }
    if (changed) state = state.copyWith(dirty: true);
  }

  /// 保存到工作区数据库（策划案可引用）。
  Future<bool> save() async {
    state.scene.name =
        state.scene.name.trim().isEmpty ? '未命名布光方案' : state.scene.name;
    await _db.into(_db.lightingScenes).insertOnConflictUpdate(
          LightingScenesCompanion.insert(
            id: state.scene.id,
            name: state.scene.name,
            sceneJson: jsonEncode(state.scene.toJson()),
            linkedPoseId: const Value(null),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    state = state.copyWith(dirty: false, status: '已保存「${state.scene.name}」');
    return true;
  }

  /// 从摆姿库注入姿势（D6：姿势一键注入布光预演 3D 场景；V5 支持随姿势带入手部）。
  void injectPose(Map<String, Object?> joints, String poseName,
      {HandPoseState? handL, HandPoseState? handR}) {
    final merged = <String, Object?>{
      ...joints,
      'rootY': joints['rootY'],
      'rootPitch': joints['rootPitch'],
    };
    state = state.copyWith(
      pendingPose: merged,
      basePose: Map<String, Object?>.of(merged),
      poseInjectionSeq: state.poseInjectionSeq + 1,
      viewMode: 'split',
      handL: handL ?? state.handL,
      handR: handR ?? state.handR,
      status: '已注入姿势：$poseName',
    );
    _syncSceneHands();
  }

  /// 关节微调（A3）：更新 pendingPose；引擎侧由页面用 bridge.setJoint 实时反馈。
  void adjustPendingJoint(String joint, String axis, double value) {
    final pose = state.pendingPose;
    if (pose == null) return;
    final joints = Map<String, Object?>.of(pose);
    final List<double> axes = tripleOf(joints[joint]);
    final int index = switch (axis) { 'rx' => 0, 'ry' => 1, _ => 2 };
    axes[index] = value;
    joints[joint] = <double>[axes[0], axes[1], axes[2]];
    state = state.copyWith(pendingPose: joints, status: '关节微调：$joint');
  }

  /// 恢复注入时的原始关节。
  void resetPendingJoints() {
    final base = state.basePose;
    if (base == null) return;
    state = state.copyWith(
        pendingPose: Map<String, Object?>.of(base), status: '已恢复注入姿势');
  }

  // ---------------- V4/Q1 画质设置（持久化） ----------------

  Future<void> _loadQualitySettings() async {
    final int subdivision =
        int.tryParse(await _db.getSetting('quality_subdivision') ?? '') ?? 1;
    final String preset =
        await _db.getSetting('quality_material_preset') ?? 'standard';
    final double env =
        double.tryParse(await _db.getSetting('quality_env_intensity') ?? '') ??
            1.0;
    final bool ambient =
        (await _db.getSetting('quality_ambient_enabled') ?? '1') != '0';
    final bool contact =
        (await _db.getSetting('quality_contact_shadow') ?? '1') != '0';
    final String performance =
        await _db.getSetting('quality_performance_profile') ?? 'auto';
    final bool cones =
        (await _db.getSetting('quality_light_cones') ?? '0') == '1';
    state = state.copyWith(
      subdivisionLevel: subdivision.clamp(0, 2),
      materialPreset: preset,
      envIntensity: env.clamp(0.0, 2.0),
      ambientEnabled: ambient,
      contactShadow: contact,
      performanceProfile:
          const <String>['auto', 'high', 'low'].contains(performance)
              ? performance
              : 'auto',
      lightCones: cones,
    );
  }

  /// 细分等级：0 轻量 / 1 标准 / 2 高（R18/R26：保留原模型为轻量模式）。
  Future<void> setSubdivision(int level) async {
    final int v = level.clamp(0, 2);
    state = state.copyWith(
        subdivisionLevel: v,
        status: '细分等级：${const <String>['轻量', '标准', '高'][v]}');
    await _db.setSetting('quality_subdivision', '$v');
  }

  Future<void> setMaterialPreset(String preset) async {
    state = state.copyWith(
        materialPreset: preset, status: '材质预设：${_presetLabel(preset)}');
    await _db.setSetting('quality_material_preset', preset);
  }

  Future<void> setEnvIntensity(double value) async {
    final double v = value.clamp(0.0, 2.0);
    state = state.copyWith(envIntensity: v);
    await _db.setSetting('quality_env_intensity', v.toStringAsFixed(2));
  }

  static String _presetLabel(String preset) => switch (preset) {
        'realistic' => '写实',
        'light' => '轻量',
        _ => '标准',
      };

  // ---------------- V5/D85 环境光 ----------------

  /// 环境光开关（关 = 半球光 + 环境贴图贡献全部关闭，仅留摄影灯具）。
  Future<void> setAmbientEnabled(bool on) async {
    state.scene.ambientEnabled = on;
    state = state.copyWith(
      ambientEnabled: on,
      dirty: true,
      status: on ? '环境光已开启' : '环境光已关闭（仅摄影灯具照明）',
    );
    await _db.setSetting('quality_ambient_enabled', on ? '1' : '0');
  }

  // ---------------- V6/D111 光锥可视化 ----------------

  /// 光锥可视化开关（展示每盏灯的照射范围；性能可退回，R52）。
  Future<void> setLightCones(bool on) async {
    state =
        state.copyWith(lightCones: on, status: on ? '光锥可视化已开启' : '光锥可视化已关闭');
    await _db.setSetting('quality_light_cones', on ? '1' : '0');
  }

  // ---------------- V6/D105 相机机位 ----------------

  /// 相机 POV 预览开关（引擎侧 setCameraView）。
  void setCameraView(bool on) => state = state.copyWith(
        cameraView: on,
        status: on ? '已切到相机视角（看构图）' : '已返回自由视角',
      );

  /// 俯视图拖动相机机位。
  void moveCamera(double x, double y) {
    state.scene.camera
      ..x = x
      ..y = y;
    state = state.copyWith(dirty: true, cameraSeq: state.cameraSeq + 1);
  }

  /// 修改机位参数（高度/俯仰/偏航/焦段/启用）。
  void updateCamera(void Function(CameraRigData c) mutate) {
    mutate(state.scene.camera);
    state = state.copyWith(dirty: true, cameraSeq: state.cameraSeq + 1);
  }

  // ---------------- V6/D104 性能档 ----------------

  /// 性能档：auto（自动探测）| high | low（关接触阴影/降阴影分辨率/限制细分/降渲染分辨率）。
  Future<void> setPerformanceProfile(String profile) async {
    final String value = const <String>['auto', 'high', 'low'].contains(profile)
        ? profile
        : 'auto';
    state = state.copyWith(
      performanceProfile: value,
      status: switch (value) {
        'low' => '性能优先：已降低渲染质量',
        'high' => '画质优先：已开启完整效果',
        _ => '性能档：自动',
      },
    );
    await _db.setSetting('quality_performance_profile', value);
  }

  // ---------------- V5/D91 接触阴影 ----------------

  /// 接触阴影开关（仅 realistic 预设生效；性能退路，R38）。
  Future<void> setContactShadow(bool on) async {
    state = state.copyWith(
      contactShadow: on,
      status: on ? '接触阴影已开启（写实预设）' : '接触阴影已关闭',
    );
    await _db.setSetting('quality_contact_shadow', on ? '1' : '0');
  }

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
            pose ?? state.basePose ?? <String, Object?>{});
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
        poseInjectionSeq:
            pose == null ? state.poseInjectionSeq : state.poseInjectionSeq + 1,
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
              handR: next, dirty: true, status: '手部预设：${preset.label}')
          : state.copyWith(
              handL: next, dirty: true, status: '手部预设：${preset.label}');
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
    final HandPoseState next =
        current.copyWith(preset: 'custom', spread: value.clamp(0, 1));
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

  void requestCapture() =>
      state = state.copyWith(captureSeq: state.captureSeq + 1);

  void setStatus(String status) => state = state.copyWith(status: status);
}
