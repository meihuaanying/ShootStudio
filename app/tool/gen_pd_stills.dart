import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'asset_common.dart';

class _Film {
  const _Film(this.title, this.year, this.tokens);

  final String title;
  final int year;
  final List<String> tokens;

  String get display => '$title ($year)';
  String get fileSlug => slug('$title-$year', max: 36);
}

const List<_Film> _films = <_Film>[
  _Film('Nosferatu', 1922, <String>['nosferatu', 'murnau']),
  _Film('The Kid', 1921, <String>['kid', 'chaplin']),
  _Film('Sherlock Jr.', 1924, <String>['sherlock', 'keaton']),
  _Film('Battleship Potemkin', 1925,
      <String>['potemkin', 'battleship', 'bronenosets']),
  _Film('The General', 1926, <String>['general', 'keaton']),
  _Film('Metropolis', 1927, <String>['metropolis', 'lang']),
  _Film('The Cabinet of Dr. Caligari', 1920, <String>['caligari', 'cabinet']),
  _Film('A Trip to the Moon', 1902,
      <String>['trip', 'moon', 'voyage', 'lune', 'melies', 'méliès']),
  _Film('His Girl Friday', 1940,
      <String>['friday', 'girl', 'grant', 'russell']),
  _Film('Night of the Living Dead', 1968,
      <String>['night', 'living', 'dead', 'zombie', 'duane', 'barbra']),
];

