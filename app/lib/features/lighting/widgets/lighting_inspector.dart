// V8/S6 · D152：布光预演右栏「属性检查器」。
//
// 选中灯具/道具时显示该对象的字段 + 贴图/删除 + 关节/手部/画质面板；
// 未选中时显示空态 + 机位面板 + 测光表 + 同一组公共面板（原先两分支各写一遍，
// 视觉会随改动漂移，这里合并为 _InspectorExtras 一处）。
// 从 lighting_page.dart 拆出（R73 行数门禁）；版面与行为不变。

import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';
import '../../../services/content_packs.dart';
import '../../../services/engine/engine_bridge.dart';

import '../camera_helpers.dart';
import '../lighting_controller.dart';
import '../lighting_models.dart';
import 'lighting_effect_widgets.dart';
import 'lighting_pose_widgets.dart';
import 'lighting_rig_widgets.dart';

/// 属性检查器（布光预演右栏）。
class LightingInspector extends StatelessWidget {
  const LightingInspector({
    super.key,
    required this.state,
    required this.controller,
    required this.bridge,
    required this.guides,
    required this.onGuides,
    required this.assistDistance,
    required this.assistDofAvailable,
    required this.legacyCharacter,
    required this.onSavePose,
    required this.onResetPose,
    required this.onUploadTexture,
    required this.onChanged,
    required this.onNotify,
  });

  final LightingState state;
  final LightingController controller;
  final EngineBridge? bridge;
  final CameraGuideSettings guides;
  final ValueChanged<CameraGuideSettings> onGuides;
  final double assistDistance;
  final bool assistDofAvailable;

  /// 轻量假人（无手指骨骼）时手部面板降级。
  final bool legacyCharacter;

  /// 另存为自定义姿势（含手部）。
  final Future<void> Function(String name, HandPoseState l, HandPoseState r)
  onSavePose;

  /// 恢复导入前的关节。
  final VoidCallback onResetPose;

  /// 上传自定义贴图。
  final Future<void> Function() onUploadTexture;

  /// 删除等会改变 state 的动作后请页面重建。
  final VoidCallback onChanged;

  /// 轻提示（ssToast）。
  final void Function(String message) onNotify;

