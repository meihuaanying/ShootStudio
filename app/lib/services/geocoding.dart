import 'package:dio/dio.dart';

/// 在线地名搜索（F10）：Nominatim，失败时返回 null 由调用方离线回退。
class GeocodingService {
  GeocodingService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<({String name, double lat, double lon})?> search(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return null;
    try {
      final Response<Object?> res = await _dio.get<Object?>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: <String, Object?>{
          'q': q,
          'format': 'json',
          'limit': 1,
          'accept-language': 'zh-CN',
        },
        options: Options(
          headers: <String, Object?>{
            'User-Agent': 'ShootStudio/1.0 (plan assistant)',
          },
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
      );
      final Object? data = res.data;
      if (data is! List || data.isEmpty) return null;
      final Object? first = data.first;
      if (first is! Map) return null;
      final double? lat = double.tryParse('${first['lat']}');
      final double? lon = double.tryParse('${first['lon']}');
      if (lat == null || lon == null) return null;
      final String name = '${first['display_name']}'.split(',').first.trim();
      return (name: name.isEmpty ? q : name, lat: lat, lon: lon);
    } on DioException {
      return null;
    }
  }
}
