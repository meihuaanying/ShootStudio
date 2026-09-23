import 'dart:async';

import 'package:dio/dio.dart';

import '../../net_router.dart';
import '../search_models.dart';

/// 源实现共用工具：统一通道 Dio、并发限流、许可判定、IIIF 链接。

/// 统一 Dio（R44：全部走 NetRouter）。
Dio searchDio({
  Duration connectTimeout = const Duration(seconds: 15),
  Duration receiveTimeout = const Duration(seconds: 20),
  int retries = 2,
  Map<String, dynamic>? headers,
}) => NetRouter.I.dio(
  connectTimeout: connectTimeout,
  receiveTimeout: receiveTimeout,
  retries: retries,
  headers: headers,
);

/// 并发限流映射（保持输入顺序）。
Future<List<R>> mapLimit<T, R>(
  List<T> items,
  int limit,
  Future<R> Function(T item, int index) task,
) async {
  final List<R?> results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final int index = next++;
      if (index >= items.length) return;
      results[index] = await task(items[index], index);
    }
  }

  final int workers = limit < 1 ? 1 : limit;
  await Future.wait(
    List<Future<void>>.generate(
      workers < items.length ? workers : items.length,
      (int _) => worker(),
    ),
  );
  return results.cast<R>();
}

/// 许可是否允许商用（D117/R63：CC0/PD/CC-BY 系；NC/ND 不计可商用）。
bool isCommercialLicense(String license) {
  final String l = license.toLowerCase();
  final RegExp boundary = RegExp(r'(^|[^a-z])(nc|nd)([^a-z]|$)');
  if (boundary.hasMatch(l) ||
      l.contains('noncommercial') ||
      l.contains('non-commercial') ||
      l.contains('noderiv') ||
      l.contains('no derivative')) {
    return false;
  }
  const List<String> ok = <String>[
    'cc0',
    'public domain',
    'publicdomain',
    'no known copyright',
    'no known restrictions',
    'cc by',
    'cc-by',
    'pexels license',
    'unsplash license',
  ];
  for (final String marker in ok) {
    if (l.contains(marker)) return true;
  }
  return false;
}

/// 开放许可展示标签（D134/R63）：保留来源原始许可文本，缺失时明确标注。
String openLicenseLabel(String raw, [String version = '']) {
  final String l = raw.trim().toLowerCase();
  final String v = version.trim();
  if (l.isEmpty) return '许可未标注';
  if (l == 'cc0') return v.isEmpty ? 'CC0 1.0' : 'CC0 $v';
  if (l == 'pdm') return 'Public Domain Mark';
  if (l == 'public domain' || l == 'publicdomain') return 'Public Domain';
  if (l.startsWith('cc ')) return l.toUpperCase().replaceFirst('CC ', 'CC ');
  if (l.startsWith('by') || l.startsWith('cc-by')) {
    final String body = l.startsWith('cc-') ? l.substring(3) : l;
    return 'CC ${body.toUpperCase()}${v.isEmpty ? '' : ' $v'}';
  }
  return raw.trim();
}

String _clean(String url) {
  if (url.startsWith('//')) return 'https:$url';
  return url;
}

/// IIIF 尺寸链接（缺省取 width 边）。
String iiifUrl(String base, {int width = 600, String region = 'full'}) {
  final String b = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  return '$b/$region/!$width,$width/0/default.jpg';
}

/// 简单 HTML 属性提取（抓取源 fixture 化测试用，R48）。
String? htmlAttr(String html, String tag, String attr) {
  final RegExp re = RegExp(
    '<$tag[^>]*\\s$attr\\s*=\\s*"([^"]+)"',
    caseSensitive: false,
  );
  final RegExpMatch? m = re.firstMatch(html);
  return m?.group(1);
}

List<String> htmlAttrs(String html, String tag, String attr) {
  final RegExp re = RegExp(
    '<$tag[^>]*\\s$attr\\s*=\\s*"([^"]+)"',
    caseSensitive: false,
  );
  return re.allMatches(html).map((RegExpMatch m) => m.group(1) ?? '').toList();
}

/// 容错取 Map。
Map<String, Object?> asMapSafe(Object? value) =>
    value is Map ? value.cast<String, Object?>() : <String, Object?>{};

/// 容错取 List。
List<Object?> asListSafe(Object? value) =>
    value is List ? value : const <Object?>[];

String strSafe(Object? value, [String fallback = '']) =>
    value == null ? fallback : '$value';

int intSafe(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? fallback;

/// 带鉴权 Key 的源基类。
abstract class KeyedSearchSource implements SearchSource {
  const KeyedSearchSource(this.apiKey);

  final String apiKey;

  @override
  bool get enabled => apiKey.trim().isNotEmpty;

  @override
  String get disabledHint {
    final String setting = capability.keySettingId;
    if (setting.isEmpty) return '缺 $label Key（设置 → 图片素材通道）';
    return '缺 $label Key（设置 → 图片素材通道）';
  }
}

/// 域名域过滤：源声明不支持的域返回空页（UI 显示"不适用"）。
bool sourceSupports(SearchSource source, ImageDomain domain) =>
    source.capability.supportsDomain(domain);

/// 由源 ID 与 URL 生成稳定条目 ID。
String hitId(String sourceId, String url) {
  final String key = url.split('?').first;
  return '$sourceId:${key.hashCode.toRadixString(16)}';
}

String cleanUrl(String url) => _clean(url.trim());
