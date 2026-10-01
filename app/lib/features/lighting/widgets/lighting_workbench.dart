// V8/S6 · D152：布光预演中栏（顶部工具条 + 3D 视口/灯位图画面）。
//
// D152：视口是主角（≥60% 宽），工具条集中「机位/构图/画质/出片/撤销重做」；
// 俯视灯位图从独占视口降级为视口左上角可拖动画中画（可一键全屏/还原）。
// 从 lighting_page.dart 拆出（R73 行数门禁）；画面与交互沿用原实现。

import 'package:flutter/material.dart';

import '../../../core/design/widgets.dart';
import '../../../services/engine/engine_bridge.dart';
import '../../../services/engine/engine_view.dart';

import '../camera_helpers.dart';
import '../lighting_controller.dart';
import '../lighting_models.dart';
import 'lighting_canvas_view.dart';

/// 顶部工具条（视图 / 机位 / 构图 / 画质 / 人物 / 出片 / 撤销重做）。
class LightingToolbar extends StatelessWidget {
  const LightingToolbar({
    super.key,
    required this.viewMode,
    required this.cameraView,
    required this.guides,
    required this.skeleton,
    required this.characterName,
    required this.characterSelected,
    required this.stillRunning,
    required this.abReady,
    required this.canUndo,
    required this.canRedo,
    required this.listCollapsed,
    required this.pip,
    required this.status,
    required this.onView,
    required this.onToggleSkeleton,
    required this.onPickCharacter,
    required this.onToggleCameraView,
    required this.onToggleGuides,
    required this.onToggleList,
    required this.onTogglePip,
    required this.onOpenStill,
    required this.onOpenAb,
    required this.onUndo,
    required this.onRedo,
  });

  final String viewMode;
  final bool cameraView;
  final CameraGuideSettings guides;
  final bool skeleton;
  final String characterName;
  final bool characterSelected;
  final bool stillRunning;
  final bool abReady;
  final bool canUndo;
  final bool canRedo;
  final bool listCollapsed;
  final bool pip;
  final String status;
  final ValueChanged<String> onView;
  final VoidCallback onToggleSkeleton;
  final VoidCallback onPickCharacter;
  final VoidCallback onToggleCameraView;
  final VoidCallback onToggleGuides;
  final VoidCallback onToggleList;
  final VoidCallback onTogglePip;
  final VoidCallback onOpenStill;
  final VoidCallback onOpenAb;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    Widget chip(
      String label, {
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: SsChip(label: label, selected: selected, onTap: onTap),
      );
    }

    // 窄窗口（可缩放桌面窗口）下工具条不能溢出：左半区可横向滚动，
    // 右半区（状态 + 撤销/重做 + 出片）常驻（D152 顶栏）。
    return Row(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final (String label, String mode) in <(String, String)>[
                  ('俯视图', 'top'),
                  ('3D 预览', 'scene3d'),
                  ('分屏', 'split'),
                ])
                  chip(
                    label,
                    selected: viewMode == mode,
                    onTap: () => onView(mode),
                  ),
                chip(
                  cameraView ? '相机视角中' : '机位',
                  selected: cameraView,
                  onTap: onToggleCameraView,
                ),
                chip(
                  guides.enabled ? '构图辅助开' : '构图',
                  selected: guides.enabled,
                  onTap: onToggleGuides,
                ),
                chip(
                  skeleton ? '骨骼开' : '画质',
                  selected: skeleton,
                  onTap: onToggleSkeleton,
                ),
                chip(
                  '人物 · $characterName',
                  selected: characterSelected,
                  onTap: onPickCharacter,
                ),
                chip(
                  pip ? '灯位图·画中画' : '灯位图',
                  selected: pip,
                  onTap: onTogglePip,
                ),
                chip(
                  listCollapsed ? '展开清单' : '收起清单',
                  selected: !listCollapsed,
                  onTap: onToggleList,
                ),
              ],
            ),
          ),
        ),
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              status,
              style: appMono(context.palette.inkSoft, size: 11.5),
            ),
          ),
        chip('撤销', selected: canUndo, onTap: canUndo ? onUndo : () {}),
        chip('重做', selected: canRedo, onTap: canRedo ? onRedo : () {}),
        chip(
          abReady ? 'A/B 对比 ·已冻结' : 'A/B 对比',
          selected: abReady,
          onTap: onOpenAb,
        ),
        SsButton(
          label: stillRunning ? '出片中…' : '出片',
          icon: Icons.camera_alt_outlined,
          dense: true,
          onPressed: onOpenStill,
        ),
      ],
    );
  }
}

