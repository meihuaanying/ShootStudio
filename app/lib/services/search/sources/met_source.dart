import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V6 大都会艺术博物馆源（D115 免 Key 主源）：开放 API + 公有领域标记。
/// 搜索返回 objectID 列表，再并发取对象详情（限流 6 并发）。
class MetSource implements SearchSource {
  MetSource({Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  static const String _base =
      'https://collectionapi.metmuseum.org/public/collection/v1';

  @override
  String get id => 'met';
  @override
  String get label => '大都会博物馆';
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
      '$_base/search',
      queryParameters: <String, Object?>{'q': text, 'hasImages': true},
    );
    final List<int> ids = parseSearch(res.data);
    final int start = (page - 1) * perPage;
    if (start >= ids.length) {
      return const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
    }
    final List<int> slice = ids.sublist(
      start,
      (start + perPage).clamp(0, ids.length),
    );
    final List<SearchHit?> hits = await mapLimit<int, SearchHit?>(
      slice,
      6,
      (int objectId, int _) => _object(objectId),
    );
    return SourceSearchPage(
      hits: hits.whereType<SearchHit>().toList(),
      hasMore: start + perPage < ids.length,
    );
  }

  Future<SearchHit?> _object(int objectId) async {
    try {
      final Response<Object?> res = await _dio.get<Object?>(
        '$_base/objects/$objectId',
      );
      return parseObject(asMapSafe(res.data));
    } catch (_) {
      return null;
    }
  }

  /// 解析 /search 响应为 objectID 列表（fixture 测试用）。
  static List<int> parseSearch(Object? raw) {
    final Map<String, Object?> data = asMapSafe(raw);
    final List<int> ids = <int>[];
    for (final Object? id in asListSafe(data['objectIDs'])) {
      final int value = intSafe(id);
      if (value != 0) ids.add(value);
    }
    return ids;
  }

  /// 解析 /objects/{id} 响应为条目（fixture 测试用）。
  static SearchHit? parseObject(Map<String, Object?> data) {
    final String small = strSafe(data['primaryImageSmall']);
    final String full = strSafe(data['primaryImage'], small);
    if (full.isEmpty) return null;
    final String title = strSafe(data['title'], '未命名作品');
    final String artist = strSafe(data['artistDisplayName']);
    final bool publicDomain = data['isPublicDomain'] == true;
    final int objectId = intSafe(data['objectID']);
    final String pageUrl = strSafe(
      data['objectURL'],
      objectId == 0
          ? ''
          : 'https://www.metmuseum.org/art/collection/search/$objectId',
    );
    return SearchHit(
      id: hitId('met', pageUrl.isEmpty ? full : pageUrl),
      title: title,
      thumbUrl: small.isEmpty ? full : small,
      fullUrl: full,
      sourceId: 'met',
      sourceLabel: '大都会博物馆',
      license: publicDomain ? 'CC0 / Public Domain' : '© 艺术家/博物馆（非商用参考）',
      licenseUrl: publicDomain
          ? 'https://creativecommons.org/publicdomain/zero/1.0/'
          : '',
      commercialOk: publicDomain,
      attribution:
          'The Met${artist.isEmpty ? '' : ' · $artist'}${strSafe(data['objectDate']).isEmpty ? '' : ' · ${data['objectDate']}'}',
      sourcePageUrl: pageUrl,
      domain: ImageDomain.art,
      imageType: 'artwork',
      description: strSafe(data['medium']),
      extra: <String, Object?>{
        'department': strSafe(data['department']),
        'objectId': objectId,
      },
    );
  }
}
