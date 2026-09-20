import 'package:dio/dio.dart';

/// V3：TMDB 剧照/动漫静帧（D51）。支持 v3 api_key 与 v4 Bearer Token。
/// 仅用于检索与展示，不做任何离线再分发。
class TmdbItem {
  const TmdbItem({
    required this.id,
    required this.mediaType,
    required this.title,
    this.year = '',
    this.posterPath = '',
  });

  final int id;
  final String mediaType; // movie | tv
  final String title;
  final String year;
  final String posterPath;

  String get posterUrl =>
      posterPath.isEmpty ? '' : 'https://image.tmdb.org/t/p/w200$posterPath';
}

class TmdbImage {
  const TmdbImage({
    required this.filePath,
    required this.width,
    required this.height,
    this.isStill = false,
  });

  final String filePath;
  final int width;
  final int height;
  final bool isStill;

  String url(String size) => 'https://image.tmdb.org/t/p/$size$filePath';
}

class TmdbSource {
  TmdbSource({required this.apiKey, required this.readToken, Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));

  final String apiKey;
  final String readToken;
  final Dio _dio;

  bool get configured => apiKey.isNotEmpty || readToken.isNotEmpty;

  Options _options() => Options(
    headers: <String, Object?>{
      if (readToken.isNotEmpty) 'Authorization': 'Bearer $readToken',
    },
  );

  Map<String, Object?> _params(Map<String, Object?> extra) => <String, Object?>{
    if (readToken.isEmpty && apiKey.isNotEmpty) 'api_key': apiKey,
    ...extra,
  };

  /// 中国区常用语言：zh-CN 优先。
  Future<List<TmdbItem>> search(
    String query, {
    String mediaType = 'multi',
  }) async {
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.themoviedb.org/3/search/$mediaType',
      queryParameters: _params(<String, Object?>{
        'query': query,
        'language': 'zh-CN',
        'include_adult': false,
      }),
      options: _options(),
    );
    final List<Object?> results =
        ((res.data as Map?)?['results'] as List<Object?>?) ?? <Object?>[];
    final List<TmdbItem> out = <TmdbItem>[];
    for (final Object? raw in results) {
      if (raw is! Map) continue;
      final String mt = mediaType == 'multi'
          ? '${raw['media_type'] ?? 'movie'}'
          : mediaType;
      if (mt != 'movie' && mt != 'tv') continue;
      final String date =
          '${raw['release_date'] ?? raw['first_air_date'] ?? ''}';
      out.add(
        TmdbItem(
          id: (raw['id'] as num?)?.toInt() ?? 0,
          mediaType: mt,
          title:
              '${raw['title'] ?? raw['name'] ?? raw['original_title'] ?? ''}',
          year: date.length >= 4 ? date.substring(0, 4) : '',
          posterPath: '${raw['poster_path'] ?? ''}',
        ),
      );
    }
    return out.where((TmdbItem t) => t.id != 0 && t.title.isNotEmpty).toList();
  }

  /// 影片/剧集剧照（电影用 backdrops；剧集额外抓分集 stills，覆盖动漫分镜）。
  Future<List<TmdbImage>> images(TmdbItem item, {int episodeFetch = 4}) async {
    final List<TmdbImage> out = <TmdbImage>[];
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.themoviedb.org/3/${item.mediaType}/${item.id}/images',
      queryParameters: _params(<String, Object?>{
        'include_image_language': 'zh,en,null',
      }),
      options: _options(),
    );
    final Map<String, Object?> data =
        ((res.data as Map?) ?? <String, Object?>{}).cast<String, Object?>();
    for (final Object? raw
        in (data['backdrops'] as List<Object?>? ?? <Object?>[]).take(12)) {
      if (raw is! Map) continue;
      out.add(
        TmdbImage(
          filePath: '${raw['file_path'] ?? ''}',
          width: (raw['width'] as num?)?.toInt() ?? 0,
          height: (raw['height'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    if (item.mediaType == 'tv') {
      // 分集 stills：对第 1 季前几集各抓一张（动漫/剧集静帧的关键来源）。
      final Response<Object?> season = await _dio.get<Object?>(
        'https://api.themoviedb.org/3/tv/${item.id}/season/1',
        queryParameters: _params(<String, Object?>{}),
        options: _options(),
      );
      final List<Object?> episodes =
          (((season.data as Map?)?['episodes']) as List<Object?>?) ??
          <Object?>[];
      for (final Object? ep in episodes.take(episodeFetch)) {
        if (ep is! Map) continue;
        final String still = '${ep['still_path'] ?? ''}';
        if (still.isEmpty || still == 'null') continue;
        out.add(TmdbImage(filePath: still, width: 0, height: 0, isStill: true));
      }
    }
    return out.where((TmdbImage i) => i.filePath.isNotEmpty).take(20).toList();
  }
}
