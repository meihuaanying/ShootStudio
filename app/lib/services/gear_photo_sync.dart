import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../core/db/database.dart';
import '../core/workspace/workspace.dart';
import 'net.dart';

/// 器材图运行时同步（D71/D73，V6/D131 升级）。

/// 同步目标（id + 下载地址 + 图源标识）。
class GearSyncTarget {
  const GearSyncTarget({
    required this.id,
    required this.url,
    required this.provider,
  });

  final String id;
  final String url;
  final String provider;
}

/// 同步计划（断点续跑的目标集合与跳过统计）。
class GearSyncPlan {
  const GearSyncPlan({
    required this.targets,
    required this.skippedLocal,
    required this.skippedBuiltin,
    required this.skippedSource,
    required this.skippedFailed,
    required this.skippedDone,
  });

  final List<GearSyncTarget> targets;
  final int skippedLocal;
  final int skippedBuiltin;
  final int skippedSource;
  final int skippedFailed;
  final int skippedDone;
}

/// 同步结果报告（D131：进度/缺口报告）。
class GearSyncReport {
  const GearSyncReport({
    required this.total,
    required this.downloaded,
    required this.skippedLocal,
    required this.skippedBuiltin,
    required this.skippedSource,
    required this.skippedFailed,
    required this.skippedDone,
    required this.failedIds,
  });

  final int total;
  final int downloaded;
  final int skippedLocal;
  final int skippedBuiltin;
  final int skippedSource;
  final int skippedFailed;
  final int skippedDone;
  final List<String> failedIds;

  int get gap => failedIds.length;
}

/// 器材图运行时同步（D71/D73）：读取 assets/content/gear/gear_photos2.json 与
/// assets/content/gear/gear_photo_sources.json（V6 官网/平台/开放图源），
/// 对未内置/未缓存条目下载到工作区 `images/gear/<gearId>.jpg`，
/// 断点续跑（sync_state.json）、缺口报告，并支持用户「补图」（本地/链接）。
class GearPhotoSync {
  GearPhotoSync._();

  static const String catalogAsset = 'assets/content/gear/gear_photos2.json';
  static const String sourcesAsset =
      'assets/content/gear/gear_photo_sources.json';
  static const String photo2Prefix = 'assets/content/gear/photo2/';
  static const String defaultCacheLimitMb = '2048';
  static const int maxAttempts = 3;

  static Map<String, Object?>? _catalog;
  static Map<String, Object?>? _sources;
  static final Map<String, bool> _assetCache = <String, bool>{};

  /// 读取 gear_photos2.json（失败返回空表，不抛出）。
  static Future<Map<String, Object?>> catalog() async {
    final Map<String, Object?>? cached = _catalog;
    if (cached != null) return cached;
    return _catalog = await _loadAsset(catalogAsset);
  }

  /// 读取 gear_photo_sources.json（V6/E：官网/平台/开放图源元数据）。
  static Future<Map<String, Object?>> sources() async {
    final Map<String, Object?>? cached = _sources;
    if (cached != null) return cached;
    return _sources = await _loadAsset(sourcesAsset);
  }

  static Future<Map<String, Object?>> _loadAsset(String asset) async {
    try {
      final String raw = await rootBundle.loadString(asset);
      final Object? decoded = jsonDecode(raw);
      return decoded is Map
          ? decoded.cast<String, Object?>()
          : <String, Object?>{};
    } catch (_) {
      return <String, Object?>{};
    }
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

  /// V6 图源条目（gear_photo_sources.json items[gearId]）。
  static Map<String, Object?>? sourceEntry(
    Map<String, Object?> sources,
    String gearId,
  ) {
    final Object? items = sources['items'];
    if (items is! Map) return null;
    final Object? entry = items[gearId];
    return entry is Map ? entry.cast<String, Object?>() : null;
  }

  /// V6 图源下载地址（imageUrl）。
  static String sourceUrlFor(Map<String, Object?> sources, String gearId) {
    final Map<String, Object?>? entry = sourceEntry(sources, gearId);
    return entry == null ? '' : '${entry['imageUrl'] ?? ''}'.trim();
  }

  /// V6 图源标识（official/jd/pexels/...；内置条目为 builtin）。
  static String sourceProviderOf(Map<String, Object?> sources, String gearId) {
    final Map<String, Object?>? entry = sourceEntry(sources, gearId);
    return entry == null ? '' : '${entry['provider'] ?? ''}'.trim();
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

  /// 同步台账（断点续跑）：工作区 `images/gear/sync_state.json`。
  static Map<String, Object?> syncState() {
    final File? file = _stateFile();
    if (file == null || !file.existsSync()) {
      return <String, Object?>{
        'version': 1,
        'done': <String, Object?>{},
        'failed': <String, Object?>{},
      };
    }
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map) return decoded.cast<String, Object?>();
    } catch (_) {}
    return <String, Object?>{
      'version': 1,
      'done': <String, Object?>{},
      'failed': <String, Object?>{},
    };
  }

