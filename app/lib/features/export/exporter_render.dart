// V8/S8 · D155：长图渲染（renderLongImage + 分块测量 + 模块卡绘制）。
// 从 exporter.dart 拆出（R73 行数门禁 + D158 分层）；part 同库，私有成员无需公开化。
part of 'exporter.dart';

extension _ExporterRender on ExportService {
  Future<List<Uint8List>> renderLongImage({
    required List<PlanModuleData> modules,
    required String title,
    required PlanDocStatus status,
    required bool dark,
  }) async {
    final parts = <List<PlanModuleData>>[];
    // 分页：先测量再分组。
    var current = <PlanModuleData>[];
    var height = 0.0;
    for (final PlanModuleData module in modules) {
      final h = await _measureModule(module);
      if (height + h > ExportService._maxPartHeight && current.isNotEmpty) {
        parts.add(current);
        current = <PlanModuleData>[];
        height = 0;
      }
      current.add(module);
      height += h;
    }
    if (current.isNotEmpty) parts.add(current);

    final images = <Uint8List>[];
    for (var partIndex = 0; partIndex < parts.length; partIndex++) {
      final image = await _renderPart(
        parts[partIndex],
        title,
        status,
        partIndex + 1,
        parts.length,
      );
      images.add(image);
    }
    return images;
  }

  Future<double> _measureModule(PlanModuleData module) async {
    double rowsHeight(int count, int perRow, double rowHeight) =>
        ((count + perRow - 1) ~/ perRow) * rowHeight;
    switch (module.type) {
      case PlanModuleType.refs:
        final int count = (module.data['refs'] as List? ?? <Object?>[]).length;
        return 72 + rowsHeight(math.max(count, 1), 3, 262);
      case PlanModuleType.poses:
        final int count = (module.data['poses'] as List? ?? <Object?>[]).length;
        return 72 + rowsHeight(math.max(count, 1), 3, 330);
      case PlanModuleType.crew:
      case PlanModuleType.budget:
        final int count = (module.data['rows'] as List? ?? <Object?>[]).length;
        return 96 + math.max(count, 1) * 30;
      case PlanModuleType.storyboard:
        final int count = (module.data['shots'] as List? ?? <Object?>[]).length;
        return 96 + math.max(count, 1) * 62;
      case PlanModuleType.palette:
        return 160;
      case PlanModuleType.lighting:
        return 170;
      case PlanModuleType.theme:
      case PlanModuleType.richText:
        final int lines = math.min(
          14,
          math.max(1, (module.summary.length / 26).ceil()),
        );
        return 100 + lines * 30;
      default:
        return 140 + module.summary.length * 0.5;
    }
  }

