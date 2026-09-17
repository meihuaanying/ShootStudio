// 姿势照片抓取（V4 / D65、R19）：10 类目 × 12 = 120 张真实实拍照片。
// 主源 Pexels（Authorization 头，per_page=12，逐类目取前 12 张可用）；备源 Wikimedia Commons
// （仅接受 CC0 / Public domain / CC BY 许可）。输出：
//   assets/content/poses3/photos/<id>.jpg（id=p001..p120，长边 ≤1000，≤200KB）
//   assets/content/poses3/photos_manifest.json（逐图 id/name/category/photo/source/license/author）
//   assets/content/attribution.json（按 file 去重追加）
// 用法（工作目录 app/）：
//   dart run tool/gen_pose_photos.dart            # 幂等抓取（缺什么补什么）
//   dart run tool/gen_pose_photos.dart --force    # 全部重抓
//   dart run tool/gen_pose_photos.dart --fix      # 按 poses3/rejects.json 换图（重抓被拒照片）
//   dart run tool/gen_pose_photos.dart --only 站姿,坐姿
//   dart run tool/gen_pose_photos.dart --limit-per 12
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'asset_common.dart';

const String kOutDir = 'assets/content/poses3';
const String kPhotosRel = '$kOutDir/photos';
const String kManifest = '$kOutDir/photos_manifest.json';
const String kRejects = '$kOutDir/rejects.json';
const int kSlotsPerCategory = 12;
const int kMaxEdge = 1000;
const int kMaxBytes = 200 * 1024;

class PoseCategory {
  const PoseCategory(this.id, this.name, this.query);

  final String id;
  final String name;
  final String query;
}

const List<PoseCategory> kCategories = <PoseCategory>[
  PoseCategory('standing', '站姿', 'standing pose full body model'),
  PoseCategory('sitting', '坐姿', 'sitting pose model'),
  PoseCategory('squat', '蹲姿', 'squat pose'),
  PoseCategory('kneeling', '跪姿', 'kneeling pose'),
  PoseCategory('leaning', '靠姿', 'leaning pose model'),
  PoseCategory('lying', '躺姿', 'lying pose model'),
  PoseCategory('dynamic', '动态', 'dance jump pose'),
  PoseCategory('hand', '手部', 'hand gesture pose'),
  PoseCategory('expression', '神态', 'portrait face expression pose'),
  PoseCategory('props', '道具互动', 'pose with umbrella chair props'),
];

class Candidate {
  Candidate({
    required this.origin,
    required this.source,
    required this.license,
    required this.author,
    required this.imageUrl,
    required this.sourceId,
    this.alt = '',
  });

  final String origin; // pexels | wikimedia
  final String source; // 照片页 URL
  final String license;
  final String author;
  final String imageUrl;
  final String sourceId;
  final String alt;

  Map<String, Object?> toJson() => <String, Object?>{
        'origin': origin,
        'source': source,
        'license': license,
        'author': author,
        'imageUrl': imageUrl,
        'sourceId': sourceId,
        'alt': alt,
      };

  static Candidate fromJson(Map<String, Object?> j) => Candidate(
        origin: '${j['origin'] ?? 'pexels'}',
        source: '${j['source'] ?? ''}',
        license: '${j['license'] ?? ''}',
        author: '${j['author'] ?? ''}',
        imageUrl: '${j['imageUrl'] ?? ''}',
        sourceId: '${j['sourceId'] ?? ''}',
        alt: '${j['alt'] ?? ''}',
      );
}

String idFor(int catIndex, int slot) =>
    'p${(catIndex * kSlotsPerCategory + slot + 1).toString().padLeft(3, '0')}';

Map<String, Object?> readJsonFile(String path, Map<String, Object?> fallback) {
  final File f = File(path);
  if (!f.existsSync()) return fallback;
  try {
    final Object? decoded = jsonDecode(f.readAsStringSync());
    return decoded is Map ? decoded.cast<String, Object?>() : fallback;
  } catch (_) {
    return fallback;
  }
}

void writeJsonFile(String path, Object value) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));
}

