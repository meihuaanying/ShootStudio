import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/design/widgets.dart';
import '../../core/theme/tokens.dart';
import '../../core/workspace/workspace.dart';
import '../../services/engine/engine_bridge.dart';

/// V7/D138：静帧导出会话（「效果预览」对话框状态机）。
/// 路径追踪（path）为照片级模式：首次需编译着色器（本机 RTX 4060 实测约 40–80s），
/// 预热或二次导出为亚秒级（程序缓存命中）；低配档/加载失败自动回退超采样。
class StillExportSession extends ChangeNotifier {
  StillExportSession({required this.workspace});

  final Workspace workspace;

  EngineBridge? bridge;
  bool running = false;
  String mode = 'path';
  String phase = '';
  int samples = 0;
  int target = 0;
  int elapsedMs = 0;
  String? error;
  EngineStillRendered? result;
  String? savedPath;

  bool get hasResult => result != null && result!.ok;

  String get statusLabel {
    if (error != null) return '失败：$error';
    if (!running) return hasResult ? '已完成' : '待开始';
    if (phase == 'compile') return '正在编译路径追踪着色器（首次较慢，请稍候）…';
    if (mode == 'warm') return '着色器预热中…';
    return '采样 $samples / $target';
  }

  void start({
    required String mode,
    required int width,
    required int height,
    required int samples,
    required int factor,
    required bool useCameraRig,
  }) {
    if (running) return;
    final EngineBridge? b = bridge;
    if (b == null) {
      error = '3D 引擎未就绪（切换到「3D 预览」或「分屏」后重试）';
      notifyListeners();
      return;
    }
    this.mode = mode;
    running = true;
    phase = mode == 'path' ? 'compile' : 'render';
    this.samples = 0;
    target = mode == 'path' ? samples : factor;
    elapsedMs = 0;
    error = null;
    result = null;
    savedPath = null;
    notifyListeners();
    b.renderStill(
      mode: mode,
      width: width,
      height: height,
      samples: samples,
      factor: factor,
      useCameraRig: useCameraRig,
    );
  }

  void onProgress(EngineStillProgress event) {
    if (event.mode == 'warm') {
      // 预热进度不占用导出会话状态，仅刷新提示。
      return;
    }
    running = true;
    phase = event.phase;
    samples = event.samples;
    target = event.target;
    elapsedMs = event.elapsedMs;
    notifyListeners();
  }

  Future<void> onRendered(EngineStillRendered event) async {
    running = false;
    result = event;
    phase = 'done';
    error = event.ok ? null : (event.error.isEmpty ? '渲染失败' : event.error);
    if (event.ok && event.dataUrl.isNotEmpty) {
      savedPath = await saveToWorkspace(event);
    }
    notifyListeners();
  }

