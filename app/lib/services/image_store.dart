import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'palette_extractor.dart';

/// 图片导入：压缩（单张 ≤300KB）→ 落盘工作区 `images/<category>/` → 返回文件名与色卡。
class ImageStore {
  ImageStore(this.workspaceRoot);

  final String workspaceRoot;
  static const Uuid _uuid = Uuid();

  /// 压缩编码：限制最长边与质量，直到 ≤ [maxKb]。
  static Uint8List compress(Uint8List raw,
      {int maxKb = 300, int maxEdge = 2000}) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return raw;
    var work = decoded;
    var quality = 84;
    var encoded = Uint8List.fromList(img.encodeJpg(work, quality: quality));
    for (var i = 0; i < 7 && encoded.lengthInBytes > maxKb * 1024; i++) {
      if (quality > 40) {
        quality -= 12;
      } else {
        final longest = work.width > work.height ? work.width : work.height;
        if (longest > 400) {
          work = img.copyResize(
            work,
            width: (work.width * 0.75).round(),
            height: (work.height * 0.75).round(),
            interpolation: img.Interpolation.average,
          );
        }
      }
      encoded = Uint8List.fromList(img.encodeJpg(work, quality: quality));
    }
    if (encoded.lengthInBytes > maxKb * 1024) {
      work = img.copyResize(work, width: 720);
      encoded = Uint8List.fromList(img.encodeJpg(work, quality: 40));
    }
    return encoded;
  }

  /// 导入并保存。返回 (相对文件名, 色卡)。
  Future<(String, PaletteResult)> importBytes(
    Uint8List raw, {
    required String category,
    String? title,
  }) async {
    final compressed = compress(raw);
    final palette = PaletteExtractor.extract(compressed);
    final safeTitle =
        (title ?? 'img').replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 6)}_$safeTitle.jpg';
    final dir = Directory(p.join(workspaceRoot, 'images', category));
    await dir.create(recursive: true);
    await File(p.join(dir.path, name)).writeAsBytes(compressed);
    return (name, palette);
  }

  Future<(String, PaletteResult)> importFile(
    String sourcePath, {
    required String category,
  }) async {
    final raw = await File(sourcePath).readAsBytes();
    return importBytes(raw,
        category: category, title: p.basenameWithoutExtension(sourcePath));
  }

  String pathOf(String category, String fileName) =>
      p.join(workspaceRoot, 'images', category, fileName);

  Future<void> delete(String category, String fileName) async {
    final f = File(pathOf(category, fileName));
    if (await f.exists()) await f.delete();
  }

  Future<Uint8List?> read(String category, String fileName) async {
    final f = File(pathOf(category, fileName));
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }
}
