import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V7 维基共享资源源（D134 免 Key）：逐文件许可（CC/PD），走 DoH 隧道。
class WikimediaSource implements SearchSource {
  WikimediaSource({Dio? dio})
    : _dio =
          dio ??
          searchDio(
            receiveTimeout: const Duration(seconds: 25),
            headers: <String, dynamic>{
              // Wikimedia 要求可识别的 User-Agent（含联系方式）。
              'User-Agent':
                  'ShootStudio/1.3 (https://github.com/meihuaanying/ShootStudio)',
            },
          );

  final Dio _dio;

  static const String _base = 'https://commons.wikimedia.org/w/api.php';

  @override
  String get id => 'wikimedia';

  @override
  String get label => '维基共享资源';

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
    final int limit = perPage.clamp(1, 50);
    final Response<Object?> res = await _dio.get<Object?>(
      _base,
      queryParameters: <String, Object?>{
        'action': 'query',
        'format': 'json',
        'generator': 'search',
        'gsrsearch': text,
        'gsrnamespace': 6,
        'gsrlimit': limit,
        'gsroffset': (page - 1) * limit,
        'prop': 'imageinfo',
        'iiprop': 'url|size|extmetadata',
        'iiurlwidth': 640,
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    return SourceSearchPage(
      hits: hits,
      hasMore: asMapSafe(data['continue']).isNotEmpty,
    );
  }

  /// 解析 action=query 响应（fixture 测试用）。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    final Map<String, Object?> pages = asMapSafe(
      asMapSafe(data['query'])['pages'],
    );
    for (final Object? item in pages.values) {
      final Map<String, Object?> page = asMapSafe(item);
      final Object? infoRaw = asListSafe(page['imageinfo']).isNotEmpty
          ? asListSafe(page['imageinfo']).first
          : null;
      final Map<String, Object?> info = asMapSafe(infoRaw);
      final String full = strSafe(info['url']);
      final String thumb = strSafe(info['thumburl'], full);
      if (full.isEmpty) continue;
      final Map<String, Object?> meta = asMapSafe(info['extmetadata']);
      final String license = _meta(meta, 'LicenseShortName');
      final String licenseUrl = _meta(meta, 'LicenseUrl');
      final String artist = _stripTags(_meta(meta, 'Artist'));
      final String title = _cleanTitle(strSafe(page['title'], '未命名作品'));
      out.add(
        SearchHit(
          id: hitId('wikimedia', strSafe(page['pageid'], full)),
          title: title,
          thumbUrl: thumb,
          fullUrl: full,
          sourceId: 'wikimedia',
          sourceLabel: '维基共享资源',
          license: license.isEmpty ? '许可未标注' : license,
          licenseUrl: licenseUrl,
          commercialOk: isCommercialLicense(license),
          attribution: artist.isEmpty
              ? 'Wikimedia Commons'
              : 'Wikimedia Commons · $artist',
          sourcePageUrl: strSafe(info['descriptionurl']),
          width: intSafe(info['width']),
          height: intSafe(info['height']),
          domain: ImageDomain.art,
          imageType: 'artwork',
        ),
      );
    }
    return out;
  }

  static String _meta(Map<String, Object?> meta, String key) =>
      strSafe(asMapSafe(meta[key])['value']);

  static String _stripTags(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _cleanTitle(String title) {
    String out = title;
    if (out.startsWith('File:')) out = out.substring(5);
    final int dot = out.lastIndexOf('.');
    if (dot > 0) out = out.substring(0, dot);
    return out.replaceAll('_', ' ').trim();
  }
}
