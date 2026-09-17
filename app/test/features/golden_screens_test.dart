import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/app.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/planner/planner_page.dart';

import '../support/test_env.dart';

Future<void> settleUntil(
  WidgetTester tester,
  Finder finder, {
  int tries = 120,
  bool required = false,
}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 60));
  }
  if (required) {
    expect(finder.evaluate(), isNotEmpty, reason: '等待超时：$finder');
  }
}

Future<void> settleUntilGone(
  WidgetTester tester,
  Finder finder, {
  int tries = 120,
}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isEmpty) return;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// F6 黄金三屏：引导页 / 开案页 / 空策划案。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    EditableText.debugDeterministicCursor = true;
    await TestEnv.install();
  });

  tearDown(() async {
    EditableText.debugDeterministicCursor = false;
    await TestEnv.dispose();
  });

  void useGoldenView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1360, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('golden · 引导页', (WidgetTester tester) async {
    useGoldenView(tester);
    await tester.pumpWidget(const ProviderScope(child: ShootStudioApp()));
    await settleUntil(tester, find.textContaining('开始空白工作区'), required: true);
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding.png'),
    );
  });

  testWidgets('golden · 开案页（极简首屏）', (WidgetTester tester) async {
    useGoldenView(tester);
    await tester.pumpWidget(const ProviderScope(child: ShootStudioApp()));
    await settleUntil(tester, find.textContaining('开始空白工作区'), required: true);
    await settleUntilGone(tester, find.textContaining('正在准备默认目录'));
    await tester.ensureVisible(find.text('开始空白工作区'));
    await tester.tap(find.text('开始空白工作区'));
    await tester.pump();
    await settleUntil(tester, find.text('说说你想拍什么'), required: true);
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_empty.png'),
    );
  });

  testWidgets('golden · 空策划案', (WidgetTester tester) async {
    useGoldenView(tester);
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: PlannerPage())),
      ),
    );
    await settleUntil(tester, find.text('空策划案'), required: true);
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/planner_empty.png'),
    );
  });
}
