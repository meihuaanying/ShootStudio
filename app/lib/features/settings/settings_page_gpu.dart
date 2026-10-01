// V8/S9 · D158：GPU 后端卡片（适配器 / 模式 / 引擎）。
// 从 settings_page.dart 拆出（R73 行数门禁）；part 同库，私有成员无需公开化。
part of 'settings_page.dart';

class _GpuCard extends ConsumerStatefulWidget {
  const _GpuCard();

  @override
  ConsumerState<_GpuCard> createState() => _GpuCardState();
}

class _GpuCardState extends ConsumerState<_GpuCard> {
  List<GpuAdapter> _adapters = <GpuAdapter>[];
  String _mode = 'auto';
  String _backend = 'cpu';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppDatabase db = ref.read(databaseProvider);
    final List<GpuAdapter> adapters = await GpuService.adapters(refresh: true);
    final String mode =
        await db.getSetting('gpu_mode') ?? GpuService.readModeSync();
    final String backend =
        await db.getSetting('gpu_recognize_backend') ?? 'cpu';
    if (!mounted) return;
    setState(() {
      _adapters = adapters;
      _mode = GpuService.modes.contains(mode) ? mode : 'auto';
      _backend = GpuService.recognizeBackends.contains(backend)
          ? backend
          : 'cpu';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final AppDatabase db = ref.read(databaseProvider);
    await db.setSetting('gpu_mode', _mode);
    await db.setSetting('gpu_recognize_backend', _backend);
    await GpuService.writeMode(_mode);
    // 热切：请求引擎重建 WebView（WebView2 参数在环境创建时读取）。
    requestEngineReload();
    if (!mounted) return;
    ssToast(context, '已保存并请求引擎热重载；若渲染器未切换，请重启应用（识别后端下次识别生效）');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle small = TextStyle(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SsSectionTitle(
            '显卡',
            subtitle: 'V7/D135：DXGI 枚举 · 3D 引擎独显优先 · 端上识别后端',
          ),
          const SizedBox(height: AppSpace.s3),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else ...<Widget>[
            if (_adapters.isEmpty)
              Text('未检测到适配器（非 Windows 或通道不可用）', style: small)
            else
              for (final GpuAdapter a in _adapters)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.memory_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${a.name}（${a.vendorLabel} · ${a.kindLabel} · ${a.memoryLabel}）',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            Text('3D 引擎（WebView2）', style: small),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                for (final String mode in GpuService.modes)
                  SsChip(
                    label: GpuService.modeLabels[mode] ?? mode,
                    selected: _mode == mode,
                    onTap: () => setState(() => _mode = mode),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('端上识别后端（D141 高精度模式）', style: small),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: <Widget>[
                SsChip(
                  label: 'CPU',
                  selected: _backend == 'cpu',
                  onTap: () => setState(() => _backend = 'cpu'),
                ),
                SsChip(
                  label: 'GPU（独显 / DirectML）',
                  selected: _backend == 'gpu',
                  onTap: () => setState(() => _backend = 'gpu'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: engineGpuRenderer,
              builder: (BuildContext _, String renderer, Widget? _) => Text(
                renderer.isEmpty
                    ? '当前引擎 GPU：未报告（打开布光预演后更新）'
                    : '当前引擎 GPU：$renderer',
                style: small,
              ),
            ),
            const SizedBox(height: 8),
            SsButton(label: '保存并应用', dense: true, onPressed: _save),
          ],
        ],
      ),
    );
  }
}
