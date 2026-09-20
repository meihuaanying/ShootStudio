import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../services/content_packs.dart';
import '../../services/image_store.dart';
import '../../services/palette_extractor.dart';

/// 参考画板视图。
enum RefsView { films, board }

/// 单个静帧条目的展示模型（内置索引帧或用户导入帧）。
class RefFrame {
  const RefFrame({
    required this.id,
    required this.name,
    required this.palette,
    required this.gradient,
    required this.sourceUrl,
    required this.description,
    required this.inBoard,
    required this.filmTitle,
    this.imagePath = '',
  });

  final String id;
  final String name;
  final List<String> palette;
  final List<String> gradient;
  final String sourceUrl;
  final String description;
  final bool inBoard;
  final String filmTitle;
  final String imagePath;
}

class RefsState {
  const RefsState({
    this.films = const <FilmEntry>[],
    this.filteredFilms = const <FilmEntry>[],
    this.selectedFilm,
    this.board = const <RefFrame>[],
    this.keyword = '',
    this.view = RefsView.films,
    this.initialized = false,
    this.status = '',
  });

  final List<FilmEntry> films;
  final List<FilmEntry> filteredFilms;
  final FilmEntry? selectedFilm;
  final List<RefFrame> board;
  final String keyword;
  final RefsView view;
  final bool initialized;
  final String status;

  RefsState copyWith({
    List<FilmEntry>? films,
    List<FilmEntry>? filteredFilms,
    Object? selectedFilm = _sentinel,
    List<RefFrame>? board,
    String? keyword,
    RefsView? view,
    bool? initialized,
    String? status,
  }) {
    return RefsState(
      films: films ?? this.films,
      filteredFilms: filteredFilms ?? this.filteredFilms,
      selectedFilm: selectedFilm == _sentinel
          ? this.selectedFilm
          : selectedFilm as FilmEntry?,
      board: board ?? this.board,
      keyword: keyword ?? this.keyword,
      view: view ?? this.view,
      initialized: initialized ?? this.initialized,
      status: status ?? this.status,
    );
  }

  static const Object _sentinel = Object();
}

final refsControllerProvider = NotifierProvider<RefsController, RefsState>(
  RefsController.new,
);

/// 待插入策划案的参考帧。
class PendingFrame {
  const PendingFrame({
    required this.name,
    required this.palette,
    required this.gradient,
    required this.sourceUrl,
    this.imagePath = '',
  });

  final String name;
  final List<String> palette;
  final List<String> gradient;
  final String sourceUrl;
  final String imagePath;
}

final pendingFramesProvider =
    StateNotifierProvider<PendingFramesNotifier, List<PendingFrame>>(
      (ref) => PendingFramesNotifier(),
    );

class PendingFramesNotifier extends StateNotifier<List<PendingFrame>> {
  PendingFramesNotifier() : super(const <PendingFrame>[]);

  void add(PendingFrame frame) {
    if (state.any((PendingFrame f) => f.name == frame.name)) return;
    state = <PendingFrame>[...state, frame];
  }

  void clear() => state = const <PendingFrame>[];
}

class RefsController extends Notifier<RefsState> {
  static const Uuid _uuid = Uuid();
  late final AppDatabase _db = ref.read(databaseProvider);

  @override
  RefsState build() => const RefsState();

  String get _workspaceRoot => ref.read(workspaceProvider).root.path;

  Future<void> init() async {
    if (state.initialized) return;
    final films = await ContentPacks.films();
    state = state.copyWith(
      films: films,
      filteredFilms: films,
      initialized: true,
    );
    await _reloadBoard();
  }

  void setView(RefsView view) => state = state.copyWith(view: view);

  void selectFilm(FilmEntry? film) =>
      state = state.copyWith(selectedFilm: film);

  void setKeyword(String keyword) {
    final lower = keyword.trim().toLowerCase();
    final filtered = state.films.where((FilmEntry f) {
      if (lower.isEmpty) return true;
      return f.title.toLowerCase().contains(lower) ||
          f.director.toLowerCase().contains(lower) ||
          '${f.year ?? ''}'.contains(lower) ||
          f.tags.any((String t) => t.toLowerCase().contains(lower));
    }).toList();
    state = state.copyWith(keyword: keyword, filteredFilms: filtered);
  }

