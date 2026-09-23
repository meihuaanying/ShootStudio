import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../search_models.dart';
import 'source_utils.dart';

/// V7 内置索引型开放源（D134）：NGA / Walters 无查询 API，
/// 使用精选 CC0 索引（随包）+ 官方图片热链（运行时经 SearchCache 缓存）。
class OpenIndexSource implements SearchSource {
  OpenIndexSource({
    required this.id,
    required this.label,
    required this.asset,
    required this.attributionBase,
    this.domain = ImageDomain.art,
  });

  @override
  final String id;

  @override
  final String label;

  /// 索引资产路径（`assets/content/search/open_index/<id>.json`）。
  final String asset;
  final String attributionBase;
  final ImageDomain domain;

  static final Map<String, List<SearchHit>> _cache =
      <String, List<SearchHit>>{};

  @override
  SourceCapability get capability => const SourceCapability(
    byTitle: true,
    byPerson: true,
    byKeyword: true,
    hasLicenseFilter: true,
    domains: <ImageDomain>{ImageDomain.art},
    requiresKey: false,
  );

  @override
  bool get enabled => true;

  @override
  String get disabledHint => '';

  Future<List<SearchHit>> _hits() async {
    final List<SearchHit>? cached = _cache[id];
    if (cached != null) return cached;
    try {
      final String raw = await rootBundle.loadString(asset);
      final Map<String, Object?> data = asMapSafe(jsonDecode(raw));
      final List<SearchHit> hits = parse(data, id: id, label: label);
      return _cache[id] = hits;
    } catch (_) {
      // 失败不缓存：避免一次瞬时失败把该源永久置空（V7）。
      return <SearchHit>[];
    }
  }

  @override
  Future<SourceSearchPage> search(
    SearchQuery query, {
    int page = 1,
    int perPage = 24,
  }) async {
    final String text =
        query.intent == SearchIntent.person && query.person.isNotEmpty
        ? query.person
        : query.forSource(id);
    final List<String> tokens = text
        .toLowerCase()
        .split(RegExp(r'[\s,，、]+'))
        .where((String t) => t.trim().isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
    }
    final List<SearchHit> all = await _hits();
    final List<SearchHit> matched = all
        .where((SearchHit h) => _matches(h, tokens))
        .toList();
    final int start = (page - 1) * perPage;
    if (start >= matched.length) {
      return const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
    }
    final int end = (start + perPage).clamp(0, matched.length);
    return SourceSearchPage(
      hits: matched.sublist(start, end),
      hasMore: end < matched.length,
    );
  }

  static bool _matches(SearchHit hit, List<String> tokens) {
    final String haystack = '${hit.title} ${hit.attribution} ${hit.description}'
        .toLowerCase();
    for (final String token in tokens) {
      if (!haystack.contains(token)) return false;
    }
    return true;
  }

  /// 解析索引 JSON（fixture 测试用）。
  static List<SearchHit> parse(
    Map<String, Object?> data, {
    String id = '',
    String label = '',
  }) {
    final String sourceId = strSafe(data['source'], id);
    final String sourceLabel = strSafe(data['label'], label);
    final String attributionBase = strSafe(
      data['attribution'],
      sourceLabel.isEmpty ? sourceId : sourceLabel,
    );
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['items'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final String full = strSafe(m['fullUrl']);
      final String thumb = strSafe(m['thumbUrl'], full);
      if (full.isEmpty) continue;
      final String artist = strSafe(m['artist']);
      out.add(
        SearchHit(
          id: hitId(sourceId, strSafe(m['id'], full)),
          title: strSafe(m['title'], '未命名作品'),
          thumbUrl: thumb,
          fullUrl: full,
          sourceId: sourceId,
          sourceLabel: sourceLabel,
          license: strSafe(data['license'], 'CC0 1.0'),
          licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
          commercialOk: true,
          attribution: artist.isEmpty
              ? attributionBase
              : '$attributionBase · $artist',
          sourcePageUrl: strSafe(m['pageUrl']),
          width: intSafe(m['width']),
          height: intSafe(m['height']),
          domain: ImageDomain.art,
          imageType: 'artwork',
          description: strSafe(m['date']),
        ),
      );
    }
    return out;
  }
}
