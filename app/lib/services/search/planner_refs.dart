import 'dart:typed_data';

import '../../core/db/database.dart';
import '../image_store.dart';
import '../palette_extractor.dart';
import 'query_planner.dart';
import 'search_cache.dart';
import 'search_engine.dart';
import 'search_keys.dart';
import 'search_models.dart';

/// AI 策划联动（D121）：按主题自动搜集 5–10 张参考图并写入参考样片模块。
///
/// - 图片下载到工作区 `images/refs/`（R47：不入 git/安装包）；
/// - 每条登记来源与许可（R56）；
/// - 网络/Key 不可用时返回空列表，由调用方提示，不阻塞策划案生成。
class PlannerRefsService {
  PlannerRefsService({required AppDatabase db, required this.workspaceRoot})
    : _db = db;

  final AppDatabase _db;
  final String workspaceRoot;

  Future<List<Map<String, Object?>>> searchForTheme(
    String theme, {
    int target = 8,
  }) async {
    final String trimmed = theme.trim();
    if (trimmed.isEmpty) return <Map<String, Object?>>[];
    final QueryPlanner planner = QueryPlanner(_db);
    SearchQuery query = await planner.plan(trimmed, domain: ImageDomain.photo);
    if (query.text.trim().isEmpty) {
      // 摄影域无词时尝试影视域（TMDB 支持中文检索但红线优先英文词）。
      final SearchQuery film = await planner.plan(
        trimmed,
        domain: ImageDomain.film,
      );
      if (film.text.trim().isNotEmpty || film.title.trim().isNotEmpty) {
        query = film;
      } else {
        return <Map<String, Object?>>[];
      }
    }
    final SearchKeys keys = await SearchKeys.load(_db);
    final SearchEngine engine = SearchEngine(sources: keys.sources());
    final AggregatedResult result = await engine.search(
      query,
      perPage: target + 6,
    );
    if (result.hits.isEmpty) return <Map<String, Object?>>[];
    final SearchCache cache = await SearchCache.from(_db, workspaceRoot);
    final ImageStore store = ImageStore(workspaceRoot);
    final List<Map<String, Object?>> entries = <Map<String, Object?>>[];
    for (final SearchHit hit in result.hits) {
      if (entries.length >= target) break;
      try {
        final Uint8List bytes = await cache.getOrFetch(
          hit.fullUrl,
          original: true,
        );
        if (bytes.isEmpty) continue;
        final (String fileName, PaletteResult palette) = await store
            .importBytes(bytes, category: 'refs', title: hit.title);
        entries.add(<String, Object?>{
          'name': '${hit.title}（${hit.sourceLabel}）',
          'palette': palette.colors,
          'gradient': palette.colors.take(2).toList(),
          'sourceUrl': hit.sourcePageUrl.isEmpty
              ? hit.fullUrl
              : hit.sourcePageUrl,
          'imageRef': fileName,
          'source': hit.sourceLabel,
          'license': hit.license,
        });
      } catch (_) {
        // 单张失败跳过，尽力而为。
      }
    }
    return entries;
  }
}
