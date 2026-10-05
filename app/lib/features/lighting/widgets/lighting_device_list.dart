// V8/S6 · D152：布光预演左栏（32 套布光预设 + 设备/道具清单）。
//
// D152 信息架构：左 = 设备/道具清单（可折叠），中 = 3D 视口（主角，≥60% 宽），
// 右 = 属性检查器。本文件承载左栏，页面只负责喂数据与回调。
// 从 lighting_page.dart 拆出（R73 行数门禁）；版面沿用原实现。

import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';

import '../../../services/content_packs.dart';

import '../lighting_models.dart';

/// 预设卡组（按 category 分组 + 加灯/加道具/清空）。
class LightingPresetPanel extends StatelessWidget {
  const LightingPresetPanel({
    super.key,
    required this.presets,
    required this.onPick,
    required this.onAddLight,
    required this.onAddProp,
    required this.onClear,
  });

  final List<LightPresetEntry> presets;
  final void Function(LightPresetEntry preset) onPick;
  final VoidCallback onAddLight;
  final VoidCallback onAddProp;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<LightPresetEntry>> grouped =
        <String, List<LightPresetEntry>>{};
    for (final LightPresetEntry preset in presets) {
      grouped
          .putIfAbsent(preset.category, () => <LightPresetEntry>[])
          .add(preset);
    }
    return SizedBox(
      width: 208,
      child: SsCard(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SsSectionTitle('布光预设', subtitle: '内置 ${presets.length} 套'),
            const SizedBox(height: AppSpace.s2),
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
                          fontSize: AppFontSize.caption,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final LightPresetEntry preset in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SsCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          onTap: () => onPick(preset),
                          child: Text(
                            preset.name,
                            style: const TextStyle(fontSize: AppFontSize.small),
                          ),
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
                    onPressed: onAddLight,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SsButton(
                    label: '加道具',
                    kind: SsButtonKind.text,
                    dense: true,
                    onPressed: onAddProp,
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
                    kind: SsButtonKind.text,
                    dense: true,
                    onPressed: onClear,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 设备/道具清单（点选选中 + 右键菜单 + 保存预览图）。
class LightingDeviceList extends StatelessWidget {
  const LightingDeviceList({
    super.key,
    required this.devices,
    required this.selectedId,
    required this.onSelect,
    required this.onCapture,
    this.onOpenMenu,
  });

  final List<DeviceSpec> devices;
  final String? selectedId;
  final void Function(String id) onSelect;
  final VoidCallback onCapture;

  /// 右键/长按打开快捷菜单（D152：右键 = 快捷菜单）。
  final void Function(DeviceSpec device, Offset globalPosition)? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SsSectionTitle(
            '设备与道具',
            subtitle: '共 ${devices.length} 个对象',
            trailing: SsButton(
              label: '保存预览图',
              kind: SsButtonKind.text,
              dense: true,
              onPressed: onCapture,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: devices.isEmpty
                ? const Center(
                    child: Text(
                      '空影棚 · 未布置任何灯光',
                      style: TextStyle(fontSize: AppFontSize.smallSm),
                    ),
                  )
                : ListView(
                    children: <Widget>[
                      for (final DeviceSpec d in devices)
                        _DeviceRow(
                          device: d,
                          selected: d.id == selectedId,
                          onTap: () => onSelect(d.id),
                          onOpenMenu: onOpenMenu,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 光型名（与 lighting_models 的 LightType 对齐，未知值回落「硬光」）。
String lightingTypeLabel(String type) {
  for (final LightType t in LightType.values) {
    if (t.name == type) return t.label;
  }
  return '硬光';
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.selected,
    required this.onTap,
    this.onOpenMenu,
  });

  final DeviceSpec device;
  final bool selected;
  final VoidCallback onTap;
  final void Function(DeviceSpec device, Offset globalPosition)? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final DeviceGeometry g = geometryOf(device.x, device.y);
    return GestureDetector(
      onSecondaryTapDown: (TapDownDetails d) =>
          onOpenMenu?.call(device, d.globalPosition),
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          onOpenMenu?.call(
            device,
            box?.localToGlobal(Offset.zero) ?? Offset.zero,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 90,
                child: Text(
                  device.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSize.smallSm,
                    color: selected ? p.accent : null,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  device.isLight
                      ? '${lightingTypeLabel(device.type)} · 方位 ${g.azimuthLabel} · 距离 ${g.distanceLabel} · '
                            '${device.intensity}% · ${device.kelvin}K · ${device.height.toStringAsFixed(1)}m'
                      : '道具 · 坐标 (${device.x.toStringAsFixed(1)}, ${device.y.toStringAsFixed(1)})',
                  style: appMono(p.inkSoft),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