Future<void> main() async {
  final Map<String, Object?> config = readImageSources();
  final Net net = netFromConfig(config);
  final Directory dir = Directory('assets/content/stills/pd')
    ..createSync(recursive: true);

  final Set<String> usedUrls = <String>{};
  final Set<String> written = <String>{};
  final List<Map<String, Object?>> filmsOut = <Map<String, Object?>>[];
  final List<String> missing = <String>[];
  final List<Map<String, Object?>> attribution = <Map<String, Object?>>[];

  for (final _Film film in _films) {
    final List<Map<String, Object?>> frames = <Map<String, Object?>>[];
    final List<String> queries = <String>[
      '${film.title} ${film.year} still',
      '${film.title} ${film.year} screenshot',
      '${film.title} ${film.year} film still',
      '${film.title} ${film.year} film',
      '${film.title} ${film.year}',
    ];
    for (int qi = 0; qi < queries.length; qi++) {
      if (frames.length >= 6) break;
      if (qi >= 2 && frames.length >= 4) break;
      final String query = queries[qi];
      List<Map<String, Object?>> candidates;
      try {
        candidates = await _search(net, query);
      } catch (e) {
        stdout.writeln('[pd] search failed: ${film.display} / "$query" -> $e');
        continue;
      }
      for (final Map<String, Object?> candidate in candidates) {
        if (frames.length >= 6) break;
        final String url = '${candidate['url']}';
        final String title = '${candidate['title']}';
        if (url.isEmpty || usedUrls.contains(url)) continue;
        if (!_relevant(title, film)) continue;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final List<int>? jpeg = await fetchJpeg(net, url, tag: film.display);
        if (jpeg == null) continue;
        usedUrls.add(url);
        final String hash =
            md5.convert(utf8.encode(url)).toString().substring(0, 8);
        final String file = '${film.fileSlug}-$hash.jpg';
        File('${dir.path}/$file').writeAsBytesSync(jpeg);
        written.add(file);
        frames.add(<String, Object?>{
          'film': film.display,
          'title': title,
          'file': file,
          'source': candidate['source'],
          'license': candidate['license'],
          'author': candidate['author'],
        });
      }
    }

    if (frames.length < 4) {
      for (final Map<String, Object?> frame in frames) {
        final String file = '${frame['file']}';
        final File stale = File('${dir.path}/$file');
        if (stale.existsSync()) stale.deleteSync();
        written.remove(file);
      }
      missing.add(film.display);
      stdout.writeln('[pd] missing: ${film.display} (${frames.length} frames)');
      continue;
    }

    filmsOut.add(<String, Object?>{
      'title': film.title,
      'year': film.year,
      'frames': frames,
    });
    for (final Map<String, Object?> frame in frames) {
      attribution.add(<String, Object?>{
        'file': 'assets/content/stills/pd/${frame['file']}',
        'name': '${film.display} 静帧',
        'source': frame['source'],
        'license': frame['license'],
        'author': frame['author'],
      });
    }
    stdout.writeln('[pd] ${film.display}: ${frames.length} frames');
  }

  removeStaleTree(dir, written);

  final int frameCount = filmsOut.fold<int>(
      0,
      (int sum, Map<String, Object?> f) =>
          sum + (f['frames'] as List<Object?>).length);
  final Map<String, Object?> stills = <String, Object?>{
    'version': 1,
    'note': '已验证公有领域（Public domain/CC0）影片静帧包，来源 Wikimedia Commons，'
        '逐张署名见 attribution.json',
    'films': filmsOut,
    'missing': missing,
  };
  File('assets/content/stills/stills.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(stills));
  mergeAttribution('assets/content/stills/pd/', attribution);

  stdout.writeln('stills.json: films=${filmsOut.length} frames=$frameCount '
      'missing=${missing.length}');
  if (missing.isNotEmpty) stdout.writeln('missing list: ${missing.join(', ')}');
  net.close();
}

bool _relevant(String title, _Film film) {
  final String t = title.toLowerCase();
  if (t.contains('${film.year}')) return true;
  for (final String token in film.tokens) {
    if (t.contains(token)) return true;
  }
  return false;
}

Future<List<Map<String, Object?>>> _search(Net net, String query) async {
  final Uri uri =
      Uri.https('commons.wikimedia.org', '/w/api.php', <String, String>{
    'action': 'query',
    'generator': 'search',
    'gsrsearch': query,
    'gsrnamespace': '6',
    'gsrlimit': '30',
    'prop': 'imageinfo',
    'iiprop': 'url|extmetadata',
    'iiurlwidth': '480',
    'format': 'json',
    'formatversion': '2',
  });
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  final NetResponse res = await net.get(uri);
  if (res.statusCode != 200 || !res.text.startsWith('{')) {
    return <Map<String, Object?>>[];
  }
  final Object? decoded = jsonDecode(res.text);
  if (decoded is! Map) return <Map<String, Object?>>[];
  final List<Object?> pages =
      ((decoded['query'] as Map?)?['pages'] as List<Object?>?) ?? <Object?>[];
  final List<Map<String, Object?>> out = <Map<String, Object?>>[];
  for (final Object? raw in pages) {
    if (raw is! Map) continue;
    final Map<String, Object?> page = raw.cast<String, Object?>();
    final String title = '${page['title'] ?? ''}';
    final String lower = title.toLowerCase();
    if (RegExp(r'\.(svg|pdf|webm|ogv|oga|ogg|mp3|flac|wav|tif|tiff|gif|xcf|djvu)$')
        .hasMatch(lower)) {
      continue;
    }
    if (lower.contains('logo') || lower.contains('sheet music')) continue;
    final List<Object?> info =
        (page['imageinfo'] as List<Object?>?) ?? <Object?>[];
    if (info.isEmpty || info.first is! Map) continue;
    final Map<String, Object?> ii = (info.first as Map).cast<String, Object?>();
    final Map<String, Object?> meta =
        ((ii['extmetadata'] as Map?) ?? <String, Object?>{})
            .cast<String, Object?>();
    final String license =
        '${(meta['LicenseShortName'] as Map?)?['value'] ?? ''}'.trim();
    final String ll = license.toLowerCase();
    if (!ll.contains('public domain') && !ll.contains('cc0')) continue;
    final String url = '${ii['thumburl'] ?? ii['url'] ?? ''}';
    if (url.isEmpty) continue;
    final String author =
        stripHtml('${(meta['Artist'] as Map?)?['value'] ?? ''}');
    out.add(<String, Object?>{
      'title': title.startsWith('File:') ? title.substring(5) : title,
      'url': url,
      'source':
          '${ii['descriptionurl'] ?? 'https://commons.wikimedia.org/wiki/$title'}',
      'license': license,
      'author': author.isEmpty ? 'Wikimedia contributor' : author,
    });
  }
  return out;
}
