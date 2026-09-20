import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../services/image_sources.dart' show describeNetworkError;
import '../../services/search/image_to_search.dart';
import '../../services/search/query_planner.dart';
import '../../services/search/result_ranker.dart';
import '../../services/search/search_cache.dart';
import '../../services/search/search_engine.dart';
import '../../services/search/search_keys.dart';
import '../../services/search/search_models.dart';
import '../../services/search/theme_packs.dart';
import '../../services/search_prefs.dart';
import 'refs_controller.dart';

/// V6 搜图工作台（合同 §3.C.7）：多源聚合 / 人名按作品分组 / 每源状态 /
/// 许可筛选 / 主题包 / 以图搜图 / 一键入案；免责声明固定可见（R47）。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery = '',
    this.initialDomain = ImageDomain.photo,
  });

  final String initialQuery;
  final ImageDomain initialDomain;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _input = TextEditingController();

  late ImageDomain _domain = widget.initialDomain;
  SearchIntent? _intentOverride;
  bool _commercialOnly = false;

  bool _loading = false;
  bool _loadingMore = false;
  String _status = '输入画面描述 / 片名 / 人名 / 主题，多源聚合搜索';
  List<SearchHit> _hits = <SearchHit>[];
  List<SourceStatus> _statuses = <SourceStatus>[];
  SearchQuery? _query;
  SearchEngine? _engine;
  int _page = 1;
  bool _hasMore = false;
  String _lastInput = '';

  List<String> _history = <String>[];
  List<String> _favorites = <String>[];
  bool _isFav = false;

  VisionResult? _vision;
  bool _visionLoading = false;

  SearchCache? _cache;
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _input.text = widget.initialQuery;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
      final AppDatabase db = ref.read(databaseProvider);
      final List<String> history = await SearchPrefsView.history(db);
      final List<String> favorites = await SearchPrefsView.favorites(db);
      final SearchCache cache = await SearchCache.from(
        db,
        ref.read(workspaceProvider).root.path,
      );
      final int bytes = await cache.totalBytes();
      if (!mounted) return;
      setState(() {
        _history = history;
        _favorites = favorites;
        _cache = cache;
        _cacheBytes = bytes;
      });
      if (widget.initialQuery.trim().isNotEmpty) {
        unawaited(_run());
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _status = '正在规划查询…';
      _hits = <SearchHit>[];
      _statuses = <SourceStatus>[];
      _page = 1;
      _hasMore = false;
      _lastInput = text;
      _vision = null;
    });
    final AppDatabase db = ref.read(databaseProvider);
    await SearchPrefsView.pushHistory(db, text);
    _history = await SearchPrefsView.history(db);
    _isFav = await SearchPrefsView.isFavorite(db, text);
    final QueryPlanner planner = QueryPlanner(db);
    SearchQuery query = await planner.plan(text, domain: _domain);
    query = _applyIntentOverride(query);
    if (!mounted) return;
    if (query.text.trim().isEmpty &&
        query.person.trim().isEmpty &&
        query.title.trim().isEmpty) {
      setState(() {
        _loading = false;
        _status = query.sourceNote.isEmpty
            ? '未得到英文检索词：请换用可识别的画面词（词表）、配置 AI 提供方或改用英文关键词'
            : query.sourceNote;
      });
      return;
    }
    await _runQuery(query);
  }

  SearchQuery _applyIntentOverride(SearchQuery query) {
    final SearchIntent? override = _intentOverride;
    if (override == null || override == query.intent) return query;
    if (override == SearchIntent.person) {
      final String person = QueryPlanner.extractPerson(query.raw);
      return query.copyWith(
        intent: SearchIntent.person,
        person: person,
        title: '',
        perSource: <String, String>{
          if (person.isNotEmpty) ...<String, String>{
            'tmdb': person,
            'anilist': person,
          },
        },
      );
    }
    if (override == SearchIntent.title) {
      return query.copyWith(
        intent: SearchIntent.title,
        title: query.raw,
        person: '',
        perSource: const <String, String>{},
      );
    }
    return query.copyWith(
      intent: SearchIntent.keyword,
      person: '',
      title: '',
      perSource: const <String, String>{},
    );
  }

  Future<void> _runQuery(SearchQuery query) async {
    setState(() {
      _loading = true;
      _status = '多源搜索中…（${query.domain.label}）';
      _query = query;
    });
    try {
      final SearchKeys keys = await SearchKeys.load(ref.read(databaseProvider));
      final SearchEngine engine = SearchEngine(sources: keys.sources());
      final AggregatedResult result = await engine.search(
        query,
        page: 1,
        commercialOnly: _commercialOnly,
      );
      if (!mounted) return;
      setState(() {
        _engine = engine;
        _loading = false;
        _hits = result.hits;
        _statuses = result.statuses;
        _page = 1;
        _hasMore = result.hasMore;
        _status = _describe(result);
      });
      await _refreshCacheUsage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '搜索失败：${describeNetworkError(e)}';
      });
    }
  }

  Future<void> _loadMore() async {
    final SearchEngine? engine = _engine;
    final SearchQuery? query = _query;
    if (engine == null || query == null || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final AggregatedResult result = await engine.search(
      query,
      page: _page + 1,
      commercialOnly: _commercialOnly,
    );
    if (!mounted) return;
    final List<SearchHit> merged = ResultRanker.rank(
      <SearchHit>[..._hits, ...result.hits],
      query: query,
      commercialOnly: _commercialOnly,
    );
    setState(() {
      _loadingMore = false;
      _page += 1;
      _hasMore = result.hasMore;
      _hits = merged;
      _status = '已加载至第 $_page 页 · 共 ${_hits.length} 条';
      for (final SourceStatus s in result.statuses) {
        if (!s.ok && s.enabled) continue;
        final int idx = _statuses.indexWhere((SourceStatus e) => e.id == s.id);
        if (idx >= 0) _statuses[idx] = s;
      }
    });
  }

  /// 单源重试（R45）。
  Future<void> _retrySource(SourceStatus status) async {
    final SearchEngine? engine = _engine;
    final SearchQuery? query = _query;
    if (engine == null || query == null || _loading) return;
    SearchSource? source;
    for (final SearchSource s in engine.sourcesFor(query.domain)) {
      if (s.id == status.id) source = s;
    }
    if (source == null) return;
    setState(() => _status = '重试 ${status.label}…');
    final Stopwatch sw = Stopwatch()..start();
    try {
      final SourceSearchPage page = await source.search(
        query,
        page: 1,
        perPage: 24,
      );
      sw.stop();
      if (!mounted) return;
      setState(() {
        _hits = ResultRanker.rank(
          <SearchHit>[...page.hits, ..._hits],
          query: query,
          commercialOnly: _commercialOnly,
        );
        _statuses = <SourceStatus>[
          for (final SourceStatus s in _statuses)
            if (s.id == status.id)
              SourceStatus(
                id: s.id,
                label: s.label,
                ok: true,
                count: page.hits.length,
                elapsedMs: sw.elapsedMilliseconds,
                domain: s.domain,
              )
            else
              s,
        ];
        _status =
            '${status.label} 重试成功：${page.hits.length} 条 · '
            '${sw.elapsedMilliseconds}ms';
      });
    } catch (e) {
      sw.stop();
      if (!mounted) return;
      setState(() {
        _statuses = <SourceStatus>[
          for (final SourceStatus s in _statuses)
            if (s.id == status.id)
              SourceStatus(
                id: s.id,
                label: s.label,
                ok: false,
                count: 0,
                elapsedMs: sw.elapsedMilliseconds,
                error: describeNetworkError(e),
                domain: s.domain,
              )
            else
              s,
        ];
        _status = '${status.label} 重试失败：${describeNetworkError(e)}';
      });
    }
  }

  String _describe(AggregatedResult result) {
    final int ok = result.okSources;
    final int failed = result.failedSources;
    if (result.hits.isEmpty) {
      if (ok == 0 && failed > 0) {
        return '所有源均失败：可检查网络/代理，或在设置页配置图源 Key；'
            '本地 PD 静帧库与素材包不受影响';
      }
      return '没有结果（关键词：${result.query.text}）· 换个描述、切换分类或试用主题包';
    }
    return '共 ${result.hits.length} 条 · 关键词：${result.query.text}'
        '${result.query.sourceNote.isEmpty ? '' : '（${result.query.sourceNote}）'}'
        '${failed > 0 ? ' · $failed 个源失败（可点击重试）' : ''}';
  }

  /// 一键加入参考画面（下载原图 → 画板，带来源与许可，R47）。
  Future<void> _addToBoard(SearchHit hit) async {
    setState(() => _status = '正在下载「${hit.title}」…');
    try {
      final SearchCache? cache = _cache;
      final Uint8List bytes = cache != null
          ? await cache.getOrFetch(hit.fullUrl, original: true)
          : await SearchCache(
              ref.read(workspaceProvider).root.path,
            ).getOrFetch(hit.fullUrl, original: true);
      await ref
          .read(refsControllerProvider.notifier)
          .addFetched(
            bytes: bytes,
            title: hit.title,
            sourceUrl: hit.fullUrl,
            sourceLabel: '${hit.sourceLabel} · ${hit.license}',
          );
      if (!mounted) return;
      setState(() => _status = '已收入画板：${hit.title}（${hit.sourceLabel}）');
      ssToast(context, '已加入参考画面');
      await _refreshCacheUsage();
    } catch (e) {
      if (mounted) {
        setState(() => _status = '下载失败：${describeNetworkError(e)}');
      }
    }
  }

  Future<void> _refreshCacheUsage() async {
    final SearchCache? cache = _cache;
    if (cache == null) return;
    final int bytes = await cache.totalBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  /// 以图搜图（D116）：AI 视觉描述 → 关键词 → 多源搜。
  Future<void> _searchByImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: '选择参考图（AI 视觉描述 → 多源检索）',
    );
    final String? path = result?.files.single.path;
    if (path == null || !mounted) return;
    final Uint8List bytes = await File(path).readAsBytes();
    if (!mounted) return;
    setState(() {
      _visionLoading = true;
      _status = 'AI 视觉分析中…';
      _vision = null;
    });
    final ImageToSearch service = ImageToSearch(ref.read(databaseProvider));
    final ({VisionResult vision, SearchQuery? query}) planned = await service
        .planFromImage(bytes, domain: _domain);
    if (!mounted) return;
    if (planned.query == null) {
      setState(() {
        _visionLoading = false;
        _vision = planned.vision;
        _status = planned.vision.error.isNotEmpty
            ? planned.vision.error
            : '视觉分析未得到英文关键词：可手动输入关键词继续';
      });
      return;
    }
    setState(() {
      _visionLoading = false;
      _vision = planned.vision;
      _input.text = planned.vision.keywords;
    });
    await _runQuery(planned.query!);
  }

  Future<void> _toggleFavorite() async {
    final String q = _lastInput.isEmpty ? _input.text.trim() : _lastInput;
    if (q.isEmpty) return;
    final AppDatabase db = ref.read(databaseProvider);
    final bool added = await SearchPrefsView.toggleFavorite(db, q);
    final List<String> list = await SearchPrefsView.favorites(db);
    if (!mounted) return;
    setState(() {
      _isFav = added;
      _favorites = list;
      _status = added ? '已收藏检索词「$q」' : '已取消收藏「$q」';
    });
  }

  Future<void> _showThemePacks() async {
    final ThemePack? picked = await showModalBottomSheet<ThemePack>(
      context: context,
      builder: (BuildContext ctx) => _ThemePackSheet(domain: _domain),
    );
    if (picked == null || !mounted) return;
    final AppDatabase db = ref.read(databaseProvider);
    final QueryPlanner planner = QueryPlanner(db);
    final SearchQuery query = planner.fromThemePack(picked);
    setState(() {
      _domain = query.domain;
      _input.text = picked.name;
      _lastInput = picked.name;
      _intentOverride = null;
    });
    await SearchPrefsView.pushHistory(db, picked.name);
    await _runQuery(query);
  }

  void _switchDomain(ImageDomain domain) {
    if (_domain == domain || _loading) return;
    setState(() => _domain = domain);
    if (_input.text.trim().isNotEmpty && _query != null) {
      unawaited(_run());
    }
  }

  void _showDetail(SearchHit hit) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => _HitDetailDialog(
        hit: hit,
        onAdd: () {
          Navigator.pop(ctx);
          _addToBoard(hit);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜图工作台'),
        actions: <Widget>[
          IconButton(
            tooltip: _isFav ? '取消收藏检索词' : '收藏检索词',
            icon: Icon(
              _isFav ? Icons.star_rounded : Icons.star_outline_rounded,
            ),
            onPressed: _toggleFavorite,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildSearchBar(theme),
          _buildStatusRow(theme),
          const Divider(height: 1),
          Expanded(child: _buildResults(theme)),
          _buildFooter(theme),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s16,
        AppTokens.s12,
        AppTokens.s16,
        AppTokens.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _input,
                  decoration: const InputDecoration(
                    hintText: '例：雨夜霓虹 天台 逆光 / 星际穿越 / 导演 诺兰 / 伦勃朗光',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _run(),
                ),
              ),
              const SizedBox(width: 6),
              SsButton(
                label: _loading ? '搜索中…' : '搜索',
                dense: true,
                onPressed: _loading ? null : _run,
              ),
              const SizedBox(width: 6),
              SsButton(
                label: _visionLoading ? '分析中…' : '以图搜图',
                icon: Icons.image_search_rounded,
                kind: SsButtonKind.soft,
                dense: true,
                onPressed: _visionLoading ? null : _searchByImage,
              ),
              const SizedBox(width: 6),
              SsButton(
                label: '主题包',
                icon: Icons.collections_bookmark_outlined,
                kind: SsButtonKind.ghost,
                dense: true,
                onPressed: _showThemePacks,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final ImageDomain domain in ImageDomain.values)
                SsChip(
                  label: domain.label,
                  selected: _domain == domain,
                  onTap: () => _switchDomain(domain),
                ),
              const SizedBox(width: 8),
              for (final SearchIntent? intent in <SearchIntent?>[
                null,
                SearchIntent.title,
                SearchIntent.person,
                SearchIntent.keyword,
              ])
                SsChip(
                  label: intent == null ? '自动意图' : intent.label,
                  selected: _intentOverride == intent,
                  onTap: () => setState(() => _intentOverride = intent),
                ),
              const SizedBox(width: 8),
              SsChip(
                label: '仅可商用',
                selected: _commercialOnly,
                onTap: () {
                  setState(() => _commercialOnly = !_commercialOnly);
                  if (_query != null) unawaited(_runQuery(_query!));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, 0, AppTokens.s16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _status,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_vision != null && _vision!.success) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '视觉描述：${_vision!.description}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_statuses.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final SourceStatus s in _statuses)
                  SsChip(
                    label: '${s.label}：${s.summary}',
                    selected: s.ok,
                    onTap: (!s.ok && s.enabled) ? () => _retrySource(s) : () {},
                  ),
                if (_statuses.any((SourceStatus s) => !s.ok && s.enabled))
                  SsButton(
                    label: '重试失败源',
                    kind: SsButtonKind.ghost,
                    dense: true,
                    onPressed: () async {
                      for (final SourceStatus s in List<SourceStatus>.of(
                        _statuses,
                      )) {
                        if (!s.ok && s.enabled) await _retrySource(s);
                      }
                    },
                  ),
              ],
            ),
          ],
          if (_history.isNotEmpty && _hits.isEmpty && !_loading) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                Text(
                  '历史',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final String h in _history.take(6))
                  InkWell(
                    onTap: () {
                      _input.text = h;
                      _run();
                    },
                    child: Text(
                      h,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTokens.accent,
                      ),
                    ),
                  ),
                if (_favorites.isNotEmpty)
                  Text(
                    '收藏',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                for (final String f in _favorites.take(6))
                  InkWell(
                    onTap: () {
                      _input.text = f;
                      _run();
                    },
                    child: Text(
                      '★ $f',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTokens.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (_hits.isEmpty) {
      return const SsEmpty(
        icon: Icons.travel_explore_rounded,
        title: '还没有结果',
        hint:
            '支持中文画面词（词表/AI 翻译）、片名、人名（按作品分组）与主题包；'
            '以图搜图需配置支持图片输入的 AI 提供方',
      );
    }
    final bool personMode = _query?.intent == SearchIntent.person;
    if (personMode) {
      return _buildGroupedResults(theme);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppTokens.s16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: _hits.length,
      itemBuilder: (BuildContext context, int i) => _HitCard(
        hit: _hits[i],
        onTap: () => _showDetail(_hits[i]),
        onAdd: () => _addToBoard(_hits[i]),
      ),
    );
  }

  Widget _buildGroupedResults(ThemeData theme) {
    final Map<String, List<SearchHit>> groups = <String, List<SearchHit>>{};
    for (final SearchHit hit in _hits) {
      final String key = hit.group.isEmpty ? '未分组' : hit.group;
      groups.putIfAbsent(key, () => <SearchHit>[]).add(hit);
    }
    final List<MapEntry<String, List<SearchHit>>> entries = groups.entries
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.s16),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int i) {
        final MapEntry<String, List<SearchHit>> entry = entries[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SsSectionTitle(
              entry.key,
              subtitle:
                  '${entry.value.length} 张 · '
                  '${entry.value.map((SearchHit h) => h.sourceLabel).toSet().join('/')}',
            ),
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entry.value.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int j) => SizedBox(
                  width: 180,
                  child: _HitCard(
                    hit: entry.value[j],
                    onTap: () => _showDetail(entry.value[j]),
                    onAdd: () => _addToBoard(entry.value[j]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final double usedMb = _cacheBytes / (1024 * 1024);
    final int limit = _cache?.limitMb ?? SearchCache.defaultLimitMb;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, 6, AppTokens.s16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '图片版权归原品牌/平台，仅供选型参考，禁止商用分发；许可与来源以标注为准。'
              '缓存 ${usedMb.toStringAsFixed(1)}MB / ${limit}MB（设置页可调）',
              style: TextStyle(
                fontSize: 10.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_hasMore)
            SsButton(
              label: _loadingMore ? '加载中…' : '加载更多',
              kind: SsButtonKind.ghost,
              dense: true,
              onPressed: _loadingMore ? null : _loadMore,
            ),
        ],
      ),
    );
  }
}

