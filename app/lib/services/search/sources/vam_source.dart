import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V6 英国 V&A 博物馆源（D115 免 Key）：v2 搜索 API + IIIF 图片。
class VamSource implements SearchSource {
  VamSource({Dio? dio})
    : _dio = dio ?? searchDio(receiveTimeout: const Duration(seconds: 25));

  final Dio _dio;

  static const String _base = 'https://api.vam.ac.uk/v2/objects/search';

  @override
  String get id => 'vam';
  @override
  String get label => 'V&A 博物馆';
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
    final Response<Object?> res = await _dio.get<Object?>(
      _base,
      queryParameters: <String, Object?>{
        'q': text,
        'images_exist': 1,
        'page_size': perPage.clamp(1, 100),
        'page': page,
        'response_format': 'json',
      },
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parse(data);
    final Map<String, Object?> info = asMapSafe(data['info']);
    final int current = intSafe(info['page'], page);
    final int pages = intSafe(info['pages'], 1);
    return SourceSearchPage(hits: hits, hasMore: current < pages);
  }

  /// 解析 /v2/objects/search 响应（fixture 测试用）。
  static List<SearchHit> parse(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['records'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final Map<String, Object?> images = asMapSafe(m['_images']);
      final String iiifBase = strSafe(images['_iiif_image_base_url']);
      final String thumb = strSafe(images['_primary_thumbnail']);
      final String full = iiifBase.isEmpty
          ? ''
          : '${iiifBase.replaceAll(RegExp(r'/$'), '')}/full/!1200,1200/0/default.jpg';
      final String image = full.isNotEmpty ? full : thumb;
      if (image.isEmpty) continue;
      final String systemNumber = strSafe(m['systemNumber']);
      final String title = strSafe(m['_primaryTitle'], '未命名藏品');
      final Map<String, Object?> maker = asMapSafe(m['_primaryMaker']);
      final String makerName = strSafe(maker['name']);
      final String pageUrl = systemNumber.isEmpty
          ? ''
          : 'https://collections.vam.ac.uk/item/$systemNumber/';
      out.add(
        SearchHit(
          id: hitId('vam', systemNumber.isEmpty ? image : systemNumber),
          title: title,
          thumbUrl: thumb.isEmpty ? image : thumb,
          fullUrl: image,
          sourceId: 'vam',
          sourceLabel: 'V&A 博物馆',
          license: 'V&A 免费非商用（商用需授权）',
          commercialOk: false,
          attribution:
              'Victoria and Albert Museum${makerName.isEmpty ? '' : ' · $makerName'}',
          sourcePageUrl: pageUrl,
          domain: ImageDomain.art,
          imageType: 'artwork',
          description: strSafe(m['objectType']),
          extra: <String, Object?>{'date': strSafe(m['_primaryDate'])},
        ),
      );
    }
    return out;
  }
}
