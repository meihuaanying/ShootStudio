import 'dart:math' as math;
import 'dart:typed_data';

import 'search_models.dart';

/// V6 结果重排（合同 §3.C.3）：文本匹配分 + 源权重 + 分辨率 + 许可 + 去重
/// （URL/ID + 感知哈希）；可选 AI 文本重排由调用方另行叠加。
class ResultRanker {
  ResultRanker._();

  /// 源权重（专业匹配度：影视主源 / 摄影主源 / 免 Key 博物馆）。
  static const Map<String, double> sourceWeights = <String, double>{
    'tmdb': 1.00,
    'pexels': 0.95,
    'met': 0.90,
    'artic': 0.90,
    'cleveland': 0.90,
    'vam': 0.85,
    'anilist': 0.85,
    'wikiart': 0.80,
    'artvee': 0.80,
    'europeana': 0.78,
    'smithsonian': 0.78,
    'harvard': 0.78,
    'rijks': 0.78,
    'openverse': 0.60,
  };

  /// 排序 + 去重 + 许可过滤（不修改入参）。
  static List<SearchHit> rank(
    List<SearchHit> hits, {
    required SearchQuery query,
    bool commercialOnly = false,
  }) {
    final List<String> tokens = _tokens(
      <String>[
        query.text,
        query.title,
        query.person,
        query.raw,
      ].where((String s) => s.trim().isNotEmpty).join(' '),
    );
    final List<SearchHit> filtered = commercialOnly
        ? hits.where((SearchHit h) => h.commercialOk).toList()
        : List<SearchHit>.of(hits);
    final List<SearchHit> deduped = dedupe(filtered);
    final List<SearchHit> scored = deduped
        .map(
          (SearchHit h) => h.copyWith(score: scoreOf(h, tokens, query: query)),
        )
        .toList();
    scored.sort((SearchHit a, SearchHit b) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final int areaA = a.width * a.height;
      final int areaB = b.width * b.height;
      return areaB.compareTo(areaA);
    });
    return scored;
  }

  /// 综合得分（0–1.2 区间）。
  static double scoreOf(
    SearchHit hit,
    List<String> tokens, {
    SearchQuery? query,
  }) {
    double score = sourceWeights[hit.sourceId] ?? 0.7;
    final String haystack =
        '${hit.title} ${hit.group} ${hit.attribution} ${hit.description}'
            .toLowerCase();
    if (tokens.isNotEmpty) {
      var matched = 0;
      for (final String token in tokens) {
        if (haystack.contains(token)) matched++;
      }
      score += 0.25 * (matched / tokens.length);
    }
    final int shortEdge = math.min(hit.width, hit.height);
    if (shortEdge >= 1000) {
      score += 0.12;
    } else if (shortEdge >= 600) {
      score += 0.06;
    }
    if (hit.commercialOk) score += 0.05;
    if (query != null &&
        query.intent == SearchIntent.person &&
        hit.group.isNotEmpty) {
      score += 0.05;
    }
    return score;
  }

  /// 去重：URL/ID 规范化 + 标题+作者近似（感知哈希另见 [dedupeByHash]）。
  static List<SearchHit> dedupe(List<SearchHit> hits) {
    final Set<String> seen = <String>{};
    final Set<String> seenTitles = <String>{};
    final List<SearchHit> out = <SearchHit>[];
    for (final SearchHit hit in hits) {
      final String urlKey = hit.fullUrl.split('?').first.toLowerCase();
      if (urlKey.isEmpty) continue;
      if (!seen.add(urlKey)) continue;
      if (!seen.add(hit.id)) continue;
      final String titleKey =
          '${hit.title.toLowerCase().trim()}|${hit.attribution.toLowerCase().trim()}';
      if (hit.title.trim().length >= 6 && !seenTitles.add(titleKey)) continue;
      out.add(hit);
    }
    return out;
  }

  /// 感知哈希去重（dHash 64 位）：同一图不同尺寸/来源仅保留首条。
  static List<SearchHit> dedupeByHash(
    List<SearchHit> hits,
    Map<String, int> hashByHitId, {
    int maxDistance = 6,
  }) {
    final List<SearchHit> out = <SearchHit>[];
    final List<int> kept = <int>[];
    for (final SearchHit hit in hits) {
      final int? hash = hashByHitId[hit.id];
      if (hash == null) {
        out.add(hit);
        continue;
      }
      var duplicate = false;
      for (final int existing in kept) {
        if (hammingDistance(existing, hash) <= maxDistance) {
          duplicate = true;
          break;
        }
      }
      if (duplicate) continue;
      kept.add(hash);
      out.add(hit);
    }
    return out;
  }

  /// dHash：8×8 灰度差分 → 64 位哈希。
  /// [gray] 为逐像素灰度（行优先），长度须 >= width*height。
  static int dHash(Uint8List gray, int width, int height) {
    if (width < 9 || height < 8 || gray.length < width * height) return 0;
    var hash = 0;
    var bit = 0;
    for (var y = 0; y < 8; y++) {
      final int row = (y * height) ~/ 8;
      for (var x = 0; x < 8; x++) {
        final int leftX = (x * width) ~/ 9;
        final int rightX = ((x + 1) * width) ~/ 9;
        final int left = gray[row * width + leftX];
        final int right = gray[row * width + rightX];
        if (left > right) hash |= 1 << bit;
        bit++;
      }
    }
    return hash;
  }

  /// RGB 转灰度（感知权重）。
  static Uint8List toGrayscale(
    Uint8List rgb,
    int width,
    int height, {
    int channels = 3,
  }) {
    final int pixels = width * height;
    final Uint8List gray = Uint8List(pixels);
    for (var i = 0; i < pixels; i++) {
      final int base = i * channels;
      if (base + 2 >= rgb.length) break;
      final int r = rgb[base];
      final int g = rgb[base + 1];
      final int b = rgb[base + 2];
      gray[i] = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(0, 255);
    }
    return gray;
  }

  /// 汉明距离。
  static int hammingDistance(int a, int b) {
    var value = a ^ b;
    var count = 0;
    while (value != 0) {
      value &= value - 1;
      count++;
    }
    return count;
  }

  static List<String> _tokens(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'))
      .where((String t) => t.length >= 2)
      .toList();
}
