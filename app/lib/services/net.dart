import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'content_packs.dart';
import 'net_router.dart';

/// V3 网络层：统一代理 + 默认凭据读取（Pexels/TMDB）。
class NetConfig {
  const NetConfig(
      {this.proxy = '',
      this.pexelsKey = '',
      this.tmdbKey = '',
      this.tmdbToken = ''});
  final String proxy;
  final String pexelsKey;
  final String tmdbKey;
  final String tmdbToken;
}

/// 造 Dio（V5：统一交给 [NetRouter] —— 用户代理 / DoH 隧道 / 直连三态）。
/// [proxy] 仅在“显式传入且与全局通道不同”时按旧行为临时覆盖（兼容老调用点）。
Dio makeDio(
    {String proxy = '', Duration timeout = const Duration(seconds: 20)}) {
  final String p = proxy.trim();
  if (p.isNotEmpty &&
      p != NetRouter.I.userProxy &&
      !NetRouter.I.forceDirect &&
      (p.startsWith('http://') || p.startsWith('https://'))) {
    final Dio dio = Dio(BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
    ));
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () =>
          HttpClient()..findProxy = (_) => 'PROXY ${Uri.parse(p).authority}',
    );
    return dio;
  }
  return NetRouter.I.dio(connectTimeout: timeout, receiveTimeout: timeout);
}

/// 读取内置默认凭据（assets/config/image_sources.json）。
Future<NetConfig> loadNetConfig({String proxy = ''}) async {
  try {
    final Map<String, Object?> data = await ContentPacks.imageSourcesConfig();
    final Map<String, Object?> pexels =
        ((data['pexels'] as Map?) ?? <String, Object?>{})
            .cast<String, Object?>();
    final Map<String, Object?> tmdb =
        ((data['tmdb'] as Map?) ?? <String, Object?>{}).cast<String, Object?>();
    return NetConfig(
      proxy: proxy,
      pexelsKey: '${pexels['apiKey'] ?? ''}',
      tmdbKey: '${tmdb['apiKey'] ?? ''}',
      tmdbToken: '${tmdb['readToken'] ?? ''}',
    );
  } catch (_) {
    return NetConfig(proxy: proxy);
  }
}
