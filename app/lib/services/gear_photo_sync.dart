import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../core/db/database.dart';
import '../core/workspace/workspace.dart';
import 'net.dart';

/// 器材图运行时同步（D71/D73）：读取 assets/content/gear/gear_photos2.json，
/// 对「未内置（builtin=false）」或「内置但资产未随包」的条目按 runtimeUrl
/// （Openverse 缩略图代理优先，其次 upload.wikimedia 原图）下载到工作区
/// `images/gear/<gearId>.jpg`，供离线展示与回退。
class GearPhotoSync {
  GearPhotoSync._();

  static const String catalogAsset = 'assets/content/gear/gear_photos2.json';
  static const String photo2Prefix = 'assets/content/gear/photo2/';

  static Map<String, Object?>? _catalog;
  static final Map<String, bool> _assetCache = <String, bool>{};

  /// 读取 gear_photos2.json（失败返回空表，不抛出）。
  static Future<Map<String, Object?>> catalog() async {
    final Map<String, Object?>? cached = _catalog;
    if (cached != null) return cached;
    try {
      final String raw = await rootBundle.loadString(catalogAsset);
      final Object? decoded = jsonDecode(raw);
      _catalog = decoded is Map
          ? decoded.cast<String, Object?>()
          : <String, Object?>{};
    } catch (_) {
      _catalog = <String, Object?>{};
    }
    return _catalog!;
  }

  /// 条目 → 内置图资产路径（`assets/content/gear/photo2/<file>`）。
  static String? assetPath(Map<String, Object?> entry) {
    final String file = '${entry['file'] ?? ''}'.trim();
    if (file.isEmpty) return null;
    if (file.startsWith('assets/')) return file;
    return '$photo2Prefix$file';
  }

  /// 条目 → 运行时下载源（runtimeUrl 优先：Openverse 缩略图代理，
  /// 其次 Wikimedia 原图；兼容旧字段 sourceUrl）。
  static String runtimeUrlOf(Map<String, Object?> entry) {
    final String runtime = '${entry['runtimeUrl'] ?? ''}'.trim();
    if (runtime.isNotEmpty) return runtime;
    return '${entry['sourceUrl'] ?? ''}'.trim();
  }

  /// 内置资产是否存在（带缓存；bundle 未收录时返回 false，走同步缓存）。
  static Future<bool> assetExists(String asset) async {
    final bool? cached = _assetCache[asset];
    if (cached != null) return cached;
    bool ok = false;
    try {
      await rootBundle.load(asset);
      ok = true;
    } catch (_) {
      ok = false;
    }
    _assetCache[asset] = ok;
    return ok;
  }

  /// 已缓存的本地文件路径（未同步/工作区未就绪时返回 null）。
  static String? localPathFor(String gearId) {
    try {
      final String path = p.join(
        Workspace.I.root.path,
        'images',
        'gear',
        '$gearId.jpg',
      );
      return File(path).existsSync() ? path : null;
    } catch (_) {
      return null;
    }
  }

  /// 同步可下载条目；返回本次成功下载数量。
  /// [onProgress] 回调 (done, total)；[force] 为 true 时忽略已有缓存/内置。
  static Future<int> syncAll({
    void Function(int done, int total)? onProgress,
    AppDatabase? db,
    bool force = false,
  }) async {
    final Map<String, Object?> cat = await catalog();
    final List<Map<String, Object?>> all = _collect(cat);

    String proxy = '';
    if (db != null) {
      try {
        proxy = (await db.getSetting('proxy_url')) ?? '';
      } catch (_) {
        proxy = '';
      }
    }

    final Directory? dir = _cacheDir();
    if (dir == null) return 0;

    final List<Map<String, Object?>> targets = <Map<String, Object?>>[];
    for (final Map<String, Object?> entry in all) {
      final String id = '${entry['id'] ?? ''}'.trim();
      final String sourceUrl = runtimeUrlOf(entry);
      if (id.isEmpty || sourceUrl.isEmpty) continue;
      final bool builtin =
          entry['builtin'] == true || entry['bundled'] != false;
      if (!force && localPathFor(id) != null) continue;
      if (!force && builtin) {
        final String? asset = assetPath(entry);
        if (asset != null && await assetExists(asset)) continue;
      }
      targets.add(entry);
    }

    final Dio dio = makeDio(proxy: proxy, timeout: const Duration(seconds: 25));
    int done = 0;
    int ok = 0;
    for (final Map<String, Object?> entry in targets) {
      done++;
      onProgress?.call(done, targets.length);
      final String id = '${entry['id']}';
      final String sourceUrl = runtimeUrlOf(entry);
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final Response<List<int>> res = await dio.get<List<int>>(
            sourceUrl,
            options: Options(
              responseType: ResponseType.bytes,
              followRedirects: true,
              validateStatus: (int? s) => s != null && s < 400,
            ),
          );
          final List<int>? bytes = res.data;
          if (bytes == null || bytes.length < 2048) break;
          await File(
            p.join(dir.path, '$id.jpg'),
          ).writeAsBytes(bytes, flush: true);
          ok++;
          break;
        } on DioException catch (_) {
          if (attempt >= 2) break;
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        } catch (_) {
          break;
        }
      }
    }
    return ok;
  }

  static List<Map<String, Object?>> _collect(Map<String, Object?> cat) {
    final List<Map<String, Object?>> out = <Map<String, Object?>>[];
    final Set<String> seen = <String>{};
    void addAll(Object? raw) {
      if (raw is! List) return;
      for (final Object? item in raw) {
        if (item is! Map) continue;
        final Map<String, Object?> entry = item.cast<String, Object?>();
        final String id = '${entry['id'] ?? ''}'.trim();
        if (id.isEmpty || !seen.add(id)) continue;
        out.add(entry);
      }
    }

    addAll(cat['byId']);
    if (out.isEmpty) {
      final Object? byModel = cat['byModel'];
      if (byModel is Map) {
        addAll(byModel.values.toList());
      }
    }
    return out;
  }

  static Directory? _cacheDir() {
    try {
      final Directory dir = Directory(
        p.join(Workspace.I.root.path, 'images', 'gear'),
      );
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }
}