/// 搜索偏好薄封装（复用 V5 SearchPrefs，避免 UI 直接依赖数据库细节）。
abstract final class SearchPrefsView {
  static Future<List<String>> history(AppDatabase db) =>
      SearchPrefs(db).history();
  static Future<List<String>> favorites(AppDatabase db) =>
      SearchPrefs(db).favorites();
  static Future<void> pushHistory(AppDatabase db, String query) =>
      SearchPrefs(db).pushHistory(query);
  static Future<bool> isFavorite(AppDatabase db, String query) =>
      SearchPrefs(db).isFavorite(query);
  static Future<bool> toggleFavorite(AppDatabase db, String query) =>
      SearchPrefs(db).toggleFavorite(query);
}

class _HitCard extends StatelessWidget {
  const _HitCard({required this.hit, required this.onTap, required this.onAdd});

  final SearchHit hit;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.network(
                  hit.thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext c, Object e, StackTrace? st) =>
                      Container(
                        color: AppTokens.accentSoft,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onAdd,
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                if (hit.commercialOk)
                  const Positioned(left: 4, top: 4, child: SsMonoBadge('可商用')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hit.creditLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HitDetailDialog extends StatelessWidget {
  const _HitDetailDialog({required this.hit, required this.onAdd});

  final SearchHit hit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(hit.title, style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.rSm),
                child: Image.network(
                  hit.fullUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext c, Object e, StackTrace? st) =>
                      Container(
                        color: AppTokens.accentSoft,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '来源：${hit.sourceLabel} · 许可：${hit.license}'
              '${hit.commercialOk ? ' · 可商用' : ''}',
            ),
            if (hit.attribution.isNotEmpty) Text('署名：${hit.attribution}'),
            if (hit.width > 0 && hit.height > 0)
              Text('尺寸：${hit.width} × ${hit.height}'),
          ],
        ),
      ),
      actions: <Widget>[
        if (hit.sourcePageUrl.isNotEmpty)
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(hit.sourcePageUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('打开来源页'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        SsButton(
          label: '加入参考画面',
          icon: Icons.add_photo_alternate_outlined,
          dense: true,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _ThemePackSheet extends StatelessWidget {
  const _ThemePackSheet({required this.domain});

  final ImageDomain domain;

  @override
  Widget build(BuildContext context) {
    final List<ThemePack> packs = kThemePacks
        .where((ThemePack p) => p.domains.contains(domain))
        .toList();
    final List<ThemePack> others = kThemePacks
        .where((ThemePack p) => !p.domains.contains(domain))
        .toList();
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: 420,
        child: Column(
          children: <Widget>[
            const TabBar(
              tabs: <Widget>[
                Tab(text: '当前分类'),
                Tab(text: '全部主题包'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _packGrid(context, packs),
                  _packGrid(context, <ThemePack>[...packs, ...others]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _packGrid(BuildContext context, List<ThemePack> packs) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.4,
      ),
      itemCount: packs.length,
      itemBuilder: (BuildContext context, int i) {
        final ThemePack pack = packs[i];
        return SsCard(
          onTap: () => Navigator.pop(context, pack),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                pack.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${pack.description} · ${pack.enQuery}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
