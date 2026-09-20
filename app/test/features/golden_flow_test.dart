import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/features/planner/planner_controller.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/features/poses/poses_controller.dart';
import 'package:shoot_studio/features/refs/refs_controller.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

/// 黄金流程走查：
/// 找一帧参考 → 收入画板 → 摆一套三点布光并保存 → 挑姿势收藏并注入 →
/// 中文主题生成策划案（模板）→ 修改 + 快照回滚 → （导出在 export 测试覆盖）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late Workspace workspace;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ss_golden_');
    workspace = await Workspace.initAt(p.join(temp.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        workspaceProvider.overrideWithValue(workspace),
      ],
    );
    await ContentPacks.syncToDatabase(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });

  test('STEP1 找一帧参考（影片索引 → 收入画板）', () async {
    final films = await ContentPacks.films();
    expect(films.length, greaterThanOrEqualTo(20));
    final film = films.first;
    expect(film.frames.length, 6);
    final frame = film.frames.first;
    expect(frame.palette, hasLength(5));
    expect(frame.sourceUrl, contains('film-grab.com'));

    final controller = container.read(refsControllerProvider.notifier);
    await controller.init();
    await controller.toggleBoard(film, frame);
    final state = container.read(refsControllerProvider);
    expect(state.board, hasLength(1));
    expect(state.board.first.name, frame.name);
  });

  test('STEP2 摆一套三点布光并保存（灯位/清单/预设）', () async {
    final presets = await ContentPacks.lightPresets();
    expect(presets.length, greaterThanOrEqualTo(20));
    final threePoint = presets.firstWhere((p) => p.id == 'three-point');
    expect(threePoint.devices, hasLength(3));

    final controller = container.read(lightingControllerProvider.notifier);
    await controller.init();
    await controller.applyPreset(threePoint);
    var state = container.read(lightingControllerProvider);
    expect(state.scene.lights, hasLength(3));

    // 拖动主光 → 方位/距离更新。
    final key = state.scene.lights.first;
    controller.moveDevice(key.id, 2.0, -2.0);
    state = container.read(lightingControllerProvider);
    expect(state.dirty, isTrue);

    // 保存 → 可被策划案绑定。
    await controller.save();
    final rows = await db.select(db.lightingScenes).get();
    expect(rows, hasLength(1));
    expect(rows.first.name, contains('三点布光'));
  });

  test('STEP3 挑姿势收藏并注入布光场景', () async {
    final poseController = container.read(posesControllerProvider.notifier);
    await poseController.init();
    var poses = container.read(posesControllerProvider);
    expect(poses.all.length, greaterThanOrEqualTo(120));
    expect(poses.filtered.isNotEmpty, isTrue);

    poseController.setCategory('站姿');
    poses = container.read(posesControllerProvider);
    expect(poses.filtered.every((p) => p.category == '站姿'), isTrue);

    await poseController.toggleFavorite();
    poses = container.read(posesControllerProvider);
    expect(poses.favorites, isNotEmpty);

    // 注入布光预演。
    final current = poses.current!;
    container
        .read(lightingControllerProvider.notifier)
        .injectPose(poses.effectiveJoints, current.name);
    final lighting = container.read(lightingControllerProvider);
    expect(lighting.pendingPose, isNotNull);
    expect(lighting.viewMode, 'split');
  });

  test('STEP4 中文主题生成策划案（模板）+ 编辑 + 快照回滚', () async {
    final templates = await ContentPacks.templates();
    expect(templates.length, greaterThanOrEqualTo(8));
    final cos = templates.firstWhere((t) => t.category == 'Cos 正片');

    final controller = container.read(plannerControllerProvider.notifier);
    await controller.init();
    await controller.newFromTemplate(cos);
    var state = container.read(plannerControllerProvider);
    expect(state.modules, isNotEmpty);
    expect(state.modules.map((m) => m.type), contains(PlanModuleType.theme));

    // 中文标题与主题。
    controller.setTitle('雨夜赛博朋克风初音正片');
    final themeModule = state.modules.firstWhere(
      (m) => m.type == PlanModuleType.theme,
    );
    controller.updateModule(
      themeModule.id,
      (m) => m.data['text'] = '霓虹雨夜，初音未来，未来感',
    );
    await controller.saveNow();

    // 快照存在且可回滚。
    state = container.read(plannerControllerProvider);
    expect(state.snapshots, isNotEmpty);
    final snapshotCountBefore = state.snapshots.length;

    // 添加模块后回滚。
    controller.addModule(PlanModuleType.richText);
    await controller.saveNow();
    state = container.read(plannerControllerProvider);
    final richText = state.modules.firstWhere(
      (m) => m.type == PlanModuleType.richText,
    );
    await controller.restoreSnapshot(state.snapshots.last.id);
    state = container.read(plannerControllerProvider);
    expect(state.modules.any((m) => m.id == richText.id), isFalse);
    expect(state.snapshots.length, greaterThan(snapshotCountBefore));
  });

  test('STEP4b 模块 Schema 校验拦截非法 AI 输出', () {
    final errors = ModuleSchemaValidator.validate(<Object?>[
      <String, Object?>{
        'type': 'theme',
        'title': '主题',
        'data': <String, Object?>{'text': 'x'},
      },
      <String, Object?>{
        'type': 'not-a-type',
        'title': 'x',
        'data': <String, Object?>{},
      },
    ]);
    expect(errors, hasLength(1));
    expect(errors.first, contains('not-a-type'));
  });
}
