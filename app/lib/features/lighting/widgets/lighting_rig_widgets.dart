// V8/S6 · D152：机位面板（焦段/高度/构图辅助）+ 画质面板（VSM/细分/性能档）。
// 从 lighting_page.dart 拆出（R73 行数门禁）；版面与行为不变。

import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';

import '../camera_helpers.dart';
import '../lighting_controller.dart';
import '../lighting_models.dart';
import 'lighting_pose_widgets.dart';

class CameraRigPanel extends StatelessWidget {
  const CameraRigPanel({
    super.key,
    required this.state,
    required this.controller,
    required this.guides,
    required this.onGuides,
    this.assistDistance = 3.2,
    this.assistDofAvailable = true,
  });
  final LightingState state;
  final LightingController controller;

  /// V7/D139：构图辅助设置与回调。
  final CameraGuideSettings guides;
  final ValueChanged<CameraGuideSettings> onGuides;

  /// 相机到主体的距离（引擎实测；用于画幅尺寸提示）。
  final double assistDistance;

  /// 景深是否可用（低配档/路径追踪不可用时为 false，R69）。
  final bool assistDofAvailable;
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CameraRigData cam = state.scene.camera;
    return LightingCollapsibleCard(
      title: '机位',
      subtitle: '摄影师机位 · 自动瞄准 · 俯视图拖动',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                '相机模型',
                style: TextStyle(
                  fontSize: AppFontSize.captionLg,
                  fontWeight: AppFontWeight.medium,
                ),
              ),
              const Spacer(),
              SsChip(
                label: cam.enabled ? '显示' : '隐藏',
                selected: cam.enabled,
                onTap: () => controller.updateCamera(
                  (CameraRigData c) => c.enabled = !c.enabled,
                ),
              ),
              const SizedBox(width: 6),
              SsChip(
                label: state.cameraView ? '视角中' : '看构图',
                selected: state.cameraView,
                onTap: () {
                  final bool next = !state.cameraView;
                  controller.setCameraView(next);
                  if (next && state.viewMode == 'top') {
                    controller.setView('scene3d');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          _slider(
            context,
            '焦段',
            cam.focal.toDouble(),
            14,
            200,
            1,
            (double v) => controller.updateCamera(
              (CameraRigData c) => c.focal = v.round(),
            ),
            suffix: 'mm',
          ),
          _slider(
            context,
            '高度',
            cam.height,
            0.6,
            2.2,
            0.01,
            (double v) =>
                controller.updateCamera((CameraRigData c) => c.height = v),
            suffix: 'm',
          ),
          _slider(
            context,
            '俯仰',
            cam.pitch,
            -30,
            30,
            1,
            (double v) =>
                controller.updateCamera((CameraRigData c) => c.pitch = v),
            suffix: '°',
          ),
          _slider(
            context,
            '偏航',
            cam.yaw,
            -60,
            60,
            1,
            (double v) =>
                controller.updateCamera((CameraRigData c) => c.yaw = v),
            suffix: '°',
          ),
          // V7/D139：构图辅助（仅相机视角时叠加显示）。
          if (state.cameraView) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const Text(
                  '构图辅助',
                  style: TextStyle(
                    fontSize: AppFontSize.captionLg,
                    fontWeight: AppFontWeight.medium,
                  ),
                ),
                const Spacer(),
                SsChip(
                  label: '三分线',
                  selected: guides.thirds,
                  onTap: () =>
                      onGuides(guides.copyWith(thirds: !guides.thirds)),
                ),
                const SizedBox(width: 6),
                SsChip(
                  label: '安全框',
                  selected: guides.safeArea,
                  onTap: () =>
                      onGuides(guides.copyWith(safeArea: !guides.safeArea)),
                ),
                const SizedBox(width: 6),
                SsChip(
                  label: '中心',
                  selected: guides.centerCross,
                  onTap: () => onGuides(
                    guides.copyWith(centerCross: !guides.centerCross),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String crop in CameraGuideSettings.cropOptions)
                  SsChip(
                    label: crop == 'none' ? '原画幅' : crop,
                    selected: guides.crop == crop,
                    onTap: () => onGuides(guides.copyWith(crop: crop)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '垂直视野 ${verticalFovDeg(cam.focal.toDouble()).toStringAsFixed(1)}° · '
              '水平 ${horizontalFovDeg(cam.focal.toDouble()).toStringAsFixed(1)}° · '
              '主体距离 ${assistDistance.toStringAsFixed(2)}m · '
              '画幅高 ${frameHeightAt(cam.focal.toDouble(), assistDistance).toStringAsFixed(2)}m'
              '${assistDofAvailable ? '' : ' · 景深不可用（低配档）'}',
              style: TextStyle(
                fontSize: AppFontSize.tinyLg,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          Text(
            '机位可在俯视图上拖动；焦段决定视野扇形与 POV 构图。',
            style: TextStyle(
              fontSize: AppFontSize.tinyLg,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    double step,
    ValueChanged<double> onChanged, {
    String suffix = '',
  }) {
    final bool isInt = suffix == 'mm';
    return Row(
      children: <Widget>[
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: const TextStyle(fontSize: AppFontSize.captionLg),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(
            '${isInt ? value.round() : value.toStringAsFixed(1)}$suffix',
            style: appMono(context.palette.inkSoft),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// B2：画质设置（细分 / 材质预设 / 环境反射；持久化到工作区设置）。
class QualityPanel extends StatelessWidget {
  const QualityPanel({
    super.key,
    required this.state,
    required this.controller,
  });
  final LightingState state;
  final LightingController controller;
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LightingCollapsibleCard(
      title: '画质',
      subtitle: '环境光 · 细分等级 · 材质预设 · 环境反射',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // V5/D85：环境光开关（关 = 半球光 + 环境贴图贡献全部关闭）。
          Row(
            children: <Widget>[
              const Text(
                '环境光',
                style: TextStyle(
                  fontSize: AppFontSize.captionLg,
                  fontWeight: AppFontWeight.medium,
                ),
              ),
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
              const Text(
                '接触阴影',
                style: TextStyle(
                  fontSize: AppFontSize.captionLg,
                  fontWeight: AppFontWeight.medium,
                ),
              ),
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
                  fontSize: AppFontSize.tinyLg,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 10),
          // V6/D104：性能档（自动探测 / 画质优先 / 性能优先）。
          const Text(
            '性能档',
            style: TextStyle(
              fontSize: AppFontSize.captionLg,
              fontWeight: AppFontWeight.medium,
            ),
          ),
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
                fontSize: AppFontSize.tinyLg,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // V6/D111：光锥可视化。
          Row(
            children: <Widget>[
              const Text(
                '光锥可视化',
                style: TextStyle(
                  fontSize: AppFontSize.captionLg,
                  fontWeight: AppFontWeight.medium,
                ),
              ),
              const Spacer(),
              SsChip(
                label: state.lightCones ? '开' : '关',
                selected: state.lightCones,
                onTap: () => controller.setLightCones(!state.lightCones),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // V7/D137：软阴影（VSM）。
          Row(
            children: <Widget>[
              const Text(
                '软阴影（VSM）',
                style: TextStyle(
                  fontSize: AppFontSize.captionLg,
                  fontWeight: AppFontWeight.medium,
                ),
              ),
              const Spacer(),
              SsChip(
                label: state.softShadows ? '开' : '关',
                selected: state.softShadows,
                onTap: () => controller.setSoftShadows(!state.softShadows),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '软阴影随附件/灯距变化；性能优先档自动回退 PCF 硬边。',
              style: TextStyle(
                fontSize: AppFontSize.tinyLg,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '细分等级',
            style: TextStyle(
              fontSize: AppFontSize.captionLg,
              fontWeight: AppFontWeight.medium,
            ),
          ),
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
          const Text(
            '材质预设',
            style: TextStyle(
              fontSize: AppFontSize.captionLg,
              fontWeight: AppFontWeight.medium,
            ),
          ),
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
              const Text(
                '环境反射',
                style: TextStyle(
                  fontSize: AppFontSize.captionLg,
                  fontWeight: AppFontWeight.medium,
                ),
              ),
              const Spacer(),
              Text(
                '${state.envIntensity.toStringAsFixed(1)}×',
                style: appMono(context.palette.inkSoft),
              ),
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
              fontSize: AppFontSize.tinyLg,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// V7/D138：A/B 布光对比对话框 —— 冻结 A（调整前）→ 调灯 → 冻结 B（调整后），
/// 并排预览 + 差异摘要（阈值 12/255）+ 合成图保存到工作区。
