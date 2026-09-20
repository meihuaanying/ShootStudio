import 'package:dio/dio.dart';

import '../search_models.dart';
import 'source_utils.dart';

/// V6 Pexels 源（D113 免 Key 之外的摄影主源；Key 内置可覆盖）。
/// 许可：Pexels License（可商用、无需署名，仍标注作者）。
class PexelsImageSource implements SearchSource {
  PexelsImageSource(this.apiKey, {Dio? dio, this.locale = 'zh-CN'})
    : _dio = dio ?? searchDio();

  final String apiKey;
  final String locale;
  final Dio _dio;

  @override
  String get id => 'pexels';
  @override
  String get label => 'Pexels';
  @override
  SourceCapability get capability => const SourceCapability(
    byTitle: true,
    byPerson: false,
    byKeyword: true,
    hasLicenseFilter: true,
    domains: <ImageDomain>{ImageDomain.photo},
    requiresKey: true,
    keySettingId: 'image_pexels_key',
  );

  @override
  bool get enabled => apiKey.trim().isNotEmpty;

  @override
  String get disabledHint => '缺 Pexels Key（设置 → 图片素材通道）';

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
      'https://api.pexels.com/v1/search',
      queryParameters: <String, Object?>{
        'query': text,
        'page': page,
        'per_page': perPage.clamp(1, 80),
        'locale': locale,
      },
      options: Options(
        headers: <String, Object?>{'Authorization': apiKey.trim()},
      ),
    );
    final Map<String, Object?> data = asMapSafe(res.data);
    final List<SearchHit> hits = parsePhotos(data);
    final int total = intSafe(data['total_results'], hits.length);
    return SourceSearchPage(
      hits: hits,
      hasMore: hits.isNotEmpty && page * perPage < total,
    );
  }

  /// 解析 /v1/search 响应（fixture 测试用）。
  static List<SearchHit> parsePhotos(Map<String, Object?> data) {
    final List<SearchHit> out = <SearchHit>[];
    for (final Object? item in asListSafe(data['photos'])) {
      final Map<String, Object?> m = asMapSafe(item);
      final Map<String, Object?> src = asMapSafe(m['src']);
      final String thumb = strSafe(src['medium'], strSafe(src['small']));
      final String full = strSafe(
        src['large2x'],
        strSafe(src['original'], strSafe(src['large'])),
      );
      if (full.isEmpty) continue;
      final String photographer = strSafe(m['photographer']);
      out.add(
        SearchHit(
          id: hitId('pexels', full),
          title: strSafe(m['alt'], 'Pexels 参考图'),
          thumbUrl: thumb.isEmpty ? full : thumb,
          fullUrl: full,
          sourceId: 'pexels',
          sourceLabel: 'Pexels',
          license: 'Pexels License',
          licenseUrl: 'https://www.pexels.com/license/',
          commercialOk: true,
          attribution: photographer.isEmpty
              ? 'Pexels'
              : '$photographer · Pexels',
          sourcePageUrl: strSafe(m['url']),
          width: intSafe(m['width']),
          height: intSafe(m['height']),
          domain: ImageDomain.photo,
          imageType: 'photo',
          extra: <String, Object?>{'avgColor': strSafe(m['avg_color'])},
        ),
      );
    }
    return out;
  }
}
