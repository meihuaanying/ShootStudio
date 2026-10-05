// V8/S6 · D152：A/B 布光对比对话框（冻结 A/B + 差异摘要 + 合成图保存）。
// 从 lighting_page.dart 拆出（R73 行数门禁）；版面与行为不变。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../../core/design/widgets.dart';
import '../../../core/workspace/workspace.dart';
import '../../../services/engine/engine_bridge.dart';

import '../ab_compare.dart';

class AbCompareDialog extends StatelessWidget {
  const AbCompareDialog({
    super.key,
    required this.bridge,
    required this.workspace,
    required this.slots,
    required this.statsOf,
  });
  final EngineBridge bridge;
  final Workspace workspace;
  final ValueNotifier<AbSlots> slots;
  final AbDiffStats? Function(AbSlots) statsOf;
  Future<void> _freeze(String slot) =>
      bridge.capturePhoto(token: slot == 'b' ? 'ab-b' : 'ab-a');
  Future<void> _saveComposite(BuildContext context, AbSlots s) async {
    final AbDiffStats? stats = statsOf(s);
    final String? a = s.a;
    final String? b = s.b;
    if (a == null || b == null || stats == null) return;
    final Uint8List? bytes = abComposeSideBySide(
      base64Decode(a.contains(',') ? a.split(',').last : a),
      base64Decode(b.contains(',') ? b.split(',').last : b),
      stats,
    );
    if (bytes == null) {
      ssToast(context, '合成失败：图片解码错误');
      return;
    }
    try {
      final Directory dir = Directory(
        path.join(workspace.root.path, 'images', 'plans'),
      );
      await dir.create(recursive: true);
      final File file = File(
        path.join(
          dir.path,
          'AB对比_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      if (context.mounted) ssToast(context, 'A/B 对比图已保存到工作区 images/plans/');
    } catch (e) {
      if (context.mounted) ssToast(context, '保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1060, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: ValueListenableBuilder<AbSlots>(
            valueListenable: slots,
            builder: (BuildContext context, AbSlots s, Widget? _) {
              final AbDiffStats? stats = s.hasBoth ? statsOf(s) : null;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SsSectionTitle(
                      'A/B 布光对比',
                      subtitle: '冻结 A（调整前）→ 调整灯光 → 冻结 B（调整后）→ 查看差异与合成图',
                    ),
                    const SizedBox(height: AppSpace.s3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _pane(context, s.a, 'A · 调整前', 'ab-a'),
                        const SizedBox(width: AppSpace.s3),
                        _pane(context, s.b, 'B · 调整后', 'ab-b'),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s3),
                    if (stats != null)
                      Text(
                        '平均差 ${stats.meanAbs.toStringAsFixed(2)}/255 · '
                        '变化像素 ${(stats.changedRatio * 100).toStringAsFixed(1)}% · '
                        '最大差 ${stats.maxDelta.toStringAsFixed(0)} · '
                        '${stats.verdict}（阈值 $abDiffThreshold/255）',
                        style: appMono(context.palette.inkSoft),
                      )
                    else
                      Text(
                        '两侧都冻结后显示差异摘要（阈值 $abDiffThreshold/255）。',
                        style: TextStyle(
                          fontSize: AppFontSize.smallSm,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: AppSpace.s3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        SsButton(
                          label: '清空',
                          kind: SsButtonKind.text,
                          onPressed: s.hasBoth || s.a != null || s.b != null
                              ? () => slots.value = const AbSlots()
                              : null,
                        ),
                        const SizedBox(width: 8),
                        SsButton(
                          label: '保存对比图',
                          icon: Icons.compare_outlined,
                          onPressed: stats == null
                              ? null
                              : () => _saveComposite(context, s),
                        ),
                        const SizedBox(width: 8),
                        SsButton(
                          label: '关闭',
                          kind: SsButtonKind.text,
                          onPressed: () => Navigator.of(context).pop(),
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

  Widget _pane(
    BuildContext context,
    String? dataUrl,
    String label,
    String slot,
  ) {
    final bool frozen = dataUrl != null && dataUrl.isNotEmpty;
    return SizedBox(
      width: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: Container(
              height: 300,
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: frozen
                  ? Image.memory(
                      base64Decode(
                        dataUrl.contains(',')
                            ? dataUrl.split(',').last
                            : dataUrl,
                      ),
                      fit: BoxFit.contain,
                    )
                  : Text(
                      '未冻结',
                      style: TextStyle(
                        fontSize: AppFontSize.smallSm,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: AppFontSize.small),
                ),
              ),
              SsButton(
                label: frozen ? '重冻' : '冻结',
                icon: Icons.ac_unit,
                dense: true,
                onPressed: () => _freeze(slot),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
