import 'dart:async';

import '../image_sources.dart' show describeNetworkError;
import 'result_ranker.dart';
import 'search_models.dart';

/// V6 聚合搜索（合同 §3.C）：多源并发、逐源状态、统一排序去重。
class SearchEngine {
  SearchEngine({required List<SearchSource> sources})
    : _sources = List<SearchSource>.of(sources);

  final List<SearchSource> _sources;

  List<SearchSource> get sources => _sources;

  /// 当前域可用源（含未启用 Key 的源，UI 需要展示"未启用"）。
  List<SearchSource> sourcesFor(ImageDomain domain) => _sources
      .where((SearchSource s) => s.capability.supportsDomain(domain))
      .toList();

  Future<AggregatedResult> search(
    SearchQuery query, {
    int page = 1,
    int perPage = 24,
    bool commercialOnly = false,
    bool allDomains = false,
  }) async {
    final List<SearchSource> active = allDomains
        ? List<SearchSource>.of(_sources)
        : sourcesFor(query.domain);
    final List<SearchHit> hits = <SearchHit>[];
    final List<SourceStatus> statuses = <SourceStatus>[];
    final List<bool> more = <bool>[];

    await Future.wait(
      active.map((SearchSource source) async {
        if (!source.enabled) {
          statuses.add(
            SourceStatus(
              id: source.id,
              label: source.label,
              ok: false,
              count: 0,
              elapsedMs: 0,
              enabled: false,
              hint: source.disabledHint,
              domain: query.domain,
            ),
          );
          return;
        }
        final Stopwatch sw = Stopwatch()..start();
        try {
          final SourceSearchPage result = await source.search(
            query,
            page: page,
            perPage: perPage,
          );
          sw.stop();
          hits.addAll(result.hits);
          more.add(result.hasMore);
          statuses.add(
            SourceStatus(
              id: source.id,
              label: source.label,
              ok: true,
              count: result.hits.length,
              elapsedMs: sw.elapsedMilliseconds,
              domain: query.domain,
            ),
          );
        } catch (e) {
          sw.stop();
          statuses.add(
            SourceStatus(
              id: source.id,
              label: source.label,
              ok: false,
              count: 0,
              elapsedMs: sw.elapsedMilliseconds,
              error: describeNetworkError(e),
              domain: query.domain,
            ),
          );
        }
      }),
    );

    statuses.sort((SourceStatus a, SourceStatus b) {
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      if (a.ok != b.ok) return a.ok ? -1 : 1;
      return a.id.compareTo(b.id);
    });
    final List<SearchHit> ranked = ResultRanker.rank(
      hits,
      query: query,
      commercialOnly: commercialOnly,
    );
    return AggregatedResult(
      hits: ranked,
      statuses: statuses,
      page: page,
      hasMore: more.any((bool value) => value),
      query: query,
      rankNote: commercialOnly ? '仅可商用 · 按匹配度/源权重/分辨率排序' : '按匹配度/源权重/分辨率排序',
    );
  }
}
