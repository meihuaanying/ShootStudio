import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../services/content_packs.dart';
import '../../services/image_store.dart';
import '../../services/palette_extractor.dart';
import '../projects/project_controller.dart';

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
  late String _projectId;
  bool _initializing = false;
  bool _disposed = false;

  @override
  RefsState build() {
    _projectId = ref.watch(currentProjectIdProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const RefsState();
  }

  String get _workspaceRoot => ref.read(workspaceProvider).root.path;

  Future<void> init() async {
    if (state.initialized || _initializing || _disposed) return;
    _initializing = true;
    try {
      final films = await ContentPacks.films();
      state = state.copyWith(
        films: films,
        filteredFilms: films,
        initialized: true,
      );
      await _consumeLegacyBoard();
      await _reloadBoard();
    } finally {
      _initializing = false;
    }
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
    final rows = await (_db.select(_db.projectReferences).join([
      innerJoin(
        _db.filmFrames,
        _db.filmFrames.id.equalsExp(_db.projectReferences.frameId),
      ),
    ])..where(_db.projectReferences.projectId.equals(_projectId))).get();
    final films = await _db.select(_db.films).get();
    final filmTitles = <String, String>{
      for (final Film f in films) f.id: f.title,
    };
    final board = rows.map((result) {
      final FilmFrame row = result.readTable(_db.filmFrames);
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
    final List<RefFrame> ordered = await _applyBoardOrder(board);
    state = state.copyWith(board: ordered, status: '画板共 ${ordered.length} 帧');
  }

  /// 画板排序 key（存 setting，不改表结构；R75 数据管线不擅动）。
  static const String boardOrderKey = 'refs_board_order';
  String get _boardOrderKey => '$boardOrderKey:$_projectId';

  /// 读取持久化排序：命中的按记录顺序在前，其余保持当前相对顺序。
  Future<List<RefFrame>> _applyBoardOrder(List<RefFrame> board) async {
    final String? raw = await _db.getSetting(_boardOrderKey);
    if (raw == null || raw.isEmpty) return board;
    List<String> ids;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return board;
      ids = decoded.whereType<String>().toList();
    } catch (_) {
      return board;
    }
    if (ids.isEmpty) return board;
    final Map<String, RefFrame> byId = <String, RefFrame>{
      for (final RefFrame f in board) f.id: f,
    };
    final List<RefFrame> ordered = <RefFrame>[];
    for (final String id in ids) {
      final RefFrame? f = byId.remove(id);
      if (f != null) ordered.add(f);
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  /// 持久化画板拖拽排序（保存 id 顺序并回读刷新）。
  Future<void> setBoardOrder(List<String> ids) async {
    await _db.setSetting(_boardOrderKey, jsonEncode(ids));
    await _reloadBoard();
  }

  List<String> _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {
      // 剧集列表字段非法时退化为空列表，搜索仍可用。
    }
    return const <String>[];
  }

  Future<void> _consumeLegacyBoard() async {
    final List<FilmFrame> legacy = await (_db.select(
      _db.filmFrames,
    )..where((t) => t.inBoard.equals(true))).get();
    if (legacy.isEmpty) return;
    await _db.transaction(() async {
      for (final FilmFrame frame in legacy) {
        await _attachFrame(frame.id);
      }
      await (_db.update(_db.filmFrames)..where((t) => t.inBoard.equals(true)))
          .write(const FilmFramesCompanion(inBoard: Value(false)));
    });
  }

  Future<void> _attachFrame(String frameId) async {
    await _db
        .into(_db.projectReferences)
        .insert(
          ProjectReferencesCompanion.insert(
            projectId: _projectId,
            frameId: frameId,
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _saveFrame(FilmFramesCompanion frame) async {
    await _db.into(_db.filmFrames).insertOnConflictUpdate(frame);
    await _attachFrame(frame.id.value);
  }

  /// 收入/移出画板（写库）。
  Future<void> toggleBoard(FilmEntry film, FrameEntry frame) async {
    final id = '${film.id}:${frame.name}';
    final ProjectReference? membership =
        await (_db.select(_db.projectReferences)..where(
              (t) => t.projectId.equals(_projectId) & t.frameId.equals(id),
            ))
            .getSingleOrNull();
    final nowIn = membership == null;
    await _db
        .into(_db.films)
        .insertOnConflictUpdate(
          FilmsCompanion.insert(
            id: film.id,
            title: film.title,
            director: Value(film.director),
            year: Value(film.year),
            sourceUrl: Value(film.sourceUrl),
          ),
        );
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
            inBoard: const Value(false),
          ),
        );
    if (nowIn) {
      await _attachFrame(id);
    } else {
      await (_db.delete(_db.projectReferences)..where(
            (t) => t.projectId.equals(_projectId) & t.frameId.equals(id),
          ))
          .go();
    }
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
              inBoard: const Value(false),
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
    await _saveFrame(
      FilmFramesCompanion.insert(
        id: '$localFilmId:$fileName',
        filmId: localFilmId,
        name: title,
        imageRef: fileName,
        paletteJson: Value(jsonEncode(palette.colors)),
        sourceUrl: const Value(''),
        inBoard: const Value(false),
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
        if (!imageExts.contains(path.extension(entity.path).toLowerCase())) {
          continue;
        }
        final String title = path.basenameWithoutExtension(entity.path);
        final List<FilmFrame> existing = await (_db.select(
          _db.filmFrames,
        )..where((t) => t.name.equals(title))).get();
        if (existing.isNotEmpty) {
          for (final FilmFrame frame in existing) {
            await _attachFrame(frame.id);
          }
          continue;
        }
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
    await _saveFrame(
      FilmFramesCompanion.insert(
        id: '$localFilmId:$fileName',
        filmId: localFilmId,
        name: sourceLabel.isEmpty ? title : '$title（$sourceLabel）',
        imageRef: fileName,
        paletteJson: Value(jsonEncode(palette.colors)),
        sourceUrl: Value(sourceUrl),
        inBoard: const Value(false),
      ),
    );
    await _reloadBoard();
    state = state.copyWith(status: '已从搜图收入画板：$title');
    return true;
  }

  Future<void> removeBoardItem(RefFrame frame) async {
    await (_db.delete(_db.projectReferences)..where(
          (t) => t.projectId.equals(_projectId) & t.frameId.equals(frame.id),
        ))
        .go();
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
    await _saveFrame(
      FilmFramesCompanion.insert(
        id: id,
        filmId: localFilmId,
        name: title,
        imageRef: imagePath,
        paletteJson: Value(jsonEncode(palette)),
        sourceUrl: Value(sourceUrl),
        inBoard: const Value(false),
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
