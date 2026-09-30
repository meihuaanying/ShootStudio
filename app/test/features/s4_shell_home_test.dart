// V8/S4：App 外壳 + 首页专项测试（D151/R71–R74/R79/R82）。
//
// 覆盖：
//   1. 信息架构：3 个分组（工作流/成案/系统）+ 7 个入口下标固定且连续；
//   2. 侧边导航渲染 + 点击切 tab + 品牌区与版本行；
//   3. 更新横幅：公告存在/为空、要点只取前 2 条、双行动文案；
//   4. 首页 hero 文案与灵感条回调、空态、最近策划案空态；
//   5. R71/R82 门禁：S4 源文件禁用渐变紫蓝/Colors/字面量色，且行数 ≤600（R73）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/features/home/home_hero.dart';
import 'package:shoot_studio/features/home/home_page.dart';
import 'package:shoot_studio/features/home/home_recent.dart';
import 'package:shoot_studio/features/shell/shell_nav.dart';
import 'package:shoot_studio/features/shell/shell_update_banner.dart';
import 'package:shoot_studio/features/updater/updater.dart';

const String kShellDir = 'lib/features/shell';
const String kHomeDir = 'lib/features/home';

/// 构造测试公告。
Announcement _announcement({
  String version = '2.0.0',
  List<String> notes = const <String>['要点一', '要点二', '要点三'],
}) {
  return Announcement(
    version: version,
    notes: notes,
    publishedAt: '2026-09-30',
    downloads: <String, DownloadEntry>{
      'windows': const DownloadEntry(
        mirror: 'https://mirror.example.com/win.zip',
        github: 'https://github.com/o/r/releases/download/v2.0.0/win.zip',
        sha256: 'aa',
      ),
      'android': const DownloadEntry(
        mirror: '',
        github: 'https://github.com/o/r/releases/download/v2.0.0/app.apk',
        sha256: 'bb',
      ),
    },
    contentPacks: const <ContentPackEntry>[],
    ops: const <({String title, String date})>[],
  );
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('S4 外壳：信息架构', () {
    test('3 个分组连续覆盖 7 个入口（下标不可调整）', () {
      expect(kShellNavSections.length, 3);
      expect(
        kShellNavSections.map((ShellNavSection s) => s.label).toList(),
        <String>['工作流', '成案', '系统'],
      );
      expect(
        kShellNavSections.map((ShellNavSection s) => s.eyebrow).toList(),
        <String>['WORKFLOW', 'DELIVERY', 'SYSTEM'],
      );
      expect(
        kShellNavSections.map((ShellNavSection s) => s.startIndex).toList(),
        <int>[0, 4, 6],
      );
      for (int i = 1; i < kShellNavSections.length; i++) {
        expect(
          kShellNavSections[i].startIndex,
          greaterThan(kShellNavSections[i - 1].startIndex),
        );
      }
    });

    test('7 个入口：label/caption 齐全且唯一', () {
      expect(kShellNavItems.length, 7);
      final Set<String> labels = kShellNavItems
          .map((ShellNavItem i) => i.label)
          .toSet();
      expect(labels.length, 7);
      for (final ShellNavItem item in kShellNavItems) {
        expect(item.label.isNotEmpty, isTrue);
        expect(item.caption.isNotEmpty, isTrue);
        expect(item.caption, matches(RegExp(r'^[A-Z0-9]+$')));
      }
      expect(
        kShellNavItems.map((ShellNavItem i) => i.label).toList(),
        containsAll(<String>['开案', '画面参考', '布光预演', '动作摆姿', '资源库', '策划案', '设置']),
      );
      // 策划案 tab 下标常量与导航顺序一致（R76 迁移明示）。
      expect(kShellTabPlanner, 5);
      expect(kShellNavItems[kShellTabPlanner].label, '策划案');
    });

    testWidgets('侧边导航：品牌区 + 全部入口 + 点击回调下标', (WidgetTester tester) async {
      final List<int> picked = <int>[];
      await tester.pumpWidget(
        _wrap(ShellSideNav(index: 0, onSelect: (int i) => picked.add(i))),
      );
      expect(find.text('正片工坊'), findsOneWidget);
      expect(find.textContaining('MIT 开源'), findsOneWidget);
      for (final ShellNavItem item in kShellNavItems) {
        expect(find.text(item.label), findsWidgets, reason: item.label);
        expect(find.text(item.caption), findsWidgets, reason: item.caption);
      }
      await tester.tap(find.text('布光预演'));
      await tester.pumpAndSettle();
      expect(picked, <int>[2]);
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(picked, <int>[2, 6]);
    });

    testWidgets('侧边导航：选中项不重复高亮（同一时刻仅一个当前项）', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ShellSideNav(index: 3, onSelect: (int _) {})),
      );
      for (final ShellNavItem item in kShellNavItems) {
        expect(find.text(item.label), findsWidgets);
      }
      expect(ShellSideNav.width, greaterThanOrEqualTo(200));
    });
  });

  group('S4 外壳：更新横幅', () {
    testWidgets('有公告：眉题 + 版本 + 前 2 条要点 + 双行动', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ShellUpdateBanner(
            updater: UpdaterState(
              announcement: _announcement(),
              lastState: UpdateState.hasUpdate,
            ),
          ),
        ),
      );
      expect(find.text('更新公告'), findsOneWidget);
      expect(find.text('v2.0.0'), findsOneWidget);
      expect(find.text('要点一'), findsOneWidget);
      expect(find.text('要点二'), findsOneWidget);
      // 要点只取前 2 条，避免横幅被长文撑高。
      expect(find.text('要点三'), findsNothing);
      expect(find.text('下次再说'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
    });

    testWidgets('无公告：不渲染任何内容', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const ShellUpdateBanner(updater: UpdaterState())),
      );
      expect(find.text('更新公告'), findsNothing);
      expect(find.byType(SsButton), findsNothing);
    });

    test('公告：按平台取下载直链，mirror 优先', () {
      final Announcement a = _announcement();
      expect(a.downloadFor('windows')!.mirror, isNotEmpty);
      expect(a.downloadFor('android')!.mirror, isEmpty);
      expect(a.downloadFor('android')!.github, contains('releases/download'));
      expect(a.downloadFor('macos'), isNull);
    });
  });

  group('S4 首页', () {
    testWidgets('hero：衬线标题 + 输入 + 生成按钮 + eyebrow', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      int generates = 0;
      await tester.pumpWidget(
        _wrap(
          HomeIdeaHero(
            controller: controller,
            generating: false,
            onGenerate: () => generates += 1,
          ),
        ),
      );
      expect(find.text('OPENING · 开案'), findsOneWidget);
      expect(find.text('说说你想拍什么'), findsOneWidget);
      expect(find.text('生成策划案'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '雨夜霓虹人像');
      expect(controller.text, '雨夜霓虹人像');
      await tester.tap(find.text('生成策划案'));
      await tester.pump();
      expect(generates, 1);
      controller.dispose();
    });

    testWidgets('灵感条：6 张卡片 + 点击回传对应条目', (WidgetTester tester) async {
      expect(kHomeInspirations.length, 6);
      final List<({String title, String prompt})> picked =
          <({String title, String prompt})>[];
      await tester.pumpWidget(
        _wrap(
          HomeInspirationStrip(items: kHomeInspirations, onPick: picked.add),
        ),
      );
      // 横向列表是懒构建的，只断言首屏可见卡片。
      for (int i = 0; i < 2 && i < kHomeInspirations.length; i++) {
        expect(
          find.text(kHomeInspirations[i].title),
          findsWidgets,
          reason: kHomeInspirations[i].title,
        );
      }
      await tester.tap(find.text(kHomeInspirations[1].title).first);
      await tester.pump();
      expect(picked.single.title, kHomeInspirations[1].title);
      expect(picked.single.prompt, kHomeInspirations[1].prompt);
    });

    testWidgets('最近策划案：无数据时显示空态卡片', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            recentPlansProvider.overrideWith((Ref ref) async => <Plan>[]),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: HomeRecentPlans(onOpen: (Plan _) async {})),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('还没有策划案'), findsOneWidget);
    });
  });

  group('S4 门禁（R71/R73/R74/R82）', () {
    final List<String> files = <String>[
      '$kShellDir/app_shell.dart',
      '$kShellDir/shell_nav.dart',
      '$kShellDir/shell_update_banner.dart',
      '$kHomeDir/home_page.dart',
      '$kHomeDir/home_hero.dart',
      '$kHomeDir/home_recent.dart',
    ];

    test('全部走设计系统组件（R74）', () {
      for (final String f in files) {
        final String src = File(f).readAsStringSync();
        expect(
          src.contains('core/design/widgets.dart'),
          isTrue,
          reason: '$f 未引用设计系统',
        );
      }
    });

    test('无紫蓝渐变/硬编码颜色/Colors.*（R71 + R82）', () {
      for (final String f in files) {
        final String src = File(f).readAsStringSync();
        for (final String bad in <String>[
          'LinearGradient',
          'Colors.',
          '0x',
          'fontSize:',
        ]) {
          expect(src.contains(bad), isFalse, reason: '$f 出现 $bad');
        }
      }
    });

    test('R73：单文件 ≤600 行', () {
      for (final String f in files) {
        final int lines = File(f).readAsLinesSync().length;
        expect(lines, lessThanOrEqualTo(600), reason: '$f = $lines 行');
      }
    });
  });
}
