import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('资源库 CRUD（五大库同构表，D2）', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.resources).insert(
          ResourcesCompanion.insert(
            id: 'm1',
            type: 'models',
            name: '潇潇',
            fieldsJson: const Value('{"region":"杭州","price":"300/小时"}'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.resources).insert(
          ResourcesCompanion.insert(
            id: 'l1',
            type: 'locations',
            name: '影棚 A',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final models = await (db.select(db.resources)
          ..where((t) => t.type.equals('models')))
        .get();
    expect(models, hasLength(1));
    expect(models.first.name, '潇潇');
    expect(models.first.fieldsJson, contains('杭州'));

    // 更新
    await (db.update(db.resources)..where((t) => t.id.equals('m1'))).write(
      ResourcesCompanion(
        name: const Value('潇潇（更新）'),
        updatedAt: Value(now + 1),
      ),
    );
    final updated = await (db.select(db.resources)
          ..where((t) => t.id.equals('m1')))
        .getSingle();
    expect(updated.name, '潇潇（更新）');

    // 删除
    await (db.delete(db.resources)..where((t) => t.id.equals('l1'))).go();
    expect(await db.select(db.resources).get(), hasLength(1));
  });

  test('资源图片级联删除（D23）', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.resources).insert(
          ResourcesCompanion.insert(
            id: 'p1',
            type: 'props',
            name: '反光板',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.resourceImages).insert(
          ResourceImagesCompanion.insert(
            id: 'img1',
            resourceId: 'p1',
            filePath: 'images/props/a.jpg',
          ),
        );
    expect(await db.select(db.resourceImages).get(), hasLength(1));
    await (db.delete(db.resources)..where((t) => t.id.equals('p1'))).go();
    expect(await db.select(db.resourceImages).get(), isEmpty);
  });

  test('策划案与快照（D15–D17）', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.plans).insert(
          PlansCompanion.insert(
            id: 'plan1',
            title: '夏夜霓虹',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (var i = 0; i < 3; i++) {
      await db.into(db.planSnapshots).insert(
            PlanSnapshotsCompanion.insert(
              id: 'snap$i',
              planId: 'plan1',
              modulesJson: '[{"id":"m$i"}]',
              label: Value(i == 2 ? '客户确认版' : null),
              createdAt: now + i,
            ),
          );
    }
    final snaps = await (db.select(db.planSnapshots)
          ..where((t) => t.planId.equals('plan1'))
          ..orderBy(<OrderClauseGenerator<$PlanSnapshotsTable>>[
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
    expect(snaps, hasLength(3));
    expect(snaps.first.label, '客户确认版');
  });

  test('设置键值读写（内容包版本/更新通道）', () async {
    expect(await db.getSetting('content_pack_version'), isNull);
    await db.setSetting('content_pack_version', '1');
    expect(await db.getSetting('content_pack_version'), '1');
    await db.setSetting('content_pack_version', '2');
    expect(await db.getSetting('content_pack_version'), '2');
  });

  test('AI 提供方配置与调用日志（D8–D10）', () async {
    await db.into(db.providerConfigs).insert(
          ProviderConfigsCompanion.insert(
            id: 'deepseek',
            name: 'DeepSeek',
            baseUrl: 'https://api.deepseek.com/v1',
            encryptedKey: Value('enc:xxx'),
            defaultModel: const Value('deepseek-chat'),
          ),
        );
    final providers = await db.select(db.providerConfigs).get();
    expect(providers.single.name, 'DeepSeek');

    await db.into(db.callLogs).insert(
          CallLogsCompanion.insert(
            providerId: 'deepseek',
            model: 'deepseek-chat',
            success: true,
            latencyMs: 820,
            promptTokens: const Value(120),
            completionTokens: const Value(240),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    final logs = await db.select(db.callLogs).get();
    expect(logs.single.success, isTrue);
    expect(logs.single.latencyMs, 820);
  });
}
