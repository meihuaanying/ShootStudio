import 'package:flutter/material.dart';

import '../../core/design/widgets.dart';

/// S5/D154 瀑布流：按容器宽度分列，卡片按自身纵横比撑高（保留原图比例）。
/// 说明：Flutter 无内置瀑布流，这里用「列式布局」实现（列数随宽度自适应）。
class RefsMasonryGrid extends StatelessWidget {
  const RefsMasonryGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxColumnWidth = 260,
    this.spacing = AppSpace.s3,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double maxColumnWidth;
  final double spacing;

  static int columnsFor(double width, double maxColumnWidth, double spacing) {
    if (width <= 0) return 1;
    final int byWidth = ((width + spacing) / (maxColumnWidth + spacing))
        .floor();
    return byWidth.clamp(1, 6);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = columnsFor(width, maxColumnWidth, spacing);
        final int rows = (itemCount / columns).ceil();
        final List<List<int>> buckets = List<List<int>>.generate(
          columns,
          (int i) => <int>[],
        );
        for (int i = 0; i < itemCount; i++) {
          buckets[i % columns].add(i);
        }
        if (rows == 0) return const SizedBox.shrink();
        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int c = 0; c < columns; c++) ...<Widget>[
                if (c > 0) SizedBox(width: spacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (int k = 0; k < buckets[c].length; k++) ...<Widget>[
                        if (k > 0) SizedBox(height: spacing),
                        itemBuilder(context, buckets[c][k]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 图卡内容区：按图片自身比例撑高（hit 有 width/height 时用之），
/// 无尺寸信息时退回 4:5；无图时用 surfaceSunken + 衬线首字占位（§3.6 禁灰块/emoji）。
class RefsMasonryImage extends StatelessWidget {
  const RefsMasonryImage({
    super.key,
    this.child,
    this.width,
    this.height,
    this.placeholderLabel = '',
  });

  /// 为 null 时渲染占位（无图 / 加载失败）。
  final Widget? child;
  final int? width;
  final int? height;
  final String placeholderLabel;

  double get aspect {
    final int? w = width;
    final int? h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 4 / 5;
    final double r = w / h;
    return r.clamp(0.6, 2.4);
  }

  /// 无图占位：surfaceSunken 底 + 衬线首字（§3.6 禁灰块/emoji）。
  Widget _placeholder(AppPalette p) {
    return Container(
      color: p.surfaceSunken,
      alignment: Alignment.center,
      child: Text(
        placeholderLabel.isEmpty ? '无' : placeholderLabel.characters.first,
        style: AppType.h2.style(p.rule),
      ),
    );
  }

  /// child 为 [Image] 时注入兜底 errorBuilder：图加载失败/解码失败也回落占位，
  /// 不留空白块（网络图挂掉时仍能看出是哪一个素材）。
  Widget _resolve(AppPalette p) {
    final Widget? c = child;
    if (c == null) return _placeholder(p);
    if (c is! Image) return c;
    return Image(
      image: c.image,
      fit: c.fit,
      width: c.width,
      height: c.height,
      alignment: c.alignment,
      gaplessPlayback: c.gaplessPlayback,
      isAntiAlias: c.isAntiAlias,
      excludeFromSemantics: c.excludeFromSemantics,
      filterQuality: c.filterQuality,
      errorBuilder: (_, _, _) => _placeholder(p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(borderRadius: AppRadius.frameBorder, child: _resolve(p)),
    );
  }
}
