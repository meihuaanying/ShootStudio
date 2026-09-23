import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../services/search/image_to_search.dart';
import '../../services/search/query_planner.dart';
import '../../services/search/search_cache.dart';
import '../../services/search/search_engine.dart';
import '../../services/search/search_keys.dart';
import '../../services/search/search_models.dart';
import '../../services/search/theme_packs.dart';
import 'refs_controller.dart';

/// 参考图免责声明（R47/D130：许可与来源必须可见）。
const String kRefsDisclaimer = '参考图版权归原来源（影视/画作/摄影平台），仅供创作参考；逐图标注来源与许可，禁止二次分发。';

/// V7 画面参考（D132 极简）：搜索框 + 主题标签行 + 结果网格 + 详情弹窗 +
/// 我的画板 + 免责声明；保留粘贴截图/本地导入/以图搜图。
/// 多源检索后端（13+7 源、主题匹配、许可门控）保持不变。
class RefsPage extends ConsumerStatefulWidget {
  const RefsPage({super.key});

  @override
  ConsumerState<RefsPage> createState() => _RefsPageState();
}

class _RefsPageState extends ConsumerState<RefsPage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<SearchHit> _hits = <SearchHit>[];
  SearchQuery? _query;
  bool _searching = false;
  bool _hasMore = false;
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

  void _openHit(SearchHit hit) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(hit.title, style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  hit.thumbUrl.isEmpty ? hit.fullUrl : hit.thumbUrl,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    alignment: Alignment.center,
                    color: AppTokens.accentSoft,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(hit.creditLine, style: const TextStyle(fontSize: 11.5)),
              if (hit.attribution.isNotEmpty)
                Text(
                  hit.attribution,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              if (hit.description.isNotEmpty)
                Text(
                  hit.description,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
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
            onPressed: () {
              Navigator.pop(ctx);
              _addToBoard(hit);
            },
            child: const Text('加入参考画面'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _openBoardFrame(RefFrame frame) {
    final String? path = _localImagePath(frame);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(frame.name, style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (path != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(path),
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                )
              else
                _PaletteBar(colors: frame.gradient, height: 60),
              const SizedBox(height: 8),
              Text(
                '来自：${frame.filmTitle}',
                style: const TextStyle(fontSize: 11),
              ),
              if (frame.sourceUrl.isNotEmpty)
                Text(
                  frame.sourceUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              ref.read(refsControllerProvider.notifier).removeBoardItem(frame);
              Navigator.pop(ctx);
            },
            child: const Text('移出画板'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String? _localImagePath(RefFrame frame) {
    if (frame.imagePath.isEmpty) return null;
    final String root = ref.read(workspaceProvider).root.path;
    final File file = File(p.join(root, 'images', 'refs', frame.imagePath));
    return file.existsSync() ? file.path : null;
  }

  Future<void> _pasteImage() async {
    try {
      final Uint8List? bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) ssToast(context, '剪贴板没有图片（可先 Win+Shift+S 截图再按 Ctrl+V）');
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
    final String? path = picked?.files.single.path;
    if (path == null || !mounted) return;
    final Uint8List bytes = await File(path).readAsBytes();
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
        title: const Text('全部主题（48）', style: TextStyle(fontSize: 15)),
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

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    final RefsState state = ref.watch(refsControllerProvider);
    return _wrapPage(
      SsPage(
        title: '画面参考',
        subtitle: '中英文搜影视/画作/摄影参考 · 主题标签 · 我的画板',
        actions: <Widget>[
          IconButton(
            tooltip: '以图搜图',
            onPressed: _searching ? null : _searchByImage,
            icon: const Icon(Icons.image_search_rounded, size: 20),
          ),
          IconButton(
            tooltip: '粘贴截图（Ctrl+V）',
            onPressed: _pasteImage,
            icon: const Icon(Icons.content_paste_rounded, size: 20),
          ),
          IconButton(
            tooltip: '本地导入',
            onPressed: _importLocal,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    decoration: const InputDecoration(
                      hintText: '搜影片/导演/演员/画作/摄影主题（中英文均可）',
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SsButton(
                  label: _searching ? '检索中…' : '搜索',
                  dense: true,
                  onPressed: _searching ? null : () => _runSearch(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final ThemePack pack in commonThemePacks())
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SsChip(
                        label: pack.name,
                        selected: false,
                        onTap: () => _runTheme(pack),
                      ),
                    ),
                  SsChip(label: '更多主题', selected: false, onTap: _showAllThemes),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                SsChip(
                  label: '搜索结果${_hits.isEmpty ? '' : '（${_hits.length}）'}',
                  selected: _view == 0,
                  onTap: () => setState(() => _view = 0),
                ),
                const SizedBox(width: 6),
                SsChip(
                  label: '我的画板（${state.board.length}）',
                  selected: _view == 1,
                  onTap: () => setState(() => _view = 1),
                ),
                const Spacer(),
                if (_status.isNotEmpty)
                  Flexible(
                    child: Text(
                      _status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            if (_vision.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'AI 视觉关键词：$_vision',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTokens.accent,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _view == 1 ? _buildBoard(state) : _buildResults()),
            const SizedBox(height: 6),
            Text(
              kRefsDisclaimer,
              style: TextStyle(
                fontSize: 10.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching && _hits.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_hits.isEmpty) {
      return const SsEmpty(
        icon: Icons.travel_explore_rounded,
        title: '输入关键词开始搜索',
        hint: '支持影片/导演/演员/画作/摄影主题；也可以点上面的主题标签，或用「以图搜图」',
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemCount: _hits.length,
            itemBuilder: (BuildContext context, int i) =>
                _HitTile(hit: _hits[i], onTap: () => _openHit(_hits[i])),
          ),
        ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SsButton(
              label: '加载更多',
              dense: true,
              kind: SsButtonKind.ghost,
              onPressed: () => _runSearch(loadMore: true),
            ),
          ),
      ],
    );
  }

  Widget _buildBoard(RefsState state) {
    if (state.board.isEmpty) {
      return const SsEmpty(
        icon: Icons.collections_bookmark_outlined,
        title: '画板还是空的',
        hint: '搜索结果详情点「加入参考画面」；或粘贴截图 / 本地导入',
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: state.board.length,
      itemBuilder: (BuildContext context, int i) {
        final RefFrame frame = state.board[i];
        return _BoardTile(
          frame: frame,
          imagePath: _localImagePath(frame),
          onTap: () => _openBoardFrame(frame),
        );
      },
    );
  }

  /// 桌面拖拽 + Ctrl+V 快捷键（粘贴/导入能力保留）。
  Widget _wrapPage(Widget page) {
    Widget wrapped = page;
    if (_isDesktop) {
      wrapped = DropTarget(
        onDragDone: (DropDoneDetails details) async {
          var count = 0;
          for (final DropItem file in details.files) {
            final String path = file.path;
            final String ext = path.contains('.')
                ? path.substring(path.lastIndexOf('.')).toLowerCase()
                : '';
            if (!RefsController.imageExts.contains(ext)) continue;
            try {
              final Uint8List bytes = await File(path).readAsBytes();
              await ref
                  .read(refsControllerProvider.notifier)
                  .addFetched(
                    bytes: bytes,
                    title: path
                        .split(Platform.pathSeparator)
                        .last
                        .split('.')
                        .first,
                    sourceUrl: path,
                    sourceLabel: '拖拽导入',
                  );
              count++;
            } catch (_) {
              // 单个文件失败不影响其余。
            }
          }
          if (mounted && count > 0) {
            setState(() => _view = 1);
            ssToast(context, '已拖入并收入画板：$count 张');
          }
        },
        child: wrapped,
      );
    }
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _pasteImage,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _pasteImage,
      },
      child: Focus(autofocus: true, child: wrapped),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                hit.thumbUrl.isEmpty ? hit.fullUrl : hit.thumbUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => Container(
                  color: AppTokens.accentSoft,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hit.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Text(
            hit.creditLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({
    required this.frame,
    required this.imagePath,
    required this.onTap,
  });

  final RefFrame frame;
  final String? imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imagePath == null
                  ? _PaletteBar(colors: frame.gradient, height: double.infinity)
                  : Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            frame.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          _PaletteBar(colors: frame.palette, height: 8),
        ],
      ),
    );
  }
}

class _PaletteBar extends StatelessWidget {
  const _PaletteBar({required this.colors, required this.height});

  final List<String> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          for (final String hex in colors)
            Expanded(child: Container(color: _color(hex))),
        ],
      ),
    );
  }

  static Color _color(String hex) {
    final int v =
        int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x888888;
    return Color(0xFF000000 | v);
  }
}
