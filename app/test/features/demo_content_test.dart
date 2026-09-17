import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/features/onboarding/demo_content.dart';
import 'package:shoot_studio/services/content_packs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await ContentPacks.syncToDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('载入示例内容：策划案/布光方案/资源/画板帧/姿势收藏全部就位', () async {
    expect(await DemoContentService.isSeeded(db), isFalse);

    final int seeded = await DemoContentService.seed(db);
    expect(seeded, greaterThan(10));
    expect(await DemoContentService.isSeeded(db), isTrue);

    // 策划案。
    final plans = await db.select(db.plans).get();
    final demoPlan =
        plans.where((Plan p) => p.id == DemoContentService.planId).toList();
    expect(demoPlan, hasLength(1));
    expect(demoPlan.first.title, contains('示例'));
    expect(demoPlan.first.modulesJson.length, greaterThan(200));

    // 布光方案。
    final scenes = await db.select(db.lightingScenes).get();
    expect(scenes.any((LightingScene s) => s.id == DemoContentService.sceneId),
        isTrue);

    // 资源。
    final resources = await db.select(db.resources).get();
    for (final String id in DemoContentService.resourceIds) {
      expect(resources.any((Resource r) => r.id == id), isTrue,
          reason: '缺少 $id');
    }

    // 画板帧（6 帧入板）。
    final frames = await (db.select(db.filmFrames)
          ..where((t) => t.inBoard.equals(true)))
        .get();
    expect(frames.length, greaterThanOrEqualTo(6));

    // 姿势收藏（≥3）。
    final favorites = await (db.select(db.poses)
          ..where((t) => t.favorite.equals(true)))
        .get();
    expect(favorites.length, greaterThanOrEqualTo(3));

    // 重复载入幂等。
    expect(await DemoContentService.seed(db), 0);
  });

  test('移除示例内容：新建行删除、既有行还原、用户数据保留', () async {
    // 用户自建数据（应不受影响）。
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.resources).insert(
          ResourcesCompanion.insert(
            id: 'user-res-1',
            type: 'models',
            name: '用户自己的模特',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await DemoContentService.seed(db);
    await DemoContentService.remove(db);

    expect(await DemoContentService.isSeeded(db), isFalse);
    final plans = await db.select(db.plans).get();
    expect(plans.any((Plan p) => p.id == DemoContentService.planId), isFalse);
    final scenes = await db.select(db.lightingScenes).get();
    expect(scenes.any((LightingScene s) => s.id == DemoContentService.sceneId),
        isFalse);
    final resources = await db.select(db.resources).get();
    for (final String id in DemoContentService.resourceIds) {
      expect(resources.any((Resource r) => r.id == id), isFalse);
    }
    expect(resources.any((Resource r) => r.id == 'user-res-1'), isTrue);

    final frames = await (db.select(db.filmFrames)
          ..where((t) => t.inBoard.equals(true)))
        .get();
    expect(frames, isEmpty);
    final favorites = await (db.select(db.poses)
          ..where((t) => t.favorite.equals(true)))
        .get();
    expect(favorites, isEmpty);
  });
}
