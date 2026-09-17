import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' as pdfx;
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

import '../../core/db/database.dart';
import '../../core/utils/json_utils.dart';
import '../../core/workspace/workspace.dart';
import '../../services/richtext_lite.dart';
import '../lighting/lighting_models.dart';
import '../planner/planner_models.dart';

/// 导出格式（PRD 6.7）。
enum ExportFormat {
  longPng('long', '长图 PNG', '发微信 / 小红书'),
  pdf('pdf', '打印版 PDF', '正式确认件'),
  sspak('sspak', '.sspak 数据包', '整案交接 / 备份');

  const ExportFormat(this.id, this.label, this.usage);
  final String id;
  final String label;
  final String usage;
}

class ExportProgress {
  const ExportProgress(this.stage, [this.percent = 0]);
  final String stage;
  final double percent;
}

class ExportResult {
  const ExportResult({required this.files, required this.sha256s});
  final List<String> files;
  final Map<String, String> sha256s;
}

class ExportCancelled implements Exception {
  const ExportCancelled();
}

class IntegrityIssue {
  const IntegrityIssue(this.moduleTitle, this.detail);
  final String moduleTitle;
  final String detail;
}

/// 导出服务。
class ExportService {
  ExportService({
    required this.workspace,
    required this.db,
    this.refBytesLoader,
  });

  final Workspace workspace;
  final AppDatabase db;

  /// 参考图字节读取钩子（测试注入；默认从工作区 images/refs 读取）。
  final Future<Uint8List?> Function(String ref)? refBytesLoader;

  Future<Uint8List?> _loadRefBytes(String ref) async {
    if (ref.isEmpty) return null;
    final Future<Uint8List?> Function(String)? hook = refBytesLoader;
    if (hook != null) return hook(ref);
    final file = File(p.join(workspace.root.path, 'images', 'refs', ref));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// V4/R25：姿势照片字节（assets 内路径走 rootBundle；非 assets 走参考图钩子）。
  Future<Uint8List?> _loadPosePhotoBytes(String path) async {
    if (path.isEmpty) return null;
    if (!path.startsWith('assets/')) return _loadRefBytes(path);
    try {
      final ByteData data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<List<IntegrityIssue>> checkIntegrity(
      List<PlanModuleData> modules) async {
    final issues = <IntegrityIssue>[];
    final resources = await db.select(db.resources).get();
    final resourceIds = resources.map((Resource r) => r.id).toSet();
    final scenes = await db.select(db.lightingScenes).get();
    final sceneIds = scenes.map((LightingScene s) => s.id).toSet();
    for (final PlanModuleData module in modules) {
      switch (module.type) {
        case PlanModuleType.model:
        case PlanModuleType.location:
        case PlanModuleType.clothing:
        case PlanModuleType.props:
        case PlanModuleType.makeup:
          for (final String id
              in (module.data['ids'] as List? ?? <Object?>[]).cast<String>()) {
            if (!resourceIds.contains(id)) {
              issues.add(IntegrityIssue(module.title, '资源引用失效（$id）'));
            }
          }
        case PlanModuleType.lighting:
          final sceneId = module.data['sceneId'] as String? ?? '';
          if (sceneId.isNotEmpty && !sceneIds.contains(sceneId)) {
            issues.add(IntegrityIssue(module.title, '布光方案已被删除'));
          }
        default:
          break;
      }
    }
    return issues;
  }

  Future<ExportResult> run({
    required String planTitle,
    required PlanDocStatus status,
    required List<PlanModuleData> modules,
    required ExportFormat format,
    required void Function(ExportProgress) onProgress,
    required bool Function() isCancelled,
  }) async {
    final safeTitle = planTitle.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
    final date =
        DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
    final base = '$safeTitle-$date';
    final files = <String>[];
    final hashes = <String, String>{};

    switch (format) {
      case ExportFormat.longPng:
        onProgress(const ExportProgress('正在渲染长图…', 0.1));
        final images = await renderLongImage(
          modules: modules,
          title: planTitle,
          status: status,
          dark: false,
        );
        var index = 0;
        for (final Uint8List png in images) {
          if (isCancelled()) throw const ExportCancelled();
          final name = images.length > 1
              ? '${base}_long_${++index}.png'
              : '${base}_long.png';
          final file = File(p.join(workspace.exportsPath, name));
          await file.writeAsBytes(png);
          files.add(file.path);
          hashes[file.path] = sha256.convert(png).toString();
          onProgress(ExportProgress('已导出 $index/${images.length}',
              0.1 + 0.85 * index / images.length));
        }
      case ExportFormat.pdf:
        onProgress(const ExportProgress('正在生成 PDF…', 0.2));
        final file = File(p.join(workspace.exportsPath, '$base.pdf'));
        await _exportPdf(file, planTitle, status, modules, onProgress);
        files.add(file.path);
        hashes[file.path] = sha256.convert(await file.readAsBytes()).toString();
      case ExportFormat.sspak:
        onProgress(const ExportProgress('正在打包 .sspak…', 0.1));
        final file = File(p.join(workspace.exportsPath, '$base.sspak'));
        await _exportSspak(
            file, planTitle, status, modules, onProgress, isCancelled);
        files.add(file.path);
        hashes[file.path] = sha256.convert(await file.readAsBytes()).toString();
    }
    return ExportResult(files: files, sha256s: hashes);
  }

  // ---------------- 长图渲染（纯 dart:ui 离屏拼接；高度超限自动分页） ----------------

  static const double _width = 1080;
  static const double _maxPartHeight = 28000;

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
      if (height + h > _maxPartHeight && current.isNotEmpty) {
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
          parts[partIndex], title, status, partIndex + 1, parts.length);
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
        final int lines =
            math.min(14, math.max(1, (module.summary.length / 26).ceil()));
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
    final contentWidth = _width - margin * 2;

    double y = 0;
    final heights = <double>[];
    for (final PlanModuleData module in modules) {
      final h = await _measureModule(module);
      heights.add(h);
      y += h;
    }
    final totalHeight = y + 320;

    final recorder = ui.PictureRecorder();
    final canvas =
        ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, _width, totalHeight));
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, _width, totalHeight),
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

