// V8/S6 · D152：折叠卡 + 12 关节微调面板 + 手部预设面板（布光预演右栏）。
// 从 lighting_page.dart 拆出（R73 行数门禁）；版面与行为不变。

import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';
import '../../../services/content_packs.dart';
import '../../../services/engine/engine_bridge.dart';

import '../hand_presets.dart';
import '../lighting_controller.dart';

class LightingCollapsibleCard extends StatefulWidget {
  const LightingCollapsibleCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  State<LightingCollapsibleCard> createState() =>
      LightingCollapsibleCardState();
}

class LightingCollapsibleCardState extends State<LightingCollapsibleCard> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: AppFontSize.small,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: AppFontSize.tinyLg,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                  ),
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
class JointTunePanel extends StatefulWidget {
  const JointTunePanel({
    super.key,
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
  State<JointTunePanel> createState() => JointTunePanelState();
}

class JointTunePanelState extends State<JointTunePanel> {
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
    return LightingCollapsibleCard(
      title: '关节微调',
      subtitle: pose == null ? '请先导入照片姿势' : '12 关节 · 实时同步 3D',
      child: pose == null
          ? const Text(
              '从「动作摆姿库」导入照片姿势后，可在此微调 12 个关节角度。',
              style: TextStyle(fontSize: AppFontSize.captionLg),
            )
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
                  _axisSlider(context, pose, label, axis, index),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    SsButton(
                      label: '恢复注入姿势',
                      kind: SsButtonKind.text,
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
                          hintText: '另存为姿势名称',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SsButton(
                      label: '另存为姿势',
                      dense: true,
                      kind: SsButtonKind.outline,
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
    BuildContext context,
    Map<String, Object?> pose,
    String label,
    String axis,
    int index,
  ) {
    final List<double> triple = _triple(pose[_joint]);
    final (double, double) range = _range(_joint, index);
    final double value = triple[index].clamp(range.$1, range.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(fontSize: AppFontSize.captionLg),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(0),
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
class HandPosePanel extends StatefulWidget {
  const HandPosePanel({
    super.key,
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
  State<HandPosePanel> createState() => HandPosePanelState();
}

class HandPosePanelState extends State<HandPosePanel> {
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
    return LightingCollapsibleCard(
      title: '手部动作',
      subtitle: widget.legacy ? '轻量假人无手指骨骼' : '左右独立 · 预设与每指微调',
      child: widget.legacy
          ? const Text(
              '轻量假人不含手指骨骼：在视图工具条切换到 GLB 人物后可用手部动作。',
              style: TextStyle(fontSize: AppFontSize.captionLg),
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
                      ('r', '右手'),
                    ])
                      SsChip(
                        label: label,
                        selected: _side == s,
                        onTap: () => setState(() => _side = s),
                      ),
                    const SizedBox(width: 6),
                    SsButton(
                      label: '恢复默认',
                      kind: SsButtonKind.text,
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
                    for (final HandPresetInfo preset in kHandPresetList.where(
                      (HandPresetInfo preset) => !preset.dual,
                    ))
                      SsChip(
                        label: '${preset.emoji} ${preset.label}',
                        selected: _current.preset == preset.id,
                        onTap: () => _applyPreset(preset.id),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(
                      '双手组合',
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    for (final HandPresetInfo preset in kHandPresetList.where(
                      (HandPresetInfo preset) => preset.dual,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: SsChip(
                          label: '${preset.emoji} ${preset.label}',
                          selected:
                              widget.state.handL.preset == preset.id &&
                              widget.state.handR.preset == preset.id,
                          onTap: () {
                            widget.controller.setHandPreset('both', preset.id);
                            widget.bridge?.setHandPose('l', preset.id);
                          },
                        ),
                      ),
                  ],
                ),
                const Divider(height: 16),
                Text(
                  '每指微调（${_side == 'r' ? '右手' : '左手'}）',
                  style: TextStyle(
                    fontSize: AppFontSize.caption,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
            style: appMono(context.palette.inkSoft),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// V6/D105：机位面板（俯视图拖动 + 高度/俯仰/偏航/焦段 + POV 预览）。
