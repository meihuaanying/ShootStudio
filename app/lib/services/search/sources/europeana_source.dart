import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// Europeana 源（D98 Key 预留）：用户填入 wskey 即启用。
class EuropeanaSource implements SearchSource {
  EuropeanaSource(this.apiKey, {Dio? dio})
      : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final String apiKey;
  final Dio _dio;

  @override
  String get id => 'europeana';
  @override
  String get label => 'Europeana';
  @override
  SourceCapability get capability => const SourceCapability(
        byTitle: true,
        byPerson: true,
        byKeyword: true,
        hasLicenseFilter: true,
        domains: <ImageDomain>{ImageDomain.art},
        requiresKey: true,
        keySettingId: 'search_key_europeana',
      );

  @override
  bool get enabled => apiKey.trim().isNotEmpty;

  @override
  String get disabledHint => '缺 Europeana Key（设置 → 图片素材通道）';

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
    final int start = (page - 1) * perPage + 1;
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.europeana.eu/record/v2/search.json',
      queryParameters: <String, Object?>{
        'wskey': apiKey.trim(),
        'query': text,
        'media': true,
        'rows': perPage.clamp(1, 100),
        'start': start,
        'profile': 'rich',
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    final int total = intSafe(data['totalResults'], hits.length);
    return SourceSearchPage(hits: hits, hasMore: start + perPage - 1 < total);
  }

  /// 解析 /record/v2/search.json 响应（fixture 测试用）。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['items'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final String thumb = _first(m['edmPreview']);
      final String full =
          _first(m['edmIsShownBy']).isEmpty ? thumb : _first(m['edmIsShownBy']);
      if (full.isEmpty) continue;
      final String title = _first(m['title'], fallback: 'Europeana 藏品');
      final String creator = _first(m['dcCreator']);
      final String rights = _first(m['rights']);
      final bool commercial = isCommercialLicense(rights) ||
          rights.toLowerCase().contains('publicdomain');
      final String guid = strSafe(m['guid']);
      out.add(SearchHit(
        id: hitId('europeana', strSafe(m['id'], guid)),
        title: title,
        thumbUrl: thumb.isEmpty ? full : thumb,
        fullUrl: full,
        sourceId: 'europeana',
        sourceLabel: 'Europeana',
        license: rights.isEmpty ? 'Europeana（许可未知）' : rights,
        licenseUrl: rights,
        commercialOk: commercial,
        attribution: 'Europeana${creator.isEmpty ? '' : ' · $creator'}',
        sourcePageUrl: guid,
        domain: ImageDomain.art,
        imageType: 'artwork',
      ));
    }
    return out;
  }

  static String _first(Object? raw, {String fallback = ''}) {
    final List<Object?> list = asListSafe(raw);
    for (final Object? item in list) {
      final String value = strSafe(item);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }
}