  Future<Uint8List> _renderPart(
    List<PlanModuleData> modules,
    String title,
    PlanDocStatus status,
    int partIndex,
    int partTotal,
  ) async {
    const margin = 56.0;
    final contentWidth = ExportService._width - margin * 2;

    double y = 0;
    final heights = <double>[];
    for (final PlanModuleData module in modules) {
      final h = await _measureModule(module);
      heights.add(h);
      y += h;
    }
    final totalHeight = y + 320;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, ExportService._width, totalHeight),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, ExportService._width, totalHeight),
      ui.Paint()..color = const ui.Color(0xFFF7F8FA),
    );

    // 预载参考图层真实图片（F12）。
    final refImages = <String, ui.Image>{};
    for (final PlanModuleData module in modules) {
      if (module.type != PlanModuleType.refs) continue;
      for (final Object? entry
          in (module.data['refs'] as List? ?? <Object?>[])) {
        if (entry is! Map) continue;
        final String ref = entry['imageRef'] as String? ?? '';
        if (ref.isEmpty || refImages.containsKey(ref)) continue;
        final Uint8List? bytes = await _loadRefBytes(ref);
        if (bytes == null) continue;
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frame = await codec.getNextFrame();
        refImages[ref] = frame.image;
      }
    }

    // 预载姿势照片（V4/R25：导出默认照片渲染，带出处）。
    final poseImages = <String, ui.Image>{};
    for (final PlanModuleData module in modules) {
      if (module.type != PlanModuleType.poses) continue;
      if ((module.data['poseRenderMode'] as String? ?? 'photo') == 'skeleton') {
        continue;
      }
      for (final Object? entry
          in (module.data['poses'] as List? ?? <Object?>[])) {
        if (entry is! Map) continue;
        final String photo = entry['photo'] as String? ?? '';
        if (photo.isEmpty || poseImages.containsKey(photo)) continue;
        final Uint8List? bytes = await _loadPosePhotoBytes(photo);
        if (bytes == null) continue;
        try {
          final ui.Codec codec = await ui.instantiateImageCodec(bytes);
          final ui.FrameInfo frame = await codec.getNextFrame();
          poseImages[photo] = frame.image;
        } catch (_) {
          // 解码失败回退骨架示意。
        }
      }
    }

    // 刊头：品牌眉题 + 衬线大标题 + 状态行 + 刊头主线（与 PDF 版式同源，D155）。
    var cursor = 68.0;
    _text(
      canvas,
      '正片工坊  SHOOTSTUDIO',
      margin,
      cursor,
      13,
      color: const ui.Color(0xFF8A919E),
      maxWidth: contentWidth,
    );
    cursor += 30;
    _text(
      canvas,
      title,
      margin,
      cursor,
      44,
      bold: true,
      color: const ui.Color(0xFF1F2329),
      maxWidth: contentWidth,
    );
    cursor += 62;
    _text(
      canvas,
      '状态：${status.label}${status == PlanDocStatus.draft ? ' · 草稿·未定稿' : ''}'
      '${partTotal > 1 ? ' · 第 $partIndex/$partTotal 部分' : ''}',
      margin,
      cursor,
      16,
      color: const ui.Color(0xFF646A73),
      maxWidth: contentWidth,
    );
    cursor += 30;
    canvas.drawRect(
      ui.Rect.fromLTWH(margin, cursor, contentWidth, 2.4),
      ui.Paint()..color = const ui.Color(0xFF1F2329),
    );
    cursor += 44;

    for (var i = 0; i < modules.length; i++) {
      final module = modules[i];
      final h = heights[i];
      _drawModuleCard(
        canvas,
        module,
        i + 1,
        margin,
        cursor,
        contentWidth,
        h,
        refImages,
        poseImages,
      );
      cursor += h;
    }

    // 页脚：hairline + 案名 + 品牌 + 页码（与 PDF 页脚同源，D155）。
    canvas.drawRect(
      ui.Rect.fromLTWH(margin, totalHeight - 96, contentWidth, 0.8),
      ui.Paint()..color = const ui.Color(0xFFD5D9E0),
    );
    _text(
      canvas,
      '${_ExporterPdfPress._ellipsis(title, 30)} · 由 正片工坊 ShootStudio 导出',
      margin,
      totalHeight - 72,
      14,
      color: const ui.Color(0xFF8A919E),
      maxWidth: contentWidth,
    );
    _text(
      canvas,
      partTotal > 1 ? '第 $partIndex / $partTotal 部分' : '第 $partIndex 页',
      margin,
      totalHeight - 72,
      14,
      color: const ui.Color(0xFF8A919E),
      maxWidth: contentWidth,
      align: ui.TextAlign.right,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      ExportService._width.toInt(),
      totalHeight.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  void _drawModuleCard(
    ui.Canvas canvas,
    PlanModuleData module,
    int index,
    double x,
    double y,
    double width,
    double height,
    Map<String, ui.Image> refImages,
    Map<String, ui.Image> poseImages,
  ) {
    final rect = ui.Rect.fromLTWH(x, y, width, height - 20);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(16)),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(16)),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const ui.Color(0xFFE5E7EB),
    );

    var cursor = y + 20;
    _text(
      canvas,
      '$index. ${module.title.isEmpty ? module.type.label : module.title}',
      x + 24,
      cursor,
      24,
      bold: true,
      color: const ui.Color(0xFF1F2329),
      maxWidth: width - 48,
    );
    cursor += 40;

    switch (module.type) {
      case PlanModuleType.theme:
      case PlanModuleType.richText:
        _richText(
          canvas,
          module.data['text'] as String? ?? '',
          x + 24,
          cursor,
          18,
          maxWidth: width - 48,
        );
      case PlanModuleType.palette:
        final colors = (module.data['colors'] as List? ?? <Object?>[])
            .cast<String>();
        var chipX = x + 24;
        for (final String hex in colors.take(5)) {
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(chipX, cursor, 160, 72),
              const ui.Radius.circular(10),
            ),
            ui.Paint()..color = _color(hex),
          );
          _text(
            canvas,
            hex,
            chipX,
            cursor + 78,
            13,
            color: const ui.Color(0xFF646A73),
            maxWidth: 160,
          );
          chipX += 172;
        }
      case PlanModuleType.refs:
        final refs = (module.data['refs'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();
        var tileX = x + 24;
        var tileY = cursor;
        for (var i = 0; i < refs.length && i < 6; i++) {
          final palette = (refs[i]['palette'] as List? ?? <Object?>[])
              .cast<String>();
          final tile = ui.Rect.fromLTWH(tileX, tileY, 300, 220);
          final ui.Image? real =
              refImages[refs[i]['imageRef'] as String? ?? ''];
          if (real != null) {
            canvas.save();
            canvas.clipRRect(
              ui.RRect.fromRectAndRadius(tile, const ui.Radius.circular(12)),
            );
            _drawImageCover(canvas, real, tile);
            canvas.restore();
          } else {
            final paint = ui.Paint()
              ..shader =
                  ui.Gradient.linear(tile.topLeft, tile.bottomRight, <ui.Color>[
                    _color(palette.isNotEmpty ? palette[0] : '#888888'),
                    _color(palette.length > 1 ? palette[1] : '#333333'),
                  ]);
            canvas.drawRRect(
              ui.RRect.fromRectAndRadius(tile, const ui.Radius.circular(12)),
              paint,
            );
          }
          _text(
            canvas,
            refs[i]['name'] as String? ?? '',
            tileX + 10,
            tileY + 226,
            13,
            color: const ui.Color(0xFF646A73),
            maxWidth: 300,
          );
          tileX += 320;
          if (tileX + 300 > x + width) {
            tileX = x + 24;
            tileY += 262;
          }
        }
      case PlanModuleType.lighting:
        _text(
          canvas,
          '布光方案：${module.data['sceneName'] as String? ?? '未绑定'}',
          x + 24,
          cursor,
          18,
          maxWidth: width - 48,
        );
        _text(
          canvas,
          (module.data['note'] as String? ?? '').trim().isEmpty
              ? '详见应用内布光预演室（灯位图 + 位置清单 + 效果预览）'
              : module.data['note'] as String? ?? '',
          x + 24,
          cursor + 30,
          14,
          color: const ui.Color(0xFF646A73),
          maxWidth: width - 48,
        );
      case PlanModuleType.poses:
        final poses = (module.data['poses'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();
        final String renderMode =
            module.data['poseRenderMode'] as String? ?? 'photo';
        var poseX = x + 24;
        var poseY = cursor;
        for (var i = 0; i < poses.length && i < 9; i++) {
          final cell = ui.Rect.fromLTWH(poseX, poseY, 300, 300);
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(cell, const ui.Radius.circular(12)),
            ui.Paint()..color = const ui.Color(0xFFF2F4F7),
          );
          final ui.Image? photo =
              poseImages[poses[i]['photo'] as String? ?? ''];
          if (renderMode != 'skeleton' && photo != null) {
            canvas.save();
            canvas.clipRRect(
              ui.RRect.fromRectAndRadius(cell, const ui.Radius.circular(12)),
            );
            _drawImageContain(
              canvas,
              photo,
              ui.Rect.fromLTWH(poseX + 6, poseY + 8, 288, 240),
            );
            canvas.restore();
          } else {
            final joints = asMap(poses[i]['joints']);
            _drawPoseFigure(
              canvas,
              ui.Rect.fromLTWH(poseX + 40, poseY + 16, 220, 240),
              joints,
            );
          }
          _text(
            canvas,
            poses[i]['name'] as String? ?? '',
            poseX + 12,
            poseY + 264,
            14,
            maxWidth: 280,
          );
          final String attribution = <String>[
            if ((poses[i]['author'] as String? ?? '').isNotEmpty)
              poses[i]['author'] as String,
            if ((poses[i]['license'] as String? ?? '').isNotEmpty)
              poses[i]['license'] as String,
          ].join(' · ');
          if (photo != null &&
              renderMode != 'skeleton' &&
              attribution.isNotEmpty) {
            _text(
              canvas,
              '照片：$attribution',
              poseX + 12,
              poseY + 280,
              10.5,
              color: const ui.Color(0xFF8A919E),
              maxWidth: 280,
            );
          }
          poseX += 320;
          if (poseX + 300 > x + width) {
            poseX = x + 24;
            poseY += 330;
          }
        }
      case PlanModuleType.storyboard:
        final shots = (module.data['shots'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();
        var shotY = cursor;
        for (var i = 0; i < shots.length; i++) {
          final Map<String, Object?> shot = shots[i];
          final bool key = shot['key'] == true;
          _text(
            canvas,
            '${shot['no'] ?? i + 1}. ${shot['shotSize'] ?? ''} · ${shot['lens'] ?? ''} · '
            '${shot['camera'] ?? ''} · 姿势：${shot['pose'] ?? ''}'
            '${key ? ' · ★重点' : ''}',
            x + 24,
            shotY,
            15,
            bold: key,
            maxWidth: width - 48,
          );
          shotY += 24;
          final String note = shot['note'] as String? ?? '';
          if (note.isNotEmpty) {
            _text(
              canvas,
              note,
              x + 40,
              shotY,
              12.5,
              color: const ui.Color(0xFF646A73),
              maxWidth: width - 64,
            );
            shotY += 22;
          }
          shotY += 12;
        }
      case PlanModuleType.sun:
        _text(
          canvas,
          '${module.data['place'] ?? ''} · ${module.data['date'] ?? ''}（黄金/蓝调时刻请在应用内查看）',
          x + 24,
          cursor,
          16,
          maxWidth: width - 48,
        );
      case PlanModuleType.crew:
      case PlanModuleType.budget:
        final rows = (module.data['rows'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();
        var rowY = cursor;
        for (final Map<String, Object?> row in rows) {
          final line = module.type == PlanModuleType.budget
              ? '${row['item'] ?? ''}   ¥${row['price'] ?? 0}   ${row['note'] ?? ''}'
              : '${row['role'] ?? ''}   ${row['who'] ?? ''}   ${row['time'] ?? ''}';
          _text(canvas, line, x + 24, rowY, 16, maxWidth: width - 48);
          rowY += 30;
        }
      default:
        final ids = (module.data['ids'] as List? ?? <Object?>[]).cast<String>();
        _text(
          canvas,
          ids.isEmpty
              ? (module.data['note'] as String? ?? '（占位）')
              : '已绑定 ${ids.length} 项资源',
          x + 24,
          cursor,
          16,
          color: const ui.Color(0xFF646A73),
          maxWidth: width - 48,
        );
    }
  }

  ui.Color _color(String hex) => ui.Color(
    0xFF000000 |
        (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x888888),
  );
}
