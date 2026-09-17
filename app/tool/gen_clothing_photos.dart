import 'dart:convert';
import 'dart:io';

import 'asset_common.dart';

class _Category {
  const _Category(this.id, this.name, this.query);

  final String id;
  final String name;
  final String query;
}

const List<_Category> _categories = <_Category>[
  _Category('cloth-1', '正装', 'formal suit business'),
  _Category('cloth-2', '休闲', 'casual outfit street style'),
  _Category('cloth-3', '汉服', 'hanfu chinese traditional dress'),
  _Category('cloth-4', 'JK', 'japanese school uniform'),
  _Category('cloth-5', 'Lolita', 'lolita fashion dress'),
  _Category('cloth-6', 'Cos', 'cosplay costume'),
  _Category('cloth-7', '婚纱', 'wedding dress bride'),
  _Category('cloth-8', '民族', 'traditional ethnic clothing'),
  _Category('cloth-9', '运动', 'sportswear athletic'),
];

Future<void> main() async {
  final Map<String, Object?> config = readImageSources();
  final Map<String, Object?> pexels =
      ((config['pexels'] as Map?) ?? <String, Object?>{}).cast<String, Object?>();
  final String apiKey = '${pexels['apiKey'] ?? ''}'.trim();
  if (apiKey.isEmpty) {
    stderr.writeln('[clothing] assets/config/image_sources.json 缺少 pexels.apiKey');
    exitCode = 2;
    return;
  }
  final Net net = netFromConfig(config);
  final Directory root = Directory('assets/content/clothing/photo')
    ..createSync(recursive: true);

  final Set<int> usedIds = <int>{};
  final Set<String> keep = <String>{};
  final List<Map<String, Object?>> attribution = <Map<String, Object?>>[];
  final Map<String, List<Map<String, Object?>>> byCategory =
      <String, List<Map<String, Object?>>>{};
  final List<String> failures = <String>[];

  for (final _Category category in _categories) {
    final Directory dir = Directory('${root.path}/${category.id}')
      ..createSync(recursive: true);
    final List<PexelsPhoto> photos =
        await pexelsSearch(net, apiKey, category.query, perPage: 15);
    final List<Map<String, Object?>> picked = <Map<String, Object?>>[];
    for (final PexelsPhoto photo in photos) {
      if (picked.length >= 12) break;
      if (usedIds.contains(photo.id)) continue;
      final List<int>? jpeg =
          await fetchJpeg(net, photo.srcUrl, tag: '${category.id} ${category.name}');
      if (jpeg == null) continue;
      usedIds.add(photo.id);
      final String file = '${category.id}-${photo.id}.jpg';
      File('${dir.path}/$file').writeAsBytesSync(jpeg);
      keep.add('${category.id}/$file');
      picked.add(<String, Object?>{
        'file': file,
        'photographer': photo.photographer,
        'photoUrl': photo.photoUrl,
      });
      attribution.add(<String, Object?>{
        'file': 'assets/content/clothing/photo/${category.id}/$file',
        'name': '服装参考（${category.name}）',
        'source': photo.photoUrl,
        'license': 'Pexels License',
        'author': photo.photographer,
      });
    }
    if (picked.isEmpty) {
      failures.add('${category.id}:${category.name}');
      if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
    } else {
      byCategory[category.id] = picked;
    }
    stdout.writeln('[clothing] ${category.id} ${category.name}: ${picked.length}');
  }

  removeStaleTree(root, keep);

  final Map<String, Object?> out = <String, Object?>{
    'version': 1,
    'byCategory': byCategory,
  };
  File('assets/content/clothing/clothing_photos.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(out));
  mergeAttribution('assets/content/clothing/photo/', attribution);

  final int total = byCategory.values.fold<int>(
      0, (int a, List<Map<String, Object?>> v) => a + v.length);
  stdout.writeln('clothing_photos.json: total=$total '
      'categories=${byCategory.length}/${_categories.length}');
  if (failures.isNotEmpty) stdout.writeln('failures: ${failures.join(', ')}');
  net.close();
}