  Future<void> _reloadBoard() async {
    final rows = await (_db.select(
      _db.filmFrames,
    )..where((t) => t.inBoard.equals(true))).get();
    final films = await _db.select(_db.films).get();
    final filmTitles = <String, String>{
      for (final Film f in films) f.id: f.title,
    };
    final board = rows.map((FilmFrame row) {
      final palette = _decodeList(row.paletteJson);
      return RefFrame(
        id: row.id,
        name: row.name,
        palette: palette,
        gradient: palette.length >= 2
            ? <String>[palette[0], palette[1]]
            : <String>['#888888', '#555555'],
        sourceUrl: row.sourceUrl,
        description: '',
        inBoard: true,
        filmTitle: filmTitles[row.filmId] ?? '',
        imagePath: row.imageRef,
      );
    }).toList();
    // 用户导入的帧排在前面。
    board.sort((RefFrame a, RefFrame b) => a.filmTitle == '我的导入' ? -1 : 1);
    state = state.copyWith(board: board, status: '画板共 ${board.length} 帧');
  }

  List<String> _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return const <String>[];
  }

  /// 收入/移出画板（写库）。
  Future<void> toggleBoard(FilmEntry film, FrameEntry frame) async {
    final id = '${film.id}:${frame.name}';
    final existing = await (_db.select(
      _db.filmFrames,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final nowIn = !(existing?.inBoard ?? false);
    await _db
        .into(_db.filmFrames)
        .insertOnConflictUpdate(
          FilmFramesCompanion.insert(
            id: id,
            filmId: film.id,
            name: frame.name,
            imageRef: '',
            paletteJson: Value(jsonEncode(frame.palette)),
            sourceUrl: Value(frame.sourceUrl),
            inBoard: Value(nowIn),
          ),
        );
    await _reloadBoard();
    state = state.copyWith(status: nowIn ? '已收入画板：${frame.name}' : '已移出画板');
  }

  /// 本地导入图片（用户自有素材；压缩 + 色卡 → 画板）。
  Future<int> importLocalImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      dialogTitle: '选择参考图片（可多选）',
    );
    if (result == null || result.files.isEmpty) return 0;
    final store = ImageStore(_workspaceRoot);
    const String localFilmId = 'film-local-imports';
    await _db
        .into(_db.films)
        .insertOnConflictUpdate(
          FilmsCompanion.insert(
            id: localFilmId,
            title: '我的导入',
            director: const Value('用户素材'),
            year: Value(DateTime.now().year),
          ),
        );
    var count = 0;
    for (final PlatformFile file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final raw = await File(path).readAsBytes();
      final (String fileName, PaletteResult palette) = await store.importBytes(
        raw,
        category: 'refs',
        title: file.name,
      );
      final frameId = '$localFilmId:$fileName';
      await _db
          .into(_db.filmFrames)
          .insertOnConflictUpdate(
            FilmFramesCompanion.insert(
              id: frameId,
              filmId: localFilmId,
              name: file.name,
              imageRef: fileName,
              paletteJson: Value(jsonEncode(palette.colors)),
              sourceUrl: const Value(''),
              inBoard: const Value(true),
            ),
          );
      count++;
    }
    await _reloadBoard();
    state = state.copyWith(status: '已导入 $count 张参考图并收入画板');
    return count;
  }

  /// 从浏览器截取当前画面（Android 支持截图；Windows 走提示降级）。
  Future<void> importScreenshotBytes(
    Uint8List bytes, {
    String title = '浏览面板截取',
  }) async {
    final store = ImageStore(_workspaceRoot);
    const String localFilmId = 'film-local-imports';
    await _db
        .into(_db.films)
        .insertOnConflictUpdate(
          FilmsCompanion.insert(
            id: localFilmId,
            title: '我的导入',
            director: const Value('用户素材'),
            year: Value(DateTime.now().year),
          ),
        );
    final (String fileName, PaletteResult palette) = await store.importBytes(
      bytes,
      category: 'refs',
      title: title,
    );
    await _db
        .into(_db.filmFrames)
        .insertOnConflictUpdate(
          FilmFramesCompanion.insert(
            id: '$localFilmId:$fileName',
            filmId: localFilmId,
            name: title,
            imageRef: fileName,
            paletteJson: Value(jsonEncode(palette.colors)),
            sourceUrl: const Value(''),
            inBoard: const Value(true),
          ),
        );
    await _reloadBoard();
    state = state.copyWith(status: '已截取并收入画板');
  }

  static const Set<String> imageExts = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
    '.gif',
  };

  /// V3：扫描「我的素材包」目录，增量导入参考图（剧照/动漫截图等用户素材）。
  Future<int> syncUserPack() async {
    final String dir = await _db.getSetting('user_pack_dir') ?? '';
    if (dir.isEmpty) return 0;
    final Directory directory = Directory(dir);
    if (!await directory.exists()) return 0;
    var count = 0;
    try {
      await for (final FileSystemEntity entity in directory.list(
        recursive: true,
      )) {
        if (entity is! File) continue;
        if (!imageExts.contains(p.extension(entity.path).toLowerCase())) {
          continue;
        }
        final String title = p.basenameWithoutExtension(entity.path);
        final List<FilmFrame> existing = await (_db.select(
          _db.filmFrames,
        )..where((t) => t.name.equals(title))).get();
        if (existing.isNotEmpty) continue;
        final int size = await entity.length();
        if (size > 15 * 1024 * 1024) continue;
        final Uint8List bytes = await entity.readAsBytes();
        await addFetched(
          bytes: bytes,
          title: title,
          sourceUrl: entity.path,
          sourceLabel: '我的素材包',
        );
        count++;
      }
    } catch (_) {
      // 目录不可读时静默（设置页会提示）。
    }
    if (count > 0) {
      state = state.copyWith(status: '我的素材包：已同步 $count 张');
    }
    return count;
  }

  /// G6：聚合搜图结果下载入画板（记录出处）。
  Future<bool> addFetched({
    required Uint8List bytes,
    required String title,
    String sourceUrl = '',
    String sourceLabel = '',
  }) async {
    final store = ImageStore(_workspaceRoot);
    const String localFilmId = 'film-local-imports';
    await _db
        .into(_db.films)
        .insertOnConflictUpdate(
          FilmsCompanion.insert(
            id: localFilmId,
            title: '我的导入',
            director: const Value('用户素材'),
            year: Value(DateTime.now().year),
          ),
        );
    final (String fileName, PaletteResult palette) = await store.importBytes(
      bytes,
      category: 'refs',
      title: title,
    );
    await _db
        .into(_db.filmFrames)
        .insertOnConflictUpdate(
          FilmFramesCompanion.insert(
            id: '$localFilmId:$fileName',
            filmId: localFilmId,
            name: sourceLabel.isEmpty ? title : '$title（$sourceLabel）',
            imageRef: fileName,
            paletteJson: Value(jsonEncode(palette.colors)),
            sourceUrl: Value(sourceUrl),
            inBoard: const Value(true),
          ),
        );
    await _reloadBoard();
    state = state.copyWith(status: '已从搜图收入画板：$title');
    return true;
  }

  Future<void> removeBoardItem(RefFrame frame) async {
    await (_db.update(_db.filmFrames)..where((t) => t.id.equals(frame.id)))
        .write(const FilmFramesCompanion(inBoard: Value(false)));
    await _reloadBoard();
  }

  /// 生成一个自定义帧（不依赖内置索引）。
  Future<RefFrame> addCustomFrame({
    required String title,
    required String imagePath,
    required List<String> palette,
    String sourceUrl = '',
  }) async {
    final id = 'custom:${_uuid.v4()}';
    const String localFilmId = 'film-local-imports';
    await _db
        .into(_db.films)
        .insertOnConflictUpdate(
          FilmsCompanion.insert(
            id: localFilmId,
            title: '我的导入',
            director: const Value('用户素材'),
            year: Value(DateTime.now().year),
          ),
        );
    await _db
        .into(_db.filmFrames)
        .insertOnConflictUpdate(
          FilmFramesCompanion.insert(
            id: id,
            filmId: localFilmId,
            name: title,
            imageRef: imagePath,
            paletteJson: Value(jsonEncode(palette)),
            sourceUrl: Value(sourceUrl),
            inBoard: const Value(true),
          ),
        );
    await _reloadBoard();
    return RefFrame(
      id: id,
      name: title,
      palette: palette,
      gradient: palette.length >= 2
          ? <String>[palette[0], palette[1]]
          : <String>['#888888', '#555555'],
      sourceUrl: sourceUrl,
      description: '',
      inBoard: true,
      filmTitle: '我的导入',
    );
  }
}
