import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/poses/poses_controller.dart';
import 'package:shoot_studio/services/content_packs.dart';

/// G5（V4 重写）：照片姿势库内容质量 + 控制器行为（筛选/收藏/关节微调回归）。
/// 数据门禁详见 q2_pose_photos_test.dart（D65–D70）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('V4/V7：120 条、10 类目 × 12（杂志大片/影视感替换手部/神态）、照片与骨架齐备、建议字段齐全', () async {
    final List<PoseEntry> poses = await ContentPacks.poses();
    expect(poses.length, 120);
    final Map<String, int> byCategory = <String, int>{};
    for (final PoseEntry pose in poses) {
      byCategory[pose.category] = (byCategory[pose.category] ?? 0) + 1;
      expect(pose.photo, isNotEmpty, reason: '${pose.name} 缺照片');
      expect(pose.skeleton, isNotEmpty, reason: '${pose.name} 缺骨架');
      expect(pose.joints.length, 12, reason: '${pose.name} 缺 12 关节');
      expect(pose.lens, isNotEmpty);
      expect(pose.cameraPosition, isNotEmpty);
      expect(pose.mistake, isNotEmpty);
      expect(pose.hands, isNotEmpty);
    }
    expect(byCategory.keys.toSet(), <String>{
      '站姿',
      '坐姿',
      '蹲姿',
      '跪姿',
      '靠姿',
      '躺姿',
      '动态',
      '杂志大片',
      '影视感',
      '道具互动',
    });
    for (final MapEntry<String, int> entry in byCategory.entries) {
      expect(entry.value, 12, reason: '${entry.key} 应为 12 条');
    }
  });

  test('V4：低置信度姿势必须标注 referenceOnly（R20/D68）', () async {
    final List<PoseEntry> poses = await ContentPacks.poses();
    final List<PoseEntry> reference = poses
        .where((PoseEntry p) => p.referenceOnly)
        .toList();
    expect(reference, isNotEmpty, reason: '应存在低置信度（<0.6）姿势样本');
    for (final PoseEntry pose in poses) {
      expect(pose.referenceOnly, pose.confidence < 0.6, reason: pose.id);
      expect(pose.confidence, inInclusiveRange(0, 1), reason: pose.id);
    }
  });

  test('控制器：初始化 / 类目筛选 / 搜索 / 收藏 / 今日姿势', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ContentPacks.syncToDatabase(db);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final PosesController controller = container.read(
      posesControllerProvider.notifier,
    );
    await controller.init();

    PosesState state = container.read(posesControllerProvider);
    expect(state.initialized, isTrue);
    expect(state.all.length, 120);
    expect(state.filtered.length, 120);
    expect(state.current, isNotNull);

    controller.setCategory('坐姿');
    state = container.read(posesControllerProvider);
    expect(state.filtered.length, 12);
    expect(state.filtered.every((PoseEntry p) => p.category == '坐姿'), isTrue);

    controller.setCategory('全部');
    controller.setKeyword('展臂');
    state = container.read(posesControllerProvider);
    expect(state.filtered, isNotEmpty);
    expect(
      state.filtered.every((PoseEntry p) => p.name.contains('展臂')),
      isTrue,
    );
    controller.setKeyword('');

    controller.next();
    expect(container.read(posesControllerProvider).index, 1);
    controller.prev();
    expect(container.read(posesControllerProvider).index, 0);

    final String id = container.read(posesControllerProvider).current!.id;
    await controller.toggleFavorite();
    expect(container.read(posesControllerProvider).favorites, contains(id));

    controller.today();
    state = container.read(posesControllerProvider);
    expect(state.status, startsWith('今日姿势'));
    expect(state.current, isNotNull);
  });

  test('G5 修复：关节微调只改一个轴，不覆盖其他两轴', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ContentPacks.syncToDatabase(db);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final PosesController controller = container.read(
      posesControllerProvider.notifier,
    );
    await controller.init();
    final PoseEntry? current = container.read(posesControllerProvider).current;
    expect(current, isNotNull);
    final List<Object?> base =
        current!.joints['shoulder_l'] as List<Object?>? ?? <Object?>[0, 0, 8];
    controller.adjustJoint('shoulder_l', 'rx', 40);
    final Map<String, Object?> override =
        container.read(posesControllerProvider).jointsOverride ??
        <String, Object?>{};
    final List<Object?> adjusted = override['shoulder_l'] as List<Object?>;
    expect((adjusted[0] as num).toDouble(), 40);
    expect(
      (adjusted[1] as num).toDouble(),
      (base[1] as num?)?.toDouble() ?? 0,
      reason: 'ry 不应被清零',
    );
    expect(
      (adjusted[2] as num).toDouble(),
      (base[2] as num?)?.toDouble() ?? 0,
      reason: 'rz 不应被清零',
    );
  });

  test('另存为自定义姿势：写入 DB 并进入当前列表', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await ContentPacks.syncToDatabase(db);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final PosesController controller = container.read(
      posesControllerProvider.notifier,
    );
    await controller.init();
    final int before = container.read(posesControllerProvider).all.length;
    controller.adjustJoint('neck', 'ry', 12);
    await controller.saveCustom('测试自定义姿势');
    final PosesState state = container.read(posesControllerProvider);
    expect(state.all.length, before + 1);
    expect(state.all.any((PoseEntry p) => p.name == '测试自定义姿势'), isTrue);
  });
}
