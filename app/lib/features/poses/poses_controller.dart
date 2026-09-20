import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/utils/json_utils.dart';
import '../../services/content_packs.dart';

/// 姿势库分类（V3.0 排序：常用在前）。
const List<String> poseCategories = <String>[
  '全部',
  '站姿',
  '坐姿',
  '蹲姿',
  '跪姿',
  '靠姿',
  '躺姿',
  '动态',
  '手部',
  '神态',
  '道具互动',
];

const List<String> poseDifficulties = <String>['全部', '新手友好', '进阶', '高难度'];

/// 姿势库状态。
class PosesState {
  const PosesState({
    this.all = const <PoseEntry>[],
    this.filtered = const <PoseEntry>[],
    this.category = '全部',
    this.difficulty = '全部',
    this.keyword = '',
    this.index = 0,
    this.favorites = const <String>{},
    this.jointsOverride,
    this.initialized = false,
    this.status = '',
  });

  final List<PoseEntry> all;
  final List<PoseEntry> filtered;
  final String category;
  final String difficulty;
  final String keyword;
  final int index;

  /// 收藏的姿势 id。
  final Set<String> favorites;

  /// 微调后的关节（覆盖内置姿势的默认值）。
  final Map<String, Object?>? jointsOverride;

  final bool initialized;
  final String status;

  PoseEntry? get current =>
      (index >= 0 && index < filtered.length) ? filtered[index] : null;

  /// 当前生效的关节（含 root 变换与微调覆盖）。
  Map<String, Object?> get effectiveJoints {
    final base = current?.joints ?? <String, Object?>{};
    final merged = <String, Object?>{
      ...base,
      if (current != null) 'rootY': current!.rootY,
      if (current != null) 'rootPitch': current!.rootPitch,
      ...?jointsOverride,
    };
    return merged;
  }

  PosesState copyWith({
    List<PoseEntry>? all,
    List<PoseEntry>? filtered,
    String? category,
    String? difficulty,
    String? keyword,
    int? index,
    Set<String>? favorites,
    Object? jointsOverride = _sentinel,
    bool? initialized,
    String? status,
  }) {
    return PosesState(
      all: all ?? this.all,
      filtered: filtered ?? this.filtered,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      keyword: keyword ?? this.keyword,
      index: index ?? this.index,
      favorites: favorites ?? this.favorites,
      jointsOverride: jointsOverride == _sentinel
          ? this.jointsOverride
          : jointsOverride as Map<String, Object?>?,
      initialized: initialized ?? this.initialized,
      status: status ?? this.status,
    );
  }

  static const Object _sentinel = Object();
}

final posesControllerProvider = NotifierProvider<PosesController, PosesState>(
  PosesController.new,
);

class PosesController extends Notifier<PosesState> {
  late final AppDatabase _db = ref.read(databaseProvider);

  @override
  PosesState build() => const PosesState();

  Future<void> init() async {
    if (state.initialized) return;
    final builtin = await ContentPacks.poses();
    final custom = await _loadCustomPoses();
    final favorites = await _loadFavorites();
    final all = <PoseEntry>[...builtin, ...custom];
    state = state.copyWith(
      all: all,
      favorites: favorites,
      initialized: true,
      status: '共 ${all.length} 个姿势',
    );
    _applyFilter(
      state.category,
      state.difficulty,
      state.keyword,
      resetIndex: true,
    );
  }

  Future<List<PoseEntry>> _loadCustomPoses() async {
    final rows = await (_db.select(
      _db.poses,
    )..where((t) => t.builtin.equals(false))).get();
    return rows.map((Pose row) {
      final joints = deepCopy(asMap(_decode(row.jointsJson)));
      // V5/D88：保留键 `_hands` 存手部姿态（不影响 12 关节解析）。
      final (HandPoseState?, HandPoseState?) hands = handsFromJson(
        joints.remove('_hands'),
      );
      final rootY = joints.remove('rootY');
      final rootPitch = joints.remove('rootPitch');
      return PoseEntry(
        id: row.id,
        name: row.name,
        category: row.category,
        difficulty: row.difficulty,
        joints: joints,
        rootY: asDouble(rootY),
        rootPitch: asDouble(rootPitch),
        weight: row.tip,
        hands: '',
        mistake: '',
        lens: row.lensAdvice,
        handsL: hands.$1,
        handsR: hands.$2,
      );
    }).toList();
  }

  Map<String, Object?> _decode(String raw) {
    try {
      return asMap(jsonDecode(raw));
    } catch (_) {
      return <String, Object?>{};
    }
  }

  Future<Set<String>> _loadFavorites() async {
    final rows = await (_db.select(
      _db.poses,
    )..where((t) => t.favorite.equals(true))).get();
    return rows.map((Pose row) => row.id).toSet();
  }

  void _applyFilter(
    String category,
    String difficulty,
    String keyword, {
    bool resetIndex = false,
  }) {
    final lower = keyword.trim().toLowerCase();
    final filtered = state.all.where((PoseEntry p) {
      if (category != '全部' && p.category != category) return false;
      if (difficulty != '全部' && p.difficulty != difficulty) return false;
      if (lower.isNotEmpty && !p.name.toLowerCase().contains(lower)) {
        return false;
      }
      return true;
    }).toList();
    state = state.copyWith(
      filtered: filtered,
      category: category,
      difficulty: difficulty,
      keyword: keyword,
      index: resetIndex
          ? 0
          : state.index.clamp(0, filtered.isEmpty ? 0 : filtered.length - 1),
      jointsOverride: null,
    );
  }