  /// 用户补图登记（工作区 `images/gear/sources.json`）。
  static Map<String, Object?> userRegistry() {
    final File? file = _registryFile();
    if (file == null || !file.existsSync()) {
      return <String, Object?>{'version': 1, 'items': <String, Object?>{}};
    }
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map) return decoded.cast<String, Object?>();
    } catch (_) {}
    return <String, Object?>{'version': 1, 'items': <String, Object?>{}};
  }

  /// 计算同步计划（纯函数，可离线测试）：
  /// 内置资产已有/本地已缓存/图源被关闭/断点已完成（未被 force）都跳过。
  static GearSyncPlan planSync({
    required Map<String, Object?> catalog,
    required Map<String, Object?> sources,
    required Set<String> localIds,
    required Set<String> bundledIds,
    required Map<String, Object?> state,
    Set<String>? enabledProviders,
    bool force = false,
    bool retryFailed = false,
  }) {
    final Map<String, Object?> done =
        (state['done'] as Map?)?.cast<String, Object?>() ?? <String, Object?>{};
    final Map<String, Object?> failed =
        (state['failed'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};

    final List<GearSyncTarget> targets = <GearSyncTarget>[];
    final Set<String> seen = <String>{};
    int skippedLocal = 0;
    int skippedBuiltin = 0;
    int skippedSource = 0;
    int skippedFailed = 0;
    int skippedDone = 0;

    void consider(String id, String url, String provider, bool builtin) {
      if (id.isEmpty || url.isEmpty || !seen.add(id)) return;
      final String providerKey = provider.isEmpty ? 'builtin' : provider;
      if (enabledProviders != null &&
          !enabledProviders.contains(providerKey) &&
          !(builtin && enabledProviders.contains('builtin'))) {
        skippedSource++;
        return;
      }
      if (!force && localIds.contains(id)) {
        skippedLocal++;
        return;
      }
      if (!force && builtin && bundledIds.contains(id)) {
        skippedBuiltin++;
        return;
      }
      if (failed.containsKey(id)) {
        final int attempts = (failed[id] as Map?)?['attempts'] is num
            ? ((failed[id] as Map)['attempts'] as num).toInt()
            : 1;
        if (!retryFailed && !force && attempts >= maxAttempts) {
          skippedFailed++;
          return;
        }
      }
      if (!force && done.containsKey(id)) {
        skippedDone++;
        return;
      }
      targets.add(GearSyncTarget(id: id, url: url, provider: providerKey));
    }

    final List<Map<String, Object?>> catalogEntries = _collect(catalog);
    for (final Map<String, Object?> entry in catalogEntries) {
      final String id = '${entry['id'] ?? ''}'.trim();
      consider(
        id,
        runtimeUrlOf(entry),
        'builtin',
        entry['builtin'] == true || entry['bundled'] != false,
      );
    }
    final Object? items = sources['items'];
    if (items is Map) {
      for (final MapEntry<Object?, Object?> item in items.entries) {
        if (item.value is! Map) continue;
        final Map<String, Object?> record = (item.value as Map)
            .cast<String, Object?>();
        if ('${record['kind'] ?? ''}' == 'props') continue;
        consider(
          '${item.key}'.trim(),
          '${record['imageUrl'] ?? ''}'.trim(),
          '${record['provider'] ?? ''}'.trim(),
          false,
        );
      }
    }
    return GearSyncPlan(
      targets: targets,
      skippedLocal: skippedLocal,
      skippedBuiltin: skippedBuiltin,
      skippedSource: skippedSource,
      skippedFailed: skippedFailed,
      skippedDone: skippedDone,
    );
  }

  /// 同步可下载条目；返回本次报告（含缺口）。[onProgress] 回调 (done, total)。
  static Future<GearSyncReport> syncAll({
    void Function(int done, int total)? onProgress,
    AppDatabase? db,
    bool force = false,
    bool retryFailed = false,
  }) async {
    final Map<String, Object?> cat = await catalog();
    final Map<String, Object?> src = await sources();

    String proxy = '';
    String? limitMb = defaultCacheLimitMb;
    Set<String>? enabled;
    if (db != null) {
      try {
        proxy = (await db.getSetting('proxy_url')) ?? '';
        limitMb = await db.getSetting('gear_cache_limit_mb') ?? limitMb;
        final String rawSources =
            (await db.getSetting('gear_sync_sources')) ?? '';
        if (rawSources.trim().isNotEmpty) {
          final Object? decoded = jsonDecode(rawSources);
          if (decoded is List) {
            enabled = decoded.map((Object? e) => '$e').toSet();
          }
        }
      } catch (_) {
        // 使用默认设置
      }
    }

    final Set<String> localIds = <String>{};
    final Set<String> bundledIds = <String>{};
    for (final Map<String, Object?> entry in _collect(cat)) {
      final String id = '${entry['id'] ?? ''}'.trim();
      if (id.isNotEmpty && localPathFor(id) != null) localIds.add(id);
      final String? asset = assetPath(entry);
      if (asset != null && await assetExists(asset)) bundledIds.add(id);
    }

    final GearSyncPlan plan = planSync(
      catalog: cat,
      sources: src,
      localIds: localIds,
      bundledIds: bundledIds,
      state: syncState(),
      enabledProviders: enabled,
      force: force,
      retryFailed: retryFailed,
    );

    final Directory? dir = _cacheDir();
    if (dir == null) {
      return GearSyncReport(
        total: plan.targets.length,
        downloaded: 0,
        skippedLocal: plan.skippedLocal,
        skippedBuiltin: plan.skippedBuiltin,
        skippedSource: plan.skippedSource,
        skippedFailed: plan.skippedFailed,
        skippedDone: plan.skippedDone,
        failedIds: plan.targets.map((GearSyncTarget t) => t.id).toList(),
      );
    }

    final Dio dio = makeDio(proxy: proxy, timeout: const Duration(seconds: 25));
    final Map<String, Object?> state = syncState();
    final Map<String, Object?> done =
        (state['done'] as Map?)?.cast<String, Object?>() ?? <String, Object?>{};
    final Map<String, Object?> failed =
        (state['failed'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    final List<String> failedIds = <String>[];
    int downloaded = 0;
    int index = 0;
    for (final GearSyncTarget target in plan.targets) {
      index++;
      onProgress?.call(index, plan.targets.length);
      bool ok = false;
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final Response<List<int>> res = await dio.get<List<int>>(
            target.url,
            options: Options(
              responseType: ResponseType.bytes,
              followRedirects: true,
              validateStatus: (int? s) => s != null && s < 400,
            ),
          );
          final List<int>? bytes = res.data;
          if (bytes == null || bytes.length < 2048) break;
          await File(
            p.join(dir.path, '${target.id}.jpg'),
          ).writeAsBytes(bytes, flush: true);
          done[target.id] = <String, Object?>{
            'at': DateTime.now().toUtc().toIso8601String(),
            'url': target.url,
            'provider': target.provider,
          };
          failed.remove(target.id);
          ok = true;
          downloaded++;
          break;
        } on DioException catch (_) {
          if (attempt >= 2) break;
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        } catch (_) {
          break;
        }
      }
      if (!ok) {
        final int attempts =
            ((failed[target.id] as Map?)?['attempts'] as num?)?.toInt() ?? 0;
        failed[target.id] = <String, Object?>{
          'reason': '下载失败',
          'attempts': attempts + 1,
          'at': DateTime.now().toUtc().toIso8601String(),
        };
        failedIds.add(target.id);
      }
      if ((downloaded + failedIds.length) % 10 == 0) {
        _writeState(state: state, done: done, failed: failed);
      }
    }
    _writeState(state: state, done: done, failed: failed);
    await enforceCacheLimit(limitMb: int.tryParse(limitMb ?? ''));
    return GearSyncReport(
      total: plan.targets.length,
      downloaded: downloaded,
      skippedLocal: plan.skippedLocal,
      skippedBuiltin: plan.skippedBuiltin,
      skippedSource: plan.skippedSource,
      skippedFailed: plan.skippedFailed,
      skippedDone: plan.skippedDone,
      failedIds: failedIds,
    );
  }

  /// 缺口清单：无内置、无本地、无同步缓存且无可用图源的条目 id。
  static Future<List<String>> gapIds({AppDatabase? db}) async {
    final Map<String, Object?> cat = await catalog();
    final Map<String, Object?> src = await sources();
    final Set<String> sourceIds = <String>{};
    final Object? items = src['items'];
    if (items is Map) {
      sourceIds.addAll(items.keys.map((Object? k) => '$k'));
    }
    final List<String> gaps = <String>[];
    for (final Map<String, Object?> entry in _collect(cat)) {
      final String id = '${entry['id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      if (localPathFor(id) != null) continue;
      final String? asset = assetPath(entry);
      if (asset != null && await assetExists(asset)) continue;
      if (runtimeUrlOf(entry).isNotEmpty) continue;
      if (sourceIds.contains(id)) continue;
      gaps.add(id);
    }
    return gaps;
  }

  /// 用户补图：本地文件 → 工作区 `images/gear/<id>.jpg` 并登记来源。
  static Future<String> importLocalFile(String gearId, File file) async {
    final Directory? dir = _cacheDir();
    if (dir == null) throw StateError('工作区未就绪');
    final String path = p.join(dir.path, '$gearId.jpg');
    await File(path).writeAsBytes(await file.readAsBytes(), flush: true);
    _register(gearId, source: 'user-file', url: file.path);
    return path;
  }

  /// 用户补图：图片链接 → 下载到工作区并登记来源（走 NetRouter）。
  static Future<String> importFromUrl(
    String gearId,
    String url, {
    AppDatabase? db,
  }) async {
    final Directory? dir = _cacheDir();
    if (dir == null) throw StateError('工作区未就绪');
    String proxy = '';
    if (db != null) {
      try {
        proxy = (await db.getSetting('proxy_url')) ?? '';
      } catch (_) {}
    }
    final Dio dio = makeDio(proxy: proxy, timeout: const Duration(seconds: 25));
    final Response<List<int>> res = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        validateStatus: (int? s) => s != null && s < 400,
      ),
    );
    final List<int>? bytes = res.data;
    if (bytes == null || bytes.length < 2048) {
      throw StateError('图片过小或下载失败');
    }
    final String path = p.join(dir.path, '$gearId.jpg');
    await File(path).writeAsBytes(bytes, flush: true);
    _register(gearId, source: 'user-url', url: url);
    return path;
  }

  /// 缓存用量（字节）与条目数。
  static (int, int) cacheUsage() {
    final Directory? dir = _cacheDir();
    if (dir == null) return (0, 0);
    int bytes = 0;
    int count = 0;
    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.jpg')) {
        bytes += entity.lengthSync();
        count++;
      }
    }
    return (bytes, count);
  }

  /// 缓存上限（D131）：超出时按 mtime 从旧到新清理（用户补图优先保留）。
  static Future<int> enforceCacheLimit({int? limitMb}) async {
    final int limit =
        ((limitMb ?? int.tryParse(defaultCacheLimitMb)) ?? 2048) * 1024 * 1024;
    final Directory? dir = _cacheDir();
    if (dir == null) return 0;
    final Map<String, Object?> registry = userRegistry();
    final Set<String> userIds = <String>{};
    final Object? items = registry['items'];
    if (items is Map) userIds.addAll(items.keys.map((Object? k) => '$k'));

    final List<File> files = dir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.jpg'))
        .toList();
    int total = files.fold<int>(0, (int sum, File f) => sum + f.lengthSync());
    if (total <= limit) return 0;
    final List<File> removable =
        files
            .where(
              (File f) => !userIds.contains(p.basenameWithoutExtension(f.path)),
            )
            .toList()
          ..sort(
            (File a, File b) =>
                a.statSync().modified.compareTo(b.statSync().modified),
          );
    int removed = 0;
    for (final File f in removable) {
      if (total <= limit) break;
      final int size = f.lengthSync();
      try {
        f.deleteSync();
        total -= size;
        removed++;
      } catch (_) {}
    }
    return removed;
  }

  static void _register(
    String gearId, {
    required String source,
    String url = '',
  }) {
    final File? file = _registryFile();
    if (file == null) return;
    final Map<String, Object?> registry = userRegistry();
    final Map<String, Object?> items =
        (registry['items'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    items[gearId] = <String, Object?>{
      'source': source,
      'url': url,
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    registry['items'] = items;
    registry['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(registry), flush: true);
    } catch (_) {}
  }

  static void _writeState({
    required Map<String, Object?> state,
    required Map<String, Object?> done,
    required Map<String, Object?> failed,
  }) {
    final File? file = _stateFile();
    if (file == null) return;
    state['version'] = 1;
    state['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    state['done'] = done;
    state['failed'] = failed;
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(state), flush: true);
    } catch (_) {}
  }

  static File? _stateFile() {
    try {
      return File(
        p.join(Workspace.I.root.path, 'images', 'gear', 'sync_state.json'),
      );
    } catch (_) {
      return null;
    }
  }

  static File? _registryFile() {
    try {
      return File(
        p.join(Workspace.I.root.path, 'images', 'gear', 'sources.json'),
      );
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, Object?>> _collect(Map<String, Object?> cat) {
    final List<Map<String, Object?>> out = <Map<String, Object?>>[];
    final Set<String> seen = <String>{};
    void addEntry(Object? item) {
      if (item is List) {
        for (final Object? nested in item) {
          addEntry(nested);
        }
        return;
      }
      if (item is! Map) return;
      final Map<String, Object?> entry = item.cast<String, Object?>();
      final String id = '${entry['id'] ?? ''}'.trim();
      if (id.isEmpty || !seen.add(id)) return;
      out.add(entry);
    }

    void addAll(Object? raw) {
      if (raw is Map) {
        for (final Object? item in raw.values) {
          addEntry(item);
        }
      } else if (raw is List) {
        for (final Object? item in raw) {
          addEntry(item);
        }
      }
    }

    addAll(cat['byId']);
    addAll(cat['byModel']);
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
