import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// 影视作品（TMDB 检索结果）。
class TmdbWork {
  const TmdbWork({
    required this.id,
    required this.mediaType,
    required this.title,
    this.year = '',
    this.posterPath = '',
    this.popularity = 0,
  });

  final int id;
  final String mediaType; // movie | tv | person
  final String title;
  final String year;
  final String posterPath;
  final double popularity;

  String get posterThumb =>
      posterPath.isEmpty ? '' : 'https://image.tmdb.org/t/p/w300$posterPath';
  String get posterFull =>
      posterPath.isEmpty ? '' : 'https://image.tmdb.org/t/p/w780$posterPath';
  String get pageUrl => mediaType == 'tv'
      ? 'https://www.themoviedb.org/tv/$id'
      : 'https://www.themoviedb.org/movie/$id';
}

/// V6 TMDB 主源（D113）：作品/人名/剧照分页，按作品分组（D114）。
/// v3 api_key 与 v4 Bearer Token 均可；仅检索展示，不做离线再分发。
class TmdbImageSource implements SearchSource {
  TmdbImageSource({
    this.apiKey = '',
    this.readToken = '',
    Dio? dio,
    this.language = 'zh-CN',
  }) : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final String apiKey;
  final String readToken;
  final String language;
  final Dio _dio;

  @override
  String get id => 'tmdb';
  @override
  String get label => 'TMDB';
  @override
  SourceCapability get capability => const SourceCapability(
    byTitle: true,
    byPerson: true,
    byKeyword: true,
    domains: <ImageDomain>{ImageDomain.film},
    requiresKey: true,
    keySettingId: 'image_tmdb_key',
  );

  @override
  bool get enabled => apiKey.trim().isNotEmpty || readToken.trim().isNotEmpty;

  @override
  String get disabledHint => '缺 TMDB Key/Token（设置 → 图片素材通道）';

  Options _options() => Options(
    headers: <String, Object?>{
      if (readToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${readToken.trim()}',
    },
  );

  Map<String, Object?> _params(Map<String, Object?> extra) => <String, Object?>{
    if (readToken.trim().isEmpty && apiKey.trim().isNotEmpty)
      'api_key': apiKey.trim(),
    'language': language,
    ...extra,
  };

  @override
  Future<SourceSearchPage> search(
    SearchQuery query, {
    int page = 1,
    int perPage = 24,
  }) async {
    if (!enabled) {
      throw StateError(disabledHint);
    }
    final List<SearchHit> hits = <SearchHit>[];
    bool hasMore = false;
    if (query.intent == SearchIntent.person) {
      final String person = query.person.isNotEmpty ? query.person : query.text;
      final TmdbWork? found = await _findPerson(person);
      if (found == null) {
        return const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
      }
      final _CreditPage credits = await _credits(found.id, page: page);
      hasMore = credits.hasMore;
      hits.addAll(
        await _expandWorks(
          credits.works.take(perPage).toList(),
          expandLimit: 4,
          groupOverride: '',
        ),
      );
      return SourceSearchPage(hits: hits, hasMore: hasMore);
    }
    final String text =
        query.intent == SearchIntent.title && query.title.isNotEmpty
        ? query.title
        : query.forSource(id);
    if (text.trim().isEmpty) {
      return const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
    }
    final _WorkPage works = await _searchWorks(text, page: page);
    if (works.works.isEmpty && page == 1) {
      // 兜底：作品检索为空时按人名再试（D114：人名 → 作品分组）。
      final TmdbWork? person = await _findPerson(text);
      if (person != null) {
        final _CreditPage credits = await _credits(person.id, page: 1);
        hits.addAll(
          await _expandWorks(
            credits.works.take(perPage).toList(),
            expandLimit: 4,
            groupOverride: '',
          ),
        );
        return SourceSearchPage(hits: hits, hasMore: credits.hasMore);
      }
    }
    hasMore = works.hasMore;
    hits.addAll(
      await _expandWorks(
        works.works.take(perPage).toList(),
        expandLimit: 4,
        groupOverride: '',
      ),
    );
    return SourceSearchPage(hits: hits, hasMore: hasMore);
  }

  Future<TmdbWork?> _findPerson(String name) async {
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.themoviedb.org/3/search/person',
      queryParameters: _params(<String, Object?>{
        'query': name,
        'include_adult': false,
      }),
      options: _options(),
    );
    final List<TmdbWork> people = parseSearch(res.data);
    final List<TmdbWork> sorted = List<TmdbWork>.of(people)
      ..sort((TmdbWork a, TmdbWork b) => b.popularity.compareTo(a.popularity));
    return sorted.isEmpty ? null : sorted.first;
  }