  void setCategory(String category) =>
      _applyFilter(category, state.difficulty, state.keyword, resetIndex: true);

  void setDifficulty(String difficulty) =>
      _applyFilter(state.category, difficulty, state.keyword, resetIndex: true);

  void setKeyword(String keyword) =>
      _applyFilter(state.category, state.difficulty, keyword, resetIndex: true);

  void select(int index) {
    if (index < 0 || index >= state.filtered.length) return;
    state = state.copyWith(index: index, jointsOverride: null);
  }

  void next() => select(
    (state.index + 1) % (state.filtered.isEmpty ? 1 : state.filtered.length),
  );

  void prev() => select(
    (state.index - 1 + state.filtered.length) %
        (state.filtered.isEmpty ? 1 : state.filtered.length),
  );

  /// 今日姿势：按日期种子推荐。
  void today() {
    if (state.filtered.isEmpty) return;
    final day = DateTime.now();
    final seed = day.year * 10000 + day.month * 100 + day.day;
    select(seed % state.filtered.length);
    state = state.copyWith(status: '今日姿势：${state.current?.name ?? ''}');
  }

  Future<void> toggleFavorite() async {
    final pose = state.current;
    if (pose == null) return;
    final favorites = Set<String>.of(state.favorites);
    final now = !favorites.contains(pose.id);
    if (now) {
      favorites.add(pose.id);
    } else {
      favorites.remove(pose.id);
    }
    final existing = await (_db.select(
      _db.poses,
    )..where((t) => t.id.equals(pose.id))).getSingleOrNull();
    await _db
        .into(_db.poses)
        .insertOnConflictUpdate(
          PosesCompanion.insert(
            id: pose.id,
            name: pose.name,
            category: pose.category,
            difficulty: Value(pose.difficulty),
            jointsJson: jsonEncode(pose.joints),
            tip: Value(pose.weight),
            lensAdvice: Value(pose.lens),
            builtin: Value(existing?.builtin ?? true),
            favorite: Value(now),
          ),
        );
    state = state.copyWith(
      favorites: favorites,
      status: now ? '已收藏「${pose.name}」' : '已取消收藏',
    );
  }

  /// 关节微调（轴：rx/ry/rz）。以当前姿势为基线，三轴互不覆盖（G5 修复）。
  void adjustJoint(String joint, String axis, double value) {
    final joints = Map<String, Object?>.of(
      state.jointsOverride ?? <String, Object?>{},
    );
    final List<double> base = tripleOf(state.current?.joints[joint]);
    final List<double> axes = tripleOf(joints[joint] ?? base);
    final axisIndex = switch (axis) {
      'rx' => 0,
      'ry' => 1,
      _ => 2,
    };
    axes[axisIndex] = value;
    joints[joint] = <double>[axes[0], axes[1], axes[2]];
    state = state.copyWith(jointsOverride: joints, status: '微调中：$joint');
  }

  /// 另存为自定义姿势。
  Future<void> saveCustom(String name) async {
    final pose = state.current;
    if (pose == null || name.trim().isEmpty) return;
    await saveCustomPose(
      name: name,
      joints: state.effectiveJoints,
      category: pose.category,
      difficulty: pose.difficulty,
      weight: pose.weight,
      lens: pose.lens,
      handsL: pose.handsL,
      handsR: pose.handsR,
    );
  }

  /// V5/D88：从布光页另存（含手部姿态）；[joints] 可含 rootY/rootPitch。
  Future<void> saveCustomPose({
    required String name,
    required Map<String, Object?> joints,
    String category = '站姿',
    String difficulty = '进阶',
    String weight = '',
    String lens = '',
    HandPoseState? handsL,
    HandPoseState? handsR,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty || joints.isEmpty) return;
    final String id = 'custom-${DateTime.now().millisecondsSinceEpoch}';
    final Map<String, Object?> stored = Map<String, Object?>.of(joints);
    final Map<String, Object?>? hands = handsToJson(handsL, handsR);
    if (hands != null) stored['_hands'] = hands;
    await _db
        .into(_db.poses)
        .insertOnConflictUpdate(
          PosesCompanion.insert(
            id: id,
            name: trimmed,
            category: category,
            difficulty: Value(difficulty),
            jointsJson: jsonEncode(stored),
            tip: Value(weight),
            lensAdvice: Value(lens),
            builtin: const Value(false),
            favorite: const Value(false),
          ),
        );
    final Map<String, Object?> poseJoints = Map<String, Object?>.of(joints)
      ..remove('rootY')
      ..remove('rootPitch');
    final PoseEntry entry = PoseEntry(
      id: id,
      name: trimmed,
      category: category,
      difficulty: difficulty,
      joints: poseJoints,
      rootY: asDouble(joints['rootY']),
      rootPitch: asDouble(joints['rootPitch']),
      weight: weight,
      hands: '',
      mistake: '',
      lens: lens,
      handsL: handsL,
      handsR: handsR,
    );
    state = state.copyWith(
      all: <PoseEntry>[...state.all, entry],
      filtered: <PoseEntry>[...state.filtered, entry],
      status: '已另存为「$trimmed」',
    );
  }
}
