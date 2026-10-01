// V8/S8 · D155：PDF 导出（版式 + 灯位图 + 设备行）。
// 从 exporter.dart 拆出（R73 行数门禁 + D158 分层）；part 同库，私有成员无需公开化。
part of 'exporter.dart';

extension _ExporterPdf on ExportService {
  Future<void> _exportPdf(
    File file,
    String title,
    PlanDocStatus status,
    List<PlanModuleData> modules,
    void Function(ExportProgress) onProgress,
  ) async {
    final font = _loadCjkFont();
    final pw.Font? pdfFont = font == null ? null : pw.Font.ttf(font);
    final doc = pw.Document();
    final baseStyle = pdfFont == null
        ? const pw.TextStyle(fontSize: 11)
        : pw.TextStyle(font: pdfFont, fontSize: 11);
    if (font == null) {
      onProgress(const ExportProgress('提示：未找到可内嵌中文字体，PDF 中文可能显示异常', 0.4));
    }

    // 预载参考图字节（F12：PDF 内嵌真实图片）。
    final Map<String, Uint8List> refBytes = <String, Uint8List>{};
    for (final PlanModuleData module in modules) {
      if (module.type != PlanModuleType.refs) continue;
      for (final Object? entry
          in (module.data['refs'] as List? ?? <Object?>[])) {
        if (entry is! Map) continue;
        final String ref = entry['imageRef'] as String? ?? '';
        if (ref.isEmpty || refBytes.containsKey(ref)) continue;
        final Uint8List? bytes = await _loadRefBytes(ref);
        if (bytes != null) refBytes[ref] = bytes;
      }
    }

    // V4/R25：预载姿势照片字节（PDF 默认照片渲染，可切换骨架示意）。
    for (final PlanModuleData module in modules) {
      if (module.type != PlanModuleType.poses) continue;
      if ((module.data['poseRenderMode'] as String? ?? 'photo') == 'skeleton') {
        continue;
      }
      for (final Object? entry
          in (module.data['poses'] as List? ?? <Object?>[])) {
        if (entry is! Map) continue;
        final String photo = entry['photo'] as String? ?? '';
        if (photo.isEmpty || refBytes.containsKey(photo)) continue;
        final Uint8List? bytes = await _loadPosePhotoBytes(photo);
        if (bytes != null) refBytes[photo] = bytes;
      }
    }

    // 预载布光场景（F12：矢量灯位图）。
    final Set<String> sceneIds = <String>{};
    for (final PlanModuleData module in modules) {
      if (module.type != PlanModuleType.lighting) continue;
      final String id = module.data['sceneId'] as String? ?? '';
      if (id.isNotEmpty) sceneIds.add(id);
    }
    final Map<String, LightingSceneData> scenes = <String, LightingSceneData>{};
    if (sceneIds.isNotEmpty) {
      onProgress(const ExportProgress('正在读取布光方案…', 0.35));
      final rows = await (db.select(
        db.lightingScenes,
      )..where((t) => t.id.isIn(sceneIds))).get();
      for (final LightingScene scene in rows) {
        try {
          scenes[scene.id] = LightingSceneData.fromJson(
            asMap(jsonDecode(scene.sceneJson)),
          );
        } catch (_) {}
      }
    }

    // D155：来源 / 许可清单（附录页用；从 refs + poses 模块里收，不丢字段）。
    final List<(String, String)> attributions =
        _ExporterPdfPress._collectAttributions(modules);

    doc.addPage(
      pw.MultiPage(
        pageFormat: pdfx.PdfPageFormat.a4,
        // D155：页眉（刊名 + 案名）与页脚（页码 + 品牌），让导出物能直接拿出去。
        header: (pw.Context context) =>
            _pdfRunningHead(baseStyle, title, status: status),
        footer: (pw.Context context) => _pdfRunningFoot(
          baseStyle,
          context.pageNumber,
          total: context.pagesCount,
        ),
        build: (pw.Context context) => <pw.Widget>[
          pw.Text(
            title,
            style: baseStyle.copyWith(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '状态：${status.label}${status == PlanDocStatus.draft ? '（草稿·未定稿）' : ''} · 正片工坊 ShootStudio',
            style: baseStyle.copyWith(fontSize: 9),
          ),
          pw.SizedBox(height: 10),
          // 刊头下的 hairline 主线，与阅读视图一致。
          pw.Container(height: 1.4, color: pdfx.PdfColors.grey900),
          pw.SizedBox(height: 14),
          for (var i = 0; i < modules.length; i++)
            _pdfModule(
              baseStyle,
              modules[i],
              i + 1,
              pdfFont: pdfFont,
              docContext: context,
              refBytes: refBytes,
              scenes: scenes,
            ),
          if (attributions.isNotEmpty)
            _pdfAttributionAppendix(baseStyle, attributions),
        ],
      ),
    );
    final bytes = await doc.save();
    await file.writeAsBytes(bytes);
  }

  /// D155：页眉——左侧刊名（衬线感用加粗 + 字距），右侧案名截断；下方一条 hairline。
  pw.Widget _pdfModule(
    pw.TextStyle base,
    PlanModuleData module,
    int index, {
    pw.Font? pdfFont,
    pw.Context? docContext,
    Map<String, Uint8List> refBytes = const <String, Uint8List>{},
    Map<String, LightingSceneData> scenes = const <String, LightingSceneData>{},
  }) {
    final pdfx.PdfFont? painterFont = (pdfFont != null && docContext != null)
        ? pdfFont.getFont(docContext)
        : null;
    pw.Widget body;
    switch (module.type) {
      case PlanModuleType.palette:
        final colors = (module.data['colors'] as List? ?? <Object?>[])
            .cast<String>();
        body = pw.Wrap(
          spacing: 6,
          children: <pw.Widget>[
            for (final String hex in colors.take(5))
              pw.Container(
                width: 60,
                height: 36,
                color: pdfx.PdfColor.fromInt(
                  0xFF000000 |
                      (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ??
                          0x888888),
                ),
              ),
          ],
        );
      case PlanModuleType.crew:
      case PlanModuleType.budget:
        final rows = (module.data['rows'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();
        body = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            for (final Map<String, Object?> row in rows)
              pw.Text(
                module.type == PlanModuleType.budget
                    ? '${row['item'] ?? ''}  ¥${row['price'] ?? 0}  ${row['note'] ?? ''}'
                    : '${row['role'] ?? ''}  ${row['who'] ?? ''}  ${row['time'] ?? ''}',
                style: base,
              ),
          ],
        );
      case PlanModuleType.refs:
        final refs = (module.data['refs'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();
        body = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            if (refBytes.isNotEmpty)
              pw.Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <pw.Widget>[
                  for (final Map<String, Object?> frame in refs)
                    if (refBytes[frame['imageRef'] as String? ?? ''] != null)
                      pw.ClipRRect(
                        horizontalRadius: 4,
                        verticalRadius: 4,
                        child: pw.Image(
                          pw.MemoryImage(
                            refBytes[frame['imageRef'] as String? ?? '']!,
                          ),
                          width: 130,
                          height: 86,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                ],
              ),
            if (refBytes.isNotEmpty) pw.SizedBox(height: 4),
            for (final Map<String, Object?> frame in refs)
              pw.Text(
                '· ${frame['name'] ?? ''}${(frame['sourceUrl'] as String? ?? '').isEmpty ? '' : '（出处：${frame['sourceUrl']}）'}',
                style: base.copyWith(fontSize: 9.5),
              ),
          ],
        );
      case PlanModuleType.poses:
        final poses = (module.data['poses'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();
        final String renderMode =
            module.data['poseRenderMode'] as String? ?? 'photo';
        final List<Map<String, Object?>> withPhoto = renderMode == 'skeleton'
            ? <Map<String, Object?>>[]
            : poses
                  .where(
                    (Map<String, Object?> p) =>
                        refBytes[p['photo'] as String? ?? ''] != null,
                  )
                  .toList();
        // 无照片（或选择骨架示意）的条目仍以文字登记，避免导出丢项。
        final List<Map<String, Object?>> textPoses = withPhoto.isEmpty
            ? poses
            : poses
                  .where((Map<String, Object?> p) => !withPhoto.contains(p))
                  .toList();
        body = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            if (withPhoto.isNotEmpty)
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <pw.Widget>[
                  for (final Map<String, Object?> pose in withPhoto.take(9))
                    pw.SizedBox(
                      width: 132,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: <pw.Widget>[
                          pw.ClipRRect(
                            horizontalRadius: 4,
                            verticalRadius: 4,
                            child: pw.Image(
                              pw.MemoryImage(
                                refBytes[pose['photo'] as String? ?? '']!,
                              ),
                              width: 132,
                              height: 168,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                          pw.Text(
                            '${pose['name'] ?? ''}',
                            style: base.copyWith(fontSize: 9.5),
                          ),
                          if (ExportService._poseAttribution(pose).isNotEmpty)
                            pw.Text(
                              '照片：${ExportService._poseAttribution(pose)}',
                              style: base.copyWith(
                                fontSize: 8,
                                color: pdfx.PdfColor.fromInt(0xFF8A919E),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            if (textPoses.isNotEmpty)
              for (final Map<String, Object?> pose in textPoses)
                pw.Text(
                  '· ${pose['name'] ?? ''}${(pose['lens'] as String? ?? '').isEmpty ? '' : '（${pose['lens']}）'}',
                  style: base.copyWith(fontSize: 10),
                ),
          ],
        );
      case PlanModuleType.lighting:
        final LightingSceneData? scene =
            scenes[module.data['sceneId'] as String? ?? ''];
        final String note = module.data['note'] as String? ?? '';
        body = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              '布光方案：${module.data['sceneName'] as String? ?? '未绑定'}',
              style: base,
            ),
            if (note.trim().isNotEmpty)
              pw.Text(note, style: base.copyWith(fontSize: 9.5)),
            if (scene != null) ...<pw.Widget>[
              pw.SizedBox(height: 6),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: pdfx.PdfColor.fromInt(0xFFD0D5DD),
                    width: 0.6,
                  ),
                ),
                child: pw.CustomPaint(
                  size: const pdfx.PdfPoint(430, 260),
                  painter: (pdfx.PdfGraphics canvas, pdfx.PdfPoint size) =>
                      _pdfLightingDiagram(canvas, size, scene, painterFont),
                ),
              ),
              pw.SizedBox(height: 4),
              for (final DeviceSpec device in scene.devices.where(
                (DeviceSpec d) => d.isLight && d.on,
              ))
                pw.Text(
                  _pdfDeviceLine(device),
                  style: base.copyWith(fontSize: 9.5),
                ),
            ],
          ],
        );
      case PlanModuleType.theme:
      case PlanModuleType.richText:
        final List<RichLine> lines = RichTextLite.parse(
          module.data['text'] as String? ?? '',
        );
        body = pw.RichText(
          textAlign: pw.TextAlign.left,
          text: pw.TextSpan(
            style: base,
            children: <pw.TextSpan>[
              for (var i = 0; i < lines.length; i++) ...<pw.TextSpan>[
                if (i > 0) const pw.TextSpan(text: '\n'),
                if (lines[i].bullet) const pw.TextSpan(text: '• '),
                for (final RichSpan span in lines[i].spans)
                  pw.TextSpan(
                    text: span.text,
                    style: span.bold
                        ? base.copyWith(fontWeight: pw.FontWeight.bold)
                        : base,
                  ),
              ],
            ],
          ),
        );
      case PlanModuleType.storyboard:
        final shots = (module.data['shots'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();
        body = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            for (var i = 0; i < shots.length; i++)
              pw.Text(
                '${shots[i]['no'] ?? i + 1}. ${shots[i]['shotSize'] ?? ''} · '
                '${shots[i]['lens'] ?? ''} · ${shots[i]['camera'] ?? ''} · '
                '姿势：${shots[i]['pose'] ?? ''}'
                '${shots[i]['key'] == true ? ' · ★重点' : ''}'
                '${(shots[i]['note'] as String? ?? '').isEmpty ? '' : '\n    ${shots[i]['note']}'}',
                style: base.copyWith(
                  fontSize: 10,
                  fontWeight: shots[i]['key'] == true
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
          ],
        );
      case PlanModuleType.sun:
        body = pw.Text(
          '${module.data['place'] ?? ''} · ${module.data['date'] ?? ''}',
          style: base,
        );
      default:
        body = pw.Text(
          (module.data['note'] as String? ?? '').trim().isEmpty
              ? '已绑定 ${(module.data['ids'] as List? ?? <Object?>[]).length} 项资源'
              : module.data['note'] as String? ?? '',
          style: base,
        );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: pdfx.PdfColor.fromInt(0xFFE5E7EB),
          width: 0.6,
        ),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            '$index. ${module.title.isEmpty ? module.type.label : module.title}',
            style: base.copyWith(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          body,
        ],
      ),
    );
  }

  /// PDF 矢量灯位图（F12）：俯视图（被摄体 + 灯位 + 指向 + 颜色 + 标签）。
  void _pdfLightingDiagram(
    pdfx.PdfGraphics canvas,
    pdfx.PdfPoint size,
    LightingSceneData scene,
    pdfx.PdfFont? font,
  ) {
    const double w = 430;
    const double h = 260;
    canvas.setColor(pdfx.PdfColor.fromInt(0xFFF8FAFC));
    canvas.drawRect(0, 0, w, h);
    canvas.fillPath();

    final List<DeviceSpec> lights = scene.devices
        .where((DeviceSpec d) => d.isLight && d.on)
        .toList();
    var maxR = 1.6;
    for (final DeviceSpec d in lights) {
      final double r = math.sqrt(d.x * d.x + d.y * d.y) + 0.6;
      if (r > maxR) maxR = r;
    }
    final double cx = w / 2;
    final double cy = h / 2;
    final double scale = math.min((w - 70) / (2 * maxR), (h - 70) / (2 * maxR));
    double px(DeviceSpec d) => cx + d.x * scale;
    double py(DeviceSpec d) => cy - d.y * scale;

    // 被摄体。
    canvas.setColor(pdfx.PdfColor.fromInt(0xFF1F2329));
    canvas.drawEllipse(cx, cy, 8, 8);
    canvas.fillPath();
    if (font != null) {
      canvas.drawString(font, 8, '被摄体', cx - 14, cy - 20);
    }

    for (final DeviceSpec device in lights) {
      final double x = px(device);
      final double y = py(device);
      // 指向线。
      canvas.setColor(pdfx.PdfColor.fromInt(0xFF98A2B3));
      canvas.setLineWidth(0.8);
      canvas.moveTo(x, y);
      canvas.lineTo(cx, cy);
      canvas.strokePath();
      // 灯位色点。
      final pdfx.PdfColor color = pdfx.PdfColor.fromInt(
        0xFF000000 |
            (int.tryParse(device.color.replaceFirst('#', ''), radix: 16) ??
                0xFFFFFF),
      );
      canvas.setColor(color);
      canvas.drawEllipse(x, y, 6, 6);
      canvas.fillPath();
      canvas.setStrokeColor(pdfx.PdfColor.fromInt(0xFF344054));
      canvas.setLineWidth(0.7);
      canvas.drawEllipse(x, y, 6, 6);
      canvas.strokePath();
      if (font != null) {
        final String label = device.name.length > 10
            ? device.name.substring(0, 10)
            : device.name;
        canvas.drawString(font, 7, label, x + 8, y + 7);
      }
    }
  }

  String _pdfDeviceLine(DeviceSpec device) {
    final DeviceGeometry geo = geometryOf(device.x, device.y);
    return '· ${device.name}：${geo.azimuthLabel} / ${geo.distanceLabel} · '
        '${device.intensity}% · ${device.kelvin}K · 高 ${device.height.toStringAsFixed(1)}m';
  }

  ByteData? _loadCjkFont() {
    const candidates = <String>[
      r'C:\Windows\Fonts\simhei.ttf',
      r'C:\Windows\Fonts\msyh.ttf',
      r'C:\Windows\Fonts\simsun.ttc',
      '/system/fonts/NotoSansCJK-Regular.ttc',
      '/system/fonts/DroidSansFallback.ttf',
    ];
    for (final String path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        final Uint8List bytes = file.readAsBytesSync();
        // pdf 包仅支持单字体（TTF/OTF）；TTC 字体集合会因缺 head 表解析崩溃 → 跳过。
        // （Windows 的 simsun.ttc / Android 的 NotoSansCJK-Regular.ttc 均属此类。）
        if (bytes.length < 12 ||
            (bytes[0] == 0x74 &&
                bytes[1] == 0x74 &&
                bytes[2] == 0x63 &&
                bytes[3] == 0x66)) {
          continue;
        }
        return ByteData.sublistView(bytes);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ---------------- .sspak ----------------
}
