import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const Duration kNetTimeout = Duration(seconds: 20);
const int kNetRetries = 3;
const int kMaxEdge = 960;
const int kMaxBytes = 180 * 1024;
const int kMinBytes = 10 * 1024;

class NetResponse {
  NetResponse(this.statusCode, this.bodyBytes, this.headers);

  final int statusCode;
  final Uint8List bodyBytes;
  final Map<String, String> headers;

  String get text => utf8.decode(bodyBytes, allowMalformed: true);

  String? header(String name) => headers[name.toLowerCase()];
}

class Net {
  Net({String httpProxy = '', String httpsProxy = ''})
      : _client = HttpClient()
          ..connectionTimeout = kNetTimeout
          ..idleTimeout = const Duration(seconds: 30)
          ..userAgent = 'ShootStudio/1.0.3 asset-pipeline' {
    final String hp = httpProxy.trim();
    final String sp = httpsProxy.trim();
    if (hp.isNotEmpty || sp.isNotEmpty) {
      _client.findProxy = (Uri uri) {
        final String raw = uri.scheme == 'https'
            ? (sp.isNotEmpty ? sp : hp)
            : (hp.isNotEmpty ? hp : sp);
        if (raw.isEmpty) return 'DIRECT';
        if (raw.startsWith('PROXY') ||
            raw.startsWith('SOCKS') ||
            raw.contains('=')) {
          return raw;
        }
        return 'PROXY $raw';
      };
    }
  }

  final HttpClient _client;

  Future<NetResponse> get(Uri uri,
      {Map<String, String>? headers, int retries = kNetRetries}) async {
    Object? last;
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final NetResponse res =
            await _once(uri, headers ?? const <String, String>{})
                .timeout(kNetTimeout);
        if (res.statusCode == 429 || res.statusCode == 503) {
          final int wait = int.tryParse('${res.header('retry-after')}'.trim()) ??
              10 * attempt;
          stdout.writeln('[net] HTTP ${res.statusCode} on ${uri.host}; '
              'wait ${wait}s ($attempt/$retries)');
          await Future<void>.delayed(Duration(seconds: wait));
          continue;
        }
        return res;
      } catch (e) {
        last = e;
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
    }
    throw HttpException('request failed ($last)', uri: uri);
  }

  Future<NetResponse> _once(Uri uri, Map<String, String> headers) async {
    final HttpClientRequest req = await _client.getUrl(uri);
    headers.forEach(req.headers.set);
    final HttpClientResponse res = await req.close();
    final List<int> chunks = await res.fold<List<int>>(
        <int>[], (List<int> a, List<int> b) => a..addAll(b));
    final Map<String, String> responseHeaders = <String, String>{};
    res.headers.forEach((String name, List<String> values) {
      responseHeaders[name.toLowerCase()] = values.join(', ');
    });
    return NetResponse(
        res.statusCode, Uint8List.fromList(chunks), responseHeaders);
  }

  void close() => _client.close(force: true);
}

Map<String, Object?> readImageSources() {
  final File file = File('assets/config/image_sources.json');
  if (!file.existsSync()) return <String, Object?>{};
  try {
    final Object? decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map
        ? decoded.cast<String, Object?>()
        : <String, Object?>{};
  } catch (_) {
    return <String, Object?>{};
  }
}

Net netFromConfig(Map<String, Object?> config) {
  final Map<String, Object?> proxy =
      ((config['proxy'] as Map?) ?? <String, Object?>{}).cast<String, Object?>();
  return Net(
    httpProxy: '${proxy['http'] ?? ''}',
    httpsProxy: '${proxy['https'] ?? ''}',
  );
}

List<int>? toJpegWithin(
  Uint8List bytes, {
  int maxEdge = kMaxEdge,
  int maxBytes = kMaxBytes,
}) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  img.Image current = decoded;
  if (current.width > maxEdge || current.height > maxEdge) {
    current = current.width >= current.height
        ? img.copyResize(current,
            width: maxEdge, interpolation: img.Interpolation.cubic)
        : img.copyResize(current,
            height: maxEdge, interpolation: img.Interpolation.cubic);
  }
  if (current.width < 1 || current.height < 1) return null;
  for (final int quality in <int>[86, 80, 74, 66, 58, 50, 42]) {
    final List<int> out = img.encodeJpg(current, quality: quality);
    if (out.length <= maxBytes) return out;
  }
  while (current.width > 360 && current.height > 360) {
    final int edge =
        ((current.width >= current.height ? current.width : current.height) * 4) ~/
            5;
    current = current.width >= current.height
        ? img.copyResize(current,
            width: edge, interpolation: img.Interpolation.cubic)
        : img.copyResize(current,
            height: edge, interpolation: img.Interpolation.cubic);
    final List<int> out = img.encodeJpg(current, quality: 50);
    if (out.length <= maxBytes) return out;
  }
  return img.encodeJpg(current, quality: 40);
}

