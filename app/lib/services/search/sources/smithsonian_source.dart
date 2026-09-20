import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// 史密森尼源（D98 Key 预留）：api.si.edu 开放访问 API。
class SmithsonianSource implements SearchSource {
  SmithsonianSource(this.apiKey, {Dio? dio})
      : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final String apiKey;
  final Dio _dio;

  @override
  String get id => 'smithsonian';
  @override
  String get label => '史密森尼';
  @override
  SourceCapability get capability => const SourceCapability(
        byTitle: true,
        byPerson: true,
        byKeyword: true,
        hasLicenseFilter: true,
        domains: <ImageDomain>{ImageDomain.art},
        requiresKey: true,
        keySettingId: 'search_key_smithsonian',
      );

  @override
  bool get enabled => apiKey.trim().isNotEmpty;

  @override
  String get disabledHint => '缺 Smithsonian Key（设置 → 图片素材通道）';

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
    final int start = (page - 1) * perPage;
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.si.edu/openaccess/api/v1.0/search',
      queryParameters: <String, Object?>{
        'api_key': apiKey.trim(),
        'q': text,
        'rows': perPage.clamp(1, 100),
        'start': start,
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final Map<String, Object?> response = asMapSafe(data['response']);
    final List<SearchHit> hits = parse(response);
    final int total = intSafe(response['rowCount'], hits.length);
    return SourceSearchPage(hits: hits, hasMore: start + perPage < total);
  }

  /// 解析 openaccess 搜索响应（fixture 测试用）。
  static List<SearchHit> parse(Map<String, Object?> response) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(response['rows'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final Map<String, Object?> content = asMapSafe(m['content']);
      final Map<String, Object?> dnr =
          asMapSafe(content['descriptiveNonRepeating']);
      final Map<String, Object?> media = asMapSafe(dnr['online_media']);
      Map<String, Object?>? picked;
      for (final Object? entry in asListSafe(media['media'])) {
        final Map<String, Object?> candidate = asMapSafe(entry);
        final String src = strSafe(candidate['content']);
        if (src.isEmpty) continue;
        if (src.toLowerCase().contains('.pdf')) continue;
        picked = candidate;
        break;
      }
      if (picked == null) continue;
      final String full = strSafe(picked['content']);
      final String thumb = strSafe(picked['thumbnail'], full);
      final String title = strSafe(m['title'], 'Smithsonian 藏品');
      final String access =
          strSafe(asMapSafe(picked['usage'])['access']).toUpperCase();
      final bool commercial = access.contains('CC0');
      final String recordLink = strSafe(dnr['record_link']);
      out.add(SearchHit(
        id: hitId('smithsonian', strSafe(m['id'], full)),
        title: title,
        thumbUrl: thumb,
        fullUrl: full,
        sourceId: 'smithsonian',
        sourceLabel: '史密森尼',
        license: commercial
            ? 'CC0 / Public Domain'
            : (access.isEmpty ? 'Smithsonian（许可未知）' : access),
        commercialOk: commercial,
        attribution:
            'Smithsonian${strSafe(dnr['unit_code']).isEmpty ? '' : ' · ${dnr['unit_code']}'}',
        sourcePageUrl: recordLink,
        domain: ImageDomain.art,
        imageType: 'artwork',
      ));
    }
    return out;
  }
}
