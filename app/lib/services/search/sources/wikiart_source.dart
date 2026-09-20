import 'dart:convert';

import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V6 WikiArt 抓取源（D115）：无官方 API，走站内 JSON 端点（易变，失败降级）。
/// 解析器 fixture 化（R48），失败只影响本源。
class WikiArtSource implements SearchSource {
  WikiArtSource({Dio? dio})
      : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  @override
  String get id => 'wikiart';
  @override
  String get label => 'WikiArt';
  @override
  SourceCapability get capability => const SourceCapability(
        byTitle: true,
        byPerson: true,
        byKeyword: true,
        hasLicenseFilter: false,
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
    final Response<String> res = await _dio.get<String>(
      'https://www.wikiart.org/en/search/${Uri.encodeComponent(text)}/$page',
      queryParameters: <String, Object?>{'json': 2},
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, Object?>{
          'Accept': 'application/json, text/plain, */*'
        },
      ),
    );
    final List<SearchHit> hits = parse(res.data ?? '');
    return SourceSearchPage(
      hits: hits.take(perPage).toList(),
      hasMore: hits.length >= perPage,
    );
  }

  /// 解析 JSON 响应（数组或 {Paintings: []}；fixture 测试用）。
  static List<SearchHit> parse(String body) {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) return <SearchHit>[];
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return <SearchHit>[];
    }
    List<Object?> items = <Object?>[];
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map) {
      final Map<String, Object?> map = decoded.cast<String, Object?>();
      items = asListSafe(map['Paintings']);
      if (items.isEmpty) items = asListSafe(map['paintings']);
    }
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in items) {
      final Map<String, Object?> m = asMapSafe(item);
      final String image = strSafe(m['image']);
      if (image.isEmpty) continue;
      final String title = strSafe(m['title'], '未命名作品');
      final String artist = strSafe(m['artistName']);
      final String path = strSafe(m['url']);
      final String pageUrl = path.isEmpty ? '' : 'https://www.wikiart.org$path';
      final String full = image
          .replaceAll(RegExp(r'!(?:Large|PinterestSmall|Small)\.\w+$'), '')
          .replaceAll(RegExp(r'!.*\.jpg$'), '.jpg');
      out.add(SearchHit(
        id: hitId('wikiart', pageUrl.isEmpty ? image : pageUrl),
        title: title,
        thumbUrl: image,
        fullUrl: full,
        sourceId: 'wikiart',
        sourceLabel: 'WikiArt',
        license: 'WikiArt（许可以作品页为准）',
        commercialOk: false,
        attribution: artist.isEmpty ? 'WikiArt' : '$artist · WikiArt',
        sourcePageUrl: pageUrl,
        width: intSafe(m['width']),
        height: intSafe(m['height']),
        domain: ImageDomain.art,
        imageType: 'artwork',
        extra: <String, Object?>{'year': strSafe(m['year'])},
      ));
    }
    return out;
  }
}
