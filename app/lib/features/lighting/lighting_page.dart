import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/workspace/workspace.dart';
import '../../services/app_logger.dart';
import '../../services/content_packs.dart';
import '../../services/image_store.dart';
import '../../services/engine/engine_bridge.dart';
import '../../services/engine/engine_view.dart';
import 'light_meter.dart';
import '../poses/character_picker.dart';
import '../poses/poses_controller.dart';
import 'hand_presets.dart';
import 'lighting_controller.dart';
import 'lighting_models.dart';
import 'widgets/lighting_canvas_view.dart';

/// M2 布光预演室：俯视灯位图 + 设备/道具清单 + 3D 实时预览（双轨制轨道一）。
class LightingPage extends ConsumerStatefulWidget {
  const LightingPage({super.key});

  @override
  ConsumerState<LightingPage> createState() => _LightingPageState();
}

class _LightingPageState extends ConsumerState<LightingPage> {
  EngineBridge? _bridge;
  bool _skeleton = false;
  CharacterSelection _character =
      const CharacterSelection(characterId: '', characterName: '默认人物');
  List<LightPresetEntry> _presets = <LightPresetEntry>[];
  bool _applyQueued = false;
  int _lastPoseSeq = 0;
  int _lastCaptureSeq = 0;
  int _lastSubdivision = -1;
  String _lastPreset = '';
  double _lastEnv = -1;
  String _lastPerformance = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
      _presets = await ContentPacks.lightPresets();
      if (mounted) setState(() {});
      await ref.read(lightingControllerProvider.notifier).init();
    });
  }

  void _queueApplyScene() {
    if (_applyQueued) return;
    _applyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _applyQueued = false;
      final state = ref.read(lightingControllerProvider);
      final joints = state.pendingPose;
      _bridge?.applyScene(state.scene.toEngineJson(
        poseJoints: joints,
        hands: state.scene.hands,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lightingControllerProvider);

    // 场景变化 → 引擎同步（联动/解耦由引擎侧 linkage 控制拖动回传）。
    ref.listen(lightingControllerProvider,
        (LightingState? prev, LightingState next) {
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
    });

    return SsPage(
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
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildPresetPanel(state),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _buildViewSwitch(state),
                      const SizedBox(height: AppTokens.s8),
                      Expanded(child: _buildStageArea(state)),
                      const SizedBox(height: AppTokens.s8),
                      SizedBox(height: 132, child: _buildPositionList(state)),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.s12),
                SizedBox(width: 264, child: _buildParamPanel(state)),
              ],
            ),
    );
  }

  Widget _buildPresetPanel(LightingState state) {
    final grouped = <String, List<LightPresetEntry>>{};
    for (final LightPresetEntry preset in _presets) {
      grouped
          .putIfAbsent(preset.category, () => <LightPresetEntry>[])
          .add(preset);
    }
    return SizedBox(
      width: 208,
      child: SsCard(
        padding: const EdgeInsets.all(AppTokens.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SsSectionTitle('布光预设', subtitle: '内置 ${_presets.length} 套'),
            const SizedBox(height: AppTokens.s8),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final MapEntry<String, List<LightPresetEntry>> entry
                      in grouped.entries) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final LightPresetEntry preset in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SsCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          onTap: () {
                            ref
                                .read(lightingControllerProvider.notifier)
                                .applyPreset(preset);
                            if (context.mounted) ssToast(context, preset.note);
                          },
                          child: Text(preset.name,
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: SsButton(
                    label: '加灯',
                    icon: Icons.add,
                    dense: true,
                    onPressed: () => _addWithLimitCheck(() {
                      ref.read(lightingControllerProvider.notifier).addLight();
                    }),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SsButton(
                    label: '加道具',
                    kind: SsButtonKind.ghost,
                    dense: true,
                    onPressed: () => _addWithLimitCheck(() {
                      ref.read(lightingControllerProvider.notifier).addProp();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: SsButton(
                    label: '清空影棚',
                    kind: SsButtonKind.ghost,
                    dense: true,
                    onPressed: () {
                      ref.read(lightingControllerProvider.notifier).clearAll();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addWithLimitCheck(VoidCallback add) {
    if (ref.read(lightingControllerProvider).scene.devices.length >=
        LightingSceneData.maxDevices) {
      ssToast(context, '单影棚上限 ${LightingSceneData.maxDevices} 个对象');
      return;
    }
    add();
    if (mounted) setState(() {});
  }

  Widget _buildViewSwitch(LightingState state) {
    final controller = ref.read(lightingControllerProvider.notifier);
    return Row(
      children: <Widget>[
        for (final (String label, String mode) in <(String, String)>[
          ('俯视图', 'top'),
          ('3D 预览', 'scene3d'),
          ('分屏', 'split'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SsChip(
              label: label,
              selected: state.viewMode == mode,
              onTap: () => controller.setView(mode),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: SsChip(
            label: _skeleton ? '骨骼开' : '骨骼',
            selected: _skeleton,
            onTap: () {
              setState(() => _skeleton = !_skeleton);
              _bridge?.setSkeletonMode(_skeleton);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: SsChip(
            label: '人物 · ${_character.characterName}',
            selected: _character.characterId.isNotEmpty,
            onTap: () async {
              final CharacterSelection? next =
                  await showCharacterPicker(context, current: _character);
              if (next == null) return;
              setState(() => _character = next);
              await applyCharacterSelection(_bridge, next);
            },
          ),
        ),
        const Spacer(),
        if (state.status.isNotEmpty)
          Text(
            state.status,
            style: AppTokens.mono(
              context,
              size: 11.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildStageArea(LightingState state) {
    final controller = ref.read(lightingControllerProvider.notifier);
    final canvas = SsCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        child: LightingCanvasView(
          scene: state.scene,
          selectedId: state.selectedId,
          onSelect: controller.select,
          onMove: controller.moveDevice,
          onMoveEnd: _queueApplyScene,
        ),
      ),
    );
    final engine = ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      child: EngineView(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        onExportDiagnostics: _exportDiagnostics,
        onBridgeReady: (EngineBridge bridge) {
          _bridge = bridge;
          _queueApplyScene();
        },
        onEvent: (EngineEvent event) {
          switch (event) {
            case EngineReady():
              _bridge?.setLinkage(state.linkage);
              _bridge
                  ?.setTheme(Theme.of(context).brightness == Brightness.dark);
              _bridge?.setSkeletonMode(_skeleton);
              final LightingState fresh = ref.read(lightingControllerProvider);
              _lastSubdivision = fresh.subdivisionLevel;
              _lastPreset = fresh.materialPreset;
              _lastEnv = fresh.envIntensity;
              _bridge?.setSubdivision(fresh.subdivisionLevel);
              _bridge?.setMaterialPreset(fresh.materialPreset);
              _bridge?.setEnvIntensity(fresh.envIntensity);
              _bridge?.setAmbientEnabled(fresh.ambientEnabled);
              _bridge?.setContactShadow(fresh.contactShadow);
              _lastPerformance = fresh.performanceProfile;
              _bridge?.setPerformanceProfile(fresh.performanceProfile);
              if (_character.characterId.isNotEmpty) {
                applyCharacterSelection(_bridge, _character);
              }
              _queueApplyScene();
            case EngineCharacterChanged(
                character: final String id,
                name: final String name
              ):
              if (id != 'legacy') {
                setState(() => _character =
                    _character.copyWith(characterId: id, characterName: name));
              }
            case EngineSelection(
                kind: final String? kind,
                id: final String? id
              ):
              if (kind == 'light' || kind == 'prop') {
                controller.select(id);
              }
            case EngineSceneChanged(
                lights: final List<Map<String, Object?>>? lights,
                props: final List<Map<String, Object?>>? props
              ):
              controller.applyEngineMove(lights: lights, props: props);
            case EngineCaptured(dataUrl: final String dataUrl):
              _saveCapture(dataUrl);
            case EngineJointClicked():
              break;
            case EngineHeartbeat():
            case EngineConsole():
              break;
            case EngineErrorEvent(
                message: final String message,
                fatal: final bool fatal,
                source: final String source
              ):
              // V6/R41：致命错误才降级提示；角色局部失败给可读状态，JS 噪声只落盘。
              if (fatal) {
                controller.setStatus('3D 引擎异常，已降级到俯视图');
              } else if (source == 'character') {
                controller.setStatus(message);
              }
          }
        },
      ),
    );

    switch (state.viewMode) {
      case 'top':
        return canvas;
      case 'scene3d':
        return engine;
      default:
        return Row(
          children: <Widget>[
            Expanded(child: canvas),
            const SizedBox(width: AppTokens.s8),
            Expanded(child: engine),
          ],
        );
    }
  }

  Future<void> _uploadTexture() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: '选择贴图图片',
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final raw = await File(path).readAsBytes();
      final compressed = ImageStore.compress(raw, maxKb: 160, maxEdge: 512);
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      ref.read(lightingControllerProvider.notifier).setSelectedTexture(dataUrl);
      if (mounted) ssToast(context, '贴图已应用到选中对象（同步至 3D 场景）');
    } catch (e) {
      if (mounted) ssToast(context, '贴图处理失败：$e');
    }
  }

  /// V6/D103：导出诊断包（应用日志 + 引擎统计 + 场景 JSON + 环境信息 → zip）。
  Future<void> _exportDiagnostics() async {
    final LightingController controller =
        ref.read(lightingControllerProvider.notifier);
    try {
      final LightingState state = ref.read(lightingControllerProvider);
      final Workspace workspace = ref.read(workspaceProvider);
      final DateTime now = DateTime.now();
      final String stamp = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final Directory dir =
          Directory(p.join(workspace.root.path, 'diagnostics', 'diag-$stamp'));
      await dir.create(recursive: true);

      // 1) 应用日志（引擎控制台 / JS 错误均已写入）。
      final File log = File(p.join(AppLogger.I.logDir, 'app.log'));
      if (await log.exists()) {
        await log.copy(p.join(dir.path, 'app.log'));
      }

      // 2) 引擎统计（缓存/内存/FPS）。
      final Object? engineStats = await _bridge?.evaluate(
        'JSON.stringify(window.ss && window.ss.getEngineStats ? window.ss.getEngineStats() : null)',
      );
      await File(p.join(dir.path, 'engine-stats.json'))
          .writeAsString('${engineStats ?? 'null'}');

      // 3) 当前布光场景。
      await File(p.join(dir.path, 'scene.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          state.scene.toEngineJson(
            poseJoints: state.pendingPose,
            hands: state.scene.hands,
          ),
        ),
      );

      // 4) 环境信息。
      await File(p.join(dir.path, 'env.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'os': Platform.operatingSystem,
          'osVersion': Platform.operatingSystemVersion,
          'processors': Platform.numberOfProcessors,
          'dartVersion': Platform.version,
          'viewMode': state.viewMode,
          'materialPreset': state.materialPreset,
          'subdivision': state.subdivisionLevel,
          'ambientEnabled': state.ambientEnabled,
          'contactShadow': state.contactShadow,
          'exportedAt': now.toIso8601String(),
        }),
      );

      // 5) 打包 zip。
      final Archive archive = Archive();
      for (final FileSystemEntity entity in dir.listSync()) {
        if (entity is File) {
          archive.addFile(ArchiveFile(p.basename(entity.path),
              entity.lengthSync(), entity.readAsBytesSync()));
        }
      }
      final File zip =
          File(p.join(workspace.root.path, 'diagnostics', 'diag-$stamp.zip'));
      await zip.writeAsBytes(ZipEncoder().encode(archive)!, flush: true);
      controller.setStatus('诊断包已导出：${zip.path}');
      if (mounted) ssToast(context, '诊断包已导出到工作区 diagnostics/');
    } catch (e) {
      controller.setStatus('诊断包导出失败：$e');
      if (mounted) ssToast(context, '诊断包导出失败：$e');
    }
  }

  Future<void> _saveCapture(String dataUrl) async {
    try {
      final base64Part =
          dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
      final bytes = base64Decode(base64Part);
      final workspace = ref.read(workspaceProvider);
      final dir = Directory(p.join(workspace.root.path, 'images', 'plans'));
      await dir.create(recursive: true);
      final file = File(
        p.join(dir.path, '布光预览_${DateTime.now().millisecondsSinceEpoch}.png'),
      );
      await file.writeAsBytes(bytes);
      ref.read(lightingControllerProvider.notifier).setStatus(
          '已保存效果预览图：${file.path.split(Platform.pathSeparator).last}');
      if (mounted) ssToast(context, '效果预览图已保存到工作区 images/plans/');
    } catch (e) {
      ref.read(lightingControllerProvider.notifier).setStatus('预览图保存失败：$e');
    }
  }

  Widget _deviceRow(BuildContext context, LightingState state, DeviceSpec d) {
    final g = geometryOf(d.x, d.y);
    return InkWell(
      onTap: () => ref.read(lightingControllerProvider.notifier).select(d.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 90,
              child: Text(
                d.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: d.id == state.selectedId ? AppTokens.accent : null,
                  fontWeight: d.id == state.selectedId
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: Text(
                d.isLight
                    ? '${_typeLabel(d.type)} · 方位 ${g.azimuthLabel} · 距离 ${g.distanceLabel} · '
                        '${d.intensity}% · ${d.kelvin}K · ${d.height.toStringAsFixed(1)}m'
                    : '道具 · 坐标 (${d.x.toStringAsFixed(1)}, ${d.y.toStringAsFixed(1)})',
                style: AppTokens.mono(context, size: 10.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionList(LightingState state) {
    final rows = state.scene.devices;
    return SsCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SsSectionTitle(
            '设备与道具位置清单',
            subtitle: '共 ${rows.length} 个对象',
            trailing: SsButton(
              label: '保存预览图',
              kind: SsButtonKind.ghost,
              dense: true,
              onPressed: () => ref
                  .read(lightingControllerProvider.notifier)
                  .requestCapture(),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child:
                        Text('空影棚 · 未布置任何灯光', style: TextStyle(fontSize: 12)),
                  )
                : ListView(
                    children: <Widget>[
                      for (final DeviceSpec d in rows)
                        _deviceRow(context, state, d),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    for (final LightType t in LightType.values) {
      if (t.name == type) return t.label;
    }
    return '硬光';
  }

  Widget _buildParamPanel(LightingState state) {
    final selected = state.selected;
    if (selected == null) {
      return SsCard(
        child: ListView(
          children: <Widget>[
            const SsSectionTitle('参数面板'),
            const SizedBox(height: AppTokens.s12),
            const SsEmpty(
              icon: Icons.touch_app_outlined,
              art: SsArt.light,
              title: '未选中对象',
              hint: '在画布或 3D 视图中点选灯光 / 道具',
            ),
            const SizedBox(height: AppTokens.s12),
            _LightMeterCard(scene: state.scene),
            const SizedBox(height: AppTokens.s12),
            _JointTunePanel(
              pose: state.pendingPose,
              controller: ref.read(lightingControllerProvider.notifier),
              handL: state.handL,
              handR: state.handR,
              bridge: _bridge,
              onSave: (String name, HandPoseState l, HandPoseState r) async {
                await ref.read(posesControllerProvider.notifier).saveCustomPose(
                      name: name,
                      joints:
                          ref.read(lightingControllerProvider).pendingPose ??
                              <String, Object?>{},
                      handsL: l,
                      handsR: r,
                    );
                if (mounted) ssToast(context, '已另存为「$name」（含手部姿态）');
              },
              onReset: () {
                ref
                    .read(lightingControllerProvider.notifier)
                    .resetPendingJoints();
                final Map<String, Object?>? restored =
                    ref.read(lightingControllerProvider).pendingPose;
                if (restored != null) {
                  _bridge?.setPose(restored, durationMs: 150);
                }
              },
            ),
            const SizedBox(height: AppTokens.s12),
            _HandPosePanel(
              state: state,
              controller: ref.read(lightingControllerProvider.notifier),
              bridge: _bridge,
              legacy: _character.characterId == 'legacy',
            ),
            const SizedBox(height: AppTokens.s12),
            _QualityPanel(
              state: state,
              controller: ref.read(lightingControllerProvider.notifier),
            ),
            const SizedBox(height: AppTokens.s12),
            _EffectPreview(scene: state.scene),
          ],
        ),
      );
    }
    final controller = ref.read(lightingControllerProvider.notifier);
    final g = geometryOf(selected.x, selected.y);
    return SsCard(
      child: ListView(
        children: <Widget>[
          SsSectionTitle(
            selected.name,
            subtitle: selected.isLight
                ? '方位 ${g.azimuthLabel} · 距离 ${g.distanceLabel}'
                : '道具 · (${selected.x.toStringAsFixed(2)}, ${selected.y.toStringAsFixed(2)})',
          ),
          const SizedBox(height: AppTokens.s8),
          if (selected.isLight) ...<Widget>[
            _dropdown<String>(
              label: '光型',
              value: selected.type,
              options: <String, String>{
                for (final LightType t in LightType.values) t.name: t.label,
              },
              onChanged: (String v) =>
                  controller.updateSelected((DeviceSpec d) => d.type = v),
            ),
            _dropdown<String>(
              label: '灯具',
              value: selected.fixture,
              options: <String, String>{
                'cob-600d': '600W COB 白光',
                'cob-300d': '300W COB 白光',
                'cob-300b': '300W COB 双色温',
                'rgb-tube': 'RGB 像素管灯',
                'panel-120': '120W 平板灯',
                'speedlight': '机顶闪光灯',
                'strobe-400': '400Ws 影室闪',
                'fresnel': '菲涅尔聚光灯',
              },
              onChanged: (String v) =>
                  controller.updateSelected((DeviceSpec d) => d.fixture = v),
            ),
            _dropdown<String>(
              label: '控光件',
              value: selected.modifier,
              options: <String, String>{
                'bare': '裸灯',
                'standard-reflector': '标准反光罩',
                'softbox-medium': '中号柔光箱',
                'softbox-large': '大号柔光箱',
                'honeycomb-grid': '蜂巢',
                'diffusion-cloth': '柔光布',
                'beauty-dish': '雷达罩',
                'snoot': '束光筒',
              },
              onChanged: (String v) =>
                  controller.updateSelected((DeviceSpec d) => d.modifier = v),
            ),
            _slider(
              label: '亮度',
              value: selected.intensity.toDouble(),
              min: 1,
              max: 100,
              display: '${selected.intensity}%',
              onChanged: (double v) => controller
                  .updateSelected((DeviceSpec d) => d.intensity = v.round()),
            ),
            _slider(
              label: '色温',
              value: selected.kelvin.toDouble(),
              min: 2700,
              max: 7500,
              display: '${selected.kelvin}K',
              onChanged: (double v) => controller
                  .updateSelected((DeviceSpec d) => d.kelvin = v.round()),
            ),
            _slider(
              label: '光束角',
              value: selected.beamAngle,
              min: 8,
              max: 150,
              display: '${selected.beamAngle.toStringAsFixed(0)}°',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.beamAngle = v),
            ),
            _slider(
              label: '柔度',
              value: selected.softness,
              min: 0.02,
              max: 1,
              display: '${(selected.softness * 100).toStringAsFixed(0)}%',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.softness = v),
            ),
            _slider(
              label: '高度',
              value: selected.height,
              min: 0.3,
              max: 3.0,
              display: '${selected.height.toStringAsFixed(1)}m',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.height = v),
            ),
            _slider(
              label: '灯头朝向',
              value: selected.rotation,
              min: 0,
              max: 360,
              display: '${selected.rotation.round()}°',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.rotation = v),
            ),
            SsToggleRow(
              title: '灯光开关',
              value: selected.on,
              onChanged: (bool v) =>
                  controller.updateSelected((DeviceSpec d) => d.on = v),
            ),
          ] else ...<Widget>[
            _slider(
              label: '朝向',
              value: selected.rotation,
              min: 0,
              max: 360,
              display: '${selected.rotation.toStringAsFixed(0)}°',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.rotation = v),
            ),
            _slider(
              label: '缩放',
              value: selected.scale,
              min: 0.5,
              max: 2,
              display: '${selected.scale.toStringAsFixed(2)}×',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.scale = v),
            ),
          ],
          TextField(
            controller: TextEditingController(text: selected.note),
            decoration: const InputDecoration(hintText: '备注（≤200 字）'),
            maxLines: 2,
            onChanged: (String v) =>
                controller.updateSelected((DeviceSpec d) => d.note = v),
          ),
          const SizedBox(height: AppTokens.s8),
          const Text(
            '自定义贴图（上传图将作为贴图占位出现在 3D 场景，D23）',
            style: TextStyle(fontSize: 11.5),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              SsButton(
                label: '上传贴图',
                icon: Icons.image_outlined,
                kind: SsButtonKind.ghost,
                dense: true,
                onPressed: _uploadTexture,
              ),
              const SizedBox(width: 6),
              if (selected.texture.isNotEmpty)
                SsButton(
                  label: '移除贴图',
                  kind: SsButtonKind.ghost,
                  dense: true,
                  onPressed: () => controller.setSelectedTexture(''),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Row(
            children: <Widget>[
              Expanded(
                child: SsButton(
                  label: '删除该对象',
                  icon: Icons.delete_outline_rounded,
                  kind: SsButtonKind.ghost,
                  dense: true,
                  onPressed: () {
                    controller.removeSelected();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s16),
          _JointTunePanel(
            pose: state.pendingPose,
            controller: controller,
            handL: state.handL,
            handR: state.handR,
            bridge: _bridge,
            onSave: (String name, HandPoseState l, HandPoseState r) async {
              await ref.read(posesControllerProvider.notifier).saveCustomPose(
                    name: name,
                    joints: ref.read(lightingControllerProvider).pendingPose ??
                        <String, Object?>{},
                    handsL: l,
                    handsR: r,
                  );
              if (mounted) ssToast(context, '已另存为「$name」（含手部姿态）');
            },
            onReset: () {
              ref
                  .read(lightingControllerProvider.notifier)
                  .resetPendingJoints();
              final Map<String, Object?>? restored =
                  ref.read(lightingControllerProvider).pendingPose;
              if (restored != null) {
                _bridge?.setPose(restored, durationMs: 150);
              }
            },
          ),
          const SizedBox(height: AppTokens.s12),
          _HandPosePanel(
            state: state,
            controller: controller,
            bridge: _bridge,
            legacy: _character.characterId == 'legacy',
          ),
          const SizedBox(height: AppTokens.s12),
          _QualityPanel(state: state, controller: controller),
          const SizedBox(height: AppTokens.s16),
          _EffectPreview(scene: state.scene),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.s8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              items: <DropdownMenuItem<T>>[
                for (final MapEntry<T, String> e in options.entries)
                  DropdownMenuItem<T>(
                      value: e.key,
                      child: Text(e.value,
                          style: const TextStyle(fontSize: 12.5))),
              ],
              onChanged: (T? v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(display, style: AppTokens.mono(context, size: 11)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged),
        ),
      ],
    );
  }
}

/// 效果预览（主视角度明暗示意，随灯位实时重绘）。
class _EffectPreview extends StatelessWidget {
  const _EffectPreview({required this.scene});

  final LightingSceneData scene;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SsSectionTitle('效果预览', subtitle: '主视角度明暗示意'),
        const SizedBox(height: AppTokens.s8),
        Container(
          height: 132,
          decoration: BoxDecoration(
            color: const Color(0xFF17130F),
            borderRadius: BorderRadius.circular(AppTokens.rSm),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: CustomPaint(
            painter: _FaceLightPainter(
              devices: scene.lights.where((DeviceSpec d) => d.on).toList(),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _FaceLightPainter extends CustomPainter {
  _FaceLightPainter({required this.devices});

  final List<DeviceSpec> devices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.3;

    // 暗背景。
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF17130F));

    // 脸。
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF3A342E));

    if (devices.isEmpty) {
      _hint(canvas, size, '未布置任何灯光');
      return;
    }

    // 取最亮灯为主光。
    devices.sort(
        (DeviceSpec a, DeviceSpec b) => b.intensity.compareTo(a.intensity));
    final key = devices.first;
    final g = geometryOf(key.x, key.y);
    final int kelvin = key.kelvin;
    final double brightness = key.intensity / 100;

    // 受光半侧。
    final rad = (g.azimuth - 90) * math.pi / 180;
    final litPath = Path()
      ..addArc(Rect.fromCircle(center: center, radius: radius),
          rad - math.pi / 2, math.pi)
      ..close();
    final warm = kelvin < 4200;
    final Color lightColor = Color.lerp(
      const Color(0xFFFFE8C8),
      const Color(0xFFEAF2FF),
      warm ? 0.15 : 0.85,
    )!
        .withValues(alpha: 0.25 + 0.55 * brightness);
    canvas.drawPath(litPath, Paint()..color = lightColor);

    // 面部轮廓。
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 鼻梁高光线（提示光向）。
    final nose = Offset(
      center.dx + math.cos(rad) * radius * 0.6,
      center.dy + math.sin(rad) * radius * 0.6,
    );
    canvas.drawLine(
      center,
      nose,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 1.4,
    );

    // 读数。
    final tp = TextPainter(
      text: TextSpan(
        text:
            '主光 ${_dirLabel(g.azimuth)} · ${g.distanceLabel} · ${key.intensity}% · ${key.kelvin}K',
        style: const TextStyle(fontSize: 10, color: Color(0xFFB9B2A8)),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 12);
    tp.paint(canvas, const Offset(6, 6));
  }

  String _dirLabel(double az) {
    if (az >= 315 || az < 45) return '正面';
    if (az < 135) return '右侧';
    if (az < 225) return '背面';
    return '左侧';
  }

  void _hint(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A919E))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_FaceLightPainter old) => true;
}

/// 虚拟测光表（G4/D33）：EV / 曝光建议 / 光比 / 影调。
class _LightMeterCard extends StatelessWidget {
  const _LightMeterCard({required this.scene});

  final LightingSceneData scene;

  @override
  Widget build(BuildContext context) {
    final LightMeterReading r = LightMeter.compute(scene);
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.rSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.exposure_rounded,
                  size: 16, color: AppTokens.accent),
              const SizedBox(width: 6),
              const Text('虚拟测光表',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('EV100 ${r.ev100.toStringAsFixed(1)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _cell(context, '建议曝光',
                  'ISO ${r.iso} · ${r.shutter} · ${r.aperture}'),
              const SizedBox(width: 10),
              _cell(context, '光比', r.ratioLabel),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              _cell(context, '影调', r.moodLabel),
              const SizedBox(width: 10),
              _cell(context, '照度', '${r.keyLux.round()} lux'),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.advice,
              style: TextStyle(
                  fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String label, String value) => Expanded(
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style.copyWith(fontSize: 11.5),
            children: <TextSpan>[
              TextSpan(
                  text: '$label ',
                  style: const TextStyle(color: AppTokens.lightMuted)),
              TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

/// 可折叠小节（A3/B2：关节微调与画质）。
class _CollapsibleCard extends StatefulWidget {
  const _CollapsibleCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(AppTokens.rSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

/// A3：人物关节微调（照片姿势导入后可用；bridge.setJoint 实时同步）。
class _JointTunePanel extends StatefulWidget {
  const _JointTunePanel({
    required this.pose,
    required this.controller,
    required this.bridge,
    required this.onReset,
    required this.onSave,
    this.handL = const HandPoseState(),
    this.handR = const HandPoseState(),
  });

  final Map<String, Object?>? pose;
  final LightingController controller;
  final EngineBridge? bridge;
  final VoidCallback onReset;
  final void Function(String name, HandPoseState l, HandPoseState r) onSave;
  final HandPoseState handL;
  final HandPoseState handR;

  @override
  State<_JointTunePanel> createState() => _JointTunePanelState();
}

class _JointTunePanelState extends State<_JointTunePanel> {
  String _joint = 'shoulder_l';
  final TextEditingController _saveCtl = TextEditingController();

  @override
  void dispose() {
    _saveCtl.dispose();
    super.dispose();
  }

  static const List<(String, String)> _joints = <(String, String)>[
    ('spine', '脊柱'),
    ('neck', '颈部'),
    ('shoulder_l', '左肩'),
    ('elbow_l', '左肘'),
    ('wrist_l', '左腕'),
    ('shoulder_r', '右肩'),
    ('elbow_r', '右肘'),
    ('wrist_r', '右腕'),
    ('hip_l', '左髋'),
    ('knee_l', '左膝'),
    ('hip_r', '右髋'),
    ('knee_r', '右膝'),
  ];

  static const List<(String, String, int)> _axes = <(String, String, int)>[
    ('rx 前后', 'rx', 0),
    ('ry 左右', 'ry', 1),
    ('rz 开合', 'rz', 2),
  ];

  List<double> _triple(Object? raw) {
    if (raw is List && raw.length >= 3) {
      return <double>[
        (raw[0] as num?)?.toDouble() ?? 0,
        (raw[1] as num?)?.toDouble() ?? 0,
        (raw[2] as num?)?.toDouble() ?? 0,
      ];
    }
    if (raw is Map) {
      return <double>[
        (raw['0'] as num?)?.toDouble() ?? 0,
        (raw['1'] as num?)?.toDouble() ?? 0,
        (raw['2'] as num?)?.toDouble() ?? 0,
      ];
    }
    return <double>[0, 0, 0];
  }

  (double, double) _range(String joint, int axis) {
    final String base = joint.split('_').first;
    if (axis == 0) {
      if (base == 'knee') return (0, 140);
      if (base == 'elbow') return (-150, 5);
      if (base == 'hip') return (-120, 40);
    }
    if (axis == 2 && base == 'shoulder') return (-90, 90);
    return (-160, 160);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Object?>? pose = widget.pose;
    return _CollapsibleCard(
      title: '关节微调',
      subtitle: pose == null ? '请先导入照片姿势' : '12 关节 · 实时同步 3D',
      child: pose == null
          ? const Text('从「动作摆姿库」导入照片姿势后，可在此微调 12 个关节角度。',
              style: TextStyle(fontSize: 11.5))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final (String id, String label) in _joints)
                      SsChip(
                        label: label,
                        selected: _joint == id,
                        onTap: () => setState(() => _joint = id),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final (String label, String axis, int index) in _axes)
                  _axisSlider(pose, label, axis, index),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    SsButton(
                      label: '恢复注入姿势',
                      kind: SsButtonKind.ghost,
                      dense: true,
                      onPressed: widget.onReset,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // V5/D88：把当前关节 + 手部另存为自定义姿势（进入姿势库）。
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _saveCtl,
                        decoration: const InputDecoration(
                            hintText: '另存为姿势名称', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SsButton(
                      label: '另存为姿势',
                      dense: true,
                      kind: SsButtonKind.soft,
                      onPressed: () {
                        final String name = _saveCtl.text.trim();
                        if (name.isEmpty) return;
                        widget.onSave(name, widget.handL, widget.handR);
                        _saveCtl.clear();
                      },
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _axisSlider(
      Map<String, Object?> pose, String label, String axis, int index) {
    final List<double> triple = _triple(pose[_joint]);
    final (double, double) range = _range(_joint, index);
    final double value = triple[index].clamp(range.$1, range.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 11.5)),
            const Spacer(),
            Text(value.toStringAsFixed(0),
                style: AppTokens.mono(context, size: 11)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value,
            min: range.$1,
            max: range.$2,
            onChanged: (double v) {
              final List<double> next = List<double>.of(triple);
              next[index] = v;
              widget.controller.adjustPendingJoint(_joint, axis, v);
              widget.bridge?.setJoint(_joint, next);
            },
          ),
        ),
      ],
    );
  }
}

/// V5/D86：手部动作面板（左右独立 · 15 个预设 · 每指微调）。
class _HandPosePanel extends StatefulWidget {
  const _HandPosePanel({
    required this.state,
    required this.controller,
    required this.bridge,
    required this.legacy,
  });

  final LightingState state;
  final LightingController controller;
  final EngineBridge? bridge;
  final bool legacy;

  @override
  State<_HandPosePanel> createState() => _HandPosePanelState();
}

class _HandPosePanelState extends State<_HandPosePanel> {
  String _side = 'l';

  static const List<(String, String)> _fingers = <(String, String)>[
    ('thumb', '拇指'),
    ('index', '食指'),
    ('middle', '中指'),
    ('ring', '无名指'),
    ('pinky', '小指'),
  ];

  HandPoseState get _current =>
      _side == 'r' ? widget.state.handR : widget.state.handL;

  void _applyPreset(String id) {
    final HandPresetInfo? preset = handPresetById(id);
    if (preset == null) return;
    widget.controller.setHandPreset(_side, id);
    // 引擎即时反馈（双手组合由引擎同时写入两侧）。
    widget.bridge?.setHandPose(_side, id);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _CollapsibleCard(
      title: '手部动作',
      subtitle: widget.legacy ? '轻量假人无手指骨骼' : '左右独立 · 预设与每指微调',
      child: widget.legacy
          ? const Text(
              '轻量假人不含手指骨骼：在视图工具条切换到 GLB 人物后可用手部动作。',
              style: TextStyle(fontSize: 11.5),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    for (final (String s, String label) in <(String, String)>[
                      ('l', '左手'),
                      ('r', '右手')
                    ])
                      SsChip(
                        label: label,
                        selected: _side == s,
                        onTap: () => setState(() => _side = s),
                      ),
                    const SizedBox(width: 6),
                    SsButton(
                      label: '恢复默认',
                      kind: SsButtonKind.ghost,
                      dense: true,
                      onPressed: () {
                        widget.controller.resetHands();
                        widget.bridge?.resetHands();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final HandPresetInfo p
                        in kHandPresetList.where((HandPresetInfo p) => !p.dual))
                      SsChip(
                        label: '${p.emoji} ${p.label}',
                        selected: _current.preset == p.id,
                        onTap: () => _applyPreset(p.id),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text('双手组合',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 6),
                    for (final HandPresetInfo p
                        in kHandPresetList.where((HandPresetInfo p) => p.dual))
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: SsChip(
                          label: '${p.emoji} ${p.label}',
                          selected: widget.state.handL.preset == p.id &&
                              widget.state.handR.preset == p.id,
                          onTap: () {
                            widget.controller.setHandPreset('both', p.id);
                            widget.bridge?.setHandPose('l', p.id);
                          },
                        ),
                      ),
                  ],
                ),
                const Divider(height: 16),
                Text(
                  '每指微调（${_side == 'r' ? '右手' : '左手'}）',
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                for (final (String finger, String label) in _fingers)
                  _curlSlider(
                    label: label,
                    value: _current.curls[finger] ?? 0,
                    onChanged: (double v) {
                      widget.controller.setHandCurl(_side, finger, v);
                      widget.bridge?.setHandCurls(_side, <String, Object?>{
                        'curls': <String, double>{finger: v},
                      });
                    },
                  ),
                _curlSlider(
                  label: '张开度',
                  value: _current.spread,
                  onChanged: (double v) {
                    widget.controller.setHandSpread(_side, v);
                    widget.bridge?.setHandCurls(_side, <String, Object?>{
                      'spread': v,
                    });
                  },
                ),
              ],
            ),
    );
  }

  Widget _curlSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 52,
          child: Text(label, style: const TextStyle(fontSize: 11.5)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(0, 1),
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '${(value * 100).round()}',
            style: AppTokens.mono(context, size: 10.5),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// B2：画质设置（细分 / 材质预设 / 环境反射；持久化到工作区设置）。
class _QualityPanel extends StatelessWidget {
  const _QualityPanel({required this.state, required this.controller});

  final LightingState state;
  final LightingController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _CollapsibleCard(
      title: '画质',
      subtitle: '环境光 · 细分等级 · 材质预设 · 环境反射',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // V5/D85：环境光开关（关 = 半球光 + 环境贴图贡献全部关闭）。
          Row(
            children: <Widget>[
              const Text('环境光',
                  style:
                      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              SsChip(
                label: state.ambientEnabled ? '开' : '关（仅摄影灯）',
                selected: state.ambientEnabled,
                onTap: () =>
                    controller.setAmbientEnabled(!state.ambientEnabled),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // V5/D91：接触阴影开关（仅 realistic 预设生效，R38）。
          Row(
            children: <Widget>[
              const Text('接触阴影',
                  style:
                      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              SsChip(
                label: state.contactShadow ? '开' : '关',
                selected: state.contactShadow,
                onTap: () => controller.setContactShadow(!state.contactShadow),
              ),
            ],
          ),
          if (!state.contactShadow || state.materialPreset != 'realistic')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                !state.contactShadow ? '接触阴影已关闭。' : '接触阴影仅写实材质预设生效。',
                style: TextStyle(
                    fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 10),
          // V6/D104：性能档（自动探测 / 画质优先 / 性能优先）。
          const Text('性能档',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              for (final (String id, String label) in <(String, String)>[
                ('auto', '自动'),
                ('high', '画质优先'),
                ('low', '性能优先'),
              ])
                SsChip(
                  label: label,
                  selected: state.performanceProfile == id,
                  onTap: () => controller.setPerformanceProfile(id),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              state.performanceProfile == 'low'
                  ? '性能优先：关闭接触阴影、降低阴影与渲染分辨率、细分上限 1 级。'
                  : '自动会根据 GPU/内存自动选择；手动可随时切换。',
              style: TextStyle(
                  fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 10),
          const Text('细分等级',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              for (final (int level, String label) in <(int, String)>[
                (0, '轻量 6k'),
                (1, '标准 40k'),
                (2, '高 80k+'),
              ])
                SsChip(
                  label: label,
                  selected: state.subdivisionLevel == level,
                  onTap: () => controller.setSubdivision(level),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('材质预设',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              for (final (String id, String label) in <(String, String)>[
                ('standard', '标准'),
                ('realistic', '写实'),
                ('light', '轻量'),
              ])
                SsChip(
                  label: label,
                  selected: state.materialPreset == id,
                  onTap: () => controller.setMaterialPreset(id),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Text('环境反射',
                  style:
                      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${state.envIntensity.toStringAsFixed(1)}×',
                  style: AppTokens.mono(context, size: 11)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: state.envIntensity.clamp(0, 2),
              min: 0,
              max: 2,
              divisions: 20,
              onChanged: state.ambientEnabled
                  ? (double v) => controller.setEnvIntensity(v)
                  : null,
            ),
          ),
          Text(
            state.ambientEnabled
                ? '标准/高为运行时 Loop 细分（R18：40k–60k 面）；轻量为原模型（R26）。'
                : '环境光已关闭：环境反射滑杆暂不生效（强度已记忆）。',
            style: TextStyle(
                fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
