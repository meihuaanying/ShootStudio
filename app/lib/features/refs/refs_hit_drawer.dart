import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import '../../services/search/search_models.dart';
import 'refs_masonry.dart';
import 'refs_palette.dart';

/// S5/D154 详情抽屉：大图 + 五色色卡 + 来源/许可 + 相似图 + 双行动。
/// 从结果图卡点击进入；不再用 AlertDialog（R74 组件收口 + 杂志排版）。
class RefsHitDrawer extends ConsumerWidget {
  const RefsHitDrawer({
    super.key,
    required this.hit,
    required this.similar,
    required this.onAdd,
    this.onOpenSource,
    this.showHeader = true,
  });

  final SearchHit hit;

  /// 相似图（同一 group 或同一来源的其它命中）。
  final List<SearchHit> similar;

  final VoidCallback onAdd;
  final VoidCallback? onOpenSource;

  /// 是否在抽屉内自渲染「PLATE · 详情 + 标题」表头。由 `showSsSheet` 承载时
  /// 置 false，表头交给弹层自身（V8.21 收口）；单测直接构造时保持默认 true。
  final bool showHeader;

  /// 相似图挑选口径：同 group 优先，其次同 sourceId；最多 6 张，顺序稳定。
  static List<SearchHit> pickSimilar(SearchHit hit, List<SearchHit> all) {
    if (hit.group.isNotEmpty) {
      final List<SearchHit> same = all
          .where((SearchHit h) => h.id != hit.id && h.group == hit.group)
          .toList();
      if (same.isNotEmpty) return same.take(6).toList();
    }
    return all
        .where((SearchHit h) => h.id != hit.id && h.sourceId == hit.sourceId)
        .take(6)
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;
    final String url = hit.thumbUrl.isNotEmpty ? hit.thumbUrl : hit.fullUrl;
    return SizedBox(
      width: 880,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showHeader) ...<Widget>[
              Text('PLATE · 详情', style: appEyebrow(p.accent)),
              const SizedBox(height: AppSpace.s2),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: RefsMasonryImage(
                    width: hit.width,
                    height: hit.height,
                    placeholderLabel: hit.title,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s5),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (showHeader) ...<Widget>[
                        Text(hit.title, style: AppType.h2.style(p.ink)),
                        const SizedBox(height: AppSpace.s1),
                      ],
                      Text(hit.creditLine, style: appMono(p.muted, size: 10.5)),
                      const SizedBox(height: AppSpace.s3),
                      const SsDivider(),
                      const SizedBox(height: AppSpace.s3),
                      SsKvRow(label: '来源', value: hit.sourceLabel),
                      SsKvRow(label: '许可', value: hit.license),
                      SsKvRow(
                        label: '可商用',
                        value: hit.commercialOk ? '是' : '需自行确认',
                      ),
                      if (hit.width > 0 && hit.height > 0)
                        SsKvRow(
                          label: '尺寸',
                          value: '${hit.width}×${hit.height}',
                        ),
                      if (hit.sourcePageUrl.isNotEmpty)
                        SsKvRow(label: '来源页', value: '已提供'),
                      const SizedBox(height: AppSpace.s3),
                      Text('五色色卡', style: AppType.caption.style(p.muted)),
                      const SizedBox(height: AppSpace.s1),
                      RefsPaletteSlot(hit: hit),
                      if (hit.attribution.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpace.s3),
                        Text(
                          hit.attribution,
                          style: AppType.caption.style(p.inkSoft),
                        ),
                      ],
                      if (hit.description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          hit.description,
                          style: AppType.small.style(p.inkSoft),
                        ),
                      ],
                      const SizedBox(height: AppSpace.s4),
                      Row(
                        children: <Widget>[
                          SsButton(
                            label: '加入参考画面',
                            icon: Icons.bookmark_add_outlined,
                            onPressed: onAdd,
                          ),
                          const SizedBox(width: AppSpace.s2),
                          if (hit.sourcePageUrl.isNotEmpty)
                            SsButton(
                              label: '打开来源页',
                              kind: SsButtonKind.outline,
                              icon: Icons.open_in_new_rounded,
                              onPressed:
                                  onOpenSource ??
                                  () => launchUrl(
                                    Uri.parse(hit.sourcePageUrl),
                                    mode: LaunchMode.externalApplication,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (similar.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpace.s5),
              Text('相似参考', style: AppType.h3.style(p.ink)),
              const SizedBox(height: AppSpace.s2),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: similar.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpace.s2),
                  itemBuilder: (BuildContext context, int i) => SizedBox(
                    width: 120,
                    child: RefsMasonryImage(
                      width: similar[i].width,
                      height: similar[i].height,
                      placeholderLabel: similar[i].title,
                      child: Image.network(
                        similar[i].thumbUrl.isNotEmpty
                            ? similar[i].thumbUrl
                            : similar[i].fullUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 打开详情抽屉（结果页调用；单测可直接构造 [RefsHitDrawer]）。
Future<void> showRefsHitDrawer(
  BuildContext context, {
  required SearchHit hit,
  required List<SearchHit> all,
  required Future<void> Function(SearchHit hit) onAdd,
}) {
  return showSsSheet<void>(
    context: context,
    eyebrow: 'PLATE · 详情',
    title: hit.title,
    child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      // ProviderScope 在 MaterialApp 之上，路由内可直接用 ConsumerWidget。
      child: RefsHitDrawer(
        hit: hit,
        similar: RefsHitDrawer.pickSimilar(hit, all),
        showHeader: false,
        onAdd: () {
          onAdd(hit);
          Navigator.pop(context);
        },
      ),
    ),
  );
}
