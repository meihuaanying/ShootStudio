import 'dart:convert';
import 'dart:io';

/// P2：从 poly.pizza 抓取 Quaternius CC0/CC-BY 人形 GLB（幂等）。
/// 输出 app/assets/models/characters/*.glb + manifest.json，并追加署名。
Future<void> main() async {
  final Directory dir = Directory('assets/models/characters')
    ..createSync(recursive: true);
  final List<Map<String, Object?>> catalog = <Map<String, Object?>>[
    <String, Object?>{'q': 'universal base character male', 'tag': '基础', 'n': 2},
    <String, Object?>{'q': 'universal base character female', 'tag': '基础', 'n': 2},
    <String, Object?>{'q': 'animated woman', 'tag': '基础', 'n': 2},
    <String, Object?>{'q': 'hoodie character', 'tag': '休闲', 'n': 1},
    <String, Object?>{'q': 'casual character', 'tag': '休闲', 'n': 2},
    <String, Object?>{'q': 'beach character', 'tag': '休闲', 'n': 1},
    <String, Object?>{'q': 'business man character', 'tag': '职业', 'n': 2},
    <String, Object?>{'q': 'worker character', 'tag': '职业', 'n': 1},
    <String, Object?>{'q': 'suit character', 'tag': '职业', 'n': 1},
    <String, Object?>{'q': 'punk character', 'tag': '风格', 'n': 1},
    <String, Object?>{'q': 'adventurer character', 'tag': '风格', 'n': 2},
    <String, Object?>{'q': 'soldier character', 'tag': '风格', 'n': 1},
    <String, Object?>{'q': 'witch character', 'tag': '风格', 'n': 1},
    <String, Object?>{'q': 'sci fi character', 'tag': '风格', 'n': 1},
  ];
  final List<Map<String, Object?>> characters = <Map<String, Object?>>[];
  final List<Map<String, Object?>> attribution = <Map<String, Object?>>[];
  final List<String> missing = <String>[];
  final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final Set<String> seenIds = <String>{};
  var seq = 0;

  Future<String?> get(String url, {Map<String, String>? headers}) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final HttpClientRequest req = await client.getUrl(Uri.parse(url));
        req.headers.set('User-Agent', 'ShootStudio/1.0 (asset build)');
        headers?.forEach(req.headers.set);
        final HttpClientResponse res = await req.close();
        if (res.statusCode == 429) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        if (res.statusCode != 200) return null;
        return await res.transform(utf8.decoder).join();
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
    return null;
  }

  Future<List<int>?> getBytes(String url) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final HttpClientRequest req = await client.getUrl(Uri.parse(url));
        req.headers.set('User-Agent', 'ShootStudio/1.0 (asset build)');
        final HttpClientResponse res = await req.close();
        if (res.statusCode != 200) continue;
        return await res.fold<List<int>>(<int>[], (List<int> a, List<int> b) => a..addAll(b));
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
    return null;
  }

  for (final Map<String, Object?> entry in catalog) {
    final String query = '${entry['q']}';
    final String html =
        await get('https://poly.pizza/search/${Uri.encodeComponent(query)}') ?? '';
    final RegExp re = RegExp(r'/m/([A-Za-z0-9_-]{8,14})');
    final List<String> ids = re
        .allMatches(html)
        .map((RegExpMatch m) => m.group(1)!)
        .toSet()
        .take((entry['n'] as int) * 3)
        .toList();
    var taken = 0;
    for (final String id in ids) {
      if (taken >= (entry['n'] as int)) break;
      if (!seenIds.add(id)) continue;
      final String page = await get('https://poly.pizza/m/$id') ?? '';
      if (page.isEmpty) continue;
      final String license = page.contains('CC0')
          ? 'CC0'
          : (page.contains('CC-BY') || page.contains('Creative Commons Attribution'))
              ? 'CC-BY'
              : '';
      if (license.isEmpty) continue;
      final RegExp glbRe = RegExp(r'https://static\.poly\.pizza/[0-9a-fA-F-]{36}\.glb');
      final String? glb = glbRe.firstMatch(page)?.group(0);
      if (glb == null) continue;
      final String title = RegExp(r'<title>([^<]+)</title>')
              .firstMatch(page)
              ?.group(1)
              ?.replaceAll(' | poly.pizza', '')
              .trim() ??
          'character-$id';
      final List<int>? bytes = await getBytes(glb);
      if (bytes == null || bytes.length < 20 * 1024 || bytes.length > 8 * 1024 * 1024) {
        continue;
      }
      seq++;
      final String file = 'char-${seq.toString().padLeft(2, '0')}.glb';
      File('${dir.path}/$file').writeAsBytesSync(bytes);
      final bool female = title.toLowerCase().contains('woman') ||
          title.toLowerCase().contains('female');
      characters.add(<String, Object?>{
        'id': 'char-$seq',
        'name': title,
        'gender': female ? 'female' : 'male',
        'tag': entry['tag'],
        'file': file,
        'license': license,
        'source': 'https://poly.pizza/m/$id',
        'sizeKb': bytes.length ~/ 1024,
      });
      attribution.add(<String, Object?>{
        'file': 'assets/models/characters/$file',
        'name': title,
        'source': 'https://poly.pizza/m/$id',
        'license': license == 'CC0' ? 'CC0' : 'CC BY',
        'author': 'Quaternius',
      });
      taken++;
      stdout.writeln('+ ${entry['tag']} $title (${bytes.length ~/ 1024}KB, $license)');
    }
    if (taken == 0) missing.add(query);
  }

  File('assets/models/characters/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'version': 1,
    'note': 'Quaternius via poly.pizza；CC0/CC-BY；完整人物模型（含服装），可整人切换。',
    'characters': characters,
    'missing': missing,
  }));

  // 合并 attribution
  final File af = File('assets/content/attribution.json');
  final Map<String, Object?> data = af.existsSync()
      ? (jsonDecode(af.readAsStringSync()) as Map).cast<String, Object?>()
      : <String, Object?>{'items': <Object?>[], 'note': '素材署名'};
  final List<Object?> items = <Object?>[...(data['items'] as List<Object?>? ?? <Object?>[])];
  final Set<String> files = items
      .whereType<Map>()
      .map((Map m) => '${m['file']}')
      .toSet();
  for (final Map<String, Object?> a in attribution) {
    if (files.add('${a['file']}')) items.add(a);
  }
  data['items'] = items;
  af.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));

  stdout.writeln('characters=${characters.length} missing=$missing attribution=${items.length}');
  client.close(force: true);
}
