import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V6 AniList 源（D113，实测 GraphQL POST 可用）：动漫封面/横幅静帧；
/// 人名意图走 Staff → staffMedia，按作品分组（D114）。
class AniListSource implements SearchSource {
  AniListSource({Dio? dio})
      : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  static const String _endpoint = 'https://graphql.anilist.co';

  @override
  String get id => 'anilist';
  @override
  String get label => 'AniList';
  @override
  SourceCapability get capability => const SourceCapability(
        byTitle: true,
        byPerson: true,
        byKeyword: true,
        domains: <ImageDomain>{ImageDomain.film},
        requiresKey: false,
      );

  @override
  bool get enabled => true;

  @override
  String get disabledHint => '';

  static const String _mediaQuery = '''
query (\$search: String, \$page: Int, \$perPage: Int) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { hasNextPage }
    media(search: \$search, type: ANIME, isAdult: false) {
      id
      title { romaji english native }
      coverImage { large extraLarge }
      bannerImage
      startDate { year }
      format
      siteUrl
    }
  }
}''';

  static const String _staffQuery = '''
query (\$search: String) {
  Staff(search: \$search) {
    id
    name { full }
    staffMedia(perPage: 12, sort: [POPULARITY_DESC]) {
      nodes {
        id
        title { romaji english native }
        coverImage { large extraLarge }
        bannerImage
        startDate { year }
        format
        siteUrl
      }
    }
  }
}''';

  @override
  Future<SourceSearchPage> search(
    SearchQuery query, {
    int page = 1,
    int perPage = 24,
  }) async {
    final String text = query.forSource(id);
    if (text.trim().isEmpty) {
      return const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
    }
    if (query.intent == SearchIntent.person) {
      final String person = query.person.isNotEmpty ? query.person : text;
      final Response<Object?> res = await _dio.post<Object?>(
        _endpoint,
        data: <String, Object?>{
          'query': _staffQuery,
          'variables': <String, Object?>{'search': person},
        },
      );
      final Map<String, Object?> data = asMapSafe(res.data);
      final Map<String, Object?> root = asMapSafe(data['data']);
      final Map<String, Object?> staff = asMapSafe(root['Staff']);
      if (staff.isEmpty) {
        return const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
      }
      final List<SearchHit> hits = parseStaff(staff);
      return SourceSearchPage(
          hits: hits.take(perPage).toList(), hasMore: hits.length > perPage);
    }
    final Response<Object?> res = await _dio.post<Object?>(
      _endpoint,
      data: <String, Object?>{
        'query': _mediaQuery,
        'variables': <String, Object?>{
          'search': text,
          'page': page,
          'perPage': perPage.clamp(1, 50),
        },
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final Map<String, Object?> root = asMapSafe(data['data']);
    final Map<String, Object?> pageData = asMapSafe(root['Page']);
    final List<SearchHit> hits = parseMedia(pageData);
    final Map<String, Object?> pageInfo = asMapSafe(pageData['pageInfo']);
    return SourceSearchPage(
      hits: hits,
      hasMore: pageInfo['hasNextPage'] == true,
    );
  }

  /// 解析 Page.media 响应（fixture 测试用）。
  static List<SearchHit> parseMedia(Map<String, Object?> pageData) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(pageData['media'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final Map<String, Object?> title = asMapSafe(m['title']);
      final String name = _titleOf(title);
      if (name.isEmpty) continue;
      final Map<String, Object?> cover = asMapSafe(m['coverImage']);
      final String banner = strSafe(m['bannerImage']);
      final String thumb =
          strSafe(cover['large'], strSafe(cover['extraLarge']));
      final String full =
          banner.isNotEmpty ? banner : strSafe(cover['extraLarge'], thumb);
      if (full.isEmpty) continue;
      final String year = strSafe(asMapSafe(m['startDate'])['year']);
      out.add(SearchHit(
        id: hitId(
            'anilist', strSafe(m['siteUrl'], '$name-${intSafe(m['id'])}')),
        title: '$name${year.isEmpty ? '' : '（$year）'}',
        thumbUrl: thumb.isEmpty ? full : thumb,
        fullUrl: full,
        sourceId: 'anilist',
        sourceLabel: 'AniList',
        license: 'AniList（版权归制作方，个人参考）',
        commercialOk: false,
        attribution: 'AniList · $name',
        sourcePageUrl: strSafe(m['siteUrl']),
        group: name,
        domain: ImageDomain.film,
        imageType: banner.isNotEmpty ? 'still' : 'poster',
        extra: <String, Object?>{'format': strSafe(m['format'])},
      ));
    }
    return out;
  }

  /// 解析 Staff.staffMedia 响应（人名 → 作品分组，D114）。
  static List<SearchHit> parseStaff(Map<String, Object?> staff) {
    final Map<String, Object?> media = asMapSafe(staff['staffMedia']);
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(media['nodes'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final String name = _titleOf(asMapSafe(m['title']));
      if (name.isEmpty) continue;
      final Map<String, Object?> cover = asMapSafe(m['coverImage']);
      final String banner = strSafe(m['bannerImage']);
      final String thumb =
          strSafe(cover['large'], strSafe(cover['extraLarge']));
      final String full =
          banner.isNotEmpty ? banner : strSafe(cover['extraLarge'], thumb);
      if (full.isEmpty) continue;
      out.add(SearchHit(
        id: hitId('anilist', 'staff-${intSafe(m['id'])}'),
        title: name,
        thumbUrl: thumb.isEmpty ? full : thumb,
        fullUrl: full,
        sourceId: 'anilist',
        sourceLabel: 'AniList',
        license: 'AniList（版权归制作方，个人参考）',
        commercialOk: false,
        attribution: 'AniList · $name',
        sourcePageUrl: strSafe(m['siteUrl']),
        group: name,
        domain: ImageDomain.film,
        imageType: banner.isNotEmpty ? 'still' : 'poster',
      ));
    }
    return out;
  }

  static String _titleOf(Map<String, Object?> title) => strSafe(
        title['english'],
        strSafe(title['romaji'], strSafe(title['native'])),
      );
}
