import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as path;

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../services/search/image_to_search.dart';
import '../../services/search/query_planner.dart';
import '../../services/search/search_cache.dart';
import '../../services/search/search_engine.dart';
import '../../services/search/search_keys.dart';
import '../../services/search/search_models.dart';
import '../../services/search/theme_packs.dart';
import 'refs_board.dart';
import 'refs_controller.dart';
import 'refs_hit_card.dart';
import 'refs_hit_drawer.dart';
import 'refs_home.dart';
import 'refs_masonry.dart';
import 'refs_page_chrome.dart';

/// 参考图免责声明（R47/D130：许可与来源必须可见）。
const String kRefsDisclaimer = '参考图版权归原来源（影视/画作/摄影平台），仅供创作参考；逐图标注来源与许可，禁止二次分发。';

/// V8/D154 画面参考（杂志画册风重做）：首屏 = 居中检索 + 8 个常用主题画报（图卡）；
/// 结果 = 保留纵横比的瀑布流 + 悬停浮层（来源/许可/收画板/以图搜图）+ 详情抽屉
/// （大图 + 五色色卡 + 来源许可 + 相似图）；我的画板 = 图卡编排 + 拖拽排序 + 导出长图。
///
/// 检索管线（R75/D154：管线不动）保持原样：QueryPlanner → SearchEngine（13 源）→
/// SearchCache 落工作区 → RefsController 画板；本步只重做 UI 与展示层。
class RefsPage extends ConsumerStatefulWidget {
  const RefsPage({super.key});

  @override
  ConsumerState<RefsPage> createState() => _RefsPageState();
}

