import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../services/content_packs.dart';
import '../../services/engine/engine_bridge.dart';
import '../poses/character_picker.dart';
import '../poses/poses_controller.dart';
import 'ab_compare.dart';
import 'camera_helpers.dart';
import 'lighting_controller.dart';
import 'lighting_files.dart';
import 'still_export.dart';
import 'widgets/lighting_ab_dialog.dart';
import 'widgets/lighting_inspector.dart';
import 'widgets/lighting_left_column.dart';
import 'widgets/lighting_workbench.dart';

part 'lighting_page_ab.dart';

/// M2 布光预演室：俯视灯位图 + 设备/道具清单 + 3D 实时预览（双轨制轨道一）。
class LightingPage extends ConsumerStatefulWidget {
  const LightingPage({super.key});

  @override
  ConsumerState<LightingPage> createState() => _LightingPageState();
}

class _LightingPageState extends ConsumerState<LightingPage> with _LightingPageAb {
  bool _skeleton = false;
  CharacterSelection _character = const CharacterSelection(
    characterId: '',
    characterName: '默认人物',
  );
  List<LightPresetEntry> _presets = <LightPresetEntry>[];
  bool _applyQueued = false;
  int _lastPoseSeq = 0;
  int _lastCaptureSeq = 0;
  int _lastSubdivision = -1;
  String _lastPreset = '';
  double _lastEnv = -1;
  String _lastPerformance = '';
  int _lastCameraSeq = 0;
  bool _warmQueued = false;
  // V8/S6 · D152：左栏折叠 + 画中画灯位图。
  bool _listCollapsed = false;
  bool _pip = true;
  // V7/D139：构图辅助（叠加显示，不进导出图）与相机辅助信息。
  CameraGuideSettings _guides = const CameraGuideSettings();
  double _assistDistance = 3.2;
  double _assistFocalDeg = 0;
  bool _assistDofAvailable = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
      _presets = await ContentPacks.lightPresets();
      if (mounted) setState(() {});
      await ref.read(lightingControllerProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _abSlots.dispose();
    _stillSession?.dispose();
    super.dispose();
  }

