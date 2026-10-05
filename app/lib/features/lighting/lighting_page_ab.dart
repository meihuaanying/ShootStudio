part of 'lighting_page.dart';

/// A/B 对比：冻结 A/B 两帧画面并计算差异统计。
///
/// 拆成 mixin 而不是 extension：riverpod 的 `ConsumerState.ref` 与 Flutter 的
/// `State.context` 都受保护成员约束，`--fatal-infos` 下 extension 访问会报
/// `invalid_use_of_protected_member`；mixin 在类的继承链上，访问合法，
/// 且方法仍归属 _LightingPageState，build() 里的调用点零改动。
mixin _LightingPageAb on ConsumerState<LightingPage> {
  EngineBridge? _bridge;

  // V7/D138：静帧导出与 A/B 对比。
  StillExportSession? _stillSession;

  final ValueNotifier<AbSlots> _abSlots = ValueNotifier<AbSlots>(
    const AbSlots(),
  );
  AbDiffStats? _abStats;

  void _setAbSlot(String slot, String dataUrl) {
    _abSlots.value = _abSlots.value.withSlot(slot, dataUrl);
    _abStats = null;
    ref
        .read(lightingControllerProvider.notifier)
        .setStatus(slot == 'b' ? '已冻结 B 画面，可对比差异' : '已冻结 A 画面，请调整灯光后冻结 B');
  }

  AbDiffStats? _abStatsFor(AbSlots slots) {
    if (_abStats != null) return _abStats;
    final String? a = slots.a;
    final String? b = slots.b;
    if (a == null || b == null) return null;
    _abStats = abDiffStats(
      base64Decode(a.contains(',') ? a.split(',').last : a),
      base64Decode(b.contains(',') ? b.split(',').last : b),
    );
    return _abStats;
  }

  void _openStillDialog() {
    if (_bridge == null) {
      ssToast(context, '3D 引擎未就绪：请先切换到「3D 预览」或「分屏」');
      return;
    }
    final StillExportSession session = _stillSession ??= StillExportSession(
      workspace: ref.read(workspaceProvider),
    );
    session.bridge = _bridge;
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => StillExportDialog(session: session),
    );
  }

  void _openAbDialog() {
    final EngineBridge? bridge = _bridge;
    if (bridge == null) {
      ssToast(context, '3D 引擎未就绪：请先切换到「3D 预览」或「分屏」');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => AbCompareDialog(
        bridge: bridge,
        workspace: ref.read(workspaceProvider),
        slots: _abSlots,
        statsOf: _abStatsFor,
      ),
    );
  }
}
