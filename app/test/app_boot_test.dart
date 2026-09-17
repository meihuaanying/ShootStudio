import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/app.dart';

import 'support/test_env.dart';

/// 应用级冒烟（用户视角）：真实启动 ShootStudioApp，首屏应无异常。
/// 说明：testWidgets 运行在 FakeAsync 中，真实 IO 的 Future 需要 runAsync 推进；
/// path_provider 由 TestEnv 提供临时目录 Mock。
Future<void> bootAndSettle(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ShootStudioApp()));
  await settleUntil(tester, find.textContaining('正片工坊'));
}

/// 交替推进真实异步与帧，直到 [finder] 命中或超时（避免依赖固定时序）。
Future<void> settleUntil(
  WidgetTester tester,
  Finder finder, {
  int tries = 20,
}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestEnv.install();
  });

  tearDownAll(() async {
    await TestEnv.dispose();
  });

  testWidgets('首屏启动：不抛异常且能看到引导页', (WidgetTester tester) async {
    await bootAndSettle(tester);
    final Object? error = tester.takeException();
    expect(error, isNull, reason: '首屏构建不应抛异常（release 下会渲染为灰屏）');
    expect(find.textContaining('正片工坊'), findsWidgets);
  });

  testWidgets('引导页可见：默认目录与选择按钮存在', (WidgetTester tester) async {
    await bootAndSettle(tester);
    expect(find.textContaining('工作区'), findsWidgets);
    await settleUntil(tester, find.textContaining('开始空白工作区'));
    expect(find.textContaining('开始空白工作区'), findsWidgets);
    expect(find.textContaining('载入示例内容'), findsWidgets);
  });

  test('默认工作区路径可解析（Windows 文档目录）', () async {
    expect(Platform.isWindows, isTrue);
  }, skip: !Platform.isWindows ? '仅 Windows 平台适用（CI Linux 跳过）' : null);
}