    // 头部。
    var cursor = 72.0;
    _text(canvas, title, margin, cursor, 40,
        bold: true, color: const ui.Color(0xFF1F2329), maxWidth: contentWidth);
    cursor += 56;
    _text(
      canvas,
      '状态：${status.label}${status == PlanDocStatus.draft ? ' · 草稿·未定稿' : ''} · 正片工坊 ShootStudio'
      '${partTotal > 1 ? ' · 第 $partIndex/$partTotal 部分' : ''}',
      margin,
      cursor,
      16,
      color: const ui.Color(0xFF646A73),
      maxWidth: contentWidth,
    );
    cursor += 40;

    for (var i = 0; i < modules.length; i++) {
      final module = modules[i];
      final h = heights[i];
      _drawModuleCard(canvas, module, i + 1, margin, cursor, contentWidth, h,
          refImages, poseImages);
      cursor += h;
    }

    _text(
      canvas,
      '由 正片工坊 ShootStudio 导出 · 模块顺序与策划案画布一致',
      margin,
      totalHeight - 72,
      14,
      color: const ui.Color(0xFF8A919E),
      maxWidth: contentWidth,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), totalHeight.ceil());
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
        final colors =
            (module.data['colors'] as List? ?? <Object?>[]).cast<String>();
        var chipX = x + 24;
        for (final String hex in colors.take(5)) {
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(chipX, cursor, 160, 72),
              const ui.Radius.circular(10),
            ),
            ui.Paint()..color = _color(hex),
          );
          _text(canvas, hex, chipX, cursor + 78, 13,
              color: const ui.Color(0xFF646A73), maxWidth: 160);
          chipX += 172;
        }
      case PlanModuleType.refs:
        final refs = (module.data['refs'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();
        var tileX = x + 24;
        var tileY = cursor;
        for (var i = 0; i < refs.length && i < 6; i++) {
          final palette =
              (refs[i]['palette'] as List? ?? <Object?>[]).cast<String>();
          final tile = ui.Rect.fromLTWH(tileX, tileY, 300, 220);
          final ui.Image? real =
              refImages[refs[i]['imageRef'] as String? ?? ''];
          if (real != null) {
            canvas.save();
            canvas.clipRRect(
                ui.RRect.fromRectAndRadius(tile, const ui.Radius.circular(12)));
            _drawImageCover(canvas, real, tile);
            canvas.restore();
          } else {
            final paint = ui.Paint()
              ..shader = ui.Gradient.linear(
                tile.topLeft,
                tile.bottomRight,
                <ui.Color>[
                  _color(palette.isNotEmpty ? palette[0] : '#888888'),
                  _color(palette.length > 1 ? palette[1] : '#333333'),
                ],
              );
            canvas.drawRRect(
                ui.RRect.fromRectAndRadius(tile, const ui.Radius.circular(12)),
                paint);
          }
          _text(canvas, refs[i]['name'] as String? ?? '', tileX + 10,
              tileY + 226, 13,
              color: const ui.Color(0xFF646A73), maxWidth: 300);
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
                ui.RRect.fromRectAndRadius(cell, const ui.Radius.circular(12)));
            _drawImageContain(canvas, photo,
                ui.Rect.fromLTWH(poseX + 6, poseY + 8, 288, 240));
            canvas.restore();
          } else {
            final joints = asMap(poses[i]['joints']);
            _drawPoseFigure(canvas,
                ui.Rect.fromLTWH(poseX + 40, poseY + 16, 220, 240), joints);
          }
          _text(canvas, poses[i]['name'] as String? ?? '', poseX + 12,
              poseY + 264, 14,
              maxWidth: 280);
          final String attribution = <String>[
            if ((poses[i]['author'] as String? ?? '').isNotEmpty)
              poses[i]['author'] as String,
            if ((poses[i]['license'] as String? ?? '').isNotEmpty)
              poses[i]['license'] as String,
          ].join(' · ');
          if (photo != null &&
              renderMode != 'skeleton' &&
              attribution.isNotEmpty) {
            _text(canvas, '照片：$attribution', poseX + 12, poseY + 280, 10.5,
                color: const ui.Color(0xFF8A919E), maxWidth: 280);
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
            _text(canvas, note, x + 40, shotY, 12.5,
                color: const ui.Color(0xFF646A73), maxWidth: width - 64);
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

  ui.Color _color(String hex) => ui.Color(0xFF000000 |
      (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x888888));

  void _text(
    ui.Canvas canvas,
    String text,
    double x,
    double y,
    double size, {
    bool bold = false,
    ui.Color color = const ui.Color(0xFF1F2329),
    required double maxWidth,
  }) {
    if (text.isEmpty) return;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: size,
        maxLines: 6,
        ellipsis: '…',
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
      ))
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
    final ui.Rect src = ui.Rect.fromLTWH(
      (iw - sw) / 2,
      (ih - sh) / 2,
      sw,
      sh,
    );
    canvas.drawImageRect(image, src, dst, ui.Paint());
  }

  /// V4/R25：姿势照片署名（作者 · 许可）。
  static String _poseAttribution(Map<String, Object?> pose) => <String>[
        if ((pose['author'] as String? ?? '').isNotEmpty)
          pose['author'] as String,
        if ((pose['license'] as String? ?? '').isNotEmpty)
          pose['license'] as String,
      ].join(' · ');

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
        ui.ParagraphStyle(
          fontSize: size,
          maxLines: 6,
          ellipsis: '…',
        ),
      );
      if (line.bullet) {
        builder
          ..pushStyle(ui.TextStyle(
            color: const ui.Color(0xFF1F2329),
            fontSize: size,
          ))
          ..addText('• ');
      }
      for (final RichSpan span in line.spans) {
        builder
          ..pushStyle(ui.TextStyle(
            color: const ui.Color(0xFF1F2329),
            fontSize: size,
            fontWeight: span.bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
          ))
          ..addText(span.text);
      }
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(
            width: line.bullet ? maxWidth - indent : maxWidth));
      canvas.drawParagraph(
          paragraph, ui.Offset(line.bullet ? x + indent : x, cy));
      cy += paragraph.height + (line.spans.isEmpty ? 0 : 4);
    }
  }

  /// 姿势九宫格简化投影（R25：无照片/选择「骨架示意」时的静态投影表示）。
  void _drawPoseFigure(
      ui.Canvas canvas, ui.Rect area, Map<String, Object?> joints) {
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
    final head =
        ui.Offset(neck.dx + math.sin(lean) * h * 0.05, neck.dy - h * 0.09);

    // 躯干。
    canvas.drawLine(hip, neck, stroke);
    canvas.drawCircle(
        head, h * 0.07, ui.Paint()..color = const ui.Color(0xFF343A46));

    void limb(ui.Offset from, double upperDeg, double lowerDeg, double length,
        {bool mirror = false}) {
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
    limb(neck + ui.Offset(0, h * 0.02), axis('shoulder_l')[2],
        axis('elbow_l')[0] * 0.4, armLength);
    limb(neck + ui.Offset(0, h * 0.02), axis('shoulder_r')[2],
        axis('elbow_r')[0] * 0.4, armLength,
        mirror: true);
    // 腿。
    final legLength = h * 0.42;
    final hipLeft = hip + ui.Offset(-h * 0.06, 0);
    final hipRight = hip + ui.Offset(h * 0.06, 0);
    limb(hipLeft, axis('hip_l')[0] * -0.6, axis('knee_l')[0] * 0.5, legLength);
    limb(hipRight, axis('hip_r')[0] * -0.6, axis('knee_r')[0] * 0.5, legLength,
        mirror: false);
  }

  // ---------------- PDF ----------------

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
      final rows = await (db.select(db.lightingScenes)
            ..where((t) => t.id.isIn(sceneIds)))
          .get();
      for (final LightingScene scene in rows) {
        try {
          scenes[scene.id] =
              LightingSceneData.fromJson(asMap(jsonDecode(scene.sceneJson)));
        } catch (_) {}
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pdfx.PdfPageFormat.a4,
        build: (pw.Context context) => <pw.Widget>[
          pw.Text(title,
              style: baseStyle.copyWith(
                  fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            '状态：${status.label}${status == PlanDocStatus.draft ? '（草稿·未定稿）' : ''} · 正片工坊 ShootStudio',
            style: baseStyle.copyWith(fontSize: 9),
          ),
          pw.SizedBox(height: 12),
          for (var i = 0; i < modules.length; i++)
            _pdfModule(baseStyle, modules[i], i + 1,
                pdfFont: pdfFont,
                docContext: context,
                refBytes: refBytes,
                scenes: scenes),
        ],
      ),
    );
    final bytes = await doc.save();
    await file.writeAsBytes(bytes);
  }

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
        final colors =
            (module.data['colors'] as List? ?? <Object?>[]).cast<String>();
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
                              refBytes[frame['imageRef'] as String? ?? '']!),
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
                .where((Map<String, Object?> p) =>
                    refBytes[p['photo'] as String? ?? ''] != null)
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
                                  refBytes[pose['photo'] as String? ?? '']!),
                              width: 132,
                              height: 168,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                          pw.Text('${pose['name'] ?? ''}',
                              style: base.copyWith(fontSize: 9.5)),
                          if (_poseAttribution(pose).isNotEmpty)
                            pw.Text('照片：${_poseAttribution(pose)}',
                                style: base.copyWith(
                                    fontSize: 8,
                                    color: pdfx.PdfColor.fromInt(0xFF8A919E))),
                        ],
                      ),
                    ),
                ],
              ),
            if (textPoses.isNotEmpty)
              for (final Map<String, Object?> pose in textPoses)
                pw.Text(
                    '· ${pose['name'] ?? ''}${(pose['lens'] as String? ?? '').isEmpty ? '' : '（${pose['lens']}）'}',
                    style: base.copyWith(fontSize: 10)),
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
                      color: pdfx.PdfColor.fromInt(0xFFD0D5DD), width: 0.6),
                ),
                child: pw.CustomPaint(
                  size: const pdfx.PdfPoint(430, 260),
                  painter: (pdfx.PdfGraphics canvas, pdfx.PdfPoint size) =>
                      _pdfLightingDiagram(canvas, size, scene, painterFont),
                ),
              ),
              pw.SizedBox(height: 4),
              for (final DeviceSpec device
                  in scene.devices.where((DeviceSpec d) => d.isLight && d.on))
                pw.Text(_pdfDeviceLine(device),
                    style: base.copyWith(fontSize: 9.5)),
            ],
          ],
        );
      case PlanModuleType.theme:
      case PlanModuleType.richText:
        final List<RichLine> lines =
            RichTextLite.parse(module.data['text'] as String? ?? '');
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
            style: base);
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
        border:
            pw.Border.all(color: pdfx.PdfColor.fromInt(0xFFE5E7EB), width: 0.6),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
              '$index. ${module.title.isEmpty ? module.type.label : module.title}',
              style:
                  base.copyWith(fontSize: 13, fontWeight: pw.FontWeight.bold)),
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

    final List<DeviceSpec> lights =
        scene.devices.where((DeviceSpec d) => d.isLight && d.on).toList();
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
      if (file.existsSync()) {
        try {
          return ByteData.sublistView(file.readAsBytesSync());
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  // ---------------- .sspak ----------------

  Future<void> _exportSspak(
    File outFile,
    String title,
    PlanDocStatus status,
    List<PlanModuleData> modules,
    void Function(ExportProgress) onProgress,
    bool Function() isCancelled,
  ) async {
    final archive = Archive();

    void addBytes(String name, List<int> bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addBytes(
      'manifest.json',
      utf8.encode(const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'format': 'sspak',
        'version': 1,
        'app': 'ShootStudio',
        'appVersion': '1.0.0',
        'title': title,
        'exportedAt': DateTime.now().toIso8601String(),
      })),
    );
    addBytes(
      'plan.json',
      utf8.encode(jsonEncode(<String, Object?>{
        'title': title,
        'status': status.storageName,
        'modules': modules.map((PlanModuleData m) => m.toJson()).toList(),
      })),
    );

    // 关联资源与图片。
    final resources = await db.select(db.resources).get();
    final relatedIds = <String>{};
    for (final PlanModuleData module in modules) {
      relatedIds
          .addAll((module.data['ids'] as List? ?? <Object?>[]).cast<String>());
    }
    final related =
        resources.where((Resource r) => relatedIds.contains(r.id)).toList();
    addBytes(
      'resources.json',
      utf8.encode(jsonEncode(<String, Object?>{
        'resources': related
            .map((Resource r) => <String, Object?>{
                  'id': r.id,
                  'type': r.type,
                  'name': r.name,
                  'fields': asMap(jsonDecode(r.fieldsJson)),
                  'cover': r.coverImage,
                })
            .toList(),
      })),
    );

    // 布光方案。
    final sceneIds = modules
        .where((PlanModuleData m) => m.type == PlanModuleType.lighting)
        .map((PlanModuleData m) => m.data['sceneId'] as String? ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();
    final scenes = await db.select(db.lightingScenes).get();
    addBytes(
      'lighting.json',
      utf8.encode(jsonEncode(<String, Object?>{
        'scenes': scenes
            .where((LightingScene s) => sceneIds.contains(s.id))
            .map((LightingScene s) => <String, Object?>{
                  'id': s.id,
                  'name': s.name,
                  'scene': asMap(jsonDecode(s.sceneJson)),
                })
            .toList(),
      })),
    );

    // 收藏姿势。
    final poses = await db.select(db.poses).get();
    addBytes(
      'poses.json',
      utf8.encode(jsonEncode(<String, Object?>{
        'poses': poses
            .where((Pose pose) => pose.favorite)
            .map((Pose pose) => <String, Object?>{
                  'id': pose.id,
                  'name': pose.name,
                  'category': pose.category,
                  'difficulty': pose.difficulty,
                  'joints': asMap(jsonDecode(pose.jointsJson)),
                  'tip': pose.tip,
                  'lens': pose.lensAdvice,
                })
            .toList(),
      })),
    );

    // 参考帧（画板）。
    final frames = await (db.select(db.filmFrames)
          ..where((t) => t.inBoard.equals(true)))
        .get();
    addBytes(
      'refs.json',
      utf8.encode(jsonEncode(<String, Object?>{
        'refs': frames
            .map((FilmFrame frame) => <String, Object?>{
                  'id': frame.id,
                  'name': frame.name,
                  'imageRef': frame.imageRef,
                  'palette': frame.paletteJson,
                  'sourceUrl': frame.sourceUrl,
                })
            .toList(),
      })),
    );

    // 图片文件：资源封面与参考图。
    var count = 0;
    for (final Resource resource in related) {
      final cover = resource.coverImage;
      if (cover == null || cover.isEmpty) continue;
      final file =
          File(p.join(workspace.root.path, 'images', resource.type, cover));
      if (await file.exists()) {
        addBytes('images/${resource.type}/$cover', await file.readAsBytes());
        count++;
      }
    }
    for (final FilmFrame frame in frames) {
      if (frame.imageRef.isEmpty) continue;
      final file =
          File(p.join(workspace.root.path, 'images', 'refs', frame.imageRef));
      if (await file.exists()) {
        addBytes('images/refs/${frame.imageRef}', await file.readAsBytes());
        count++;
      }
    }
    onProgress(ExportProgress('已打包 $count 张图片', 0.6));
    if (isCancelled()) throw const ExportCancelled();
    final encoded = ZipEncoder().encode(archive);
    await outFile.writeAsBytes(encoded!);
  }
}

/// .sspak 导入还原（PRD 6.7 边界：校验包内版本号）。
class SspakImporter {
  SspakImporter({required this.workspace, required this.db});

  final Workspace workspace;
  final AppDatabase db;

  Future<({String planId, String title, int moduleCount})> import(
      String sspakPath) async {
    final bytes = await File(sspakPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    Map<String, Object?> readJson(String name) {
      for (final ArchiveFile file in archive) {
        if (file.name == name) {
          return asMap(jsonDecode(utf8.decode(file.content!)));
        }
      }
      throw StateError('.sspak 缺少 $name');
    }

    final manifest = readJson('manifest.json');
    if (manifest['format'] != 'sspak' ||
        (manifest['version'] as num?)?.toInt() != 1) {
      throw const FormatException('不兼容的 .sspak 版本');
    }

    // 图片落盘。
    for (final ArchiveFile file in archive) {
      if (!file.name.startsWith('images/')) continue;
      final relative = file.name.substring('images/'.length);
      final target = File(p.join(workspace.root.path, 'images', relative));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(file.content!);
    }

    // 资源还原（新 id 防冲突）。
    final resourceIdMap = <String, String>{};
    final resourcesJson = readJson('resources.json');
    final list = resourcesJson['resources'] as List? ?? <Object?>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final Object? raw in list) {
      if (raw is! Map) continue;
      final map = raw.cast<String, Object?>();
      final newId = 'imported-${map['id']}';
      resourceIdMap[map['id'] as String? ?? ''] = newId;
      await db.into(db.resources).insertOnConflictUpdate(
            ResourcesCompanion.insert(
              id: newId,
              type: map['type'] as String? ?? 'props',
              name: map['name'] as String? ?? '导入资源',
              fieldsJson:
                  Value(jsonEncode(map['fields'] ?? <String, Object?>{})),
              coverImage: Value(map['cover'] as String?),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    // 布光方案还原。
    final lightingJson = readJson('lighting.json');
    final sceneIdMap = <String, String>{};
    for (final Object? raw in lightingJson['scenes'] as List? ?? <Object?>[]) {
      if (raw is! Map) continue;
      final map = raw.cast<String, Object?>();
      final newId = 'imported-${map['id']}';
      sceneIdMap[map['id'] as String? ?? ''] = newId;
      await db.into(db.lightingScenes).insertOnConflictUpdate(
            LightingScenesCompanion.insert(
              id: newId,
              name: map['name'] as String? ?? '导入布光方案',
              sceneJson: jsonEncode(map['scene'] ?? <String, Object?>{}),
              linkedPoseId: const Value(null),
              updatedAt: now,
            ),
          );
    }

    // 姿势还原。
    final posesJson = readJson('poses.json');
    for (final Object? raw in posesJson['poses'] as List? ?? <Object?>[]) {
      if (raw is! Map) continue;
      final map = raw.cast<String, Object?>();
      await db.into(db.poses).insertOnConflictUpdate(
            PosesCompanion.insert(
              id: 'imported-${map['id']}',
              name: map['name'] as String? ?? '导入姿势',
              category: map['category'] as String? ?? '站姿',
              difficulty: Value(map['difficulty'] as String? ?? '进阶'),
              jointsJson: jsonEncode(map['joints'] ?? <String, Object?>{}),
              tip: Value(map['tip'] as String? ?? ''),
              lensAdvice: Value(map['lens'] as String? ?? ''),
              builtin: const Value(false),
              favorite: const Value(true),
            ),
          );
    }

    // 策划案还原（重映射引用）。
    final planJson = readJson('plan.json');
    final modules = (planJson['modules'] as List? ?? <Object?>[])
        .whereType<Map>()
        .map((Map m) => PlanModuleData.fromJson(m.cast<String, Object?>()))
        .toList();
    for (final PlanModuleData module in modules) {
      final ids = (module.data['ids'] as List? ?? <Object?>[]).cast<String>();
      if (ids.isNotEmpty) {
        module.data['ids'] =
            ids.map((String id) => resourceIdMap[id] ?? id).toList();
      }
      if (module.type == PlanModuleType.lighting) {
        final sceneId = module.data['sceneId'] as String? ?? '';
        module.data['sceneId'] = sceneIdMap[sceneId] ?? sceneId;
      }
    }
    final nextId = DateTime.now().microsecondsSinceEpoch;
    final planId = 'imported-$nextId';
    await db.into(db.plans).insertOnConflictUpdate(
          PlansCompanion.insert(
            id: planId,
            title: '${planJson['title'] ?? '导入策划案'}（导入）',
            status: Value(planJson['status'] as String? ?? 'draft'),
            modulesJson: Value(jsonEncode(
                modules.map((PlanModuleData m) => m.toJson()).toList())),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (
      planId: planId,
      title: planJson['title'] as String? ?? '导入策划案',
      moduleCount: modules.length
    );
  }
}
