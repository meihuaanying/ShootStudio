import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import 'refs_controller.dart';

/// V8/D154 · S5：画面参考页的外壳件（桌面拖拽落画板 + Ctrl/Cmd+V 粘贴 + 画板图卡详情弹窗）。
///
/// 抽出来的原因：R73 文件行数门禁（`lib/features/**` ≤ 600 行）。页面本体
/// [RefsPage] 只保留检索/编排状态与版面组装，平台相关的壳与弹窗集中在这里。
/// 视觉与行为不变：拖拽只接收图片扩展名，单文件失败不影响其余。
class RefsDropZone extends StatelessWidget {
  const RefsDropZone({
    super.key,
    required this.child,
    required this.onFilePath,
    required this.onDone,
    required this.onPasteKey,
  });

  final Widget child;

  /// 收到一个图片文件路径（调用方负责读取与入库）。
  final Future<void> Function(String filePath) onFilePath;

  /// 至少成功收入一张时回调（调用方切到「我的画板」并提示）。
  final VoidCallback onDone;

  /// Ctrl/Cmd+V 快捷键动作（页面提供粘贴实现）。
  final VoidCallback onPasteKey;

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Widget _wrap(Widget page) {
    Widget wrapped = page;
    if (_isDesktop) {
      wrapped = DropTarget(
        onDragDone: (DropDoneDetails details) async {
          int count = 0;
          for (final DropItem file in details.files) {
            final String filePath = file.path;
            final String ext = filePath.contains('.')
                ? filePath.substring(filePath.lastIndexOf('.')).toLowerCase()
                : '';
            if (!RefsController.imageExts.contains(ext)) continue;
            try {
              await onFilePath(filePath);
              count++;
            } catch (_) {
              // 单个文件失败不影响其余。
            }
          }
          if (count > 0) onDone();
        },
        child: wrapped,
      );
    }
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            onPasteKey,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): onPasteKey,
      },
      child: Focus(autofocus: true, child: wrapped),
    );
  }

  @override
  Widget build(BuildContext context) => _wrap(child);
}

/// 画板图卡详情弹窗：名称 / 所属影视 / 来源页 + 打开来源 / 移出画板 / 关闭。
Future<void> showRefFrameDialog({
  required BuildContext context,
  required RefFrame frame,
  required VoidCallback onRemove,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(frame.name, style: AppType.h3.style(ctx.palette.ink)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('来自：${frame.filmTitle}'),
            if (frame.sourceUrl.isNotEmpty)
              Text(
                frame.sourceUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appMono(ctx.palette.muted, size: 10),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        if (frame.sourceUrl.isNotEmpty)
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(frame.sourceUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('打开来源页'),
          ),
        TextButton(
          onPressed: () {
            onRemove();
            Navigator.pop(ctx);
          },
          child: const Text('移出画板'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

/// 图卡来源链接的落盘文件名（拖拽导入时用作标题）。
String refsTitleFromPath(String filePath) =>
    path.basenameWithoutExtension(filePath);
