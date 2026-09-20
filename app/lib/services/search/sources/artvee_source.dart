import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V6 Artvee 抓取源（D115）：公有领域艺术与海报，HTML 抓取 + fixture 解析（R48）。
class ArtveeSource implements SearchSource {
  ArtveeSource({Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  static final RegExp _imageRe = RegExp(
    r'https://artvee\.com/wp-content/uploads/[^"\s)]+?\.(?:jpe?g|png)',
    caseSensitive: false,
  );
  static final RegExp _linkRe = RegExp(
    r'href="(https://artvee\.com/[^"]+)"',
    caseSensitive: false,
  );
  static final RegExp _titleRe = RegExp(
    r'<h2[^>]*class="[^"]*product-title[^"]*"[^>]*>\s*(?:<a[^>]*>)?\s*([^<]+)',
    caseSensitive: false,
  );

  @override
  String get id => 'artvee';
  @override
  String get label => 'Artvee';
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
    final String url = page <= 1
        ? 'https://artvee.com/?s=${Uri.encodeQueryComponent(text)}'
        : 'https://artvee.com/page/$page/?s=${Uri.encodeQueryComponent(text)}';
    final Response<String> res = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final List<SearchHit> hits = parse(res.data ?? '');
    return SourceSearchPage(
      hits: hits.take(perPage).toList(),
      hasMore: hits.length >= perPage,
    );
  }

  /// 解析搜索结果页 HTML（fixture 测试用）。
  static List<SearchHit> parse(String html) {
    if (html.trim().isEmpty) return <SearchHit>[];
    final List<String> images = _imageRe
        .allMatches(html)
        .map((RegExpMatch m) => m.group(0) ?? '')
        .toList();
    final List<String> links = _linkRe
        .allMatches(html)
        .map((RegExpMatch m) => m.group(1) ?? '')
        .where(
          (String url) => url.contains('/dl/') || url.contains('/artwork/'),
        )
        .toList();
    final List<String> titles = _titleRe
        .allMatches(html)
        .map((RegExpMatch m) => (m.group(1) ?? '').trim())
        .where((String t) => t.isNotEmpty)
        .toList();
    final Set<String> seen = <String>{};
    final List<SearchHit> out = <SearchHit>[];
    for (var i = 0; i < images.length; i++) {
      final String image = images[i];
      final String base = image.replaceAll(RegExp(r'-\d+x\d+(?=\.)'), '');
      if (!seen.add(base)) continue;
      final String link = i < links.length ? links[i] : '';
      final String title = i < titles.length ? titles[i] : 'Artvee 作品';
      out.add(
        SearchHit(
          id: hitId('artvee', base),
          title: title,
          thumbUrl: image,
          fullUrl: base,
          sourceId: 'artvee',
          sourceLabel: 'Artvee',
          license: 'Public Domain（Artvee）',
          licenseUrl: 'https://creativecommons.org/publicdomain/mark/1.0/',
          commercialOk: true,
          attribution: 'Artvee · $title',
          sourcePageUrl: link,
          domain: ImageDomain.art,
          imageType: 'artwork',
        ),
      );
    }
    return out;
  }
}
