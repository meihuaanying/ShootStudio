import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import '../../core/db/database.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../services/content_packs.dart';
import '../../services/search/search_models.dart';
import 'refs_controller.dart';
import 'search_page.dart';

/// M1 画面参考库：影片静帧索引 + 我的参考画板 + 内置浏览器（FILMGRAB 转化）。
class RefsPage extends ConsumerStatefulWidget {
  const RefsPage({super.key});

  @override
  ConsumerState<RefsPage> createState() => _RefsPageState();
}

class _RefsPageState extends ConsumerState<RefsPage> {
  StreamSubscription<FileSystemEvent>? _watchSub;

  Future<void> _startFolderWatch() async {
    final AppDatabase db = ref.read(databaseProvider);
    final String dir = await db.getSetting('user_pack_dir') ?? '';
    if (dir.isEmpty) return;
    try {
      _watchSub = Directory(dir).watch(events: FileSystemEvent.create).listen((
        FileSystemEvent event,
      ) {
        final String path = event.path;
        final String ext = path.contains('.')
            ? path.substring(path.lastIndexOf('.')).toLowerCase()
            : '';
        if (!RefsController.imageExts.contains(ext)) return;
        final File file = File(path);
        file.length().then((int size) async {
          if (size > 15 * 1024 * 1024) return;
          final Uint8List bytes = await file.readAsBytes();
          await ref
              .read(refsControllerProvider.notifier)
              .addFetched(
                bytes: bytes,
                title: path.split(Platform.pathSeparator).last.split('.').first,
                sourceUrl: path,
                sourceLabel: '我的素材包',
              );
        });
      });
    } catch (_) {
      // 目录监控不可用时静默（可用手动同步）。
    }
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
      await _startFolderWatch();
      final int synced = await ref
          .read(refsControllerProvider.notifier)
          .syncUserPack();
      if (synced > 0 && mounted) ssToast(context, '我的素材包已同步 $synced 张');

      unawaited(ref.read(refsControllerProvider.notifier).init());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(refsControllerProvider);
    final controller = ref.read(refsControllerProvider.notifier);
    final boardCount = state.board.length;
    return _wrapPage(
      SsPage(
        title: '画面参考库',
        subtitle: '影片静帧索引 · 多源搜图工作台 · 五色色卡 · 参考画板 · FILMGRAB 浏览器',
        actions: <Widget>[
          SsButton(
            label: 'TMDB 剧照/动漫',
            icon: Icons.movie_filter_rounded,
            dense: true,
            onPressed: () => _openTmdb(context),
          ),
          const SizedBox(width: 6),
          SsButton(
            label: '我的素材包',
            icon: Icons.folder_special_rounded,
            kind: SsButtonKind.ghost,
            dense: true,
            onPressed: () async {
              final int count = await ref
                  .read(refsControllerProvider.notifier)
                  .syncUserPack();
              if (context.mounted) {
                ssToast(
                  context,
                  count > 0 ? '已同步 $count 张（目录可在设置页修改）' : '没有新素材（先在设置页指定素材包目录）',
                );
              }
            },
          ),
          const SizedBox(width: 6),
          SsButton(
            label: '智能搜图',
            icon: Icons.travel_explore_rounded,
            dense: true,
            onPressed: () => _openSmartSearch(context),
          ),
          const SizedBox(width: 6),
          SsButton(
            label: '粘贴截图',
            icon: Icons.content_paste_rounded,
            kind: SsButtonKind.ghost,
            dense: true,
            onPressed: _pasteImage,
          ),
          const SizedBox(width: 6),
          SsButton(
            label: '本地导入',
            icon: Icons.upload_file_rounded,
            kind: SsButtonKind.ghost,
            dense: true,
            onPressed: () async {
              final count = await controller.importLocalImages();
              if (count > 0 && context.mounted) {
                ssToast(context, '已导入 $count 张');
              }
            },
          ),
          const SizedBox(width: 6),
          SsButton(
            label: '打开 FILMGRAB 浏览',
            icon: Icons.public_rounded,
            dense: true,
            onPressed: () => _openBrowserPanel(context),
          ),
        ],
        body: !state.initialized
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
            : Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SsChip(
                        label: 'PD 静帧库（真实）',
                        selected: state.view == RefsView.films,
                        onTap: () => controller.setView(RefsView.films),
                      ),
                      const SizedBox(width: 6),
                      SsChip(
                        label: '我的参考画板（$boardCount）',
                        selected: state.view == RefsView.board,
                        onTap: () => controller.setView(RefsView.board),
                      ),
                      const Spacer(),
                      if (state.view == RefsView.films) ...<Widget>[
                        SizedBox(
                          width: 280,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: '搜索公有领域影片（PD 静帧库）',
                              isDense: true,
                            ),
                            onChanged: controller.setKeyword,
                          ),
                        ),
                      ] else
                        SsButton(
                          label: '清空待插入',
                          kind: SsButtonKind.ghost,
                          dense: true,
                          onPressed: () =>
                              ref.read(pendingFramesProvider.notifier).clear(),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.s8),
                  if (state.status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          state.status,
                          style: AppTokens.mono(
                            context,
                            size: 11.5,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: state.view == RefsView.films
                        ? _PdStillsView(keyword: state.keyword)
                        : _buildBoard(state),
                  ),
                ],
              ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFilms(RefsState state) {
    final controller = ref.read(refsControllerProvider.notifier);
    final film = state.selectedFilm;
    if (film != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SsButton(
                label: '← 返回影片列表',
                kind: SsButtonKind.ghost,
                dense: true,
                onPressed: () => controller.selectFilm(null),
              ),
              const SizedBox(width: 10),
              Text(
                '${film.title}（${film.year ?? '—'}）· ${film.director}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(film.sourceUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  '在 FILMGRAB 查看原片页 ↗',
                  style: TextStyle(fontSize: 11.5, color: AppTokens.accent),
                ),
              ),
              const Spacer(),
              Text(
                '点静帧看色卡与出处 · 可收入画板',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
              ),
              itemCount: film.frames.length,
              itemBuilder: (BuildContext context, int i) => _FrameCard(
                name: film.frames[i].name,
                gradient: film.frames[i].gradient,
                palette: film.frames[i].palette,
                badge: '索引',
                onTap: () => _showFrameDetail(film, film.frames[i]),
              ),
            ),
          ),
        ],
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: state.filteredFilms.length,
      itemBuilder: (BuildContext context, int i) {
        final FilmEntry f = state.filteredFilms[i];
        return SsCard(
          padding: EdgeInsets.zero,
          onTap: () => controller.selectFilm(f),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        _color(
                          f.frames.first.gradient.isNotEmpty
                              ? f.frames.first.gradient[0]
                              : '#444444',
                        ),
                        _color(
                          f.frames.first.gradient.length > 1
                              ? f.frames.first.gradient[1]
                              : '#222222',
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      f.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${f.director} · ${f.year ?? '—'} · ${f.frames.length} 帧',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: <Widget>[
                        for (final String tag in f.tags.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.accentSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTokens.accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoard(RefsState state) {
    if (state.board.isEmpty) {
      return const SsEmpty(
        icon: Icons.collections_bookmark_outlined,
        title: '画板还是空的',
        hint: '在影片静帧库里点开静帧 →「收入画板」；或本地导入自有参考图',
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: state.board.length,
      itemBuilder: (BuildContext context, int i) {
        final RefFrame frame = state.board[i];
        final localPath = _localImagePath(frame);
        return _FrameCard(
          name: frame.name,
          gradient: frame.gradient,
          palette: frame.palette,
          badge: frame.filmTitle.isEmpty ? '' : frame.filmTitle,
          imagePath: localPath,
          onTap: () => _showBoardDetail(frame),
        );
      },
    );
  }

  String? _localImagePath(RefFrame frame) {
    if (frame.imagePath.isEmpty) return null;
    final workspace = ref.read(workspaceProvider);
    final file = File(
      p.join(workspace.root.path, 'images', 'refs', frame.imagePath),
    );
    return file.existsSync() ? file.path : null;
  }

  Color _color(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x666666;
    return Color(0xFF000000 | v);
  }

  void _showFrameDetail(FilmEntry film, FrameEntry frame) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => _FrameDetailDialog(
        title: frame.name,
        palette: frame.palette,
        gradient: frame.gradient,
        description: frame.description,
        sourceUrl: frame.sourceUrl,
        filmTitle: '${film.title}（${film.director} · ${film.year ?? '—'}）',
        onBoard: () =>
            ref.read(refsControllerProvider.notifier).toggleBoard(film, frame),
      ),
    );
  }

  void _showBoardDetail(RefFrame frame) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => _FrameDetailDialog(
        title: frame.name,
        palette: frame.palette,
        gradient: frame.gradient,
        description: '来自：${frame.filmTitle}',
        sourceUrl: frame.sourceUrl,
        filmTitle: frame.filmTitle,
        imagePath: frame.imagePath,
        onBoard: () {
          ref.read(refsControllerProvider.notifier).removeBoardItem(frame);
          Navigator.pop(ctx);
        },
        boardAction: '移出画板',
      ),
    );
  }

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// V3：桌面端支持系统拖拽图片入画板；所有平台支持 Ctrl+V 粘贴截图。
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
          if (mounted && count > 0) ssToast(context, '已拖入并收入画板：$count 张');
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
      if (mounted) ssToast(context, '已从剪贴板收入画板');
    } catch (e) {
      if (mounted) ssToast(context, '粘贴失败：$e');
    }
  }

  /// V6：影视静帧 / 动漫 / 人名 → 搜图工作台（影视分类）。
  void _openTmdb(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            const SearchPage(initialDomain: ImageDomain.film),
      ),
    );
  }

  void _openSmartSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext _) => const SearchPage()),
    );
  }

  void _openBrowserPanel(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => const _FilmGrabPanel(),
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.name,
    required this.gradient,
    required this.palette,
    required this.onTap,
    this.badge = '',
    this.imagePath,
  });

  final String name;
  final List<String> gradient;
  final List<String> palette;
  final VoidCallback onTap;
  final String badge;
  final String? imagePath;

  Color _color(String hex) => Color(
    0xFF000000 |
        (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x666666),
  );

  @override
  Widget build(BuildContext context) {
    return SsCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: imagePath != null && File(imagePath!).existsSync()
                ? Image.file(File(imagePath!), fit: BoxFit.cover)
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          _color(gradient.isNotEmpty ? gradient[0] : '#555555'),
                          _color(gradient.length > 1 ? gradient[1] : '#252525'),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    for (final String hex in palette.take(5))
                      Expanded(
                        child: Container(
                          height: 8,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: _color(hex),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                if (badge.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

/// 静帧详情：色卡 + 出处 + 收入画板 / 插入策划案。
class _FrameDetailDialog extends ConsumerWidget {
  const _FrameDetailDialog({
    required this.title,
    required this.palette,
    required this.gradient,
    required this.description,
    required this.sourceUrl,
    required this.filmTitle,
    required this.onBoard,
    this.boardAction = '收入画板',
    this.imagePath = '',
  });

  final String title;
  final List<String> palette;
  final List<String> gradient;
  final String description;
  final String sourceUrl;
  final String filmTitle;
  final VoidCallback onBoard;
  final String boardAction;
  final String imagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(
                      0xFF000000 |
                          (int.tryParse(
                                (gradient.isNotEmpty ? gradient[0] : '#555555')
                                    .replaceFirst('#', ''),
                                radix: 16,
                              ) ??
                              0x555555),
                    ),
                    Color(
                      0xFF000000 |
                          (int.tryParse(
                                (gradient.length > 1 ? gradient[1] : '#222222')
                                    .replaceFirst('#', ''),
                                radix: 16,
                              ) ??
                              0x222222),
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTokens.rMd),
              ),
            ),
            const SizedBox(height: AppTokens.s12),
            Text(description, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 8),
            Text('出处：$filmTitle', style: const TextStyle(fontSize: 12)),
            if (sourceUrl.isNotEmpty)
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(sourceUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  sourceUrl,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTokens.accent,
                  ),
                ),
              ),
            const SizedBox(height: AppTokens.s12),
            const Text(
              '五色色卡（点击复制色值）',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (final String hex in palette)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // 复制色值到剪贴板。
                        ssToast(context, '色值 $hex（请在导出/策划案中直接引用）');
                      },
                      child: Column(
                        children: <Widget>[
                          Container(
                            height: 34,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Color(
                                0xFF000000 |
                                    (int.tryParse(
                                          hex.replaceFirst('#', ''),
                                          radix: 16,
                                        ) ??
                                        0x888888),
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                          Text(hex, style: AppTokens.mono(context, size: 9.5)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        SsButton(
          label: boardAction,
          kind: SsButtonKind.ghost,
          onPressed: () {
            onBoard();
            ssToast(context, '$boardAction 完成');
          },
        ),
        SsButton(
          label: '插入策划案样片',
          onPressed: () {
            ref
                .read(pendingFramesProvider.notifier)
                .add(
                  PendingFrame(
                    name: title,
                    palette: palette,
                    gradient: gradient,
                    sourceUrl: sourceUrl,
                    imagePath: imagePath,
                  ),
                );
            ssToast(context, '已加入待插入样片（策划案 → 参考样片模块可插入）');
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

/// 内置 FILMGRAB 浏览面板：原站加载 + 一键截取收入画板。
class _FilmGrabPanel extends ConsumerStatefulWidget {
  const _FilmGrabPanel();

  @override
  ConsumerState<_FilmGrabPanel> createState() => _FilmGrabPanelState();
}

class _FilmGrabPanelState extends ConsumerState<_FilmGrabPanel> {
  InAppWebViewController? _controller;
  String _status = '正在加载 film-grab.com …';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 980,
        height: 680,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: <Widget>[
                  const Text(
                    '内置浏览面板 · film-grab.com',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SsButton(
                    label: '截取当前画面',
                    icon: Icons.screenshot_monitor_rounded,
                    dense: true,
                    onPressed: () async {
                      final controller = _controller;
                      if (controller == null) return;
                      try {
                        final bytes = await controller.takeScreenshot();
                        if (bytes != null) {
                          await ref
                              .read(refsControllerProvider.notifier)
                              .importScreenshotBytes(Uint8List.fromList(bytes));
                          if (mounted) {
                            setState(() => _status = '已截取并收入画板');
                          }
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(() => _status = '当前平台不支持一键截取，请改用「本地导入」上传截图');
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  SsButton(
                    label: '在系统浏览器打开',
                    kind: SsButtonKind.ghost,
                    dense: true,
                    onPressed: () => launchUrl(
                      Uri.parse('https://film-grab.com'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://film-grab.com'),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  transparentBackground: false,
                ),
                onWebViewCreated: (InAppWebViewController controller) {
                  _controller = controller;
                },
                onLoadStop: (InAppWebViewController controller, WebUri? url) {
                  if (mounted) {
                    setState(() => _status = '已加载：${url?.toString() ?? ''}');
                  }
                },
                onReceivedError:
                    (
                      InAppWebViewController controller,
                      WebResourceRequest request,
                      WebResourceError error,
                    ) {
                      if ((request.isForMainFrame ?? false) && mounted) {
                        setState(
                          () => _status = '加载失败（网络受限）：${error.description}',
                        );
                      }
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PD 影片中文别名 / 主创 / 题材（D78：支持中文检索；键为英文原片名）。
const Map<String, List<String>> kPdFilmAliases = <String, List<String>>{
  'Nosferatu': <String>['诺斯费拉图', '吸血鬼', '恐怖', '默片', '茂瑙', 'Murnau'],
  'The Kid': <String>['寻子遇仙记', '弃儿的故事', '小孩', '卓别林', 'Chaplin', '喜剧'],
  'Sherlock Jr.': <String>['福尔摩斯二世', '小福尔摩斯', '基顿', 'Keaton', '喜剧'],
  'Battleship Potemkin': <String>[
    '战舰波将金号',
    '波将金号',
    '爱森斯坦',
    'Eisenstein',
    '蒙太奇',
  ],
  'The General': <String>['将军号', '基顿', 'Keaton', '喜剧', '火车'],
  'Metropolis': <String>['大都会', '科幻', '弗里茨朗', 'Fritz Lang', '未来都市'],
  'The Cabinet of Dr. Caligari': <String>['卡里加里博士的小屋', '卡里加里', '恐怖', '表现主义'],
  'A Trip to the Moon': <String>['月球旅行记', '月球漫游', '梅里爱', 'Méliès', '科幻'],
  'His Girl Friday': <String>['女友礼拜五', '小报妙冤家', '喜剧', '新闻'],
  'Night of the Living Dead': <String>['活死人之夜', '丧尸', '罗梅罗', 'Romero', '恐怖'],
};

/// PD 影片搜索（D78）：多字段 + 中文别名 + 空格分词 token 匹配。
bool pdFilmMatches(Map<String, Object?> film, List<String> tokens) {
  if (tokens.isEmpty) return true;
  final String title = '${film['title'] ?? ''}'.toLowerCase();
  final String year = '${film['year'] ?? ''}';
  final List<String> aliases = kPdFilmAliases['${film['title']}'] ?? <String>[];
  final String haystack = <String>[
    title,
    year,
    ...aliases,
    for (final Object? f in film['frames'] as List<Object?>? ?? <Object?>[])
      if (f is Map) '${f['title'] ?? ''} ${f['author'] ?? ''}',
  ].join(' ').toLowerCase();
  return tokens.every((String t) => haystack.contains(t));
}

/// V3：PD 公有领域电影静帧库（真实图片，可收入画板）。
class _PdStillsView extends ConsumerStatefulWidget {
  const _PdStillsView({required this.keyword});
  final String keyword;

  @override
  ConsumerState<_PdStillsView> createState() => _PdStillsViewState();
}

class _PdStillsViewState extends ConsumerState<_PdStillsView> {
  List<Map<String, Object?>> _films = <Map<String, Object?>>[];
  bool _loaded = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    ContentPacks.pdStills()
        .then((Map<String, Object?> data) {
          if (!mounted) return;
          setState(() {
            _films = (data['films'] as List<Object?>? ?? <Object?>[])
                .whereType<Map>()
                .map((Map m) => m.cast<String, Object?>())
                .toList();
            _loaded = true;
          });
        })
        .catchError((Object e) {
          if (!mounted) return;
          setState(() {
            _loaded = true;
            _error = 'PD 静帧库加载失败：$e';
          });
        });
  }

  Future<void> _import(Map<String, Object?> frame, String film) async {
    final String file = '${frame['file']}';
    final Uint8List bytes = (await rootBundle.load(
      'assets/content/stills/pd/$file',
    )).buffer.asUint8List();
    await ref
        .read(refsControllerProvider.notifier)
        .addFetched(
          bytes: bytes,
          title: '${frame['title'] ?? file}',
          sourceUrl: '${frame['source'] ?? ''}',
          sourceLabel: 'PD 静帧 · $film',
        );
    if (mounted) ssToast(context, '已收入画板：${frame['title'] ?? file}');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.2));
    }
    if (_error.isNotEmpty) {
      return SsEmpty(
        icon: Icons.error_outline_rounded,
        title: '静帧库不可用',
        hint: _error,
      );
    }
    final List<String> tokens = widget.keyword
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String t) => t.isNotEmpty)
        .toList();
    final List<Map<String, Object?>> films = _films
        .where((Map<String, Object?> f) => pdFilmMatches(f, tokens))
        .toList();
    if (films.isEmpty) {
      return SsEmpty(
        icon: Icons.movie_outlined,
        title: '没有匹配的影片',
        hint:
            '支持片名/年份/导演/题材与中文别名（如「大都会」「卓别林」「恐怖」）；'
            '更多剧照请用「TMDB 剧照/动漫」或「我的素材包」',
      );
    }
    final int frameTotal = films.fold<int>(
      0,
      (int sum, Map<String, Object?> f) =>
          sum + ((f['frames'] as List?)?.length ?? 0),
    );
    return ListView(
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTokens.rSm),
          ),
          child: Text(
            '公有领域影片真实静帧（PD，可随应用分发）：$frameTotal 帧 · '
            '可搜片名/年份/导演/题材/中文别名；点任意帧查看大图并收入画板。'
            '有版权电影请用 TMDB / 我的素材包（用户自备）。',
            style: const TextStyle(fontSize: 11.5),
          ),
        ),
        for (final Map<String, Object?> film in films) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: SsSectionTitle(
              '${film['title']}',
              subtitle:
                  '${film['year']} · ${(film['frames'] as List?)?.length ?? 0} 帧'
                  '${(kPdFilmAliases['${film['title']}'] ?? <String>[]).isEmpty ? '' : ' · ${(kPdFilmAliases['${film['title']}'] ?? <String>[]).take(3).join('/')}'}',
            ),
          ),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: (film['frames'] as List? ?? <Object?>[]).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int i) {
                final Map<String, Object?> frame =
                    ((film['frames'] as List)[i] as Map)
                        .cast<String, Object?>();
                return InkWell(
                  onTap: () => _import(frame, '${film['title']}'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.rSm),
                    child: Image.asset(
                      'assets/content/stills/pd/${frame['file']}',
                      width: 210,
                      height: 132,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (BuildContext c, Object e, StackTrace? st) =>
                              Container(
                                width: 210,
                                color: AppTokens.accentSoft,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
