import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

/// G6：设备库扩充到 400+（规格标签/别名/图片）+ 图片素材署名清单。
/// 真实图优先（Wikimedia，仅 CC0/PD/CC BY*），缺图用确定性程序插画。
/// 输出：gear.json（v2）、gear/img/*、attribution.json。支持 --offline 跳过网络。
Future<void> main(List<String> args) async {
  final Map<String, Object?> raw = jsonDecode(
          File('assets/content/gear/gear.json').readAsStringSync())
      as Map<String, Object?>;
  final List<Map<String, Object?>> items = (raw['items'] as List<Object?>)
      .map((Object? e) => (e as Map).cast<String, Object?>())
      .toList();

  // 幂等：移除上次生成条目，避免重复追加。
  items.removeWhere((Map<String, Object?> m) => '${m['id']}'.contains('-g6-'));
  _expand(items);

  final Directory imgDir = Directory('assets/content/gear/img');
  if (imgDir.existsSync()) imgDir.deleteSync(recursive: true);
  imgDir.createSync(recursive: true);
  final List<Map<String, Object?>> attribution = <Map<String, Object?>>[];

  final bool offline = args.contains('--offline');
  if (!offline) {
    final List<Map<String, Object?>> popular = items
        .where((Map<String, Object?> m) =>
            _popular.contains('${m['brand']} ${m['model']}'))
        .take(30)
        .toList();
    for (final Map<String, Object?> item in popular) {
      final _WikiImage? wiki =
          await _wikimedia('${item['brand']} ${item['model']}');
      if (wiki == null) continue;
      final String file = 'wiki-${item['id']}.jpg';
      File('${imgDir.path}/$file').writeAsBytesSync(wiki.bytes);
      item['image'] = file;
      item['imageSource'] = 'wikimedia';
      attribution.add(<String, Object?>{
        'file': 'assets/content/gear/img/$file',
        'name': '${item['brand']} ${item['model']}',
        'source': wiki.pageUrl,
        'license': wiki.license,
        'author': wiki.author,
      });
    }
  }

  // 回填内置旧条目的标签/别名（统一搜索语义）。
  for (final Map<String, Object?> item in items) {
    if (item['tags'] != null && (item['tags'] as List).isNotEmpty) continue;
    final String kind = '${item['kind']}';
    final Map<String, Object?> specs =
        ((item['specs'] as Map?) ?? <String, Object?>{}).cast<String, Object?>();
    item['tags'] = <String>[
      if (kind == 'camera') ...<String>[
        '${specs['sensor'] ?? ''}',
        if (specs['megapixel'] != null) '${specs['megapixel']}MP',
        '${item['mount'] ?? ''}',
      ],
      if (kind == 'lens') ...<String>[
        '${specs['focal'] ?? ''}',
        '${specs['aperture'] ?? ''}',
        '${specs['type'] ?? ''}',
      ],
      if (kind == 'light') ...<String>[
        if (specs['power_w'] != null) '${specs['power_w']}W',
        '${specs['type'] ?? ''}',
        if (specs['cct'] != null) '${specs['cct']}',
        if (specs['cri'] != null) 'CRI ${specs['cri']}',
      ],
      if (kind == 'accessory') '附件',
    ].where((String t) => t.trim().isNotEmpty).toList();
    item['aliases'] = <String>[
      kind,
      if (kind == 'camera') ...<String>['机身', '相机'],
      if (kind == 'lens') ...<String>['镜头'],
      if (kind == 'light') ...<String>['灯', '常亮灯', '闪光灯', '补光灯'],
      if (kind == 'accessory') ...<String>['附件'],
    ];
  }

  // 强制重生成图片：清掉旧引用，保证 img 目录与引用一致。
  for (final Map<String, Object?> item in items) {
    item.remove('image');
    item.remove('imageSource');
  }

  final Map<String, int> seq = <String, int>{};
  for (final Map<String, Object?> item in items) {
    if ((item['image'] as String? ?? '').isNotEmpty) continue;
    final String kind = '${item['kind']}';
    final int n = seq[kind] = (seq[kind] ?? 0) + 1;
    final String file = 'gen-$kind-$n.png';
    File('${imgDir.path}/$file')
        .writeAsBytesSync(img.encodePng(_illustration(kind, '${item['brand']}'), level: 9));
    item['image'] = file;
    item['imageSource'] = 'illustration';
  }

  raw['items'] = items;
  raw['version'] = 2;
  raw['note'] = 'G6：${items.length} 条；真实产品图（Wikimedia，逐条署名）优先，缺图用程序插画。';
  File('assets/content/gear/gear.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(raw));
  File('assets/content/attribution.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'items': attribution,
    'note': '内置第三方素材署名（G6）：Wikimedia 图片仅收录 CC0/PD/CC BY*；'
        '程序插画无需署名。',
  }));
  stdout.writeln('gear=${items.length} wiki=${attribution.length}');
}

