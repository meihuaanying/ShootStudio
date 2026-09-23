import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V7 美国国会图书馆源（D134 免 Key）：按 Rights Advisory 门控（仅无限制/PD）。
class LocSource implements SearchSource {
  LocSource({Dio? dio})
    : _dio =
          dio ??
          searchDio(
            receiveTimeout: const Duration(seconds: 30),
            headers: <String, dynamic>{
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
              'Accept': 'application/json',
            },
          );

  final Dio _dio;

  static const String _base = 'https://www.loc.gov/photos/';

  @override
  String get id => 'loc';

  @override
  String get label => '美国国会图书馆';

  @override
  SourceCapability get capability => const SourceCapability(
    byTitle: true,
    byPerson: true,
    byKeyword: true,
    hasLicenseFilter: true,
    domains: <ImageDomain>{ImageDomain.photo, ImageDomain.art},
    requiresKey: false,
  );

  @override
  bool get enabled => true;

  @override
  String get disabledHint => '';

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
    if (text.trim().isEmpty) {
      return const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
    }
    final int limit = perPage.clamp(1, 100);
    final Response<Object?> res = await _dio.get<Object?>(
      _base,
      queryParameters: <String, Object?>{
        'q': text,
        'fo': 'json',
        'c': limit,
        'sp': page,
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    final Map<String, Object?> pagination = asMapSafe(data['pagination']);
    final int of = intSafe(pagination['of'], hits.length);
    return SourceSearchPage(hits: hits, hasMore: page * limit < of);
  }

  /// 解析 loc.gov JSON（fixture 测试用）：仅保留无权利限制/PD 条目。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['results'])) {
      final Map<String, Object?> m = asMapSafe(item);
      if (!isOpenRights(m['rights_advisory'])) continue;
      final List<Object?> images = asListSafe(m['image_url']);
      final String thumb = images.isEmpty ? '' : strSafe(images.first);
      final String full = images.isEmpty
          ? ''
          : strSafe(images[images.length - 1]);
      if (full.isEmpty) continue;
      final String pageUrl = strSafe(m['url'], strSafe(m['id']));
      out.add(
        SearchHit(
          id: hitId('loc', strSafe(m['id'], full)),
          title: strSafe(m['title'], '未命名作品'),
          thumbUrl: thumb.isEmpty ? full : thumb,
          fullUrl: full,
          sourceId: 'loc',
          sourceLabel: 'Library of Congress',
          license: 'Public Domain / 无已知限制',
          licenseUrl: 'https://www.loc.gov/free-to-use/',
          commercialOk: true,
          attribution: 'Library of Congress',
          sourcePageUrl: pageUrl,
          domain: ImageDomain.photo,
          imageType: 'photo',
          description: _firstText(m['description']),
        ),
      );
    }
    return out;
  }

  /// Rights Advisory 门控（R63）：空或明确无限制/PD 才收录。
  static bool isOpenRights(Object? raw) {
    final List<String> texts = <String>[
      if (raw is List) ...raw.map((Object? e) => '$e'),
      if (raw is String) raw,
    ];
    if (texts.isEmpty) return true;
    for (final String t in texts) {
      final String l = t.toLowerCase();
      if (l.trim().isEmpty) continue;
      if (l.contains('no known restrictions') ||
          l.contains('public domain') ||
          l.contains('no known copyright')) {
        return true;
      }
      return false;
    }
    return true;
  }

  static String _firstText(Object? raw) {
    if (raw is List) {
      for (final Object? item in raw) {
        final String text = strSafe(item);
        if (text.isNotEmpty) return text;
      }
      return '';
    }
    return strSafe(raw);
  }
}
