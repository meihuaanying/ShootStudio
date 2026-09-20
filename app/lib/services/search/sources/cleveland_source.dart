import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V6 克利夫兰艺术博物馆源（D115 免 Key）：Open Access API + CC0 标记。
class ClevelandSource implements SearchSource {
  ClevelandSource({Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  static const String _base =
      'https://openaccess-api.clevelandart.org/api/artworks/';

  @override
  String get id => 'cleveland';
  @override
  String get label => '克利夫兰艺术博物馆';
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
    final int skip = (page - 1) * perPage;
    final Response<Object?> res = await _dio.get<Object?>(
      _base,
      queryParameters: <String, Object?>{
        'q': text,
        'limit': perPage.clamp(1, 100),
        'skip': skip,
        'has_image': 1,
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    final int total = intSafe(asMapSafe(data['info'])['total'], hits.length);
    return SourceSearchPage(hits: hits, hasMore: skip + perPage < total);
  }

  /// 解析 /artworks/ 响应（fixture 测试用）。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['data'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final Map<String, Object?> images = asMapSafe(m['images']);
      final Map<String, Object?> web = asMapSafe(images['web']);
      final Map<String, Object?> print = asMapSafe(images['print']);
      final Map<String, Object?> full = asMapSafe(images['full']);
      final String thumb = strSafe(web['url']);
      final String big = strSafe(print['url'], strSafe(full['url'], thumb));
      if (big.isEmpty) continue;
      final String title = strSafe(m['title'], '未命名作品');
      final bool cc0 =
          strSafe(m['share_license_status']).toUpperCase() == 'CC0';
      final String creator = _firstCreator(m['creators']);
      final String pageUrl = strSafe(m['url']);
      out.add(
        SearchHit(
          id: hitId('cleveland', strSafe(m['id'], pageUrl)),
          title: title,
          thumbUrl: thumb.isEmpty ? big : thumb,
          fullUrl: big,
          sourceId: 'cleveland',
          sourceLabel: '克利夫兰艺术博物馆',
          license: cc0 ? 'CC0 / Public Domain' : '© 克利夫兰艺术博物馆（非商用参考）',
          licenseUrl: cc0
              ? 'https://creativecommons.org/publicdomain/zero/1.0/'
              : '',
          commercialOk: cc0,
          attribution:
              'Cleveland Museum of Art${creator.isEmpty ? '' : ' · $creator'}',
          sourcePageUrl: pageUrl,
          domain: ImageDomain.art,
          imageType: 'artwork',
          description: strSafe(m['technique']),
          extra: <String, Object?>{'date': strSafe(m['creation_date'])},
        ),
      );
    }
    return out;
  }

  static String _firstCreator(Object? raw) {
    for (final Object? item in asListSafe(raw)) {
      final Map<String, Object?> m = asMapSafe(item);
      final String description = strSafe(m['description']);
      if (description.isNotEmpty) return description;
    }
    return '';
  }
}
