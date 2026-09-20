import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// 荷兰国立博物馆源（D98 Key 预留）：Rijksmuseum 收藏 API。
class RijksSource implements SearchSource {
  RijksSource(this.apiKey, {Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final String apiKey;
  final Dio _dio;

  @override
  String get id => 'rijks';
  @override
  String get label => '荷兰国立博物馆';
  @override
  SourceCapability get capability => const SourceCapability(
    byTitle: true,
    byPerson: true,
    byKeyword: true,
    hasLicenseFilter: false,
    domains: <ImageDomain>{ImageDomain.art},
    requiresKey: true,
    keySettingId: 'search_key_rijks',
  );

  @override
  bool get enabled => apiKey.trim().isNotEmpty;

  @override
  String get disabledHint => '缺 Rijksmuseum Key（设置 → 图片素材通道）';

  @override
  Future<SourceSearchPage> search(
    SearchQuery query, {
    int page = 1,
    int perPage = 24,
  }) async {
    if (!enabled) throw StateError(disabledHint);
    final String text = query.forSource(id);
    if (text.trim().isEmpty) {
      return const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
    }
    final Response<Object?> res = await _dio.get<Object?>(
      'https://www.rijksmuseum.nl/api/en/collection',
      queryParameters: <String, Object?>{
        'key': apiKey.trim(),
        'q': text,
        'ps': perPage.clamp(1, 100),
        'p': page,
        'imgonly': 'True',
        'format': 'json',
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    final int count = intSafe(data['count'], hits.length);
    return SourceSearchPage(hits: hits, hasMore: page * perPage < count);
  }

  /// 解析 /api/en/collection 响应（fixture 测试用）。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['artObjects'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final Map<String, Object?> web = asMapSafe(m['webImage']);
      final String full = strSafe(web['url']);
      if (full.isEmpty) continue;
      final String title = strSafe(m['title'], '未命名藏品');
      final String maker = strSafe(m['principalOrFirstMaker']);
      final String pageUrl = strSafe(asMapSafe(m['links'])['web']);
      out.add(
        SearchHit(
          id: hitId('rijks', strSafe(m['objectNumber'], full)),
          title: title,
          thumbUrl: full,
          fullUrl: full,
          sourceId: 'rijks',
          sourceLabel: '荷兰国立博物馆',
          license: 'Rijksmuseum（许可以作品页为准）',
          commercialOk: false,
          attribution: 'Rijksmuseum${maker.isEmpty ? '' : ' · $maker'}',
          sourcePageUrl: pageUrl,
          width: intSafe(web['width']),
          height: intSafe(web['height']),
          domain: ImageDomain.art,
          imageType: 'artwork',
        ),
      );
    }
    return out;
  }
}