class _RefsPageState extends ConsumerState<RefsPage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey _boardKey = GlobalKey();
  List<SearchHit> _hits = <SearchHit>[];
  SearchQuery? _query;
  bool _searching = false;
  bool _hasMore = false;
  bool _exporting = false;
  int _page = 1;
  int _view = 0; // 0=搜索结果 1=我的画板
  String _status = '';
  String _vision = '';
  StreamSubscription<FileSystemEvent>? _watchSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
      await ref.read(refsControllerProvider.notifier).init();
      await _prefillFromPlan();
    });
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// 策划案主题联动（D133）：带入当前策划案的主题模块文本并自动检索。
  Future<void> _prefillFromPlan() async {
    final AppDatabase db = ref.read(databaseProvider);
    try {
      final List<Plan> rows =
          await (db.select(db.plans)
                ..orderBy(<OrderingTerm Function(Plans)>[
                  (Plans t) => OrderingTerm.desc(t.updatedAt),
                ])
                ..limit(1))
              .get();
      if (rows.isEmpty) return;
      final Object? decoded = jsonDecode(rows.first.modulesJson);
      if (decoded is! List) return;
      for (final Object? item in decoded) {
        final Map<String, Object?>? m = item is Map
            ? item.cast<String, Object?>()
            : null;
        if (m == null || '${m['type']}' != 'theme') continue;
        final Map<String, Object?> data = m['data'] is Map
            ? (m['data']! as Map).cast<String, Object?>()
            : <String, Object?>{};
        final String text = '${data['text'] ?? ''}'.trim();
        if (text.isEmpty) continue;
        if (!mounted) return;
        _search.text = text;
        await _runSearch();
        return;
      }
    } catch (_) {
      // 无策划案或数据异常时静默（搜索框仍可用）。
    }
  }

  Future<void> _runSearch({bool loadMore = false}) async {
    final String text = _search.text.trim();
    if (text.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _status = '检索中…';
      _vision = '';
      _view = 0;
      if (!loadMore) {
        _hits = <SearchHit>[];
        _query = null;
        _page = 1;
      }
    });
    try {
      final AppDatabase db = ref.read(databaseProvider);
      final QueryPlanner planner = QueryPlanner(db);
      final SearchQuery query =
          _query ?? await planner.plan(text, domain: ImageDomain.photo);
      final SearchKeys keys = await SearchKeys.load(db);
      final SearchEngine engine = SearchEngine(sources: keys.sources());
      final AggregatedResult result = await engine.search(
        query,
        page: loadMore ? _page + 1 : 1,
        perPage: 24,
        allDomains: true,
      );
      if (!mounted) return;
      final List<SearchHit> merged = loadMore
          ? <SearchHit>[
              ..._hits,
              ...result.hits.where(
                (SearchHit h) => !_hits.any((SearchHit e) => e.id == h.id),
              ),
            ]
          : result.hits;
      setState(() {
        _query = query;
        _hits = merged;
        _page = result.page;
        _hasMore = result.hasMore;
        _searching = false;
        _status = _describe(result, merged.length);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _status = '检索失败：$e';
      });
    }
  }

  String _describe(AggregatedResult result, int total) {
    if (total == 0) {
      return result.failedSources > 0
          ? '所有源均失败：检查网络/代理或在设置页配置图源 Key'
          : '没有结果 · 换个描述或点一个主题';
    }
    final String note = result.query.sourceNote.isEmpty
        ? ''
        : '（${result.query.sourceNote}）';
    return '共 $total 条 · ${result.okSources} 源$note'
        '${result.failedSources > 0 ? ' · ${result.failedSources} 源失败' : ''}';
  }

  /// 加入画板（R47：下载原图 → 工作区，带来源与许可）。
  Future<void> _addToBoard(SearchHit hit) async {
    ssToast(context, '正在下载「${hit.title}」…');
    try {
      final SearchCache cache = await SearchCache.from(
        ref.read(databaseProvider),
        ref.read(workspaceProvider).root.path,
      );
      final Uint8List bytes = await cache.getOrFetch(
        hit.fullUrl,
        original: true,
      );
      await ref
          .read(refsControllerProvider.notifier)
          .addFetched(
            bytes: bytes,
            title: hit.title,
            sourceUrl: hit.sourcePageUrl.isEmpty
                ? hit.fullUrl
                : hit.sourcePageUrl,
            sourceLabel: '${hit.sourceLabel} · ${hit.license}',
          );
      if (mounted) ssToast(context, '已加入参考画面（${hit.sourceLabel}）');
    } catch (e) {
      if (mounted) ssToast(context, '下载失败：$e');
    }
  }

  /// 详情抽屉（D154：大图 + 五色色卡 + 来源许可 + 相似图）。
  void _openHit(SearchHit hit) {
    showRefsHitDrawer(context, hit: hit, all: _hits, onAdd: _addToBoard);
  }

  /// 以图搜图的关键词回填入口（D116 视觉关键词 → 检索）。
  void _searchSimilar(SearchHit hit) {
    final String text = hit.group.isNotEmpty ? hit.group : hit.title;
    if (text.trim().isEmpty) return;
    setState(() {
      _search.text = text;
      _hits = <SearchHit>[];
      _query = null;
    });
    _runSearch();
  }

  void _openBoardFrame(RefFrame frame) {
    showRefFrameDialog(
      context: context,
      frame: frame,
      onRemove: () =>
          ref.read(refsControllerProvider.notifier).removeBoardItem(frame),
    );
  }

  String? _localImagePath(RefFrame frame) {
    if (frame.imagePath.isEmpty) return null;
    final String root = ref.read(workspaceProvider).root.path;
    final File file = File(path.join(root, 'images', 'refs', frame.imagePath));
    return file.existsSync() ? file.path : null;
  }

  /// 画板拖拽排序 → 持久化（D154；顺序存 setting，不改表结构）。
  Future<void> _reorderBoard(String dragId, String targetId) async {
    final RefsState state = ref.read(refsControllerProvider);
    final List<RefFrame> next = RefsBoardView.applyReorder(
      state.board,
      dragId,
      targetId,
    );
    await ref
        .read(refsControllerProvider.notifier)
        .setBoardOrder(next.map((RefFrame f) => f.id).toList());
  }

  /// 导出画板长图（D154：画册编排可交付）。
  Future<void> _exportBoard() async {
    setState(() => _exporting = true);
    try {
      final String file = await exportBoardLongImage(
        boundaryKey: _boardKey,
        workspaceRoot: ref.read(workspaceProvider).root.path,
      );
      if (mounted) ssToast(context, '画板长图已保存：$file');
    } catch (e) {
      if (mounted) ssToast(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pasteImage() async {
    try {
      final Uint8List? bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ssToast(context, '剪贴板没有图片（可先 Win+Shift+S 截图再按 Ctrl+V）');
        }
        return;
      }
      await ref
          .read(refsControllerProvider.notifier)
          .addFetched(
            bytes: bytes,
            title: '剪贴板 ${DateTime.now().toIso8601String().substring(11, 19)}',
            sourceUrl: '',
            sourceLabel: '剪贴板',
          );
      if (mounted) {
        setState(() => _view = 1);
        ssToast(context, '已从剪贴板收入画板');
      }
    } catch (e) {
      if (mounted) ssToast(context, '粘贴失败：$e');
    }
  }

  Future<void> _importLocal() async {
    final int count = await ref
        .read(refsControllerProvider.notifier)
        .importLocalImages();
    if (mounted && count > 0) {
      setState(() => _view = 1);
      ssToast(context, '已导入并收入画板：$count 张');
    }
  }

  /// 以图搜图（D116）：AI 视觉描述 → 关键词 → 多源检索。
  Future<void> _searchByImage() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: '选择参考图（AI 视觉描述 → 多源检索）',
    );
    final String? pickedPath = picked?.files.single.path;
    if (pickedPath == null || !mounted) return;
    final Uint8List bytes = await File(pickedPath).readAsBytes();
    if (!mounted) return;
    setState(() {
      _searching = true;
      _status = 'AI 视觉分析中…';
    });
    final ImageToSearch service = ImageToSearch(ref.read(databaseProvider));
    final ({VisionResult vision, SearchQuery? query}) planned = await service
        .planFromImage(bytes);
    if (!mounted) return;
    if (planned.query == null) {
      setState(() {
        _searching = false;
        _vision = planned.vision.error.isNotEmpty
            ? planned.vision.error
            : '视觉分析未得到英文关键词：可手动输入关键词继续';
        _status = _vision;
      });
      return;
    }
    setState(() {
      _searching = false;
      _vision = planned.vision.keywords;
      _search.text = planned.vision.keywords;
    });
    await _runSearch();
  }

  void _runTheme(ThemePack pack) {
    final QueryPlanner planner = QueryPlanner(ref.read(databaseProvider));
    final SearchQuery query = planner.fromThemePack(pack);
    _search.text = pack.name;
    setState(() {
      _query = query;
      _searching = true;
      _status = '主题：${pack.name}';
      _view = 0;
    });
    _executeQuery(query);
  }

  Future<void> _executeQuery(SearchQuery query) async {
    try {
      final AppDatabase db = ref.read(databaseProvider);
      final SearchKeys keys = await SearchKeys.load(db);
      final SearchEngine engine = SearchEngine(sources: keys.sources());
      final AggregatedResult result = await engine.search(
        query,
        perPage: 24,
        allDomains: true,
      );
      if (!mounted) return;
      setState(() {
        _query = query;
        _hits = result.hits;
        _page = result.page;
        _hasMore = result.hasMore;
        _searching = false;
        _status = _describe(result, result.hits.length);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _status = '检索失败：$e';
      });
    }
  }

  void _showAllThemes() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('全部主题（${kThemePacks.length}）'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final ThemePack pack in kThemePacks)
                  SsChip(
                    label: pack.name,
                    selected: false,
                    onTap: () {
                      Navigator.pop(ctx);
                      _runTheme(pack);
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RefsState state = ref.watch(refsControllerProvider);
    return _wrapPage(
      SsPage(
        title: '画面参考',
        subtitle: '中英文搜影视/画作/摄影参考 · 主题画报 · 我的画板',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _viewSwitch(state),
            const SizedBox(height: AppSpace.s3),
            Expanded(child: _view == 1 ? _boardPane(state) : _searchPane()),
            const SizedBox(height: AppSpace.s2),
            Text(
              kRefsDisclaimer,
              style: AppType.caption.style(context.palette.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewSwitch(RefsState state) {
    return Row(
      children: <Widget>[
        SsChip(
          label: '搜索结果${_hits.isEmpty ? '' : '（${_hits.length}）'}',
          selected: _view == 0,
          onTap: () => setState(() => _view = 0),
        ),
        const SizedBox(width: AppSpace.s1),
        SsChip(
          label: '我的画板（${state.board.length}）',
          selected: _view == 1,
          onTap: () => setState(() => _view = 1),
        ),
      ],
    );
  }

  /// 首屏 + 结果区（D154）。
  Widget _searchPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        RefsHomeHeader(
          controller: _search,
          focusNode: _searchFocus,
          searching: _searching,
          status: _status,
          vision: _vision,
          compact: _hits.isNotEmpty,
          onSearch: _runSearch,
          onPickTheme: _runTheme,
          onAllThemes: _showAllThemes,
          onSearchByImage: _searchByImage,
          onPaste: _pasteImage,
          onImport: _importLocal,
        ),
        const SizedBox(height: AppSpace.s4),
        Expanded(child: _results()),
      ],
    );
  }

  Widget _results() {
    if (_searching && _hits.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: AppStroke.ringThin),
      );
    }
    if (_hits.isEmpty) {
      return const SsEmpty(
        icon: Icons.travel_explore_rounded,
        title: '选一张画报，或直接搜关键词',
        hint: '支持影片/导演/演员/画作/摄影主题；也可以用「以图搜图」把一张图变成检索词',
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: RefsMasonryGrid(
            itemCount: _hits.length,
            itemBuilder: (BuildContext context, int i) => RefsHitCard(
              hit: _hits[i],
              onOpen: () => _openHit(_hits[i]),
              onAdd: () => _addToBoard(_hits[i]),
              onSearchSimilar: () => _searchSimilar(_hits[i]),
            ),
          ),
        ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s2),
            child: SsButton(
              label: '加载更多',
              kind: SsButtonKind.text,
              dense: true,
              onPressed: () => _runSearch(loadMore: true),
            ),
          ),
      ],
    );
  }

  Widget _boardPane(RefsState state) {
    return RepaintBoundary(
      key: _boardKey,
      child: RefsBoardView(
        board: state.board,
        imagePathOf: _localImagePath,
        exporting: _exporting,
        onOpen: _openBoardFrame,
        onRemove: (RefFrame f) =>
            ref.read(refsControllerProvider.notifier).removeBoardItem(f),
        onReorder: (String a, String b) => _reorderBoard(a, b),
        onExport: _exportBoard,
        onPaste: _pasteImage,
        onImport: _importLocal,
      ),
    );
  }

  /// 桌面拖拽 + Ctrl+V 快捷键（粘贴/导入能力保留；实现见 RefsDropZone）。
  Widget _wrapPage(Widget page) {
    return RefsDropZone(
      onFilePath: _importDroppedFile,
      onDone: () {
        if (!mounted) return;
        setState(() => _view = 1);
        ssToast(context, '已拖入并收入画板');
      },
      onPasteKey: _pasteImage,
      child: page,
    );
  }

  /// 拖入的单个文件 → 读字节 → 入库（来源标「拖拽导入」）。
  Future<void> _importDroppedFile(String filePath) async {
    final Uint8List bytes = await File(filePath).readAsBytes();
    await ref
        .read(refsControllerProvider.notifier)
        .addFetched(
          bytes: bytes,
          title: refsTitleFromPath(filePath),
          sourceUrl: filePath,
          sourceLabel: '拖拽导入',
        );
  }
}