  /// 保存到工作区 images/plans/（返回文件路径）。
  Future<String?> saveToWorkspace(EngineStillRendered event) async {
    try {
      final String base64Part = event.dataUrl.contains(',')
          ? event.dataUrl.split(',').last
          : event.dataUrl;
      final List<int> bytes = base64Decode(base64Part);
      final Directory dir = Directory(
        p.join(workspace.root.path, 'images', 'plans'),
      );
      await dir.create(recursive: true);
      final String tag = event.mode == 'path' ? '路径追踪' : '超采样';
      final File file = File(
        p.join(
          dir.path,
          '静帧_${tag}_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      error = '保存失败：$e';
      return null;
    }
  }

  /// 以工作区根目录为基准的相对路径（用于状态提示）。
  String get savedRelative {
    final String? path = savedPath;
    if (path == null) return '';
    final String root = workspace.root.path;
    return path.startsWith(root) ? path.substring(root.length + 1) : path;
  }
}

/// 「效果预览」对话框：模式/分辨率/采样数 + 进度 + 结果预览。
class StillExportDialog extends StatefulWidget {
  const StillExportDialog({super.key, required this.session});

  final StillExportSession session;

  @override
  State<StillExportDialog> createState() => _StillExportDialogState();
}

class _StillExportDialogState extends State<StillExportDialog> {
  String _mode = 'path';
  String _resolution = '960x720';
  int _samples = 128;
  bool _useCameraRig = true;

  @override
  Widget build(BuildContext context) {
    final StillExportSession session = widget.session;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s16),
          child: AnimatedBuilder(
            animation: session,
            builder: (BuildContext context, Widget? _) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SsSectionTitle(
                      '效果预览（静帧导出）',
                      subtitle: '路径追踪 = 照片级（首次编译较慢）；超采样 = 秒级快速预览',
                    ),
                    const SizedBox(height: AppTokens.s12),
                    _options(context, session),
                    const SizedBox(height: AppTokens.s12),
                    _progress(context, session),
                    if (session.hasResult) ...<Widget>[
                      const SizedBox(height: AppTokens.s12),
                      _preview(context, session),
                    ],
                    const SizedBox(height: AppTokens.s12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        SsButton(
                          label: '关闭',
                          kind: SsButtonKind.ghost,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        SsButton(
                          label: session.running ? '渲染中…' : '渲染并保存',
                          icon: Icons.auto_awesome,
                          onPressed: session.running
                              ? null
                              : () => session.start(
                                  mode: _mode,
                                  width: _resolutionWidth,
                                  height: _resolutionHeight,
                                  samples: _samples,
                                  factor: _mode == 'path'
                                      ? 2
                                      : _samples.clamp(1, 3),
                                  useCameraRig: _useCameraRig,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  int get _resolutionWidth => int.parse(_resolution.split('x').first);

  int get _resolutionHeight => int.parse(_resolution.split('x').last);

  Widget _options(BuildContext context, StillExportSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'path',
                    label: Text('照片级（路径追踪）'),
                  ),
                  ButtonSegment<String>(
                    value: 'supersample',
                    label: Text('快速（超采样）'),
                  ),
                ],
                selected: <String>{_mode},
                onSelectionChanged: session.running
                    ? null
                    : (Set<String> value) =>
                          setState(() => _mode = value.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.s8),
        Row(
          children: <Widget>[
            const Text('分辨率', style: TextStyle(fontSize: 12.5)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _resolution,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: '640x480',
                  child: Text('640 × 480'),
                ),
                DropdownMenuItem<String>(
                  value: '960x720',
                  child: Text('960 × 720'),
                ),
                DropdownMenuItem<String>(
                  value: '1280x960',
                  child: Text('1280 × 960'),
                ),
              ],
              onChanged: session.running
                  ? null
                  : (String? value) =>
                        setState(() => _resolution = value ?? _resolution),
            ),
            const SizedBox(width: AppTokens.s16),
            Text(
              _mode == 'path' ? '采样数' : '超采样倍数',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _samples,
              items:
                  (_mode == 'path'
                          ? const <int>[64, 128, 256, 512]
                          : const <int>[2, 3])
                      .map(
                        (int v) => DropdownMenuItem<int>(
                          value: v,
                          child: Text(_mode == 'path' ? '$v' : '$v×'),
                        ),
                      )
                      .toList(),
              onChanged: session.running
                  ? null
                  : (int? value) =>
                        setState(() => _samples = value ?? _samples),
            ),
            const SizedBox(width: AppTokens.s16),
            Checkbox(
              value: _useCameraRig,
              onChanged: session.running
                  ? null
                  : (bool? value) =>
                        setState(() => _useCameraRig = value ?? true),
            ),
            const Text('用相机机位', style: TextStyle(fontSize: 12.5)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '路径追踪：首次需编译着色器（本机实测约 40–80 秒），之后同机位二次导出亚秒级；'
          '低配/软件渲染自动回退超采样。结果自动保存到工作区 images/plans/。',
          style: TextStyle(
            fontSize: 11.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _progress(BuildContext context, StillExportSession session) {
    final double value = session.target <= 0
        ? 0
        : (session.samples / session.target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (session.running)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (session.running) const SizedBox(width: 8),
            Expanded(
              child: Text(
                session.statusLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  color: session.error != null
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
            if (session.elapsedMs > 0)
              Text(
                '${(session.elapsedMs / 1000).toStringAsFixed(1)}s',
                style: AppTokens.mono(context, size: 11.5),
              ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: session.mode == 'path' && session.phase == 'compile'
              ? null
              : value,
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _preview(BuildContext context, StillExportSession session) {
    final EngineStillRendered result = session.result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
          child: Image.memory(
            base64Decode(
              result.dataUrl.contains(',')
                  ? result.dataUrl.split(',').last
                  : result.dataUrl,
            ),
            height: 260,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${result.mode == 'path' ? '路径追踪' : '超采样'} · '
          '${result.width}×${result.height} · ${result.samples} samples · '
          '${(result.ms / 1000).toStringAsFixed(1)}s'
          '${result.msPerSample == null ? '' : '（${result.msPerSample!.toStringAsFixed(0)}ms/sample）'}'
          '${result.reason == 'timeout' ? ' · 超时提前结束' : ''}'
          '${session.savedRelative.isEmpty ? '' : ' · 已存 ${session.savedRelative}'}',
          style: AppTokens.mono(context, size: 11.5),
        ),
      ],
    );
  }
}
