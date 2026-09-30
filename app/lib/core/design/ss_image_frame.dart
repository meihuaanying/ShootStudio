/// V8/D147 · S3：图片帧（§3.5「surfaceSunken 底 + hairline + 3:2/4:5/16:9 比例锁」）。
/// 禁用 emoji 占位与灰块：无图时用 surfaceSunken + 衬线首字（§3.6）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 图片比例锁（§3.6）。
enum SsFrameRatio { threeTwo, fourFive, sixteenNine }

/// 图片帧容器：比例锁 + hairline + 圆角 8。
class SsImageFrame extends StatelessWidget {
  const SsImageFrame({
    super.key,
    this.image,
    this.ratio = SsFrameRatio.threeTwo,
    this.placeholder = '正',
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  final Widget? image;
  final SsFrameRatio ratio;

  /// 无图时的衬线首字（§3.6：禁止 emoji 占位）。
  final String placeholder;
  final double? height;
  final double? width;
  final BoxFit fit;

  double get _ratio => switch (ratio) {
    SsFrameRatio.threeTwo => AppFrameRatio.threeTwo,
    SsFrameRatio.fourFive => AppFrameRatio.fourFive,
    SsFrameRatio.sixteenNine => AppFrameRatio.sixteenNine,
  };

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Widget content = image ?? _SsPlaceholderMark(text: placeholder);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: AppRadius.frameBorder,
        border: Border.all(color: p.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(child: AspectRatio(aspectRatio: 1, child: content)),
              ],
            )
          : AspectRatio(aspectRatio: _ratio, child: content),
    );
  }
}

class _SsPlaceholderMark extends StatelessWidget {
  const _SsPlaceholderMark({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Text(
      text.isEmpty ? '正' : text.characters.first,
      style: AppType.display.style(p.rule),
    );
  }
}

/// 竖幅图框（4:5 常用）：给 [height] 时限高，不给则按比例自适应。
class SsPortraitFrame extends StatelessWidget {
  const SsPortraitFrame({
    super.key,
    this.image,
    this.placeholder = '正',
    this.height = 320,
  });

  final Widget? image;
  final String placeholder;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: SsImageFrame(
        image: image,
        ratio: SsFrameRatio.fourFive,
        placeholder: placeholder,
        height: height,
      ),
    );
  }
}
