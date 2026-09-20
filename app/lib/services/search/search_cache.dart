import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/db/database.dart';
import '../net_router.dart';

/// V6 图片缓存（D97/D118/R47）：工作区 `cache/search/`，缩略图/原图分目录，
/// 5GB LRU（设置页可调）；绝不入 git/安装包；每图可追溯来源（由调用方登记）。
class SearchCache {
  SearchCache(this.workspaceRoot, {int? limitMb})
      : _limitMb = limitMb ?? defaultLimitMb;

  final String workspaceRoot;
  int _limitMb;

  static const int defaultLimitMb = 5120;
  static const String limitSettingKey = 'search_cache_limit_mb';
  static const String _thumbKind = 'thumb';
  static const String _origKind = 'orig';

  int get limitMb => _limitMb;
  int get limitBytes => _limitMb * 1024 * 1024;

  String get cacheDir => p.join(workspaceRoot, 'cache', 'search');
  String get _indexPath => p.join(cacheDir, 'index.json');

  /// 从设置读取上限（MB，0 表示不缓存）。
  static Future<SearchCache> from(AppDatabase db, String workspaceRoot) async {
    final int limit =
        int.tryParse((await db.getSetting(limitSettingKey)) ?? '') ??
            defaultLimitMb;
    return SearchCache(workspaceRoot, limitMb: limit < 0 ? 0 : limit);
  }

  Future<void> setLimitMb(int mb) async {
    _limitMb = mb < 0 ? 0 : mb;
    await enforceLimit();
  }

  /// 取缓存文件（[original] 区分原图/缩略图）。
  Future<File?> get(String url, {bool original = false}) async {
    final Map<String, Object?> index = await _loadIndex();
    final String key = _keyOf(url, original: original);
    final Object? entry = index[key];
    if (entry is! Map) return null;
    final String path = '${entry['path'] ?? ''}';
    if (path.isEmpty) return null;
    final File file = File(path);
    if (!await file.exists()) {
      index.remove(key);
      await _saveIndex(index);
      return null;
    }
    entry['atime'] = DateTime.now().millisecondsSinceEpoch;
    await _saveIndex(index);
    return file;
  }

  /// 写入缓存（返回文件；limit=0 时直接返回临时文件不落索引）。
  Future<File> put(String url, Uint8List bytes, {bool original = false}) async {
    final String kind = original ? _origKind : _thumbKind;
    final String hash = _sha1('${original ? 'o' : 't'}:$url');
    final String ext = _extOf(url);
    final Directory dir = Directory(p.join(cacheDir, kind));
    await dir.create(recursive: true);
    final File file = File(p.join(dir.path, '$hash$ext'));
    await file.writeAsBytes(bytes, flush: true);
    if (_limitMb <= 0) return file;
    final Map<String, Object?> index = await _loadIndex();
    index['$kind:$hash'] = <String, Object?>{
      'path': file.path,
      'size': bytes.length,
      'atime': DateTime.now().millisecondsSinceEpoch,
      'url': url,
    };
    await _saveIndex(index);
    await enforceLimit();
    return file;
  }

  /// 读取缓存，未命中则经 [NetRouter] 下载并写入（R44）。
  Future<Uint8List> getOrFetch(String url, {bool original = false}) async {
    final File? cached = await get(url, original: original);
    if (cached != null) return cached.readAsBytes();
    final Response<List<int>> res = await NetRouter.I
        .dio(retries: 2, receiveTimeout: const Duration(seconds: 40))
        .get<List<int>>(url,
            options: Options(responseType: ResponseType.bytes));
    final Uint8List bytes = Uint8List.fromList(res.data ?? <int>[]);
    if (bytes.isEmpty) throw StateError('下载为空：$url');
    await put(url, bytes, original: original);
    return bytes;
  }

  /// 当前占用（字节）。
  Future<int> totalBytes() async {
    final Map<String, Object?> index = await _loadIndex();
    var total = 0;
    for (final Object? entry in index.values) {
      if (entry is Map) total += (entry['size'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  Future<int> fileCount() async {
    final Map<String, Object?> index = await _loadIndex();
    return index.length;
  }

  /// LRU 淘汰至上限内。
  Future<void> enforceLimit() async {
    final Map<String, Object?> index = await _loadIndex();
    final List<MapEntry<String, Object?>> entries = index.entries.toList()
      ..sort((MapEntry<String, Object?> a, MapEntry<String, Object?> b) {
        final int at = (a.value is Map)
            ? ((a.value as Map)['atime'] as num?)?.toInt() ?? 0
            : 0;
        final int bt = (b.value is Map)
            ? ((b.value as Map)['atime'] as num?)?.toInt() ?? 0
            : 0;
        return at.compareTo(bt);
      });
    var total = 0;
    for (final MapEntry<String, Object?> entry in entries) {
      if (entry.value is Map) {
        total += ((entry.value as Map)['size'] as num?)?.toInt() ?? 0;
      }
    }
    var changed = false;
    for (final MapEntry<String, Object?> entry in entries) {
      if (total <= limitBytes) break;
      final Object? value = entry.value;
      if (value is! Map) continue;
      final int size = (value['size'] as num?)?.toInt() ?? 0;
      final String path = '${value['path'] ?? ''}';
      if (path.isNotEmpty) {
        final File file = File(path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
      index.remove(entry.key);
      total -= size;
      changed = true;
    }
    if (changed) await _saveIndex(index);
  }

  /// 清空缓存。
  Future<void> clear() async {
    final Directory dir = Directory(cacheDir);
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  static String _keyOf(String url, {required bool original}) =>
      '${original ? _origKind : _thumbKind}:${_sha1('${original ? 'o' : 't'}:$url')}';

  static String _sha1(String value) =>
      sha1.convert(utf8.encode(value)).toString();

  static String _extOf(String url) {
    final String path = Uri.tryParse(url)?.path ?? url;
    final String ext = p.extension(path).toLowerCase();
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') {
      return ext;
    }
    return '.jpg';
  }

  Future<Map<String, Object?>> _loadIndex() async {
    try {
      final File file = File(_indexPath);
      if (!await file.exists()) return <String, Object?>{};
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) return decoded.cast<String, Object?>();
    } catch (_) {}
    return <String, Object?>{};
  }

  Future<void> _saveIndex(Map<String, Object?> index) async {
    try {
      final Directory dir = Directory(cacheDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      await File(_indexPath).writeAsString(jsonEncode(index), flush: true);
    } catch (_) {
      // 索引写失败不阻塞搜索（缓存可重建）。
    }
  }
}
