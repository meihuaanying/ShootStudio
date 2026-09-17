import 'dart:convert';
import 'dart:io';

import 'asset_common.dart';

class _Kind {
  const _Kind(this.id, this.query);

  final String id;
  final String query;
}

class _Model {
  const _Model(this.name, this.query);

  final String name;
  final String query;
}

const List<_Kind> _kinds = <_Kind>[
  _Kind('camera', 'camera body dslr mirrorless'),
  _Kind('lens', 'camera lens closeup'),
  _Kind('light', 'studio strobe light softbox'),
  _Kind('accessory', 'tripod photography studio'),
  _Kind('flash', 'speedlight flash photography'),
];

const List<_Model> _models = <_Model>[
  _Model('佳能 EOS R5', 'Canon EOS R5 camera'),
  _Model('索尼 A7 IV', 'Sony A7 IV camera'),
  _Model('尼康 Z9', 'Nikon Z9 camera'),
  _Model('富士 X-T5', 'Fujifilm X-T5 camera'),
  _Model('佳能 RF 24-70mm F2.8L', 'Canon RF 24-70mm F2.8L lens'),
  _Model('索尼 FE 24-70mm F2.8 GM', 'Sony FE 24-70mm F2.8 GM lens'),
  _Model('神牛 AD200Pro', 'Godox AD200Pro flash'),
  _Model('神牛 SL60W', 'Godox SL60W light'),
  _Model('爱图仕 120D II', 'Aputure 120D II light'),
  _Model('爱图仕 300X', 'Aputure 300X light'),
  _Model('南冠 Forza 60B', 'Nanlite Forza 60B light'),
  _Model('曼富图 MT055', 'Manfrotto MT055 tripod'),
  _Model('神牛 S2 圆形柔光箱', 'Godox S2 softbox'),
  _Model('索尼 A7S III', 'Sony A7S III camera'),
  _Model('佳能 EOS R6 Mark II', 'Canon EOS R6 Mark II camera'),
];

Future<void> main() async {
  final Map<String, Object?> config = readImageSources();
  final Map<String, Object?> pexels =
      ((config['pexels'] as Map?) ?? <String, Object?>{}).cast<String, Object?>();
  final String apiKey = '${pexels['apiKey'] ?? ''}'.trim();
  if (apiKey.isEmpty) {
    stderr.writeln('[gear] assets/config/image_sources.json 缺少 pexels.apiKey');
    exitCode = 2;
    return;
  }
  final Net net = netFromConfig(config);
  final Directory dir = Directory('assets/content/gear/photo')
    ..createSync(recursive: true);

  final Set<int> usedIds = <int>{};
  final Set<String> keep = <String>{};
  final List<Map<String, Object?>> attribution = <Map<String, Object?>>[];
  final Map<String, List<Map<String, Object?>>> byKind =
      <String, List<Map<String, Object?>>>{};
  final Map<String, List<Map<String, Object?>>> byModel =
      <String, List<Map<String, Object?>>>{};
  final List<String> failures = <String>[];

  for (final _Kind kind in _kinds) {
    final List<PexelsPhoto> photos =
        await pexelsSearch(net, apiKey, kind.query, perPage: 15);
    final List<Map<String, Object?>> picked = <Map<String, Object?>>[];
    for (final PexelsPhoto photo in photos) {
      if (picked.length >= 6) break;
      if (usedIds.contains(photo.id)) continue;
      final List<int>? jpeg =
          await fetchJpeg(net, photo.srcUrl, tag: kind.id);
      if (jpeg == null) continue;
      usedIds.add(photo.id);
      final String file = '${kind.id}-${photo.id}.jpg';
      File('${dir.path}/$file').writeAsBytesSync(jpeg);
      keep.add(file);
      picked.add(<String, Object?>{
        'file': file,
        'photographer': photo.photographer,
        'photoUrl': photo.photoUrl,
      });
      attribution.add(<String, Object?>{
        'file': 'assets/content/gear/photo/$file',
        'name': '器材实拍（${kind.id}）',
        'source': photo.photoUrl,
        'license': 'Pexels License',
        'author': photo.photographer,
      });
    }
    byKind[kind.id] = picked;
    if (picked.isEmpty) failures.add('kind:${kind.id}');
    stdout.writeln('[gear] kind ${kind.id}: ${picked.length}');
  }

  for (int i = 0; i < _models.length; i++) {
    final _Model model = _models[i];
    final List<PexelsPhoto> photos =
        await pexelsSearch(net, apiKey, model.query, perPage: 8);
    List<Map<String, Object?>> picked = <Map<String, Object?>>[];
    for (final PexelsPhoto photo in photos) {
      if (usedIds.contains(photo.id)) continue;
      final List<int>? jpeg = await fetchJpeg(net, photo.srcUrl, tag: model.name);
      if (jpeg == null) continue;
      usedIds.add(photo.id);
      final String file = 'model-${i + 1}-${photo.id}.jpg';
      File('${dir.path}/$file').writeAsBytesSync(jpeg);
      keep.add(file);
      picked = <Map<String, Object?>>[
        <String, Object?>{
          'file': file,
          'photographer': photo.photographer,
          'photoUrl': photo.photoUrl,
        },
      ];
      attribution.add(<String, Object?>{
        'file': 'assets/content/gear/photo/$file',
        'name': '器材实拍（${model.name}）',
        'source': photo.photoUrl,
        'license': 'Pexels License',
        'author': photo.photographer,
      });
      break;
    }
    if (picked.isEmpty) failures.add('model:${model.name}');
    else byModel[model.name] = picked;
    stdout.writeln('[gear] model ${model.name}: ${picked.length}');
  }

  removeStaleTree(dir, keep);

  final Map<String, Object?> out = <String, Object?>{
    'version': 1,
    'byKind': byKind,
    'byModel': byModel,
    'note': 'Pexels 氛围实拍，非官方产品图',
  };
  File('assets/content/gear/gear_photos.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(out));
  mergeAttribution('assets/content/gear/photo/', attribution);

  final int kindTotal = byKind.values.fold<int>(
      0, (int a, List<Map<String, Object?>> v) => a + v.length);
  final int modelTotal = byModel.values.fold<int>(
      0, (int a, List<Map<String, Object?>> v) => a + v.length);
  stdout.writeln('gear_photos.json: total=${kindTotal + modelTotal} '
      'byKind=${byKind.length} byModel=${byModel.length}');
  if (failures.isNotEmpty) stdout.writeln('failures: ${failures.join(', ')}');
  net.close();
}
