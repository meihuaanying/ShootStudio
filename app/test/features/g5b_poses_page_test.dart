import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/poses/poses_page.dart';

import '../support/test_env.dart';

/// G5b：V4 照片姿势页渲染回归（照片网格 + 详情 + 导入布光入口，无布局异常）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Workspace workspace;
  late ProviderContainer container;

  setUp(() async {
    await TestEnv.install();
    workspace = await Workspace.initAt(p.join(TestEnv.root.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        workspaceProvider.overrideWithValue(workspace),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await TestEnv.dispose();
  });

  testWidgets('V4：照片姿势页渲染（照片网格 + 骨架说明 + 导入布光）', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PosesPage())),
      ),
    );

    for (var i = 0; i < 80; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 60));
      if (find.text('站姿·展臂').evaluate().isNotEmpty) break;
    }

    expect(find.text('站姿·展臂'), findsWidgets, reason: '姿势未加载');
    expect(find.text('导入到布光预演'), findsWidgets, reason: '缺导入布光入口');
    expect(find.textContaining('骨架置信度'), findsWidgets, reason: '缺骨架置信度说明');
    expect(tester.takeException(), isNull, reason: '姿势页布局异常');
  });
}