  void _queueApplyScene() {
    if (_applyQueued) return;
    _applyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _applyQueued = false;
      final state = ref.read(lightingControllerProvider);
      final joints = state.pendingPose;
      _bridge?.applyScene(
        state.scene.toEngineJson(poseJoints: joints, hands: state.scene.hands),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lightingControllerProvider);

    // 场景变化 → 引擎同步（联动/解耦由引擎侧 linkage 控制拖动回传）。
    ref.listen(lightingControllerProvider, (
      LightingState? prev,
      LightingState next,
    ) {
      if (!next.initialized) return;
      if (prev?.scene != next.scene || prev?.dirty != next.dirty) {
        _queueApplyScene();
      }
      if (next.poseInjectionSeq != _lastPoseSeq) {
        _lastPoseSeq = next.poseInjectionSeq;
        _queueApplyScene();
      }
      if (next.captureSeq != _lastCaptureSeq) {
        _lastCaptureSeq = next.captureSeq;
        _bridge?.capturePhoto();
      }
      // V4/Q1 画质同步。
      if (next.subdivisionLevel != _lastSubdivision) {
        _lastSubdivision = next.subdivisionLevel;
        _bridge?.setSubdivision(next.subdivisionLevel);
      }
      if (next.materialPreset != _lastPreset) {
        _lastPreset = next.materialPreset;
        _bridge?.setMaterialPreset(next.materialPreset);
      }
      if ((next.envIntensity - _lastEnv).abs() > 0.001) {
        _lastEnv = next.envIntensity;
        _bridge?.setEnvIntensity(next.envIntensity);
      }
      // V5/D85 环境光开关。
      if (prev?.ambientEnabled != next.ambientEnabled) {
        _bridge?.setAmbientEnabled(next.ambientEnabled);
      }
      // V5/D91 接触阴影开关。
      if (prev?.contactShadow != next.contactShadow) {
        _bridge?.setContactShadow(next.contactShadow);
      }
      // V6/D104 性能档。
      if (next.performanceProfile != _lastPerformance) {
        _lastPerformance = next.performanceProfile;
        _bridge?.setPerformanceProfile(next.performanceProfile);
      }
      // V6/D111 光锥。
      if (prev?.lightCones != next.lightCones) {
        _bridge?.setLightCones(next.lightCones);
      }
      // V7/D137 软阴影。
      if (prev?.softShadows != next.softShadows) {
        _bridge?.setSoftShadows(next.softShadows);
      }
      // V6/D105 相机 POV。
      if (prev?.cameraView != next.cameraView) {
        _bridge?.setCameraView(next.cameraView);
        _refreshCameraAssist();
      }
      // V6/D105 机位变更（拖动/滑杆）→ 引擎即时同步。
      if (next.cameraSeq != _lastCameraSeq) {
        _lastCameraSeq = next.cameraSeq;
        _bridge?.setCameraRig(next.scene.camera.toJson());
        _refreshCameraAssist();
      }
    });

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.space): _toggleCameraMode,
      },
      child: Focus(
        autofocus: true,
        child: SsPage(
          title: '布光预演室',
          subtitle: '拖动灯位与道具 · 实时方位角/距离 · 3D 光影预览 · 布光单导出',
          actions: <Widget>[
            SsChip(
              label: state.linkage ? '俯视 ↔ 3D 联动' : '俯视 / 3D 已解耦',
              selected: state.linkage,
              onTap: () => ref
                  .read(lightingControllerProvider.notifier)
                  .setLinkage(!state.linkage),
            ),
            const SizedBox(width: 8),
            SsButton(
              label: '保存布光图',
              icon: Icons.save_outlined,
              dense: true,
              onPressed: () async {
                await ref.read(lightingControllerProvider.notifier).save();
                if (context.mounted) {
                  ssToast(context, ref.read(lightingControllerProvider).status);
                }
              },
            ),
          ],
          body: !state.initialized
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: AppStroke.ringBold,
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (!_listCollapsed) ...<Widget>[
                      _buildLeftColumn(state),
                      const SizedBox(width: AppSpace.s3),
                    ],
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          _buildViewSwitch(state),
                          const SizedBox(height: AppSpace.s2),
                          Expanded(child: _buildStageArea(state)),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    SizedBox(width: 264, child: _buildParamPanel(state)),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _uploadTexture() async {
    try {
      final String? dataUrl = await pickTextureDataUrl();
      if (dataUrl == null) return;
      ref.read(lightingControllerProvider.notifier).setSelectedTexture(dataUrl);
      if (mounted) ssToast(context, '贴图已应用到选中对象（同步至 3D 场景）');
    } catch (e) {
      if (mounted) ssToast(context, '贴图处理失败：$e');
    }
  }

  /// V6/D103 诊断包 / V7/D138 预览图：共用状态 + toast 提示口径。
  Future<void> _exportDiagnostics() => runLightingFileAction(
    action: () => exportLightingDiagnostics(
      workspace: ref.read(workspaceProvider),
      state: ref.read(lightingControllerProvider),
      bridge: _bridge,
    ),
    successStatus: (String f) => '诊断包已导出：$f',
    failureStatus: (Object e) => '诊断包导出失败：$e',
    onStatus: ref.read(lightingControllerProvider.notifier).setStatus,
    onToast: (String m) {
      if (mounted) ssToast(context, m);
    },
  );

  Future<void> _saveCapture(String dataUrl) => runLightingFileAction(
    action: () => saveLightingPreview(
      workspace: ref.read(workspaceProvider),
      dataUrl: dataUrl,
    ),
    successStatus: (String f) => '已保存效果预览图：$f',
    failureStatus: (Object e) => '预览图保存失败：$e',
    onStatus: ref.read(lightingControllerProvider.notifier).setStatus,
    onToast: (String m) {
      if (mounted) ssToast(context, '效果预览图已保存到工作区 images/plans/');
    },
  );

  /// V7/D138：后台预热路径追踪器（提前付着色器编译成本；失败不影响导出）。
  void _scheduleWarmPathTracer() {
    if (_warmQueued) return;
    _warmQueued = true;
    Future<void>.delayed(AppWait.poll, () {
      _warmQueued = false;
      _bridge?.warmPathTracer();
    });
  }

  /// V7/D139：读取引擎相机辅助信息（视场角/主体距离/景深可用性），失败保留上次值。
  Future<void> _refreshCameraAssist() async {
    final Map<String, Object?>? info = await _bridge?.getCameraAssist();
    if (info == null || !mounted) return;
    final double distance = (info['subjectDistance'] as num?)?.toDouble() ?? 0;
    final double fovDeg = (info['fovDeg'] as num?)?.toDouble() ?? 0;
    final bool dof = info['dofAvailable'] != false;
    final bool same =
        distance == _assistDistance &&
        fovDeg == _assistFocalDeg &&
        dof == _assistDofAvailable;
    if (distance <= 0 || same) return;
    setState(() {
      _assistDistance = distance;
      _assistFocalDeg = fovDeg;
      _assistDofAvailable = dof;
    });
  }


  Widget _buildViewSwitch(LightingState state) {
    final controller = ref.read(lightingControllerProvider.notifier);
    return ValueListenableBuilder<AbSlots>(
      valueListenable: _abSlots,
      builder: (BuildContext context, AbSlots slots, Widget? _) =>
          LightingToolbar(
            viewMode: state.viewMode,
            cameraView: state.cameraView,
            guides: _guides,
            skeleton: _skeleton,
            characterName: _character.characterName,
            characterSelected: _character.characterId.isNotEmpty,
            stillRunning: _stillSession?.running ?? false,
            abReady: slots.hasBoth,
            canUndo: state.canUndo,
            canRedo: state.canRedo,
            listCollapsed: _listCollapsed,
            pip: _pip,
            status: state.status,
            onView: controller.setView,
            onToggleSkeleton: () {
              setState(() => _skeleton = !_skeleton);
              _bridge?.setSkeletonMode(_skeleton);
            },
            onPickCharacter: () async {
              final CharacterSelection? next = await showCharacterPicker(
                context,
                current: _character,
              );
              if (next == null || !mounted) return;
              setState(() => _character = next);
              await applyCharacterSelection(_bridge, next);
            },
            onToggleCameraView: () {
              final bool next = !state.cameraView;
              controller.setCameraView(next);
              if (next && state.viewMode == 'top') {
                controller.setView('scene3d');
              }
            },
            onToggleGuides: () => setState(
              () => _guides = _guides.copyWith(
                thirds: !_guides.enabled,
                safeArea: !_guides.enabled,
                crop: 'none',
              ),
            ),
            onToggleList: () =>
                setState(() => _listCollapsed = !_listCollapsed),
            onTogglePip: () => setState(() => _pip = !_pip),
            onOpenStill: _openStillDialog,
            onOpenAb: _openAbDialog,
            onUndo: _undo,
            onRedo: _redo,
          ),
    );
  }

  /// 引擎就绪：把当前状态一次性全量同步（画质/阴影/机位/人物），再预热静帧。
  void _syncEngineOnReady() {
    final LightingState fresh = ref.read(lightingControllerProvider);
    final EngineBridge? bridge = _bridge;
    bridge
      ?..setLinkage(fresh.linkage)
      ..setTheme(Theme.of(context).brightness == Brightness.dark)
      ..setSkeletonMode(_skeleton)
      ..setSubdivision(fresh.subdivisionLevel)
      ..setMaterialPreset(fresh.materialPreset)
      ..setEnvIntensity(fresh.envIntensity)
      ..setAmbientEnabled(fresh.ambientEnabled)
      ..setContactShadow(fresh.contactShadow)
      ..setPerformanceProfile(fresh.performanceProfile)
      ..setSoftShadows(fresh.softShadows)
      ..setCameraView(fresh.cameraView)
      ..setLightCones(fresh.lightCones);
    _lastSubdivision = fresh.subdivisionLevel;
    _lastPreset = fresh.materialPreset;
    _lastEnv = fresh.envIntensity;
    _lastPerformance = fresh.performanceProfile;
    _lastCameraSeq = fresh.cameraSeq;
    if (_character.characterId.isNotEmpty) {
      applyCharacterSelection(bridge, _character);
    }
    _queueApplyScene();
    _scheduleWarmPathTracer();
    _refreshCameraAssist();
  }

  void _handleEngineEvent(EngineEvent event, LightingState state) {
    final controller = ref.read(lightingControllerProvider.notifier);
    switch (event) {
      case EngineReady():
        _syncEngineOnReady();
      case EngineCharacterChanged(
        character: final String id,
        name: final String name,
      ):
        if (id != 'legacy') {
          setState(
            () => _character = _character.copyWith(
              characterId: id,
              characterName: name,
            ),
          );
        }
      case EngineSelection(kind: final String? kind, id: final String? id):
        if (kind == 'light' || kind == 'prop') {
          controller.select(id);
        }
      case EngineSceneChanged(
        lights: final List<Map<String, Object?>>? lights,
        props: final List<Map<String, Object?>>? props,
      ):
        // D152：3D 内拖动 = 一步撤销（首次回传记基准，dragEnded 收口）。
        controller.beginInteraction('engine');
        controller.applyEngineMove(lights: lights, props: props);
      case EngineDragEnded():
        controller.endInteraction();
      case EngineCaptured(
        dataUrl: final String dataUrl,
        token: final String token,
      ):
        // V7/D138：带 token 的取图走 A/B 冻结槽，其余仍是「出片」保存。
        if (token == 'ab-a' || token == 'ab-b') {
          _setAbSlot(token == 'ab-b' ? 'b' : 'a', dataUrl);
        } else {
          _saveCapture(dataUrl);
        }
      case EngineStillProgress():
        _stillSession?.onProgress(event);
      case EngineStillRendered():
        _stillSession?.onRendered(event);
      case EngineJointClicked():
        break;
      case EngineHeartbeat():
      case EngineConsole():
        break;
      case EngineErrorEvent(
        message: final String message,
        fatal: final bool fatal,
        source: final String source,
      ):
        // V6/R41：致命错误才降级提示；角色局部失败给可读状态，JS 噪声只落盘。
        if (fatal) {
          controller.setStatus('3D 引擎异常，已降级到俯视图');
        } else if (source == 'character') {
          controller.setStatus(message);
        }
    }
  }

  Widget _buildStageArea(LightingState state) {
    final controller = ref.read(lightingControllerProvider.notifier);
    return LightingStageView(
      scene: state.scene,
      selectedId: state.selectedId,
      viewMode: state.viewMode,
      cameraView: state.cameraView,
      guides: _guides,
      assistDistance: _assistDistance,
      pip: _pip,
      linkage: state.linkage,
      onSelect: controller.select,
      onMove: controller.moveDevice,
      onMoveEnd: _queueApplyScene,
      onCameraMove: controller.moveCamera,
      onCameraMoveEnd: _queueApplyScene,
      onExportDiagnostics: _exportDiagnostics,
      onBridgeReady: (EngineBridge bridge) {
        _bridge = bridge;
        _queueApplyScene();
      },
      onEvent: (EngineEvent event) => _handleEngineEvent(event, state),
    );
  }

  Widget _buildLeftColumn(LightingState state) {
    return LightingLeftColumn(
      state: state,
      controller: ref.read(lightingControllerProvider.notifier),
      presets: _presets,
    );
  }

  /// D152：撤销 / 重做 / 删除选中（快捷键与工具条共用）。
  void _undo() => ref.read(lightingControllerProvider.notifier).undo();

  void _redo() => ref.read(lightingControllerProvider.notifier).redo();

  void _deleteSelected() {
    if (ref.read(lightingControllerProvider).selected == null) return;
    ref.read(lightingControllerProvider.notifier).removeSelected();
  }

  /// D152：空格 = 相机漫游 / 对象操作 互切（相机视角 = 漫游，自由视角 = 操作）。
  void _toggleCameraMode() {
    final LightingState state = ref.read(lightingControllerProvider);
    final LightingController c = ref.read(lightingControllerProvider.notifier);
    final bool next = !state.cameraView;
    c.setCameraView(next);
    c.setStatus(next ? '相机漫游（空格切回对象操作）' : '对象操作（空格切回相机漫游）');
  }

  Future<void> _saveCustomPose(
    String name,
    HandPoseState l,
    HandPoseState r,
  ) async {
    await ref
        .read(posesControllerProvider.notifier)
        .saveCustomPose(
          name: name,
          joints:
              ref.read(lightingControllerProvider).pendingPose ??
              <String, Object?>{},
          handsL: l,
          handsR: r,
        );
    if (mounted) ssToast(context, '已另存为「$name」（含手部姿态）');
  }

  void _resetPose() {
    ref.read(lightingControllerProvider.notifier).resetPendingJoints();
    final Map<String, Object?>? restored = ref
        .read(lightingControllerProvider)
        .pendingPose;
    if (restored != null) {
      _bridge?.setPose(restored, durationMs: 150);
    }
  }

  Widget _buildParamPanel(LightingState state) {
    return LightingInspector(
      state: state,
      controller: ref.read(lightingControllerProvider.notifier),
      bridge: _bridge,
      guides: _guides,
      onGuides: (CameraGuideSettings next) => setState(() => _guides = next),
      assistDistance: _assistDistance,
      assistDofAvailable: _assistDofAvailable,
      legacyCharacter: _character.characterId == 'legacy',
      onSavePose: _saveCustomPose,
      onResetPose: _resetPose,
      onUploadTexture: _uploadTexture,
      onChanged: () {
        if (mounted) setState(() {});
      },
      onNotify: (String message) {
        if (mounted) ssToast(context, message);
      },
    );
  }
}
