// V8/S6 · D152：布光预演左栏（预设 + 设备/道具清单 + 右键菜单 + 加灯/加道具/清空）。
//
// D152 信息架构：左 = 设备/道具清单（可折叠），中 = 视口（≥60%），右 = 属性检查器。
// 左栏自持交互（上限校验、右键菜单），页面只喂 state / controller / presets。

import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';
import '../../../services/content_packs.dart';

import '../lighting_controller.dart';
import '../lighting_models.dart';
import 'lighting_device_list.dart';

/// 左栏：208px 预设卡组 + 弹性设备清单。
class LightingLeftColumn extends StatelessWidget {
  const LightingLeftColumn({
    super.key,
    required this.state,
    required this.controller,
    required this.presets,
  });

  final LightingState state;
  final LightingController controller;
  final List<LightPresetEntry> presets;

  void _addWithLimitCheck(BuildContext context, VoidCallback add) {
    if (state.scene.devices.length >= LightingSceneData.maxDevices) {
      ssToast(context, '单影棚上限 ${LightingSceneData.maxDevices} 个对象');
      return;
    }
    add();
  }

  /// D152：右键 / 长按设备行 → 快捷菜单（聚焦属性 / 复制 / 删除）。
  Future<void> _openMenu(
    BuildContext context,
    DeviceSpec device,
    Offset at,
  ) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final String? choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(at.dx, at.dy, 0, 0),
        Offset.zero & (box?.size ?? Size.zero),
      ),
      items: const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'focus', child: Text('聚焦属性')),
        PopupMenuItem<String>(value: 'duplicate', child: Text('复制一个')),
        PopupMenuItem<String>(value: 'delete', child: Text('删除')),
      ],
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'focus':
        controller.select(device.id);
        controller.setStatus('已选中 ${device.name}（右栏显示属性）');
      case 'duplicate':
        _addWithLimitCheck(
          context,
          () =>
              controller.addLight(type: device.type, name: '${device.name} 副本'),
        );
      case 'delete':
        controller.select(device.id);
        controller.removeSelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 208,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 208,
            child: LightingPresetPanel(
              presets: presets,
              onPick: (LightPresetEntry preset) {
                controller.applyPreset(preset);
                ssToast(context, preset.note);
              },
              onAddLight: () =>
                  _addWithLimitCheck(context, controller.addLight),
              onAddProp: () => _addWithLimitCheck(context, controller.addProp),
              onClear: controller.clearAll,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          Expanded(
            child: LightingDeviceList(
              devices: state.scene.devices,
              selectedId: state.selectedId,
              onSelect: controller.select,
              onCapture: controller.requestCapture,
              onOpenMenu: (DeviceSpec d, Offset at) =>
                  _openMenu(context, d, at),
            ),
          ),
        ],
      ),
    );
  }
}
