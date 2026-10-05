/// V8/D147 · S3：空态（衬线大字 + 一行指引 + 主行动，§3.5）与加载骨架屏（§3.5）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 空态程序插画主题（hairline 线稿）。
enum SsArt { film, light, pose, compass }

/// 空态：衬线大字标题 + 一行指引 + 可选主行动 + 可选线稿插画。
class SsEmpty extends StatelessWidget {
  const SsEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
    this.art,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;
  final SsArt? art;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Center(
      child: Padding(
        padding: AppSpace.block,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (art != null)
              SizedBox(
                width: 132,
                height: 84,
                child: CustomPaint(
                  painter: _SsArtPainter(
                    art!,
                    p.muted.withValues(alpha: 0.35),
                    p.accent.withValues(alpha: 0.75),
                  ),
                ),
              )
            else
              Icon(icon, size: 40, color: p.muted.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpace.s3),
            Text(title, style: AppType.h2.style(p.ink)),
            if (hint != null) ...<Widget>[
              const SizedBox(height: AppSpace.s1),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: AppType.small.style(p.muted),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpace.s4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 空态线稿：胶片框 / 灯位 / 姿态 / 罗盘（§3.6 衬线线稿风）。
class _SsArtPainter extends CustomPainter {
  _SsArtPainter(this.art, this.muted, this.accent);

  final SsArt art;
  final Color muted;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = muted
      ..strokeCap = StrokeCap.round;
    final Paint accentPaint = Paint()..color = accent;
    final Rect box = Rect.fromLTWH(0, 6, size.width, size.height - 12);

    switch (art) {
      case SsArt.film:
        final RRect frame = RRect.fromRectAndRadius(
          Rect.fromLTWH(box.left + 8, box.top, box.width - 16, box.height),
          const Radius.circular(AppRadius.frame),
        );
        canvas.drawRRect(frame, line);
        for (var i = 0; i < 5; i++) {
          final double x = frame.left + 8 + i * ((frame.width - 16) / 4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(x, frame.top + 6),
                width: 8,
                height: 5,
              ),
              const Radius.circular(AppRadiusFine.n1_5),
            ),
            line,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(x, frame.bottom - 6),
                width: 8,
                height: 5,
              ),
              const Radius.circular(AppRadiusFine.n1_5),
            ),
            line,
          );
        }
        canvas.drawCircle(box.center, 9, accentPaint);
      case SsArt.light:
        final Offset lamp = Offset(box.center.dx, box.top + 16);
        canvas.drawCircle(lamp, 7, accentPaint);
        canvas.drawLine(lamp, Offset(box.left + 16, box.bottom), line);
        canvas.drawLine(lamp, Offset(box.center.dx, box.bottom), line);
        canvas.drawLine(lamp, Offset(box.right - 16, box.bottom), line);
        final Path cone = Path()
          ..moveTo(lamp.dx, lamp.dy + 6)
          ..lineTo(box.left + 10, box.bottom)
          ..lineTo(box.right - 10, box.bottom)
          ..close();
        canvas.drawPath(
          cone,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = muted.withValues(alpha: 0.5),
        );
      case SsArt.pose:
        final Offset hip = Offset(box.center.dx, box.top + box.height * 0.52);
        final Offset neck = Offset(box.center.dx + 4, box.top + 14);
        final Paint body = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = muted;
        canvas.drawLine(hip, neck, body);
        canvas.drawCircle(neck - const Offset(0, 8), 7, accentPaint);
        canvas.drawLine(neck, Offset(box.left + 14, box.top + 30), body);
        canvas.drawLine(neck, Offset(box.right - 10, box.top + 22), body);
        canvas.drawLine(hip, Offset(box.left + 20, box.bottom - 4), body);
        canvas.drawLine(hip, Offset(box.right - 18, box.bottom - 4), body);
      case SsArt.compass:
        final Offset center = box.center;
        final double r = box.height / 2;
        canvas.drawCircle(center, r, line);
        canvas.drawCircle(center, r * 0.62, line);
        final Path needle = Path()
          ..moveTo(center.dx, center.dy - r * 0.62)
          ..lineTo(center.dx + 8, center.dy)
          ..lineTo(center.dx, center.dy + r * 0.62)
          ..lineTo(center.dx - 8, center.dy)
          ..close();
        canvas.drawPath(needle, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SsArtPainter oldDelegate) =>
      oldDelegate.art != art || oldDelegate.muted != muted;
}

/// 骨架屏块（surfaceSunken 底 + 呼吸微光；加载指示器允许循环动效，§3.4）。
class SsSkeleton extends StatefulWidget {
  const SsSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.control,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SsSkeleton> createState() => _SsSkeletonState();
}

class _SsSkeletonState extends State<SsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(p.surfaceSunken, p.rule, 0.35 * _controller.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// 流光进度条（生成中动效；替代旧 `SsShimmer`）。
class SsShimmer extends StatefulWidget {
  const SsShimmer({super.key, this.height = 4, this.label});

  final double height;
  final String? label;

  @override
  State<SsShimmer> createState() => _SsShimmerState();
}

class _SsShimmerState extends State<SsShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(widget.label!, style: appEyebrow(p.accent)),
          const SizedBox(height: AppSpace.s2),
        ],
        AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = _controller.value;
            return Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height / 2),
                gradient: LinearGradient(
                  begin: Alignment(-1.6 + 3.2 * t, 0),
                  end: Alignment(-0.6 + 3.2 * t, 0),
                  colors: <Color>[
                    p.accentSoft,
                    p.accent.withValues(alpha: 0.75),
                    p.film.withValues(alpha: 0.6),
                    p.accentSoft,
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
