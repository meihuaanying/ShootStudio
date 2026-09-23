import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V7 Wellcome Collection 源（D134 免 Key）：逐图许可（CC-BY/PDM 等）。
class WellcomeSource implements SearchSource {
  WellcomeSource({Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  static const String _base =
      'https://api.wellcomecollection.org/catalogue/v2/images';

  @override
  String get id => 'wellcome';

  @override
  String get label => 'Wellcome Collection';

  @override
  SourceCapability get capability => const SourceCapability(
    byTitle: true,
    byPerson: true,
    byKeyword: true,
    hasLicenseFilter: true,
    domains: <ImageDomain>{ImageDomain.art, ImageDomain.photo},
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
        'query': text,
        'page': page,
        'pageSize': perPage.clamp(1, 100),
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    final int total = intSafe(data['totalResults'], hits.length);
    return SourceSearchPage(hits: hits, hasMore: page * perPage < total);
  }

  /// 解析 v2/images 响应（fixture 测试用）。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['results'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final Map<String, Object?> thumb = asMapSafe(m['thumbnail']);
      final Map<String, Object?> loc = asListSafe(m['locations']).isNotEmpty
          ? asMapSafe(asListSafe(m['locations']).first)
          : <String, Object?>{};
      final Map<String, Object?> lic = asMapSafe(thumb['license']).isNotEmpty
          ? asMapSafe(thumb['license'])
          : asMapSafe(loc['license']);
      final String thumbUrl = strSafe(thumb['url']);
      final String fullUrl = strSafe(loc['url'], thumbUrl);
      if (fullUrl.isEmpty) continue;
      final Map<String, Object?> source = asMapSafe(m['source']);
      final String title = strSafe(source['title'], '未命名作品');
      final String creator = _firstCreator(source['creators']);
      final String licenseId = strSafe(lic['id']);
      final String licenseLabel = strSafe(
        lic['label'],
        openLicenseLabel(licenseId),
      );
      final String id = strSafe(m['id'], fullUrl);
      out.add(
        SearchHit(
          id: hitId('wellcome', id),
          title: title,
          thumbUrl: thumbUrl.isEmpty ? fullUrl : thumbUrl,
          fullUrl: fullUrl,
          sourceId: 'wellcome',
          sourceLabel: 'Wellcome Collection',
          license: licenseLabel.isEmpty ? '许可未标注' : licenseLabel,
          licenseUrl: strSafe(lic['url']),
          commercialOk: isCommercialLicense('$licenseId $licenseLabel'),
          attribution: creator.isEmpty
              ? 'Wellcome Collection'
              : 'Wellcome Collection · $creator',
          sourcePageUrl: 'https://wellcomecollection.org/images/$id',
          domain: ImageDomain.art,
          imageType: 'artwork',
          description: strSafe(source['id']),
        ),
      );
    }
    return out;
  }

  static String _firstCreator(Object? raw) {
    for (final Object? item in asListSafe(raw)) {
      final Map<String, Object?> m = asMapSafe(item);
      final String label = strSafe(m['label']);
      if (label.isNotEmpty) return label;
    }
    return '';
  }
}
