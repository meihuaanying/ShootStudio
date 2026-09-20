import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// 芝加哥艺术博物馆一页结果。
class ArticPage {
  const ArticPage({required this.hits, required this.hasMore});
  final List<SearchHit> hits;
  final bool hasMore;
}

/// V6 芝加哥艺术博物馆源（D115 免 Key）：Art Institute of Chicago 开放 API + IIIF。
class ArticSource implements SearchSource {
  ArticSource({Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  static const String _base = 'https://api.artic.edu/api/v1/artworks/search';
  static const String _fallbackIiif = 'https://www.artic.edu/iiif/2';

  @override
  String get id => 'artic';
  @override
  String get label => '芝加哥艺术博物馆';
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
    final Response<Object?> res = await _dio.get<Object?>(
      _base,
      queryParameters: <String, Object?>{
        'q': text,
        'page': page,
        'limit': perPage.clamp(1, 100),
        'fields':
            'id,title,image_id,is_public_domain,artist_display,date_display,medium_display,thumbnail',
      },
    );
    final ArticPage parsed = parse(asMapSafe(res.data));
    return SourceSearchPage(hits: parsed.hits, hasMore: parsed.hasMore);
  }

  /// 解析 /artworks/search 响应（fixture 测试用）。
  static ArticPage parse(Map<String, Object?> data) {
    final Map<String, Object?> config = asMapSafe(data['config']);
    final String iiif = strSafe(
      config['iiif_url'],
      _fallbackIiif,
    ).replaceAll(RegExp(r'/$'), '');
    final List<SearchHit> hits = <SearchHit>[];
    for (final Object? item in asListSafe(data['data'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final String imageId = strSafe(m['image_id']);
      if (imageId.isEmpty) continue;
      final String title = strSafe(m['title'], '未命名作品');
      final bool publicDomain = m['is_public_domain'] == true;
      final int id = intSafe(m['id']);
      final String pageUrl = id == 0
          ? ''
          : 'https://www.artic.edu/artworks/$id';
      final String base = '$iiif/$imageId';
      hits.add(
        SearchHit(
          id: hitId('artic', imageId),
          title: title,
          thumbUrl: '$base/full/400,/0/default.jpg',
          fullUrl: '$base/full/1686,/0/default.jpg',
          sourceId: 'artic',
          sourceLabel: '芝加哥艺术博物馆',
          license: publicDomain ? 'CC0 / Public Domain' : '© 艺术家/博物馆（非商用参考）',
          licenseUrl: publicDomain
              ? 'https://creativecommons.org/publicdomain/zero/1.0/'
              : '',
          commercialOk: publicDomain,
          attribution:
              'Art Institute of Chicago${strSafe(m['artist_display']).isEmpty ? '' : ' · ${m['artist_display']}'}',
          sourcePageUrl: pageUrl,
          domain: ImageDomain.art,
          imageType: 'artwork',
          description: strSafe(m['medium_display']),
          extra: <String, Object?>{'date': strSafe(m['date_display'])},
        ),
      );
    }
    final Map<String, Object?> pagination = asMapSafe(data['pagination']);
    final int current = intSafe(pagination['current_page'], 1);
    final int totalPages = intSafe(pagination['total_pages'], 1);
    return ArticPage(hits: hits, hasMore: current < totalPages);
  }
}