// ---------------- Pexels ----------------
Future<List<Candidate>> pexelsPage(
    Net net, String apiKey, String query, int page) async {
  final Uri uri = Uri.https('api.pexels.com', '/v1/search', <String, String>{
    'query': query,
    'orientation': 'portrait',
    'size': 'medium',
    'per_page': '$kSlotsPerCategory',
    'page': '$page',
  });
  try {
    final NetResponse res = await net.get(uri, headers: <String, String>{
      'Authorization': apiKey,
    });
    if (res.statusCode != 200) {
      stdout.writeln('[pexels] HTTP ${res.statusCode} query="$query" page=$page');
      return <Candidate>[];
    }
    final Object? decoded = jsonDecode(res.text);
    if (decoded is! Map) return <Candidate>[];
    final List<Object?> photos =
        (decoded['photos'] as List<Object?>?) ?? <Object?>[];
    final List<Candidate> out = <Candidate>[];
    for (final Object? raw in photos) {
      if (raw is! Map) continue;
      final Map<String, Object?> p = raw.cast<String, Object?>();
      final Object? srcRaw = p['src'];
      if (srcRaw is! Map) continue;
      final Map<String, Object?> src = srcRaw.cast<String, Object?>();
      final String url = '${src['large2x'] ?? src['large'] ?? src['medium'] ?? src['original'] ?? ''}';
      if (url.isEmpty) continue;
      out.add(Candidate(
        origin: 'pexels',
        source: '${p['url'] ?? 'https://www.pexels.com/'}',
        license: 'Pexels License',
        author: '${p['photographer'] ?? 'Pexels contributor'}',
        imageUrl: url,
        sourceId: '${(p['id'] as num?)?.toInt() ?? 0}',
        alt: '${p['alt'] ?? ''}',
      ));
    }
    return out;
  } catch (e) {
    stdout.writeln('[pexels] 请求失败 query="$query" page=$page: $e');
    return <Candidate>[];
  }
}

// ---------------- Wikimedia Commons ----------------
bool wikiLicenseOk(String license) {
  final String l = license.toLowerCase();
  return l.contains('cc0') ||
      l.contains('public domain') ||
      l.contains('cc by') ||
      l.contains('pd-');
}

Future<List<Candidate>> wikimediaSearch(
    Net net, String query, {int limit = 20}) async {
  final Uri uri = Uri.https('commons.wikimedia.org', '/w/api.php', <String, String>{
    'action': 'query',
    'format': 'json',
    'generator': 'search',
    'gsrsearch': '$query filetype:bitmap',
    'gsrnamespace': '6',
    'gsrlimit': '$limit',
    'prop': 'imageinfo',
    'iiprop': 'url|extmetadata|mime',
    'iiurlwidth': '1280',
  });
  try {
    final NetResponse res = await net.get(uri, retries: 4);
    if (res.statusCode != 200) {
      stdout.writeln('[wikimedia] HTTP ${res.statusCode} query="$query"');
      return <Candidate>[];
    }
    final Object? decoded = jsonDecode(res.text);
    if (decoded is! Map) return <Candidate>[];
    final Object? pagesRaw = (decoded['query'] as Map?)?['pages'];
    if (pagesRaw is! Map) return <Candidate>[];
    final List<Candidate> out = <Candidate>[];
    for (final Object? pageRaw in pagesRaw.values) {
      if (pageRaw is! Map) continue;
      final Map<String, Object?> p = pageRaw.cast<String, Object?>();
      final String title = '${p['title'] ?? ''}';
      final List<Object?> infoList = (p['imageinfo'] as List<Object?>?) ?? <Object?>[];
      final Object? infoRaw = infoList.isEmpty ? null : infoList.first;
      if (infoRaw is! Map) continue;
      final Map<String, Object?> info = infoRaw.cast<String, Object?>();
      final String mime = '${info['mime'] ?? ''}';
      if (!mime.startsWith('image/')) continue;
      final Map<String, Object?> meta =
          ((info['extmetadata'] as Map?) ?? <String, Object?>{}).cast<String, Object?>();
      String metaValue(String key) {
        final Object? v = (meta[key] as Map?)?['value'];
        return stripHtml('${v ?? ''}');
      }
      final String license = metaValue('LicenseShortName');
      if (!wikiLicenseOk(license)) continue;
      final String imageUrl = '${info['thumburl'] ?? info['url'] ?? ''}';
      if (imageUrl.isEmpty) continue;
      final String author = metaValue('Artist').isEmpty
          ? 'Wikimedia Commons contributor'
          : metaValue('Artist');
      out.add(Candidate(
        origin: 'wikimedia',
        source: 'https://commons.wikimedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
        license: license,
        author: author,
        imageUrl: imageUrl,
        sourceId: title,
        alt: metaValue('ImageDescription'),
      ));
    }
    return out;
  } catch (e) {
    stdout.writeln('[wikimedia] 请求失败 query="$query": $e');
    return <Candidate>[];
  }
}

