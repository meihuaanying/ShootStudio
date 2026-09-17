// Q5 网络通道实网探针（门禁 R39：live 证据）。
// 用法（工作目录 app/）：dart run tool/net_probe.dart
// 输出：隧道状态 / DoH 解析 / Pexels 直连 / TMDB 经隧道 / TMDB CDN；不打印任何 Key。
import 'dart:convert';
import 'dart:io';

import 'package:shoot_studio/services/net_router.dart';

Future<void> main() async {
  final File cfgFile = File('assets/config/image_sources.json');
  final Map<String, Object?> cfg = cfgFile.existsSync()
      ? (jsonDecode(cfgFile.readAsStringSync()) as Map).cast<String, Object?>()
      : <String, Object?>{};
  final String pexelsKey =
      '${((cfg['pexels'] as Map?) ?? <String, Object?>{})['apiKey'] ?? ''}';
  final String tmdbKey =
      '${((cfg['tmdb'] as Map?) ?? <String, Object?>{})['apiKey'] ?? ''}';

  final NetRouter router = NetRouter.I;
  await router.configure(
      userProxy: '', autoTunnel: true, forceDirect: false);
  print('[router] mode=${router.modeLabel} tunnel=${router.tunnelRunning} '
      'port=${router.tunnelPort}');

  final List<String> ips = await router.resolver.resolve('api.themoviedb.org');
  print('[doh] api.themoviedb.org → $ips');

  final (bool ok1, int ms1, String d1) = await router.probe(
      'https://api.pexels.com/v1/search?query=portrait&per_page=1',
      timeout: const Duration(seconds: 12));
  print('[pexels] ok=$ok1 ${ms1}ms $d1');

  final (bool ok2, int ms2, String d2) = await router.probe(
      'https://api.themoviedb.org/3/search/movie?query=test&api_key=$tmdbKey',
      timeout: const Duration(seconds: 15));
  print('[tmdb-api] ok=$ok2 ${ms2}ms $d2');

  final (bool ok3, int ms3, String d3) = await router.probe(
      'https://image.tmdb.org/t/p/w200/8CdXyOlgb3vJzWqBQhQnQ0kZ8rY.jpg',
      timeout: const Duration(seconds: 15));
  print('[tmdb-cdn] ok=$ok3 ${ms3}ms $d3');

  final (bool ok4, int ms4, String d4) = await router.probe(
      'https://api.openverse.org/v1/images/?q=portrait&page_size=1',
      timeout: const Duration(seconds: 10));
  print('[openverse] ok=$ok4 ${ms4}ms $d4（实验性，允许失败）');

  print('[log]');
  for (final String line in router.log) {
    print('  $line');
  }
  await router.dispose();
  exit(ok1 && ok2 ? 0 : 1);
}