String stripHtml(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String slug(String value, {int max = 48}) {
  final String s = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (s.isEmpty) return 'item';
  if (s.length <= max) return s;
  return s.substring(0, max).replaceAll(RegExp(r'-+$'), '');
}

void mergeAttribution(
    String managedPrefix, List<Map<String, Object?>> entries) {
  final File file = File('assets/content/attribution.json');
  Map<String, Object?> root = <String, Object?>{};
  if (file.existsSync()) {
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map) root = decoded.cast<String, Object?>();
    } catch (_) {
      root = <String, Object?>{};
    }
  }
  final Map<String, Map<String, Object?>> byFile =
      <String, Map<String, Object?>>{};
  for (final Object? raw in (root['items'] as List<Object?>?) ?? <Object?>[]) {
    if (raw is! Map) continue;
    final Map<String, Object?> item = raw.cast<String, Object?>();
    final String f = '${item['file'] ?? ''}';
    if (f.isEmpty || f.startsWith(managedPrefix)) continue;
    byFile[f] = item;
  }
  for (final Map<String, Object?> entry in entries) {
    final String f = '${entry['file'] ?? ''}';
    if (f.isNotEmpty) byFile[f] = entry;
  }
  root['items'] = byFile.values.toList();
  final String note = '${root['note'] ?? ''}';
  if (note.trim().isEmpty) root['note'] = '内置第三方素材署名（G6/V3）';
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
}

void removeStaleTree(Directory root, Set<String> keepRelative) {
  if (!root.existsSync()) return;
  final String prefix = '${root.path.replaceAll('\\', '/')}/';
  for (final FileSystemEntity e in root.listSync(recursive: true)) {
    if (e is! File) continue;
    final String full = e.path.replaceAll('\\', '/');
    final String rel = full.startsWith(prefix) ? full.substring(prefix.length) : full;
    if (!keepRelative.contains(rel)) e.deleteSync();
  }
  for (final FileSystemEntity e in root.listSync()) {
    if (e is Directory && e.listSync().isEmpty) e.deleteSync();
  }
}

class PexelsPhoto {
  PexelsPhoto(this.id, this.photographer, this.photoUrl, this.srcUrl);

  final int id;
  final String photographer;
  final String photoUrl;
  final String srcUrl;
}

Future<List<PexelsPhoto>> pexelsSearch(
  Net net,
  String apiKey,
  String query, {
  int perPage = 15,
  String orientation = 'landscape',
}) async {
  final Uri uri = Uri.https('api.pexels.com', '/v1/search', <String, String>{
    'query': query,
    'orientation': orientation,
    'size': 'medium',
    'per_page': '$perPage',
  });
  final NetResponse res = await net.get(uri, headers: <String, String>{
    'Authorization': apiKey,
  });
  if (res.statusCode != 200) {
    stdout.writeln('[pexels] HTTP ${res.statusCode} query="$query"');
    return <PexelsPhoto>[];
  }
  final Object? decoded = jsonDecode(res.text);
  if (decoded is! Map) return <PexelsPhoto>[];
  final List<Object?> photos =
      (decoded['photos'] as List<Object?>?) ?? <Object?>[];
  final List<PexelsPhoto> out = <PexelsPhoto>[];
  for (final Object? raw in photos) {
    if (raw is! Map) continue;
    final Map<String, Object?> p = raw.cast<String, Object?>();
    final Object? srcRaw = p['src'];
    if (srcRaw is! Map) continue;
    final Map<String, Object?> src = srcRaw.cast<String, Object?>();
    final String url =
        '${src['large'] ?? src['large2x'] ?? src['medium'] ?? src['original'] ?? ''}';
    if (url.isEmpty) continue;
    out.add(PexelsPhoto(
      (p['id'] as num?)?.toInt() ?? 0,
      '${p['photographer'] ?? 'Pexels contributor'}',
      '${p['url'] ?? 'https://www.pexels.com/'}',
      url,
    ));
  }
  return out;
}

Future<List<int>?> fetchJpeg(Net net, String url, {String tag = ''}) async {
  try {
    final NetResponse res = await net.get(Uri.parse(url));
    if (res.statusCode != 200 || res.bodyBytes.length < kMinBytes) return null;
    return toJpegWithin(res.bodyBytes);
  } catch (e) {
    if (tag.isNotEmpty) stdout.writeln('[image] $tag failed: $e');
    return null;
  }
}
