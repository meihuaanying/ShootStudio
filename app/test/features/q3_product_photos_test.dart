import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// Q3 产品图规范化硬门禁（D71–D73、R19/R22/R24/R27）。
// 数据来源：tool/gen_product_photos.py + normalize_product_photos.py。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Object?> catalog;
  late Map<String, Object?> byId;
  late Map<String, Object?> stats;
  late Set<String> attributedFiles;

  setUpAll(() {
    final File file = File('assets/content/gear/gear_photos2.json');
    expect(file.existsSync(), isTrue, reason: '缺 gear_photos2.json');
    catalog =
        (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
    byId = (catalog['byId'] as Map).cast<String, Object?>();
    stats = (catalog['stats'] as Map).cast<String, Object?>();
    final Map<String, Object?> attr =
        (jsonDecode(File('assets/content/attribution.json').readAsStringSync())
                as Map)
            .cast<String, Object?>();
    attributedFiles = (attr['items'] as List<Object?>? ?? <Object?>[])
        .whereType<Map>()
        .map((Map m) => '${m.cast<String, Object?>()['file']}')
        .toSet();
  });

  group('Q3 产品图', () {
    test('覆盖率：相机 / 镜头 ≥90%（D72/R27）', () {
      final Map<String, Object?> coverage =
          (stats['coverage'] as Map).cast<String, Object?>();
      for (final String kind in <String>['camera', 'lens']) {
        final Map<String, Object?> c =
            (coverage[kind] as Map).cast<String, Object?>();
        final double ratio = (c['ratio'] as num).toDouble();
        expect(ratio, greaterThanOrEqualTo(0.90),
            reason: '$kind 覆盖率 ${(ratio * 100).toStringAsFixed(1)}% < 90%');
        expect((c['covered'] as num).toInt(), greaterThan(0));
      }
      // 未覆盖项必须可枚举（UI 标注「缺图/插画」）。
      expect(stats['missing'], isA<List<Object?>>());
    });

    test('内置 Top100：清单 100 条、文件存在、包体 ≤15MB（D73/R22）', () {
      final List<Object?> top =
          catalog['builtinTop100'] as List<Object?>? ?? <Object?>[];
      expect(top.length, 100);
      final List<Map<String, Object?>> builtin = byId.values
          .whereType<Map>()
          .map((Map m) => m.cast<String, Object?>())
          .where((Map<String, Object?> v) => v['builtin'] == true)
          .toList();
      expect(builtin.length, inInclusiveRange(90, 100));
      final Directory dir = Directory('assets/content/gear/photo2');
      expect(dir.existsSync(), isTrue);
      final Set<String> diskFiles = dir
          .listSync()
          .whereType<File>()
          .map((File f) => f.uri.pathSegments.last)
          .toSet();
      int totalBytes = 0;
      for (final Map<String, Object?> item in builtin) {
        final String file = '${item['file']}';
        expect(diskFiles, contains(file), reason: '内置图缺文件：$file');
        totalBytes += File('assets/content/gear/photo2/$file').lengthSync();
      }
      expect(totalBytes, lessThanOrEqualTo(15 * 1024 * 1024),
          reason: '内置产品图超 15MB 预算');
      // D1：包内只保留内置文件（其余走素材同步，不入包）。
      for (final String disk in diskFiles) {
        expect(
          builtin.any((Map<String, Object?> v) => v['file'] == disk),
          isTrue,
          reason: 'photo2 存在未标记内置的文件：$disk',
        );
      }
    });

    test('来源 / 许可 / 署名完整，禁 NC（D71/R24）', () {
      const Set<String> allowed = <String>{
        'CC0',
        'CC0-1.0',
        'CC BY 2.0',
        'CC BY 3.0',
        'CC BY 4.0',
        'CC BY-SA 2.0',
        'CC BY-SA 2.5',
        'CC BY-SA 3.0',
        'CC BY-SA 4.0',
        'Public domain',
        'PD',
        'Pexels License',
      };
      int withFile = 0;
      for (final Map<String, Object?> item in byId.values
          .whereType<Map>()
          .map((Map m) => m.cast<String, Object?>())) {
        final String file = item['file'] as String? ?? '';
        if (file.isEmpty) continue;
        withFile++;
        expect(item['license'], isNotNull, reason: '${item['id']} 缺许可');
        expect(item['author'] as String? ?? '', isNotEmpty,
            reason: '${item['id']} 缺署名');
        expect('${item['license']}'.toUpperCase(), isNot(contains('NC')),
            reason: '${item['id']} 禁 NC 数据（R24）');
        expect(allowed, contains('${item['license']}'),
            reason: '${item['id']} 许可不在白名单');
        expect(item['tier'], anyOf('product', 'series'),
            reason: '${item['id']} 缺 tier 标注（R19）');
        // 署名登记（attribution.json：file 或来源页至少其一可查）。
        final bool registered =
            attributedFiles.contains('assets/content/gear/photo2/$file') ||
                attributedFiles.contains('${item['pageUrl'] ?? ''}') ||
                attributedFiles.contains('${item['sourceUrl'] ?? ''}');
        expect(registered, isTrue,
            reason: '${item['id']} 未登记 attribution.json');
      }
      expect(withFile, greaterThanOrEqualTo(200));
      final Map<String, Object?> tier =
          (stats['tier'] as Map).cast<String, Object?>();
      expect((tier['product'] as num).toInt(),
          greaterThan((tier['series'] as num).toInt()),
          reason: '应以产品图为主（不允许氛围图冒充，R19）');
    });

    test('运行时同步：非内置条目带 runtimeUrl（D73）', () {
      final List<Map<String, Object?>> rest = byId.values
          .whereType<Map>()
          .map((Map m) => m.cast<String, Object?>())
          .where((Map<String, Object?> v) =>
              v['builtin'] != true && v['file'] != null)
          .toList();
      expect(rest.length, greaterThan(100));
      for (final Map<String, Object?> item in rest) {
        expect('${item['runtimeUrl'] ?? ''}', isNotEmpty,
            reason: '${item['id']} 缺 runtimeUrl，无法素材同步');
      }
    });

    test('规范化：抽样内置图 4:3 / 长边 800–1200 / 白底（D71）', () {
      final List<Map<String, Object?>> builtin = byId.values
          .whereType<Map>()
          .map((Map m) => m.cast<String, Object?>())
          .where((Map<String, Object?> v) => v['builtin'] == true)
          .toList();
      final int step = (builtin.length / 12).floor().clamp(1, builtin.length);
      int sampled = 0;
      for (int i = 0; i < builtin.length && sampled < 12; i += step) {
        final String file = '${builtin[i]['file']}';
        final Uint8List bytes =
            File('assets/content/gear/photo2/$file').readAsBytesSync();
        final (int, int) size = _jpegSize(bytes);
        final int longEdge = size.$1 > size.$2 ? size.$1 : size.$2;
        expect(longEdge, inInclusiveRange(800, 1200),
            reason: '$file 长边 $longEdge 越界');
        final double aspect = size.$1 / size.$2;
        expect(aspect, inInclusiveRange(1.28, 1.38),
            reason: '$file 长宽比 $aspect 非 4:3');

        final img.Image? decoded = img.decodeImage(bytes);
        expect(decoded, isNotNull, reason: '$file 解码失败');
        final img.Image image = decoded!;
        double sum = 0;
        int count = 0;
        for (int x = 0; x < image.width; x += 16) {
          for (final int y in <int>[0, image.height - 1]) {
            final img.Pixel p = image.getPixel(x, y);
            sum += (p.r + p.g + p.b) / 3;
            count++;
          }
        }
        for (int y = 0; y < image.height; y += 16) {
          for (final int x in <int>[0, image.width - 1]) {
            final img.Pixel p = image.getPixel(x, y);
            sum += (p.r + p.g + p.b) / 3;
            count++;
          }
        }
        expect(sum / count, greaterThan(200), reason: '$file 边框非白底/中性底');
        sampled++;
      }
      expect(sampled, greaterThanOrEqualTo(12));
    });
  });
}

/// 轻量 JPEG 尺寸解析（SOF0–SOF15，跳过 EXIF 等段）。
(int, int) _jpegSize(Uint8List bytes) {
  int i = 2;
  while (i + 8 < bytes.length) {
    if (bytes[i] != 0xFF) {
      i++;
      continue;
    }
    final int marker = bytes[i + 1];
    if (marker == 0xD8 ||
        marker == 0x01 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final int length = (bytes[i + 2] << 8) | bytes[i + 3];
    if (marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC) {
      final int h = (bytes[i + 5] << 8) | bytes[i + 6];
      final int w = (bytes[i + 7] << 8) | bytes[i + 8];
      return (w, h);
    }
    i += 2 + length;
  }
  throw StateError('无法解析 JPEG 尺寸');
}
