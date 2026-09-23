import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V7 Openverse 聚合源（D134 免 Key）：CC/PD 许可逐图标注。
class OpenverseSource implements SearchSource {
  OpenverseSource({Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  static const String _base = 'https://api.openverse.org/v1/images/';

  /// 全收但逐图标注（R63）：CC 全系 + PDM。
  static const String licenses =
      'cc0,pdm,by,by-sa,by-nd,by-nc,by-nc-sa,by-nc-nd';

  @override
  String get id => 'openverse';

  @override
  String get label => 'Openverse（CC 聚合）';

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
    final Response<Object?> res = await _dio.get<Object?>(
      _base,
      queryParameters: <String, Object?>{
        'q': text,
        'page': page,
        'page_size': perPage.clamp(1, 50),
        'license': licenses,
        'mature': 'false',
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    final int count = intSafe(data['result_count'], hits.length);
    return SourceSearchPage(hits: hits, hasMore: page * perPage < count);
  }

  /// 解析 /v1/images/ 响应（fixture 测试用）。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['results'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final String full = strSafe(m['url']);
      final String thumb = strSafe(m['thumbnail'], full);
      if (full.isEmpty) continue;
      final String rawLicense = strSafe(m['license']);
      final String version = strSafe(m['license_version']);
      final String label = openLicenseLabel(rawLicense, version);
      final String title = strSafe(m['title'], '未命名作品');
      final String creator = strSafe(m['creator']);
      final String pageUrl = strSafe(m['foreign_landing_url']);
      out.add(
        SearchHit(
          id: hitId('openverse', strSafe(m['id'], full)),
          title: title,
          thumbUrl: thumb,
          fullUrl: full,
          sourceId: 'openverse',
          sourceLabel: 'Openverse',
          license: label,
          licenseUrl: strSafe(m['license_url']),
          commercialOk: isCommercialLicense(label),
          attribution: creator.isEmpty ? 'Openverse' : 'Openverse · $creator',
          sourcePageUrl: pageUrl,
          width: intSafe(m['width']),
          height: intSafe(m['height']),
          domain: ImageDomain.photo,
          imageType: 'photo',
          description: strSafe(m['source']),
          extra: <String, Object?>{'provider': strSafe(m['provider'])},
        ),
      );
    }
    return out;
  }
}
