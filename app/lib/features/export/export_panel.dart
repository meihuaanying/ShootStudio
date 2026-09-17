import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../planner/planner_models.dart';
import 'exporter.dart';

/// 导出面板（PRD 6.7）：格式选择 / 完整性检查 / 进度 / 落盘路径。
class ExportPanel extends ConsumerStatefulWidget {
  const ExportPanel({
    super.key,
    required this.title,
    required this.status,
    required this.modules,
  });

  final String title;
  final PlanDocStatus status;
  final List<PlanModuleData> modules;

  @override
  ConsumerState<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends ConsumerState<ExportPanel> {
  ExportFormat _format = ExportFormat.longPng;
  bool _running = false;
  String _stage = '';
  double _percent = 0;
  List<String> _done = <String>[];
  List<IntegrityIssue> _issues = <IntegrityIssue>[];
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
      final service = _service();
      final issues = await service.checkIntegrity(widget.modules);
      if (mounted) {
        setState(() {
          _issues = issues;
          _checked = true;
        });
      }
    });
  }

  ExportService _service() {
    return ExportService(
      workspace: ref.read(workspaceProvider),
      db: ref.read(databaseProvider),
    );
  }

  Future<void> _run() async {
    if (_issues.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('存在引用失效模块'),
          content: Text(
            '${_issues.take(5).map((IntegrityIssue i) => '· ${i.moduleTitle}：${i.detail}').join('\n')}'
            '\n是否继续导出？',
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('继续导出')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() {
      _running = true;
      _done = <String>[];
      _stage = '准备中…';
      _percent = 0;
    });
    try {
      final result = await _service().run(
        planTitle: widget.title,
        status: widget.status,
        modules: widget.modules,
        format: _format,
        onProgress: (ExportProgress progress) {
          if (mounted) {
            setState(() {
              _stage = progress.stage;
              _percent = progress.percent;
            });
          }
        },
        isCancelled: () => false,
      );
      if (mounted) {
        setState(() {
          _running = false;
          _stage = '导出完成';
          _done = result.files;
        });
      }
    } on ExportCancelled {
      if (mounted) {
        setState(() {
          _running = false;
          _stage = '已取消';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _stage = '导出失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 720,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text('导出策划案',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final ExportFormat format in ExportFormat.values)
                InkWell(
                  onTap: () => setState(() => _format = format),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          _format == format
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 16,
                          color: _format == format ? AppTokens.accent : null,
                        ),
                        const SizedBox(width: 8),
                        Text('${format.label} · ${format.usage}',
                            style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (_checked && _issues.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SsBanner(
                    text: '完整性检查：${_issues.length} 处引用失效（导出前将再次确认）',
                    kind: SsBannerKind.warning,
                  ),
                ),
              if (widget.status == PlanDocStatus.draft)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: SsBanner(
                      text: '当前为草稿态：导出物将带「草稿 · 未定稿」标注',
                      kind: SsBannerKind.info),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '排版预览 · ${widget.modules.length} 个模块',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        for (var i = 0; i < widget.modules.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: Theme.of(context).colorScheme.outline),
                            ),
                            child: Text(
                              '${i + 1} ${widget.modules[i].type.label}',
                              style: const TextStyle(fontSize: 10.5),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_running)
                LinearProgressIndicator(value: _percent <= 0 ? null : _percent),
              if (_stage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _stage,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final String file in _done)
                Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: AppTokens.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(file,
                          style: AppTokens.mono(context, size: 10.5),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  SsButton(
                    label: _running ? '导出中…' : '开始导出',
                    icon: Icons.ios_share_rounded,
                    onPressed: _running ? null : _run,
                  ),
                  const SizedBox(width: 8),
                  if (_done.isNotEmpty)
                    SsButton(
                      label: '打开所在目录',
                      kind: SsButtonKind.ghost,
                      dense: true,
                      onPressed: () {
                        final dir = ref.read(workspaceProvider).exportsPath;
                        if (Platform.isWindows) {
                          Process.run('explorer', <String>[dir]);
                        } else {
                          ssToast(context, '导出目录：$dir');
                        }
                      },
                    ),
                  const Spacer(),
                  Text(
                    '保存于工作区 exports/',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
