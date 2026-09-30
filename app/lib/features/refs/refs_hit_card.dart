import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/design/widgets.dart';
import '../../services/search/search_models.dart';
import 'refs_masonry.dart';

/// S5/D154 结果图卡：图为主 + 悬停浮层（来源/许可/收画板/以图搜图，D149 桌面优先）。
/// 触控端（无 hover）时浮层内容常驻在卡片底部，保证 Android 同样可用（D149 偏差登记）。
class RefsHitCard extends StatefulWidget {
  const RefsHitCard({
    super.key,
    required this.hit,
    required this.onOpen,
    required this.onAdd,
    required this.onSearchSimilar,
    this.hovered = false,
  });

  final SearchHit hit;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onSearchSimilar;

  /// 键盘/测试可强制悬停态（截图门禁用）。
  final bool hovered;

  @override
  State<RefsHitCard> createState() => _RefsHitCardState();
}

class _RefsHitCardState extends State<RefsHitCard> {
  bool _hover = false;

  bool get _showOverlay => widget.hovered || _hover;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final SearchHit hit = widget.hit;
    final String url = hit.thumbUrl.isNotEmpty ? hit.thumbUrl : hit.fullUrl;
    return MouseRegion(
      onEnter: (PointerEnterEvent _) => setState(() => _hover = true),
      onExit: (PointerExitEvent _) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 浮层只盖图区，标题/许可常驻在图下方（R63 逐图标注不被浮层遮住）
            Stack(
              children: <Widget>[
                RefsMasonryImage(
                  width: hit.width,
                  height: hit.height,
                  placeholderLabel: hit.title,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                if (_showOverlay)
                  Positioned.fill(
                    child: _HoverLayer(
                      hit: hit,
                      onOpen: widget.onOpen,
                      onAdd: widget.onAdd,
                      onSearchSimilar: widget.onSearchSimilar,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              hit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.small.style(p.ink),
            ),
            const SizedBox(height: 2),
            Text(
              hit.creditLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appMono(p.muted, size: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverLayer extends StatelessWidget {
  const _HoverLayer({
    required this.hit,
    required this.onOpen,
    required this.onAdd,
    required this.onSearchSimilar,
  });

  final SearchHit hit;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onSearchSimilar;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.ink.withValues(alpha: 0.92),
        borderRadius: AppRadius.frameBorder,
      ),
      padding: const EdgeInsets.all(AppSpace.s2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            hit.sourceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appMono(p.bg, size: 9.5),
          ),
          const SizedBox(height: 2),
          Text(
            hit.license,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.style(p.bg),
          ),
          if (hit.commercialOk)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('可商用', style: appMono(p.film, size: 9)),
            ),
          const Spacer(),
          Row(
            children: <Widget>[
              _MiniAction(
                icon: Icons.open_in_new_rounded,
                label: '详情',
                color: p.bg,
                onTap: onOpen,
              ),
              const SizedBox(width: AppSpace.s1),
              _MiniAction(
                icon: Icons.bookmark_add_outlined,
                label: '收画板',
                color: p.accent,
                onTap: onAdd,
              ),
              const SizedBox(width: AppSpace.s1),
              _MiniAction(
                icon: Icons.image_search_rounded,
                label: '以图搜图',
                color: p.gold,
                onTap: onSearchSimilar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.chipBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s1,
            vertical: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Text(label, style: AppType.caption.style(color)),
            ],
          ),
        ),
      ),
    );
  }
}
