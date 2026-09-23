import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V7 SMK（丹麦国立美术馆）源（D134 免 Key）：仅取 public_domain=1 条目。
class SmkSource implements SearchSource {
  SmkSource({Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  static const String _base = 'https://api.smk.dk/api/v1/art/search/';

  @override
  String get id => 'smk';

  @override
  String get label => 'SMK 丹麦国立美术馆';

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
    final int limit = perPage.clamp(1, 100);
    final Response<Object?> res = await _dio.get<Object?>(
      _base,
      queryParameters: <String, Object?>{
        'keys': text,
        'offset': (page - 1) * limit,
        'limit': limit,
        'filters': '[has_image:true],[public_domain:true]',
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    final int found = intSafe(data['found'], hits.length);
    return SourceSearchPage(hits: hits, hasMore: page * limit < found);
  }

  /// 解析 art/search 响应（fixture 测试用）：非 public_domain 条目剔除。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['items'])) {
      final Map<String, Object?> m = asMapSafe(item);
      if (m['public_domain'] != true) continue;
      final String thumb = strSafe(m['image_thumbnail']);
      final String full = strSafe(m['image_native'], thumb);
      if (full.isEmpty) continue;
      final String title = _firstTitle(m['titles']);
      final String creator = _firstCreator(m['production']);
      final String objectNumber = strSafe(m['object_number']);
      out.add(
        SearchHit(
          id: hitId('smk', objectNumber.isEmpty ? full : objectNumber),
          title: title.isEmpty ? '未命名作品' : title,
          thumbUrl: thumb.isEmpty ? full : thumb,
          fullUrl: full,
          sourceId: 'smk',
          sourceLabel: 'SMK',
          license: 'CC0 / Public Domain',
          licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
          commercialOk: true,
          attribution: creator.isEmpty ? 'SMK' : 'SMK · $creator',
          sourcePageUrl: objectNumber.isEmpty
              ? ''
              : 'https://open.smk.dk/en/artwork/image/$objectNumber',
          width: intSafe(m['image_width']),
          height: intSafe(m['image_height']),
          domain: ImageDomain.art,
          imageType: 'artwork',
        ),
      );
    }
    return out;
  }

  static String _firstTitle(Object? raw) {
    for (final Object? item in asListSafe(raw)) {
      final String title = strSafe(asMapSafe(item)['title']);
      if (title.isNotEmpty) return title;
    }
    return '';
  }

  static String _firstCreator(Object? raw) {
    for (final Object? item in asListSafe(raw)) {
      final String creator = strSafe(asMapSafe(item)['creator']);
      if (creator.isNotEmpty) return creator;
    }
    return '';
  }
}
