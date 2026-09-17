import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/app.dart';

import '../support/test_env.dart';

/// 用户黄金流程（应用级）：
/// 首启引导 → 载入示例内容 → 开案页输入中文想法 → 本地引擎生成 →
/// 确认写入画布 → 策划编辑器出现模块。
Future<void> settleUntil(
  WidgetTester tester,
  Finder finder, {
  int tries = 60,
  bool required = false,
}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 80));
  }
  if (required) {
    expect(finder.evaluate(), isNotEmpty, reason: '等待超时：$finder');
  }
}

Future<void> settleUntilGone(
  WidgetTester tester,
  Finder finder, {
  int tries = 60,
}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isEmpty) return;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await TestEnv.install();
  });

  /// 放大测试视口，避免引导页内容折叠导致按钮不可点。
  void useLargeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  tearDown(() async {
    await TestEnv.dispose();
  });

  testWidgets('黄金流程：引导→示例→开案生成→写入画布', (WidgetTester tester) async {
    useLargeView(tester);
    await tester.pumpWidget(const ProviderScope(child: ShootStudioApp()));
    await settleUntil(tester, find.textContaining('载入示例内容'));
    // 等待默认目录解析完成（按钮从禁用变为可用）。
    await settleUntilGone(tester, find.textContaining('正在准备默认目录'));

    // 载入示例内容 → 进入工作台开案页。
    await tester.ensureVisible(find.text('载入示例内容'));
    await tester.tap(find.text('载入示例内容'));
    await tester.pump();
    await settleUntil(tester, find.textContaining('说说你想拍什么'),
        tries: 150, required: true);

    // 示例策划案出现在最近列表。
    await settleUntil(tester, find.textContaining('示例 · 雨夜霓虹'));

    // 输入中文想法 → 本地引擎生成（无 Key 自动降级）。
    await settleUntil(tester, find.byType(TextField), required: true);
    await tester.enterText(
      find.byType(TextField).first,
      '雨夜霓虹 cos 正片，冷主光加品红点缀',
    );
    await tester.tap(find.text('生成策划案'));
    await tester.pump();

    // J1：生成后自动进入全案阅读模式，正文可见 → 写入画布。
    await settleUntil(tester, find.text('全案阅读'), tries: 150);
    await settleUntil(tester, find.textContaining('雨夜霓虹'), tries: 120);
    await tester.tap(find.text('写入画布并编辑'));
    await tester.pump();

    // 策划编辑器出现模块卡片。
    await settleUntil(tester, find.textContaining('拍摄主题'), tries: 120);
    expect(find.textContaining('拍摄主题'), findsWidgets);
    expect(find.textContaining('预算表'), findsWidgets);
  });

  testWidgets('引导页显示三步图文与双按钮', (WidgetTester tester) async {
    useLargeView(tester);
    await tester.pumpWidget(const ProviderScope(child: ShootStudioApp()));
    await settleUntil(tester, find.textContaining('开始空白工作区'));
    expect(find.textContaining('找画面参考'), findsWidgets);
    expect(find.textContaining('摆灯光与姿势'), findsWidgets);
    expect(find.textContaining('一键成案导出'), findsWidgets);
    expect(find.textContaining('载入示例内容'), findsWidgets);
  });
}