/// 中栏画面：按 viewMode 组合俯视灯位图 / 3D 视口 / 分屏，并叠加构图辅助与画中画。
class LightingStageView extends StatelessWidget {
  const LightingStageView({
    super.key,
    required this.scene,
    required this.selectedId,
    required this.viewMode,
    required this.cameraView,
    required this.guides,
    required this.assistDistance,
    required this.pip,
    required this.linkage,
    required this.onSelect,
    required this.onMove,
    required this.onMoveEnd,
    required this.onCameraMove,
    required this.onCameraMoveEnd,
    required this.onExportDiagnostics,
    required this.onBridgeReady,
    required this.onEvent,
  });

  final LightingSceneData scene;
  final String? selectedId;
  final String viewMode;
  final bool cameraView;
  final CameraGuideSettings guides;
  final double assistDistance;
  final bool pip;
  final bool linkage;
  final void Function(String? id) onSelect;
  final void Function(String id, double x, double y) onMove;
  final VoidCallback onMoveEnd;
  final void Function(double x, double y) onCameraMove;
  final VoidCallback onCameraMoveEnd;
  final Future<void> Function() onExportDiagnostics;
  final void Function(EngineBridge bridge) onBridgeReady;
  final void Function(EngineEvent event) onEvent;

  Widget _topView(BuildContext context) {
    return SsCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: LightingCanvasView(
          scene: scene,
          selectedId: selectedId,
          onSelect: onSelect,
          onMove: onMove,
          onMoveEnd: onMoveEnd,
          onCameraMove: onCameraMove,
          onCameraMoveEnd: onCameraMoveEnd,
        ),
      ),
    );
  }

  Widget _engine(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          EngineView(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            onExportDiagnostics: onExportDiagnostics,
            onBridgeReady: onBridgeReady,
            onEvent: onEvent,
          ),
          // V7/D139：构图线/安全框/裁切预览（仅 POV 显示；叠加层不进导出图）。
          if (cameraView && guides.enabled)
            IgnorePointer(
              child: CustomPaint(
                painter: CompositionGuidePainter(
                  settings: guides,
                  focalMm: scene.camera.focal,
                  distanceM: assistDistance,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget canvas = _topView(context);
    final Widget engine = _engine(context);
    final Widget body = switch (viewMode) {
      'top' => canvas,
      'scene3d' => engine,
      _ => Row(
        children: <Widget>[
          Expanded(child: canvas),
          const SizedBox(width: AppSpace.s2),
          Expanded(child: engine),
        ],
      ),
    };
    if (viewMode == 'top' || !pip) return body;
    // 画中画：3D/分屏时把俯视灯位图缩到左上角，可拖动，点按钮可全屏。
    return Stack(
      children: <Widget>[
        body,
        Positioned(
          left: 8,
          top: 8,
          child: _PipTopView(
            onToggleFullscreen: () {},
            label: '灯位图 · ${linkage ? '联动' : '解耦'}',
            child: SizedBox(width: 240, height: 168, child: canvas),
          ),
        ),
      ],
    );
  }
}

/// 可拖动画中画（俯视灯位图）。
class _PipTopView extends StatefulWidget {
  const _PipTopView({
    required this.child,
    required this.onToggleFullscreen,
    required this.label,
  });

  final Widget child;
  final VoidCallback onToggleFullscreen;
  final String label;

  @override
  State<_PipTopView> createState() => _PipTopViewState();
}

class _PipTopViewState extends State<_PipTopView> {
  Offset _drag = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _drag,
      child: GestureDetector(
        onPanUpdate: (DragUpdateDetails d) {
          setState(() => _drag = _drag + d.delta);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: context.palette.rule, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.control),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              widget.child,
              Positioned(
                right: 4,
                top: 4,
                child: SsChip(
                  label: widget.label,
                  selected: false,
                  onTap: () {
                    setState(() => _drag = Offset.zero);
                    widget.onToggleFullscreen();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 供页面复用的 LightingState 视角别名（避免各处重复 import）。
typedef LightingWorkbenchState = LightingState;