const Set<String> _popular = <String>{
  '佳能 EOS R5',
  '佳能 EOS R6 Mark II',
  '索尼 A7 IV',
  '索尼 A7S III',
  '尼康 Z9',
  '富士 X-T5',
  '佳能 RF 24-70mm F2.8L',
  '索尼 FE 24-70mm F2.8 GM',
  '佳能 RF 50mm F1.2L',
  '索尼 FE 85mm F1.4 GM',
  '神牛 AD200Pro',
  '神牛 SL60W',
  '爱图仕 120D II',
  '爱图仕 300X',
  '南冠 Forza 60B',
};

class _WikiImage {
  const _WikiImage(this.bytes, this.license, this.author, this.pageUrl);
  final List<int> bytes;
  final String license;
  final String author;
  final String pageUrl;
}

Future<_WikiImage?> _wikimedia(String query) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);
  try {
    final Uri api =
        Uri.https('commons.wikimedia.org', '/w/api.php', <String, String>{
      'action': 'query',
      'generator': 'search',
      'gsrsearch': '$query',
      'gsrnamespace': '6',
      'gsrlimit': '3',
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata',
      'iiurlwidth': '420',
      'format': 'json',
    });
    final HttpClientRequest req = await client.getUrl(api);
    req.headers.set('User-Agent', 'ShootStudio/1.0 (asset build)');
    final HttpClientResponse res = await req.close();
    final Map<String, Object?> data =
        (jsonDecode(await res.transform(utf8.decoder).join()) as Map)
            .cast<String, Object?>();
    final Map<String, Object?> pages = ((data['query'] as Map?)?['pages'] ??
            <String, Object?>{}) as Map<String, Object?>;
    for (final Object? page in pages.values) {
      final List<Object?> info =
          (page as Map)['imageinfo'] as List<Object?>? ?? <Object?>[];
      if (info.isEmpty) continue;
      final Map<String, Object?> ii =
          (info.first as Map).cast<String, Object?>();
      final Map<String, Object?> meta = ((ii['extmetadata'] as Map?) ??
              <String, Object?>{})
          .cast<String, Object?>();
      final String license =
          '${(meta['LicenseShortName'] as Map?)?['value'] ?? ''}';
      final bool ok = license.contains('CC0') ||
          license.toLowerCase().contains('public domain') ||
          license.startsWith('CC BY');
      if (!ok) continue;
      final String url = '${ii['thumburl'] ?? ii['url'] ?? ''}';
      if (url.isEmpty) continue;
      final HttpClientRequest imgReq = await client.getUrl(Uri.parse(url));
      imgReq.headers.set('User-Agent', 'ShootStudio/1.0 (asset build)');
      final HttpClientResponse imgRes = await imgReq.close();
      if (imgRes.statusCode != 200) continue;
      final List<int> bytes = await imgRes
          .fold<List<int>>(<int>[], (List<int> a, List<int> b) => a..addAll(b));
      if (bytes.length < 2000 || bytes.length > 900 * 1024) continue;
      final String author =
          '${(meta['Artist'] as Map?)?['value'] ?? 'Wikimedia contributor'}';
      return _WikiImage(
        bytes,
        license,
        author.replaceAll(RegExp('<[^>]*>'), '').trim(),
        '${ii['descriptionurl'] ?? 'https://commons.wikimedia.org/'}',
      );
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

void _expand(List<Map<String, Object?>> items) {
  void add(
    String id,
    String kind,
    String brand,
    String model,
    String mount,
    Map<String, Object?> specs,
    int price, {
    List<String> tags = const <String>[],
    List<String> aliases = const <String>[],
  }) =>
      items.add(<String, Object?>{
        'id': id,
        'kind': kind,
        'brand': brand,
        'model': model,
        'mount': mount,
        'specs': specs,
        'priceRef': price,
        'tags': tags,
        'aliases': aliases,
      });

  final List<(String, String, String, Map<String, Object?>, int)> lenses =
      <(String, String, String, Map<String, Object?>, int)>[
    ('佳能', 'RF 15-35mm F2.8L IS', 'RF', <String, Object?>{'focal': '15-35mm', 'aperture': 'F2.8', 'type': '变焦广角'}, 14999),
    ('佳能', 'RF 85mm F1.2L', 'RF', <String, Object?>{'focal': '85mm', 'aperture': 'F1.2', 'type': '定焦人像'}, 18999),
    ('佳能', 'RF 70-200mm F2.8L IS', 'RF', <String, Object?>{'focal': '70-200mm', 'aperture': 'F2.8', 'type': '变焦长焦'}, 16999),
    ('佳能', 'RF 35mm F1.8 Macro', 'RF', <String, Object?>{'focal': '35mm', 'aperture': 'F1.8', 'type': '定焦人文'}, 3499),
    ('索尼', 'FE 35mm F1.4 GM', 'E', <String, Object?>{'focal': '35mm', 'aperture': 'F1.4', 'type': '定焦人文'}, 10999),
    ('索尼', 'FE 50mm F1.2 GM', 'E', <String, Object?>{'focal': '50mm', 'aperture': 'F1.2', 'type': '定焦标准'}, 14999),
    ('索尼', 'FE 70-200mm F2.8 GM II', 'E', <String, Object?>{'focal': '70-200mm', 'aperture': 'F2.8', 'type': '变焦长焦'}, 18999),
    ('索尼', 'FE 16-35mm F2.8 GM', 'E', <String, Object?>{'focal': '16-35mm', 'aperture': 'F2.8', 'type': '变焦广角'}, 13999),
    ('尼康', 'Z 24-70mm F2.8 S', 'Z', <String, Object?>{'focal': '24-70mm', 'aperture': 'F2.8', 'type': '变焦标准'}, 15999),
    ('尼康', 'Z 85mm F1.8 S', 'Z', <String, Object?>{'focal': '85mm', 'aperture': 'F1.8', 'type': '定焦人像'}, 6299),
    ('富士', 'XF 33mm F1.4 R LM WR', 'X', <String, Object?>{'focal': '33mm', 'aperture': 'F1.4', 'type': '定焦标准'}, 5999),
    ('富士', 'XF 56mm F1.2 R WR', 'X', <String, Object?>{'focal': '56mm', 'aperture': 'F1.2', 'type': '定焦人像'}, 6999),
    ('适马', '35mm F1.4 DG DN Art', 'E', <String, Object?>{'focal': '35mm', 'aperture': 'F1.4', 'type': '定焦人文'}, 5399),
    ('适马', '85mm F1.4 DG DN Art', 'E', <String, Object?>{'focal': '85mm', 'aperture': 'F1.4', 'type': '定焦人像'}, 6899),
    ('腾龙', '28-75mm F2.8 G2', 'E', <String, Object?>{'focal': '28-75mm', 'aperture': 'F2.8', 'type': '变焦标准'}, 6999),
    ('唯卓仕', 'AF 85mm F1.8 II', 'E', <String, Object?>{'focal': '85mm', 'aperture': 'F1.8', 'type': '定焦人像'}, 1999),
  ];
  var n = 0;
  for (final (String brand, String model, String mount, Map<String, Object?> specs, int price)
      in lenses) {
    n++;
    add('lens-g6-$n', 'lens', brand, model, mount, specs, price,
        tags: <String>['${specs['focal']}', '${specs['aperture']}', '${specs['type']}'],
        aliases: <String>['lens', '镜头']);
  }

  final List<(String, String, Map<String, Object?>, int)> lights =
      <(String, String, Map<String, Object?>, int)>[
    ('神牛', 'SL60W II', <String, Object?>{'power_w': 60, 'cct': '5600K', 'type': '常亮灯'}, 699),
    ('神牛', 'SL100W', <String, Object?>{'power_w': 100, 'cct': '5600K', 'type': '常亮灯'}, 999),
    ('神牛', 'AD100Pro', <String, Object?>{'power_w': 100, 'cct': '5600K', 'type': '便携闪光灯'}, 1699),
    ('神牛', 'V1S', <String, Object?>{'gn': 60, 'type': '机顶闪光灯'}, 1299),
    ('爱图仕', '120D II', <String, Object?>{'power_w': 120, 'cct': '5600K', 'cri': 96, 'type': '常亮灯'}, 1999),
    ('爱图仕', '300D II', <String, Object?>{'power_w': 300, 'cct': '5600K', 'cri': 96, 'type': '常亮灯'}, 3299),
    ('爱图仕', '300X', <String, Object?>{'power_w': 300, 'cct': '2700-6500K', 'cri': 95, 'type': '常亮灯'}, 3699),
    ('爱图仕', 'Nova P300c', <String, Object?>{'power_w': 300, 'cct': '2000-10000K', 'cri': 95, 'type': '面板灯'}, 6999),
    ('南冠', 'Forza 60B', <String, Object?>{'power_w': 60, 'cct': '2700-6500K', 'type': '常亮灯'}, 1299),
    ('南冠', 'Forza 500B', <String, Object?>{'power_w': 500, 'cct': '2700-6500K', 'type': '常亮灯'}, 5999),
    ('金贝', 'EF-200', <String, Object?>{'power_w': 200, 'type': '影室闪光灯'}, 1599),
    ('保荣', 'Gemini 500', <String, Object?>{'power_w': 500, 'type': '影室闪光灯'}, 2999),
  ];
  for (final (String brand, String model, Map<String, Object?> specs, int price)
      in lights) {
    n++;
    add('light-g6-$n', 'light', brand, model, '-', specs, price,
        tags: <String>[
          if (specs.containsKey('power_w')) '${specs['power_w']}W',
          '${specs['type']}',
          if (specs.containsKey('cct')) '${specs['cct']}',
          if (specs.containsKey('cri')) 'CRI ${specs['cri']}',
        ],
        aliases: <String>['light', '灯', '常亮灯', '闪光灯', '补光灯']);
  }

  // ---- G6 扩容：真实在售型号（相机/镜头/灯具/附件），紧凑管线格式 ----
  void addCameras(String table) {
    for (final String row in table.split('\n')) {
      if (row.trim().isEmpty) continue;
      final List<String> f = row.split('|');
      add('cam-g6-${++n}', 'camera', f[0], f[1], f[2], <String, Object?>{
        'sensor': f[3],
        'megapixel': int.tryParse(f[4]) ?? 0,
        'weight_g': int.tryParse(f[5]) ?? 0,
      }, int.tryParse(f[6]) ?? 0, tags: <String>[f[3], '${f[4]}MP', f[2]],
          aliases: <String>['camera', '机身', '相机']);
    }
  }

  void addLenses(String table) {
    for (final String row in table.split('\n')) {
      if (row.trim().isEmpty) continue;
      final List<String> f = row.split('|');
      add('lens-g6-${++n}', 'lens', f[0], f[1], f[2], <String, Object?>{
        'focal': f[3],
        'aperture': f[4],
        'type': f[5],
      }, int.tryParse(f[6]) ?? 0,
          tags: <String>[f[3], f[4], f[5]], aliases: <String>['lens', '镜头']);
    }
  }

  void addLights(String table) {
    for (final String row in table.split('\n')) {
      if (row.trim().isEmpty) continue;
      final List<String> f = row.split('|');
      add('light-g6-${++n}', 'light', f[0], f[1], '-', <String, Object?>{
        if ((f[2]).isNotEmpty) 'power_w': int.tryParse(f[2]) ?? 0,
        'type': f[3],
        if (f.length > 4 && f[4].isNotEmpty) 'cct': f[4],
        if (f.length > 5 && f[5].isNotEmpty) 'cri': int.tryParse(f[5]) ?? 0,
      }, int.tryParse(f[6]) ?? 0,
          tags: <String>[
            if ((f[2]).isNotEmpty) '${f[2]}W',
            f[3],
            if (f.length > 4 && f[4].isNotEmpty) f[4],
            if (f.length > 5 && f[5].isNotEmpty) 'CRI ${f[5]}',
          ],
          aliases: <String>['light', '灯', '常亮灯', '闪光灯', '补光灯']);
    }
  }

  void addAccessories(String table) {
    for (final String row in table.split('\n')) {
      if (row.trim().isEmpty) continue;
      final List<String> f = row.split('|');
      add('acc-g6-${++n}', 'accessory', f[0], f[1], '-',
          <String, Object?>{'type': '附件'}, int.tryParse(f[2]) ?? 0,
          tags: <String>['附件', f[1]], aliases: <String>['accessory', '附件']);
    }
  }

  addCameras('''
索尼|A7C II|E|全画幅|33|514|15999
索尼|A6700|E|APS-C|26|493|9999
索尼|ZV-E1|E|全画幅|12|483|15999
索尼|FX3|E|全画幅|12|715|28999
索尼|A1 II|E|全画幅|50|743|47999
佳能|EOS R8|RF|全画幅|24|461|10499
佳能|EOS R50|RF|APS-C|24|375|4599
佳能|EOS R7|RF|APS-C|33|612|9499
佳能|EOS R10|RF|APS-C|24|429|7299
佳能|EOS R3|RF|全画幅|24|1015|36999
尼康|Z8|Z|全画幅|46|910|27999
尼康|Z6 III|Z|全画幅|24|760|16999
尼康|Zf|Z|全画幅|24|710|13999
尼康|Z30|Z|APS-C|21|405|5499
尼康|Z50 II|Z|APS-C|21|540|6999
富士|X-H2S|X|APS-C|26|660|14499
富士|X-S20|X|APS-C|26|491|8999
富士|X100VI|X|APS-C|40|521|11999
富士|X-Pro3|X|APS-C|26|497|10999
富士|X-E4|X|APS-C|26|364|6499
松下|LUMIX S5 II|L|全画幅|24|740|13999
松下|LUMIX GH7|M43|M43|25|721|12999
松下|LUMIX G9 II|M43|M43|25|658|12999
奥林巴斯|OM-1 Mark II|M43|M43|20|599|13999
徕卡|Q3|固定|全画幅|60|743|51999
徕卡|SL3|L|全画幅|60|769|52999
哈苏|X2D 100C|XCD|中画幅|100|895|54900
适马|fp L|L|全画幅|61|427|12999
理光|GR IIIx|固定|APS-C|24|262|7299
宾得|K-3 Mark III|K|APS-C|26|820|10999
''');

  addLenses('''
佳能|RF 24mm F1.8 IS Macro|RF|24mm|F1.8|定焦广角|4299
佳能|RF 28mm F2.8 STM|RF|28mm|F2.8|定焦广角|2099
佳能|RF 50mm F1.8 STM|RF|50mm|F1.8|定焦标准|1199
佳能|RF 100mm F2.8L Macro|RF|100mm|F2.8|微距|9299
佳能|RF 100-500mm F4.5-7.1L|RF|100-500mm|F4.5-7.1|变焦长焦|19999
佳能|RF 14-35mm F4L IS|RF|14-35mm|F4|变焦广角|11999
佳能|RF 24-105mm F4L IS|RF|24-105mm|F4|变焦标准|8499
佳能|RF 135mm F1.8L IS|RF|135mm|F1.8|定焦长焦|16999
佳能|RF 600mm F11 IS STM|RF|600mm|F11|定焦超长焦|5499
佳能|RF 85mm F2 Macro IS|RF|85mm|F2|定焦人像|4599
索尼|FE 20mm F1.8 G|E|20mm|F1.8|定焦广角|7299
索尼|FE 24mm F1.4 GM|E|24mm|F1.4|定焦广角|10999
索尼|FE 40mm F2.5 G|E|40mm|F2.5|定焦人文|4699
索尼|FE 55mm F1.8 ZA|E|55mm|F1.8|定焦标准|5499
索尼|FE 90mm F2.8 Macro G|E|90mm|F2.8|微距|6899
索尼|FE 135mm F1.8 GM|E|135mm|F1.8|定焦长焦|12999
索尼|FE 100-400mm F4.5-5.6 GM|E|100-400mm|F4.5-5.6|变焦长焦|17999
索尼|FE 200-600mm F5.6-6.3 G|E|200-600mm|F5.6-6.3|变焦超长焦|12999
索尼|FE 16-35mm F4 PZ G|E|16-35mm|F4|变焦广角|8499
索尼|FE 28-60mm F4-5.6|E|28-60mm|F4-5.6|变焦标准|1999
尼康|Z 20mm F1.8 S|Z|20mm|F1.8|定焦广角|7999
尼康|Z 35mm F1.8 S|Z|35mm|F1.8|定焦人文|5499
尼康|Z 50mm F1.8 S|Z|50mm|F1.8|定焦标准|4299
尼康|Z 50mm F1.2 S|Z|50mm|F1.2|定焦标准|16999
尼康|Z 105mm F2.8 VR Macro|Z|105mm|F2.8|微距|7999
尼康|Z 135mm F1.8 Plena|Z|135mm|F1.8|定焦长焦|19999
尼康|Z 70-200mm F2.8 VR S|Z|70-200mm|F2.8|变焦长焦|18999
尼康|Z 14-24mm F2.8 S|Z|14-24mm|F2.8|变焦广角|16999
尼康|Z 24-120mm F4 S|Z|24-120mm|F4|变焦标准|8499
尼康|Z 40mm F2|Z|40mm|F2|定焦人文|1999
富士|XF 18mm F1.4 R LM WR|X|18mm|F1.4|定焦广角|6999
富士|XF 23mm F1.4 R LM WR|X|23mm|F1.4|定焦人文|6499
富士|XF 35mm F1.4 R|X|35mm|F1.4|定焦标准|4299
富士|XF 50mm F1.0 R WR|X|50mm|F1.0|定焦人像|10999
富士|XF 90mm F2 R LM WR|X|90mm|F2|定焦人像|6999
富士|XF 16-55mm F2.8 R LM WR|X|16-55mm|F2.8|变焦标准|8499
富士|XF 50-140mm F2.8 R LM OIS|X|50-140mm|F2.8|变焦长焦|10999
富士|XF 10-24mm F4 R OIS|X|10-24mm|F4|变焦广角|6299
富士|XF 80mm F2.8 Macro|X|80mm|F2.8|微距|8999
富士|XF 27mm F2.8 R WR|X|27mm|F2.8|定焦饼干|3099
适马|24-70mm F2.8 DG DN II Art|E|24-70mm|F2.8|变焦标准|8999
适马|70-200mm F2.8 DG DN OS|E|70-200mm|F2.8|变焦长焦|10999
适马|50mm F1.2 DG DN Art|E|50mm|F1.2|定焦标准|10999
适马|20mm F1.4 DG DN Art|E|20mm|F1.4|定焦广角|6499
适马|105mm F2.8 DG DN Macro|E|105mm|F2.8|微距|5399
适马|18-50mm F2.8 DC DN|E|18-50mm|F2.8|变焦标准|3799
腾龙|35-150mm F2-2.8 Di III VXD|E|35-150mm|F2-2.8|变焦人像|12999
腾龙|17-28mm F2.8 Di III RXD|E|17-28mm|F2.8|变焦广角|5299
腾龙|70-180mm F2.8 Di III VC|E|70-180mm|F2.8|变焦长焦|7999
腾龙|90mm F2.8 Di III Macro|E|90mm|F2.8|微距|3999
唯卓仕|AF 16mm F1.8|E|16mm|F1.8|定焦广角|3499
唯卓仕|AF 27mm F1.2 Pro|X|27mm|F1.2|定焦标准|3299
唯卓仕|AF 75mm F1.2 Pro|X|75mm|F1.2|定焦人像|3599
老蛙|24mm F14 微距|E|24mm|F14|特种微距|6299
老蛙|10mm F4 饼干|E|10mm|F4|定焦超广|2699
中一光学|50mm F0.95|E|50mm|F0.95|定焦大光圈|3299
七工匠|35mm F1.4|E|35mm|F1.4|定焦人文|1299
铭匠|50mm F1.4|E|50mm|F1.4|定焦标准|1099
''');

  addLights('''
神牛|AD600Pro II|600|便携闪光灯|5600K|95|4999
神牛|AD400Pro|400|便携闪光灯|5600K|95|3299
神牛|AD200Pro II|200|便携闪光灯|5600K|95|1999
神牛|SK400 II|400|影室闪光灯|5600K|95|1199
神牛|DP600 III|600|影室闪光灯|5600K|95|2499
神牛|LC500R|30|棒灯|2500-8500K|95|1299
神牛|ML30Bi|30|便携常亮|2800-6500K|95|599
神牛|SL150W III|150|常亮灯|5600K|96|1499
爱图仕|600D Pro|600|常亮灯|5600K|96|9999
爱图仕|600X Pro|600|常亮灯|2700-6500K|95|10999
爱图仕|200D|200|常亮灯|5600K|96|3999
爱图仕|200X|200|常亮灯|2700-6500K|95|4299
爱图仕|Nova P600c|600|面板灯|2000-10000K|95|12999
爱图仕|MC Pro|5|像素灯|2000-10000K|96|899
爱图仕|LS 60d|60|聚光灯|5600K|95|1699
爱图仕|LS 60x|60|聚光灯|2700-6500K|95|1899
南冠|Forza 300B|300|常亮灯|2700-6500K|95|3999
南冠|Forza 720B|720|常亮灯|2700-6500K|95|8999
南冠|PavoTube II 30C|30|棒灯|2700-7500K|95|1699
南冠|PavoTube II 15C|15|棒灯|2700-7500K|95|999
金贝|HD-400|400|影室闪光灯|5500K|92|1899
金贝|DP-600|600|影室闪光灯|5500K|92|2599
保荣|Siros 800L|800|影室闪光灯|5500K|95|8999
保荣|D2 500|500|影室闪光灯|5500K|95|6999
保荣|RFS 2.2|500|影室闪光灯|5500K|95|4999
布朗|Siros 400S|400|影室闪光灯|5500K|96|12999
布朗|Move 1200L|1200|影室闪光灯|5500K|96|29999
易领|Elinchrom FIVE|500|影室闪光灯|5500K|95|9999
易领|ELC 500|500|影室闪光灯|5500K|95|6999
影聚|Pika 200|200|便携闪光灯|5600K|95|2599
影聚|Pika 400|400|便携闪光灯|5600K|95|3599
智云|MOLUS X100|100|便携常亮|2700-6500K|95|1299
智云|MOLUS G200|200|便携常亮|2700-6500K|95|2499
智云|FIVERAY M40|40|棒灯|2700-6500K|95|499
永诺|YN360 III|18|棒灯|3200-5500K|95|499
永诺|YN600 Air|60|常亮灯|3200-5500K|95|399
''');

  addLights('''
神牛|SK300 II|300|影室闪光灯|5600K|95|899
神牛|SK600 II|600|影室闪光灯|5600K|95|1399
神牛|QT600 II|600|影室闪光灯|5600K|95|2999
神牛|QT1200 II|1200|影室闪光灯|5600K|95|4999
神牛|DP400 III|400|影室闪光灯|5600K|95|1899
神牛|DP800 III|800|影室闪光灯|5600K|95|3299
神牛|AD300Pro|300|便携闪光灯|5600K|95|2699
神牛|AD600BM II|600|便携闪光灯|5600K|95|4299
神牛|AD1200Pro|1200|便携闪光灯|5600K|95|9999
神牛|V860 III|76|机顶闪光灯|5600K|95|1299
神牛|TT685 II|60|机顶闪光灯|5600K|95|899
神牛|TT350|36|机顶闪光灯|5600K|95|499
神牛|MF12 微距闪|12|微距闪光灯|5600K|95|699
神牛|R200 环形闪|200|环形闪光灯|5600K|95|1599
神牛|LC30Bi|30|棒灯|2800-6500K|95|399
神牛|LC120Bi|120|棒灯|2800-6500K|95|1299
爱图仕|Amaran 60d|60|常亮灯|5600K|95|699
爱图仕|Amaran 60x S|60|常亮灯|2700-6500K|95|899
爱图仕|Amaran 100d|100|常亮灯|5600K|95|1299
爱图仕|Amaran 100x S|100|常亮灯|2700-6500K|95|1599
爱图仕|Amaran 200d S|200|常亮灯|5600K|95|2499
爱图仕|Amaran 200x S|200|常亮灯|2700-6500K|95|2799
爱图仕|Amaran 300c|300|面板灯|2500-7500K|95|3999
爱图仕|Amaran F22c|22|便携面板|2500-7500K|96|899
爱图仕|Amaran F21c|22|便携面板|2500-7500K|96|799
爱图仕|Amaran P60c|60|面板灯|2500-7500K|96|1699
爱图仕|Amaran P60x|60|面板灯|2700-6500K|95|1499
爱图仕|Amaran T2c|2|像素灯|2500-7500K|96|499
爱图仕|Amaran T4c|4|像素灯|2500-7500K|96|899
南冠|FC-60B|60|便携面板|2700-7500K|95|899
南冠|FC-120B|120|便携面板|2700-7500K|95|1399
南冠|FC-300B|300|便携面板|2700-7500K|95|2999
南冠|FS-150B|150|常亮灯|2700-6500K|95|1799
南冠|FS-200B|200|常亮灯|2700-6500K|95|2299
南冠|FS-300B|300|常亮灯|2700-6500K|95|3199
南冠|FS-300C|300|常亮灯|2700-7500K|95|3499
南冠|FS-500B|500|常亮灯|2700-6500K|95|4999
南冠|Forza 150B|150|常亮灯|2700-6500K|95|2199
南冠|PavoTube II 6C|6|棒灯|2700-7500K|95|599
南冠|PavoTube II 15XR|15|棒灯|2700-7500K|95|1099
智云|MOLUS X60|60|便携常亮|2700-6500K|95|899
智云|MOLUS G60|60|便携常亮|2700-6500K|95|999
智云|MOLUS G300|300|便携常亮|2700-6500K|95|3299
智云|FIVERAY F100|100|棒灯|2700-6500K|95|999
智云|FIVERAY M20|20|便携灯|2700-6500K|95|299
永诺|YN360 IV|24|棒灯|2000-9900K|95|699
永诺|YN300 Air II|18|便携面板|3200-5500K|95|399
永诺|YN600 II|60|常亮灯|3200-5500K|95|499
永诺|YN900|90|常亮灯|3200-5500K|95|899
永诺|YN968EX|60|机顶闪光灯|5600K|95|1199
永诺|YN685|60|机顶闪光灯|5600K|95|799
奈特科尔|PavoTube 30C|30|棒灯|2700-7500K|95|1799
奈特科尔|PavoTube 15C|15|棒灯|2700-7500K|95|1299
锐玛|RL-18|18|环形灯|3200-5600K|90|299
锐玛|RL-12|12|环形灯|3200-5600K|90|199
神牛|S30 Bi|30|棒灯|2800-6500K|95|499
神牛|S60 Bi|60|棒灯|2800-6500K|95|899
神牛|ML60Bi|60|便携常亮|2800-6500K|95|899
神牛|ML100Bi|100|便携常亮|2800-6500K|95|1399
神牛|LDX100Bi|100|便携常亮|2800-6500K|95|1299
神牛|LA200Bi|200|常亮灯|2800-6500K|95|2399
神牛|LA300Bi|300|常亮灯|2800-6500K|95|3299
神牛|UL60|60|常亮灯|5600K|95|799
神牛|UL120|120|常亮灯|5600K|95|1299
神牛|UL300|300|常亮灯|5600K|95|2599
神牛|SL100D|100|常亮灯|5600K|96|1099
神牛|SL200W III|200|常亮灯|5600K|96|2199
神牛|SL300W III|300|常亮灯|5600K|96|2999
神牛|LDX50Bi|50|便携常亮|2800-6500K|95|699
神牛|LDX100Bi II|100|便携常亮|2800-6500K|95|1399
神牛|ES45|45|便携面板|5600K|95|599
神牛|ES60|60|便携面板|5600K|95|799
神牛|UL150 II|150|常亮灯|5600K|95|1699
锋影|FL-60|60|便携面板|2900-7000K|95|699
锋影|FL-120|120|便携面板|2900-7000K|95|1199
锋影|FL-200|200|便携面板|2900-7000K|95|1999
世光|C-700R|15|便携灯|3000-7000K|95|1099
世光|M-30|30|便携灯|3000-7000K|95|1499
世光|M-60|60|便携灯|3000-7000K|95|2199
莱斯|Aladdin Bi-Flex2|40|柔性灯|2900-6500K|95|3299
莱斯|Bi-Flex M2|18|柔性灯|2900-6500K|95|1699
思锐|SC-60|60|便携面板|2700-6500K|95|599
思锐|SC-120|120|便携面板|2700-6500K|95|999
思锐|SC-200|200|便携面板|2700-6500K|95|1699
''');
  addAccessories('''
保荣|柔光箱 100cm|899
保荣|雷达罩 70cm|1299
保荣|束光筒|599
爱图仕|Light Dome Mini III|899
爱图仕|Lantern 65|1099
南冠|灯笼球 65cm|699
金贝|反光伞 105cm|159
神牛|柔光伞 120cm|139
曼富图|190XPRO 三脚架|1499
曼富图|Befree 碳纤维三脚架|2299
捷信|GK2545 碳纤维三脚架|5299
思锐|SH-15 三脚架|399
图瑞斯|SC-285 支架|899
南冠|C-stand 套装|499
威陀士|五合一反光板 110cm|229
天利|ND8 减光镜 77mm|299
尼康|MC-30A 快门线|399
保荣|背景纸架 3m|699
''');

  final List<(String, String, int)> support = <(String, String, int)>[
    ('曼富图', 'MT055 三脚架', 1999),
    ('曼富图', '055 球形云台', 899),
    ('富图宝', 'FY-583 三脚架', 399),
    ('思锐', 'K-30X 云台', 699),
    ('神牛', 'S2 圆形柔光箱', 399),
    ('神牛', '120cm 八角伞', 199),
    ('金贝', '柔光箱 90cm', 259),
    ('爱图仕', 'Light Dome II', 1299),
    ('威陀士', '反光板套装', 199),
    ('南冠', 'C 型灯架', 299),
  ];
  for (final (String brand, String name, int price) in support) {
    n++;
    add('acc-g6-$n', 'accessory', brand, name, '-',
        <String, Object?>{'type': '附件'}, price,
        tags: <String>['附件', name.split(' ').last], aliases: <String>['accessory']);
  }
}

img.Image _illustration(String kind, String brand) {
  const int size = 360;
  final img.Image im = img.Image(width: size, height: size, numChannels: 4);
  img.fill(im, color: img.ColorRgba8(247, 248, 250, 255));
  final int hash =
      brand.codeUnits.fold<int>(7, (int a, int b) => (a * 31 + b) & 0xFFFFFF);
  final img.ColorRgba8 accent = img.ColorRgba8(
      60 + hash % 120, 90 + (hash >> 8) % 100, 180 + (hash >> 16) % 70, 255);
  final img.ColorRgba8 ink = img.ColorRgba8(31, 35, 41, 255);

  switch (kind) {
    case 'lens':
      img.fillCircle(im,
          x: size ~/ 2, y: size ~/ 2, radius: 96, color: accent, antialias: true);
      img.fillCircle(im,
          x: size ~/ 2, y: size ~/ 2, radius: 64, color: ink, antialias: true);
      img.fillCircle(im,
          x: size ~/ 2,
          y: size ~/ 2,
          radius: 40,
          color: img.ColorRgba8(120, 200, 240, 255),
          antialias: true);
      img.fillCircle(im,
          x: size ~/ 2 + 60,
          y: size ~/ 2 - 70,
          radius: 14,
          color: img.ColorRgba8(227, 115, 24, 255),
          antialias: true);
    case 'light':
      img.fillRect(im,
          x1: size ~/ 2 - 70, y1: 70, x2: size ~/ 2 + 70, y2: 210, color: accent);
      img.fillRect(im,
          x1: size ~/ 2 - 10, y1: 210, x2: size ~/ 2 + 10, y2: 300, color: ink);
      for (var i = -1; i <= 1; i++) {
        img.fillRect(im,
            x1: size ~/ 2 - 50 + i * 36,
            y1: 40,
            x2: size ~/ 2 - 30 + i * 36,
            y2: 70,
            color: img.ColorRgba8(255, 235, 170, 255));
      }
    case 'accessory':
      img.fillRect(im, x1: 90, y1: 150, x2: 270, y2: 240, color: accent);
      img.fillRect(im, x1: 120, y1: 100, x2: 240, y2: 150, color: ink);
      img.fillCircle(im,
          x: 180, y: 195, radius: 24, color: img.ColorRgba8(255, 255, 255, 255));
    default:
      img.fillRect(im, x1: 70, y1: 120, x2: 290, y2: 260, color: ink);
      img.fillRect(im, x1: 130, y1: 96, x2: 190, y2: 122, color: accent);
      img.fillCircle(im,
          x: 180, y: 190, radius: 46, color: accent, antialias: true);
      img.fillCircle(im,
          x: 180,
          y: 190,
          radius: 30,
          color: img.ColorRgba8(18, 22, 30, 255),
          antialias: true);
      img.fillCircle(im,
          x: 190,
          y: 178,
          radius: 10,
          color: img.ColorRgba8(140, 210, 245, 255),
          antialias: true);
  }
  for (var x = 0; x < size; x += 36) {
    img.drawLine(im,
        x1: x, y1: 0, x2: x, y2: size, color: img.ColorRgba8(230, 233, 238, 90));
  }
  return im;
}