// ---------------- 清单 ----------------
class Manifest {
  Manifest(this.root);

  final Map<String, Object?> root;

  List<Map<String, Object?>> get photos {
    final Object? raw = root['photos'];
    if (raw is List) return raw.cast<Map<String, Object?>>();
    final List<Map<String, Object?>> list = <Map<String, Object?>>[];
    root['photos'] = list;
    return list;
  }

  Map<String, List<Map<String, Object?>>> get pool {
    final Object? raw = root['candidatePool'];
    if (raw is Map) {
      final Map<String, List<Map<String, Object?>>> out =
          <String, List<Map<String, Object?>>>{};
      for (final MapEntry<String, Object?> e in raw.cast<String, Object?>().entries) {
        out[e.key] = (e.value as List?)?.cast<Map<String, Object?>>() ?? <Map<String, Object?>>[];
      }
      return out;
    }
    final Map<String, List<Map<String, Object?>>> out =
        <String, List<Map<String, Object?>>>{};
    root['candidatePool'] = out;
    return out;
  }

  Map<String, Object?>? entryOf(String id) {
    for (final Map<String, Object?> p in photos) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  void putEntry(Map<String, Object?> entry) {
    final List<Map<String, Object?>> list = photos;
    final int i = list.indexWhere((Map<String, Object?> p) => p['id'] == entry['id']);
    if (i >= 0) {
      list[i] = entry;
    } else {
      list.add(entry);
    }
    list.sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
  }
}

bool photoOk(String relPath) {
  final File f = File(relPath);
  return f.existsSync() && f.lengthSync() > 8 * 1024;
}

Future<Uint8List?> downloadCandidate(Net net, Candidate c) async {
  try {
    final NetResponse res = await net.get(Uri.parse(c.imageUrl), retries: 4);
    if (res.statusCode != 200 || res.bodyBytes.length < 10 * 1024) return null;
    final List<int>? jpeg =
        toJpegWithin(res.bodyBytes, maxEdge: kMaxEdge, maxBytes: kMaxBytes);
    if (jpeg == null || jpeg.isEmpty) return null;
    return Uint8List.fromList(jpeg);
  } catch (e) {
    stdout.writeln('[image] ${c.origin} ${c.sourceId} 下载失败: $e');
    return null;
  }
}

void removeSkeletonArtifacts(String id) {
  // 骨架 JSON 随照片重抓失效；叠加图按 D66 只存 QA 证据目录（docs/pose-qa3），不进 assets。
  for (final String suffix in <String>['.skeleton.json', '.overlay.png']) {
    final File f = File('$kPhotosRel/$id$suffix');
    if (f.existsSync()) f.deleteSync();
  }
  final File qaOverlay = File('../docs/pose-qa3/overlay-$id.png');
  if (qaOverlay.existsSync()) qaOverlay.deleteSync();
  final File combo = File('$kPhotosRel/$id.combo.png');
  if (combo.existsSync()) combo.deleteSync();
}

void appendAttribution(List<Map<String, Object?>> entries) {
  if (entries.isEmpty) return;
  mergeAttribution('assets/content/poses3/photos/', entries);
}

Future<void> main(List<String> args) async {
  final bool force = args.contains('--force');
  final bool fix = args.contains('--fix');
  final Set<String>? only = _argList(args, '--only');
  final int limitPer = int.tryParse(_argValue(args, '--limit-per') ?? '') ?? kSlotsPerCategory;
  final Map<String, String> queryOverride = <String, String>{};
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] != '--query') continue;
    final int eq = args[i + 1].indexOf('=');
    if (eq > 0) {
      queryOverride[args[i + 1].substring(0, eq)] = args[i + 1].substring(eq + 1);
    }
  }
  final Set<String> overridden = <String>{};

  final Map<String, Object?> config = readImageSources();
  final Map<String, Object?> pexels =
      ((config['pexels'] as Map?) ?? <String, Object?>{}).cast<String, Object?>();
  final String apiKey = '${pexels['apiKey'] ?? ''}'.trim();
  if (apiKey.isEmpty) {
    stderr.writeln('[poses3] assets/config/image_sources.json 缺少 pexels.apiKey');
    exitCode = 2;
    return;
  }
  final Net net = netFromConfig(config);
  Directory(kPhotosRel).createSync(recursive: true);

  final Manifest manifest = Manifest(readJsonFile(kManifest, <String, Object?>{
    'version': 1,
    'note': '姿势照片（V4/D65）：Pexels 主 + Wikimedia 备；photo 为 app 根相对路径。',
  }));
  final Map<String, List<Map<String, Object?>>> pool = manifest.pool;

  // 被拒绝（无人/检测失败）的照片：优先用池中候选替换。
  final Set<String> rejected = <String>{};
  if (fix) {
    final Map<String, Object?> rejects = readJsonFile(kRejects, <String, Object?>{});
    for (final Object? r in (rejects['rejected'] as List<Object?>?) ?? <Object?>[]) {
      if (r is Map && '${r['id']}'.isNotEmpty) rejected.add('${r['id']}');
    }
  }

  final List<Map<String, Object?>> attribution = <Map<String, Object?>>[];
  final List<String> failures = <String>[];
  int fetched = 0;
  int replaced = 0;
  int skipped = 0;

  for (int ci = 0; ci < kCategories.length; ci++) {
    final PoseCategory cat = kCategories[ci];
    if (only != null && !only.contains(cat.name) && !only.contains(cat.id)) continue;
    final String query = queryOverride[cat.id] ?? cat.query;
    final List<Map<String, Object?>> catPool =
        pool.putIfAbsent(cat.id, () => <Map<String, Object?>>[]);
    if (queryOverride.containsKey(cat.id) && overridden.add(cat.id)) {
      catPool.clear();
    }
    int catOk = 0;
    final int slots = limitPer < kSlotsPerCategory ? limitPer : kSlotsPerCategory;
    for (int slot = 0; slot < slots; slot++) {
      final String id = idFor(ci, slot);
      final String target = '$kPhotosRel/$id.jpg';
      final Map<String, Object?>? existing = manifest.entryOf(id);
      final bool need = force || !photoOk(target) || rejected.contains(id);
      if (!need) {
        if (existing != null) {
          attribution.add(_attributionOf(existing, cat, id));
          catOk++;
        }
        skipped++;
        continue;
      }
      // 取候选：优先池，其次 Pexels/ Wikimedia。池中候选同样必须未被清单使用（防重复）。
      Candidate? pick;
      while (catPool.isNotEmpty) {
        final Map<String, Object?> head = catPool.removeAt(0);
        final Candidate c = Candidate.fromJson(head);
        if (c.imageUrl.isEmpty) continue;
        if (manifest.photos.any((Map<String, Object?> p) =>
            p['sourceId'] == c.sourceId && p['origin'] == c.origin)) {
          continue;
        }
        pick = c;
        break;
      }
      if (pick == null) {
        for (int page = 1; page <= 5 && pick == null; page++) {
          final List<Candidate> list = await pexelsPage(net, apiKey, query, page);
          if (list.isEmpty) break;
          for (final Candidate c in list) {
            if (manifest.photos.any((Map<String, Object?> p) =>
                p['sourceId'] == c.sourceId && p['origin'] == c.origin)) {
              continue;
            }
            if (catPool.any((Map<String, Object?> p) =>
                p['sourceId'] == c.sourceId && p['origin'] == c.origin)) {
              continue;
            }
            pick = c;
            break;
          }
          // 其余候选沉入池中，供后续换图（跳过清单已用，避免重复）。
          for (final Candidate c in list) {
            if (pick == null || c.sourceId != pick.sourceId || c.origin != pick.origin) {
              final Map<String, Object?> j = c.toJson();
              final bool used = manifest.photos.any((Map<String, Object?> p) =>
                  p['sourceId'] == j['sourceId'] && p['origin'] == j['origin']);
              if (!used && !catPool.any((Map<String, Object?> p) =>
                  p['sourceId'] == j['sourceId'] && p['origin'] == j['origin'])) {
                catPool.add(j);
              }
            }
          }
        }
        if (pick == null) {
          final List<Candidate> wiki = await wikimediaSearch(net, query);
          for (final Candidate c in wiki) {
            if (manifest.photos.any((Map<String, Object?> p) => p['sourceId'] == c.sourceId && p['origin'] == c.origin)) {
              continue;
            }
            pick = c;
            break;
          }
        }
      }
      if (pick == null) {
        failures.add('$id:${cat.name}（无候选）');
        continue;
      }
      Uint8List? bytes = await downloadCandidate(net, pick);
      if (bytes == null) {
        failures.add('$id:${cat.name}（下载/压缩失败）');
        continue;
      }
      // 占位换图：同一 id 若已有旧文件，直接覆盖。
      File(target).writeAsBytesSync(bytes);
      removeSkeletonArtifacts(id);
      final String name = '${cat.name}样张${(slot + 1).toString().padLeft(2, '0')}';
      final Map<String, Object?> entry = <String, Object?>{
        'id': id,
        'name': name,
        'category': cat.name,
        'categoryId': cat.id,
        'photo': '$kOutDir/photos/$id.jpg',
        'source': pick.source,
        'license': pick.license,
        'author': pick.author,
        'origin': pick.origin,
        'sourceId': pick.sourceId,
        'query': query,
        'alt': pick.alt,
      };
      manifest.putEntry(entry);
      attribution.add(_attributionOf(entry, cat, id));
      fetched++;
      if (existing != null && !force) replaced++;
      catOk++;
      stdout.writeln('[poses3] $id ${cat.name} ← ${pick.origin} ${pick.author}');
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    stdout.writeln('[poses3] ${cat.name}: $catOk/$kSlotsPerCategory'
        '（池剩余 ${catPool.length}）');
  }

  // 补足候选池（Pexels 第 2 页），供后续 --fix 换图。
  for (int ci = 0; ci < kCategories.length; ci++) {
    final PoseCategory cat = kCategories[ci];
    if (only != null && !only.contains(cat.name) && !only.contains(cat.id)) continue;
    if (queryOverride.containsKey(cat.id)) continue;
    final List<Map<String, Object?>> catPool = pool.putIfAbsent(cat.id, () => <Map<String, Object?>>[]);
    for (int page = 2; page <= 4 && catPool.length < 8; page++) {
      final List<Candidate> list = await pexelsPage(net, apiKey, cat.query, page);
      if (list.isEmpty) break;
      for (final Candidate c in list) {
        final Map<String, Object?> j = c.toJson();
        final bool used = manifest.photos.any((Map<String, Object?> p) =>
            p['sourceId'] == j['sourceId'] && p['origin'] == j['origin']);
        final bool dup = catPool.any((Map<String, Object?> p) =>
            p['sourceId'] == j['sourceId'] && p['origin'] == j['origin']);
        if (!used && !dup) catPool.add(j);
      }
    }
  }

  manifest.root['generatedAt'] = DateTime.now().toUtc().toIso8601String();
  manifest.root['total'] = manifest.photos.length;
  writeJsonFile(kManifest, manifest.root);
  appendAttribution(attribution);
  if (fix && rejected.isNotEmpty) {
    final List<Map<String, Object?>> remaining = <Map<String, Object?>>[];
    for (final String id in rejected) {
      final String target = '$kPhotosRel/$id.jpg';
      if (!photoOk(target)) remaining.add(<String, Object?>{'id': id, 'reason': '仍缺图'});
    }
    writeJsonFile(kRejects, <String, Object?>{
      'version': 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'rejected': remaining,
    });
  }
  stdout.writeln('[poses3] 抓取 $fetched 张（替换 $replaced，跳过 $skipped，限额 $limitPer）；'
      '总计 ${manifest.photos.length}/120；署名追加 ${attribution.length} 条');
  if (failures.isNotEmpty) {
    stdout.writeln('[poses3] 失败 ${failures.length} 条：');
    for (final String f in failures.take(30)) {
      stdout.writeln('  - $f');
    }
  }
  net.close();
}

Map<String, Object?> _attributionOf(
    Map<String, Object?> entry, PoseCategory cat, String id) {
  return <String, Object?>{
    'file': 'assets/content/poses3/photos/$id.jpg',
    'name': '姿势参考（${cat.name}）',
    'source': entry['source'],
    'license': entry['license'],
    'author': entry['author'],
  };
}

String? _argValue(List<String> args, String key) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == key) return args[i + 1];
  }
  return null;
}

Set<String>? _argList(List<String> args, String key) {
  final String? raw = _argValue(args, key);
  if (raw == null || raw.trim().isEmpty) return null;
  return raw.split(',').map((String s) => s.trim()).where((String s) => s.isNotEmpty).toSet();
}