  Future<_CreditPage> _credits(int personId, {int page = 1}) async {
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.themoviedb.org/3/person/$personId/combined_credits',
      queryParameters: _params(<String, Object?>{}),
      options: _options(),
    );
    final List<TmdbWork> works = parseCredits(res.data);
    const int pageSize = 12;
    final int start = (page - 1) * pageSize;
    final List<TmdbWork> slice = start >= works.length
        ? <TmdbWork>[]
        : works.sublist(start, (start + pageSize).clamp(0, works.length));
    return _CreditPage(works: slice, hasMore: start + pageSize < works.length);
  }

  Future<_WorkPage> _searchWorks(String text, {int page = 1}) async {
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.themoviedb.org/3/search/multi',
      queryParameters: _params(<String, Object?>{
        'query': text,
        'page': page,
        'include_adult': false,
      }),
      options: _options(),
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<TmdbWork> works = parseSearch(res.data)
        .where((TmdbWork w) => w.mediaType == 'movie' || w.mediaType == 'tv')
        .toList();
    final int totalPages = intSafe(data['total_pages'], 1);
    return _WorkPage(works: works, hasMore: page < totalPages);
  }

  /// 展开作品图集：前 [expandLimit] 部抓 backdrops，其余仅海报。
  Future<List<SearchHit>> _expandWorks(
    List<TmdbWork> works, {
    required int expandLimit,
    required String groupOverride,
  }) async {
    final List<SearchHit> hits = <SearchHit>[];
    for (var i = 0; i < works.length; i++) {
      final TmdbWork work = works[i];
      final String group = groupOverride.isNotEmpty
          ? groupOverride
          : work.title;
      if (i < expandLimit) {
        try {
          final List<SearchHit> stills = await _workImages(work, group);
          hits.addAll(stills);
          if (stills.isNotEmpty) continue;
        } catch (_) {
          // 单作品失败降级为海报，不影响整体（R41 局部错误不致命）。
        }
      }
      if (work.posterFull.isNotEmpty) {
        hits.add(
          SearchHit(
            id: hitId(id, '${work.mediaType}:${work.id}:poster'),
            title: '${work.title}${work.year.isEmpty ? '' : '（${work.year}）'}',
            thumbUrl: work.posterThumb,
            fullUrl: work.posterFull,
            sourceId: id,
            sourceLabel: 'TMDB',
            license: 'TMDB 海报（个人参考）',
            commercialOk: false,
            attribution: 'TMDB · ${work.title}',
            sourcePageUrl: work.pageUrl,
            width: 500,
            height: 750,
            group: group,
            domain: ImageDomain.film,
            imageType: 'poster',
          ),
        );
      }
    }
    return hits;
  }

  Future<List<SearchHit>> _workImages(TmdbWork work, String group) async {
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.themoviedb.org/3/${work.mediaType}/${work.id}/images',
      queryParameters: _params(<String, Object?>{
        'include_image_language': 'zh,en,null',
      }),
      options: _options(),
    );
    final List<SearchHit> hits = parseImages(
      res.data,
      work: work,
      group: group,
    );
    if (work.mediaType == 'tv') {
      // 剧集/动漫：补分集 stills（V3 关键来源，V6 保留）。
      try {
        final Response<Object?> season = await _dio.get<Object?>(
          'https://api.themoviedb.org/3/tv/${work.id}/season/1',
          queryParameters: _params(<String, Object?>{}),
          options: _options(),
        );
        hits.addAll(parseEpisodeStills(season.data, work: work, group: group));
      } catch (_) {
        // 分集失败不影响主图集（R41 局部错误）。
      }
    }
    return hits;
  }

  /// 解析 search/multi 或 search/person 响应。
  static List<TmdbWork> parseSearch(Object? raw) {
    final List<Object?> results = asListSafe(asMapSafe(raw)['results']);
    final List<TmdbWork> out = <TmdbWork>[];
    for (final Object? item in results) {
      final Map<String, Object?> m = asMapSafe(item);
      final String mediaType = strSafe(
        m['media_type'],
        m.containsKey('known_for') ? 'person' : 'movie',
      );
      final String date = strSafe(
        m['release_date'],
        strSafe(m['first_air_date']),
      );
      final String title = strSafe(
        m['title'],
        strSafe(m['name'], strSafe(m['original_title'])),
      );
      if (title.isEmpty) continue;
      out.add(
        TmdbWork(
          id: intSafe(m['id']),
          mediaType: mediaType,
          title: title,
          year: date.length >= 4 ? date.substring(0, 4) : '',
          posterPath: strSafe(m['poster_path']),
          popularity: (m['popularity'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return out;
  }

  /// 解析 person/combined_credits（cast+crew 合并，按热度）。
  static List<TmdbWork> parseCredits(Object? raw) {
    final Map<String, Object?> data = asMapSafe(raw);
    final List<TmdbWork> out = <TmdbWork>[];
    final Set<String> seen = <String>{};
    for (final String key in <String>['cast', 'crew']) {
      for (final Object? item in asListSafe(data[key])) {
        final Map<String, Object?> m = asMapSafe(item);
        final String mediaType = strSafe(m['media_type']);
        if (mediaType != 'movie' && mediaType != 'tv') continue;
        final String title = strSafe(m['title'], strSafe(m['name']));
        final int workId = intSafe(m['id']);
        if (title.isEmpty || workId == 0) continue;
        if (!seen.add('$mediaType:$workId')) continue;
        final String date = strSafe(
          m['release_date'],
          strSafe(m['first_air_date']),
        );
        out.add(
          TmdbWork(
            id: workId,
            mediaType: mediaType,
            title: title,
            year: date.length >= 4 ? date.substring(0, 4) : '',
            posterPath: strSafe(m['poster_path']),
            popularity: (m['popularity'] as num?)?.toDouble() ?? 0,
          ),
        );
      }
    }
    out.sort((TmdbWork a, TmdbWork b) => b.popularity.compareTo(a.popularity));
    return out;
  }

  /// 解析 /tv/{id}/season/1 响应为分集静帧条目。
  static List<SearchHit> parseEpisodeStills(
    Object? raw, {
    required TmdbWork work,
    String group = '',
  }) {
    final List<SearchHit> out = <SearchHit>[];
    final String label = group.isNotEmpty ? group : work.title;
    for (final Object? item in asListSafe(asMapSafe(raw)['episodes']).take(6)) {
      final Map<String, Object?> m = asMapSafe(item);
      final String still = strSafe(m['still_path']);
      if (still.isEmpty) continue;
      final int no = intSafe(m['episode_number']);
      out.add(
        SearchHit(
          id: hitId('tmdb', still),
          title: '$label · 第 ${no == 0 ? '?' : no} 集',
          thumbUrl: 'https://image.tmdb.org/t/p/w300$still',
          fullUrl: 'https://image.tmdb.org/t/p/w1280$still',
          sourceId: 'tmdb',
          sourceLabel: 'TMDB',
          license: 'TMDB 剧照（个人参考）',
          commercialOk: false,
          attribution: 'TMDB · ${work.title}',
          sourcePageUrl: work.pageUrl,
          width: intSafe(m['width']),
          height: intSafe(m['height']),
          group: label,
          domain: ImageDomain.film,
          imageType: 'still',
          extra: <String, Object?>{'episode': no},
        ),
      );
    }
    return out;
  }

  /// 解析 /images 响应为剧照条目。
  static List<SearchHit> parseImages(
    Object? raw, {
    required TmdbWork work,
    String group = '',
  }) {
    final Map<String, Object?> data = asMapSafe(raw);
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['backdrops']).take(10)) {
      final Map<String, Object?> m = asMapSafe(item);
      final String path = strSafe(m['file_path']);
      if (path.isEmpty) continue;
      final int w = intSafe(m['width']);
      final int h = intSafe(m['height']);
      final String label = group.isNotEmpty ? group : work.title;
      out.add(
        SearchHit(
          id: hitId('tmdb', path),
          title: '$label · 剧照',
          thumbUrl: 'https://image.tmdb.org/t/p/w300$path',
          fullUrl: 'https://image.tmdb.org/t/p/w1280$path',
          sourceId: 'tmdb',
          sourceLabel: 'TMDB',
          license: 'TMDB 剧照（个人参考）',
          commercialOk: false,
          attribution: 'TMDB · ${work.title}',
          sourcePageUrl: work.pageUrl,
          width: w,
          height: h,
          group: label,
          domain: ImageDomain.film,
          imageType: 'still',
        ),
      );
    }
    return out;
  }
}

class _WorkPage {
  const _WorkPage({required this.works, required this.hasMore});
  final List<TmdbWork> works;
  final bool hasMore;
}

class _CreditPage {
  const _CreditPage({required this.works, required this.hasMore});
  final List<TmdbWork> works;
  final bool hasMore;
}
