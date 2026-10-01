// V8/S8 · D155：绘制原语（文字 / 图片 cover+contain / 富文本 / 姿势图卡）。
// 从 exporter.dart 拆出（R73 行数门禁 + D158 分层）；part 同库，私有成员无需公开化。
part of 'exporter.dart';

extension _ExporterDraw on ExportService {
  void _text(
    ui.Canvas canvas,
    String text,
    double x,
    double y,
    double size, {
    bool bold = false,
    ui.Color color = const ui.Color(0xFF1F2329),
    required double maxWidth,
    ui.TextAlign align = ui.TextAlign.left,
  }) {
    if (text.isEmpty) return;
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontSize: size,
              maxLines: 6,
              ellipsis: '…',
              textAlign: align,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: size,
              fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
            ),
          )
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(paragraph, ui.Offset(x, y));
  }

  /// 真实图片 cover 填充（F12）。
  void _drawImageCover(ui.Canvas canvas, ui.Image image, ui.Rect dst) {
    final double iw = image.width.toDouble();
    final double ih = image.height.toDouble();
    final double scale = math.max(dst.width / iw, dst.height / ih);
    final double sw = dst.width / scale;
    final double sh = dst.height / scale;
    final ui.Rect src = ui.Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh);
    canvas.drawImageRect(image, src, dst, ui.Paint());
  }

  /// V4/R25：完整显示（不裁切）姿势照片。
  void _drawImageContain(ui.Canvas canvas, ui.Image image, ui.Rect dst) {
    final double iw = image.width.toDouble();
    final double ih = image.height.toDouble();
    final double scale = math.min(dst.width / iw, dst.height / ih);
    final double w = iw * scale;
    final double h = ih * scale;
    final ui.Rect target = ui.Rect.fromLTWH(
      dst.left + (dst.width - w) / 2,
      dst.top + (dst.height - h) / 2,
      w,
      h,
    );
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, iw, ih),
      target,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  /// 富文本轻量渲染（F12）：- 列表与 **加粗**。
  void _richText(
    ui.Canvas canvas,
    String text,
    double x,
    double y,
    double size, {
    required double maxWidth,
  }) {
    if (text.trim().isEmpty) return;
    final List<RichLine> lines = RichTextLite.parse(text);
    var cy = y;
    final double indent = size * 1.2;
    for (final RichLine line in lines) {
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: size, maxLines: 6, ellipsis: '…'),
      );
      if (line.bullet) {
        builder
          ..pushStyle(
            ui.TextStyle(color: const ui.Color(0xFF1F2329), fontSize: size),
          )
          ..addText('• ');
      }
      for (final RichSpan span in line.spans) {
        builder
          ..pushStyle(
            ui.TextStyle(
              color: const ui.Color(0xFF1F2329),
              fontSize: size,
              fontWeight: span.bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
            ),
          )
          ..addText(span.text);
      }
      final paragraph = builder.build()
        ..layout(
          ui.ParagraphConstraints(
            width: line.bullet ? maxWidth - indent : maxWidth,
          ),
        );
      canvas.drawParagraph(
        paragraph,
        ui.Offset(line.bullet ? x + indent : x, cy),
      );
      cy += paragraph.height + (line.spans.isEmpty ? 0 : 4);
    }
  }

  /// 姿势九宫格简化投影（R25：无照片/选择「骨架示意」时的静态投影表示）。
  void _drawPoseFigure(
    ui.Canvas canvas,
    ui.Rect area,
    Map<String, Object?> joints,
  ) {
    List<double> axis(String joint) => tripleOf(joints[joint]);

    final center = area.center;
    final h = area.height;
    final stroke = ui.Paint()
      ..color = const ui.Color(0xFF343A46)
      ..strokeWidth = 12
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    final spine = axis('spine');
    final lean = spine[1] * math.pi / 180 * 0.4;
    final hip = ui.Offset(center.dx, area.top + h * 0.58);
    final neck = ui.Offset(
      hip.dx + math.sin(lean) * h * 0.26,
      hip.dy - h * 0.26,
    );
    final head = ui.Offset(
      neck.dx + math.sin(lean) * h * 0.05,
      neck.dy - h * 0.09,
    );

    // 躯干。
    canvas.drawLine(hip, neck, stroke);
    canvas.drawCircle(
      head,
      h * 0.07,
      ui.Paint()..color = const ui.Color(0xFF343A46),
    );

    void limb(
      ui.Offset from,
      double upperDeg,
      double lowerDeg,
      double length, {
      bool mirror = false,
    }) {
      final sign = mirror ? -1.0 : 1.0;
      final upperRad = upperDeg * math.pi / 180;
      final knee = ui.Offset(
        from.dx + sign * math.sin(upperRad) * length * 0.5,
        from.dy + math.cos(upperRad) * length * 0.5,
      );
      final lowerRad = (upperDeg + lowerDeg) * math.pi / 180;
      final tip = ui.Offset(
        knee.dx + sign * math.sin(lowerRad) * length * 0.5,
        knee.dy + math.cos(lowerRad) * length * 0.5,
      );
      canvas.drawPath(
        ui.Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(tip.dx, tip.dy),
        stroke,
      );
    }

    // 手臂（用 shoulder rz 近似张开角）。
    final armLength = h * 0.34;
    limb(
      neck + ui.Offset(0, h * 0.02),
      axis('shoulder_l')[2],
      axis('elbow_l')[0] * 0.4,
      armLength,
    );
    limb(
      neck + ui.Offset(0, h * 0.02),
      axis('shoulder_r')[2],
      axis('elbow_r')[0] * 0.4,
      armLength,
      mirror: true,
    );
    // 腿。
    final legLength = h * 0.42;
    final hipLeft = hip + ui.Offset(-h * 0.06, 0);
    final hipRight = hip + ui.Offset(h * 0.06, 0);
    limb(hipLeft, axis('hip_l')[0] * -0.6, axis('knee_l')[0] * 0.5, legLength);
    limb(
      hipRight,
      axis('hip_r')[0] * -0.6,
      axis('knee_r')[0] * 0.5,
      legLength,
      mirror: false,
    );
  }

  // ---------------- PDF ----------------
}
