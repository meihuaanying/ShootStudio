import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/design/widgets.dart';
import 'refs_controller.dart';
import 'refs_palette.dart';

/// S5/D154 我的画板（画册式编排页）：图卡网格 + 拖拽排序 + 导出长图。
/// 来源与许可字段逐卡保留（R47/R80：不得在编排中丢失署名）。
class RefsBoardView extends StatelessWidget {
  const RefsBoardView({
    super.key,
    required this.board,
    required this.imagePathOf,
    required this.onOpen,
    required this.onRemove,
    required this.onReorder,
    required this.onExport,
    required this.onPaste,
    required this.onImport,
    this.exporting = false,
    this.reorderEnabled = true,
  });

  final List<RefFrame> board;
  final String? Function(RefFrame frame) imagePathOf;
  final ValueChanged<RefFrame> onOpen;
  final ValueChanged<RefFrame> onRemove;
  final void Function(String dragId, String targetId) onReorder;
  final VoidCallback onExport;
  final VoidCallback onPaste;
  final VoidCallback onImport;
  final bool exporting;
  final bool reorderEnabled;

  /// 纯函数排序口径：把 dragId 移到 targetId 之前（拖拽落点即插入点）。
  static List<RefFrame> applyReorder(
    List<RefFrame> board,
    String dragId,
    String targetId,
  ) {
    final int from = board.indexWhere((RefFrame f) => f.id == dragId);
    final int to = board.indexWhere((RefFrame f) => f.id == targetId);
    if (from < 0 || to < 0 || from == to) return board;
    final List<RefFrame> next = List<RefFrame>.of(board);
    final RefFrame moved = next.removeAt(from);
    next.insert(from < to ? to - 1 : to, moved);
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    if (board.isEmpty) {
      return Column(
        children: <Widget>[
          Expanded(
            child: SsEmpty(
              icon: Icons.collections_bookmark_outlined,
              title: '画板还是空的',
              hint: '结果详情点「加入参考画面」；或粘贴截图 / 本地导入 / 拖入图片',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SsButton(
                label: '粘贴截图',
                kind: SsButtonKind.outline,
                icon: Icons.content_paste_rounded,
                onPressed: onPaste,
              ),
              const SizedBox(width: AppSpace.s2),
              SsButton(
                label: '本地导入',
                kind: SsButtonKind.outline,
                icon: Icons.add_photo_alternate_outlined,
                onPressed: onImport,
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('我的画板', style: AppType.h3.style(p.ink)),
            const SizedBox(width: AppSpace.s2),
            Text('${board.length} 帧', style: appMono(p.muted, size: 10.5)),
            const Spacer(),
            SsButton(
              label: exporting ? '导出中…' : '导出画板长图',
              kind: SsButtonKind.text,
              dense: true,
              icon: Icons.download_rounded,
              onPressed: exporting ? null : onExport,
            ),
            SsButton(
              label: '粘贴',
              kind: SsButtonKind.text,
              dense: true,
              onPressed: onPaste,
            ),
            SsButton(
              label: '导入',
              kind: SsButtonKind.text,
              dense: true,
              onPressed: onImport,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        Expanded(
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                // 画册编排：按可用宽度算列数与卡片宽（160–236），宽屏不留大片空白
                const double gap = AppSpace.s3;
                final int cols = ((c.maxWidth + gap) / (236 + gap))
                    .floor()
                    .clamp(3, 8);
                final double w = ((c.maxWidth - gap * (cols - 1)) / cols).clamp(
                  160.0,
                  236.0,
                );
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final RefFrame frame in board)
                      _BoardCard(
                        frame: frame,
                        imagePath: imagePathOf(frame),
                        width: w,
                        reorderEnabled: reorderEnabled,
                        onOpen: () => onOpen(frame),
                        onRemove: () => onRemove(frame),
                        onAccept: (String dragId) =>
                            onReorder(dragId, frame.id),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Text('长按图卡可拖拽排序；来源与许可随图卡一起导出。', style: appMono(p.muted, size: 10)),
      ],
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.frame,
    required this.imagePath,
    required this.width,
    required this.onOpen,
    required this.onRemove,
    required this.onAccept,
    required this.reorderEnabled,
  });

  final RefFrame frame;
  final String? imagePath;

  /// 图块宽（由父级按可用宽度计算；R72 宽屏不留大片空白）。
  final double width;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final ValueChanged<String> onAccept;
  final bool reorderEnabled;

  /// 图块高（4:5 竖幅画册块）。
  double get _imageHeight => (width * 1.25).roundToDouble();

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Widget card = SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: _imageHeight,
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              border: Border.all(color: p.rule),
              borderRadius: AppRadius.frameBorder,
            ),
            clipBehavior: Clip.antiAlias,
            child: imagePath == null
                ? RefsPaletteStrip(colors: frame.gradient, height: _imageHeight)
                : Image.file(File(imagePath!), fit: BoxFit.cover),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            frame.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.small.style(p.ink),
          ),
          Text(
            frame.filmTitle.isEmpty ? '本地导入' : frame.filmTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appMono(p.muted, size: 9.5),
          ),
          if (frame.sourceUrl.isNotEmpty)
            Text(
              frame.sourceUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appMono(p.muted, size: 9),
            ),
          Row(
            children: <Widget>[
              _MiniIcon(
                icon: Icons.open_in_full_rounded,
                tooltip: '查看',
                onTap: onOpen,
              ),
              const SizedBox(width: AppSpace.s1),
              _MiniIcon(
                icon: Icons.close_rounded,
                tooltip: '移出画板',
                onTap: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
    if (!reorderEnabled) return card;
    return DragTarget<String>(
      onAcceptWithDetails: (DragTargetDetails<String> d) => onAccept(d.data),
      builder: (BuildContext context, List<String?> cand, _) =>
          LongPressDraggable<String>(
            data: frame.id,
            feedback: Material(
              color: context.palette.surface,
              child: SizedBox(width: width, child: card),
            ),
            childWhenDragging: Opacity(opacity: 0.4, child: card),
            child: card,
          ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.chipBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpaceFine.n2),
          child: Icon(icon, size: 14, color: context.palette.inkSoft),
        ),
      ),
    );
  }
}

/// 导出画板长图：抓 RepaintBoundary → PNG → 工作区 `images/plans/画板_<ts>.png`。
/// 返回写盘后的绝对路径；失败抛异常由调用方提示（R78：失败必须可见）。
Future<String> exportBoardLongImage({
  required GlobalKey boundaryKey,
  required String workspaceRoot,
  double pixelRatio = 2,
}) async {
  await WidgetsBinding.instance.endOfFrame;
  final RenderObject? obj = boundaryKey.currentContext?.findRenderObject();
  if (obj is! RenderRepaintBoundary) {
    throw StateError('画板渲染对象不可用，无法导出');
  }
  final ui.Image image = await obj.toImage(pixelRatio: pixelRatio);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('画板导出编码失败');
  final Uint8List bytes = data.buffer.asUint8List();
  final String sep = Platform.pathSeparator;
  final Directory dir = Directory('$workspaceRoot${sep}images${sep}plans');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final String name = '画板_${DateTime.now().millisecondsSinceEpoch}.png';
  final File out = File('${dir.path}$sep$name');
  out.writeAsBytesSync(bytes);
  return out.path;
}
