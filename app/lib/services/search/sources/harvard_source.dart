import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// 哈佛艺术博物馆源（D98 Key 预留）：imagepermissionlevel==0 视为开放。
class HarvardSource implements SearchSource {
  HarvardSource(this.apiKey, {Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final String apiKey;
  final Dio _dio;

  @override
  String get id => 'harvard';
  @override
  String get label => '哈佛艺术博物馆';
  @override
  SourceCapability get capability => const SourceCapability(
    byTitle: true,
    byPerson: true,
    byKeyword: true,
    hasLicenseFilter: true,
    domains: <ImageDomain>{ImageDomain.art},
    requiresKey: true,
    keySettingId: 'search_key_harvard',
  );

  @override
  bool get enabled => apiKey.trim().isNotEmpty;

  @override
  String get disabledHint => '缺 Harvard Key（设置 → 图片素材通道）';

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
      'https://api.harvardartmuseums.org/object',
      queryParameters: <String, Object?>{
        'apikey': apiKey.trim(),
        'q': text,
        'size': perPage.clamp(1, 100),
        'page': page,
        'hasimage': 1,
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    final Map<String, Object?> info = asMapSafe(data['info']);
    final int current = intSafe(info['page'], page);
    final int pages = intSafe(info['pages'], 1);
    return SourceSearchPage(hits: hits, hasMore: current < pages);
  }

  /// 解析 /object 响应（fixture 测试用）。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['records'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final String full = strSafe(m['primaryimageurl']);
      if (full.isEmpty) continue;
      final String title = strSafe(m['title'], '未命名作品');
      final bool open = intSafe(m['imagepermissionlevel'], 1) == 0;
      final String people = _people(m['people']);
      final String pageUrl = strSafe(m['url']);
      out.add(
        SearchHit(
          id: hitId('harvard', strSafe(m['id'], full)),
          title: title,
          thumbUrl: full,
          fullUrl: full,
          sourceId: 'harvard',
          sourceLabel: '哈佛艺术博物馆',
          license: open ? 'Harvard Open Access（无已知限制）' : '© 哈佛艺术博物馆（非商用参考）',
          commercialOk: open,
          attribution:
              'Harvard Art Museums${people.isEmpty ? '' : ' · $people'}',
          sourcePageUrl: pageUrl,
          domain: ImageDomain.art,
          imageType: 'artwork',
          extra: <String, Object?>{'dated': strSafe(m['dated'])},
        ),
      );
    }
    return out;
  }

  static String _people(Object? raw) {
    for (final Object? item in asListSafe(raw)) {
      final String name = strSafe(asMapSafe(item)['name']);
      if (name.isNotEmpty) return name;
    }
    return '';
  }
}