  /// 两个分支共用的面板（关节微调 + 手部 + 画质 + 效果预览）。
  List<Widget> _extras({bool spaced = true}) {
    return <Widget>[
      if (spaced) const SizedBox(height: AppSpace.s3),
      JointTunePanel(
        pose: state.pendingPose,
        controller: controller,
        handL: state.handL,
        handR: state.handR,
        bridge: bridge,
        onSave: onSavePose,
        onReset: onResetPose,
      ),
      const SizedBox(height: AppSpace.s3),
      HandPosePanel(
        state: state,
        controller: controller,
        bridge: bridge,
        legacy: legacyCharacter,
      ),
      const SizedBox(height: AppSpace.s3),
      QualityPanel(state: state, controller: controller),
      const SizedBox(height: AppSpace.s4),
      LightingEffectPreview(scene: state.scene),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final DeviceSpec? selected = state.selected;
    if (selected == null) return _buildEmpty(context);
    return _buildSelected(context, selected);
  }

  Widget _buildEmpty(BuildContext context) {
    return SsCard(
      child: ListView(
        children: <Widget>[
          const SsSectionTitle('参数面板'),
          const SizedBox(height: AppSpace.s3),
          const SsEmpty(
            icon: Icons.touch_app_outlined,
            art: SsArt.light,
            title: '未选中对象',
            hint: '在画布或 3D 视图中点选灯光 / 道具',
          ),
          const SizedBox(height: AppSpace.s3),
          CameraRigPanel(
            state: state,
            controller: controller,
            guides: guides,
            onGuides: onGuides,
            assistDistance: assistDistance,
            assistDofAvailable: assistDofAvailable,
          ),
          const SizedBox(height: AppSpace.s3),
          LightingMeterCard(scene: state.scene),
          ..._extras(),
        ],
      ),
    );
  }

  Widget _buildSelected(BuildContext context, DeviceSpec selected) {
    final DeviceGeometry g = geometryOf(selected.x, selected.y);
    return SsCard(
      child: ListView(
        children: <Widget>[
          SsSectionTitle(
            selected.name,
            subtitle: selected.isLight
                ? '方位 ${g.azimuthLabel} · 距离 ${g.distanceLabel}'
                : '道具 · (${selected.x.toStringAsFixed(2)}, ${selected.y.toStringAsFixed(2)})',
          ),
          const SizedBox(height: AppSpace.s2),
          if (selected.isLight) ...<Widget>[
            _InspectorDropdown<String>(
              label: '光型',
              value: selected.type,
              options: <String, String>{
                for (final LightType t in LightType.values) t.name: t.label,
              },
              onChanged: (String v) =>
                  controller.updateSelected((DeviceSpec d) => d.type = v),
            ),
            _InspectorDropdown<String>(
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
            _InspectorDropdown<String>(
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
            _InspectorSlider(
              label: '亮度',
              value: selected.intensity.toDouble(),
              min: 1,
              max: 100,
              display: '${selected.intensity}%',
              onChanged: (double v) => controller.updateSelected(
                (DeviceSpec d) => d.intensity = v.round(),
              ),
            ),
            _InspectorSlider(
              label: '色温',
              value: selected.kelvin.toDouble(),
              min: 2700,
              max: 7500,
              display: '${selected.kelvin}K',
              onChanged: (double v) => controller.updateSelected(
                (DeviceSpec d) => d.kelvin = v.round(),
              ),
            ),
            _InspectorSlider(
              label: '光束角',
              value: selected.beamAngle,
              min: 8,
              max: 150,
              display: '${selected.beamAngle.toStringAsFixed(0)}°',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.beamAngle = v),
            ),
            _InspectorSlider(
              label: '柔度',
              value: selected.softness,
              min: 0.02,
              max: 1,
              display: '${(selected.softness * 100).toStringAsFixed(0)}%',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.softness = v),
            ),
            _InspectorSlider(
              label: '高度',
              value: selected.height,
              min: 0.3,
              max: 3.0,
              display: '${selected.height.toStringAsFixed(1)}m',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.height = v),
            ),
            _InspectorSlider(
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
            _InspectorSlider(
              label: '朝向',
              value: selected.rotation,
              min: 0,
              max: 360,
              display: '${selected.rotation.toStringAsFixed(0)}°',
              onChanged: (double v) =>
                  controller.updateSelected((DeviceSpec d) => d.rotation = v),
            ),
            _InspectorSlider(
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
          const SizedBox(height: AppSpace.s2),
          const Text(
            '自定义贴图（上传图将作为贴图占位出现在 3D 场景，D23）',
            style: TextStyle(fontSize: AppFontSize.captionLg),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              SsButton(
                label: '上传贴图',
                icon: Icons.image_outlined,
                kind: SsButtonKind.text,
                dense: true,
                onPressed: onUploadTexture,
              ),
              const SizedBox(width: 6),
              if (selected.texture.isNotEmpty)
                SsButton(
                  label: '移除贴图',
                  kind: SsButtonKind.text,
                  dense: true,
                  onPressed: () => controller.setSelectedTexture(''),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Row(
            children: <Widget>[
              Expanded(
                child: SsButton(
                  label: '删除该对象',
                  icon: Icons.delete_outline_rounded,
                  kind: SsButtonKind.text,
                  dense: true,
                  onPressed: () {
                    controller.removeSelected();
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          ..._extras(spaced: false),
        ],
      ),
    );
  }
}

/// 检查器内的下拉字段（56px 标签列 + 展开下拉）。
class _InspectorDropdown<T> extends StatelessWidget {
  const _InspectorDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.smallSm,
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
                    child: Text(
                      e.value,
                      style: const TextStyle(fontSize: AppFontSize.small),
                    ),
                  ),
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
}

/// 检查器内的滑杆字段（标签行 + 3px 轨道滑杆）。
class _InspectorSlider extends StatelessWidget {
  const _InspectorSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.smallSm,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(display, style: appMono(context.palette.inkSoft)),
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
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
