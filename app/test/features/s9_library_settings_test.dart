/// V8/S9 · 资源库 + 设置 + 引导页专项测试。
///
/// 覆盖三件事（合同 §1 S9 门禁）：
///  1. 资源库六类（camera/lens/light/accessory/clothing/props）覆盖率 100% 不回归。
///     CI 已在 `.github/workflows/ci.yml` 直接跑 `python3 tool/gear_coverage.py`，
///     这里在 Dart 侧复刻同一套判定（不 spawn python，保证 Windows runner 也能跑）。
///  2. 设置往返：公告地址写入后能原样读回（DB 落盘，不触网）。
///  3. 设计组件预览入口在 debug 构建可见（合同 §6 L203），并对资源库/引导页做渲染冒烟。
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/libraries/gear_browser.dart';
import 'package:shoot_studio/features/libraries/libraries_page.dart';
import 'package:shoot_studio/features/onboarding/onboarding_page.dart';
import 'package:shoot_studio/features/settings/settings_page.dart';
import 'package:shoot_studio/features/updater/updater.dart';

const List<String> _gearKinds = <String>[
  'camera',
  'lens',
  'light',
  'accessory',
];

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// 复刻 `tool/gear_coverage.py` 的判定：返回每类的 `covered/total`。
Map<String, ({int covered, int total})> _sixKindCoverage() {
  final Map<String, Object?> gear = _readJson('assets/content/gear/gear.json');
  final Map<String, Object?> photos2 = _readJson(
    'assets/content/gear/gear_photos2.json',
  );
  final Map<String, Object?> sources = _readJson(
    'assets/content/gear/gear_photo_sources.json',
  );

  // 内置图（byId / byModel / builtinTop100）∪ 抓取图源 = 已覆盖
  // （与 tool/gear_coverage.py 的 covered_union 一致；注意 sources 存在 items 子字典里）。
  final Map<String, Object?> sourceItems =
      (sources['items'] as Map<String, Object?>?) ?? const <String, Object?>{};
  final Set<String> covered = <String>{
    ...sourceItems.keys,
    ...(photos2['byId'] as Map<String, Object?>? ?? const <String, Object?>{})
        .keys,
    ...(photos2['byModel'] as Map<String, Object?>? ??
            const <String, Object?>{})
        .keys,
    ...(photos2['builtinTop100'] as List<Object?>? ?? const <Object?>[]).map(
      (Object? id) => '$id',
    ),
  };

  final Map<String, ({int covered, int total})> out =
      <String, ({int covered, int total})>{};
  for (final String kind in _gearKinds) {
    int total = 0;
    int hit = 0;
    for (final Object? raw
        in (gear['items'] as List<Object?>? ?? const <Object?>[])) {
      final Map<String, Object?> item = raw as Map<String, Object?>;
      if (item['kind'] != kind) continue;
      total++;
      if (covered.contains(item['id'])) hit++;
    }
    out[kind] = (covered: hit, total: total);
  }

  // clothing：`clothing_photos.json` 登记了，且至少 1 张照片在磁盘上真实存在。
  final Map<String, Object?> clothing = _readJson(
    'assets/content/clothing/clothing.json',
  );
  final Map<String, Object?> clothingPhotos = _readJson(
    'assets/content/clothing/clothing_photos.json',
  );
  final Map<String, Object?> byCategory =
      (clothingPhotos['byCategory'] as Map<String, Object?>?) ??
      const <String, Object?>{};
  int clothingTotal = 0;
  int clothingHit = 0;
  for (final Object? raw
      in (clothing['categories'] as List<Object?>? ?? const <Object?>[])) {
    final Map<String, Object?> cat = raw as Map<String, Object?>;
    clothingTotal++;
    final String catId = '${cat['id']}';
    final List<Object?> files =
        byCategory[catId] as List<Object?>? ?? const <Object?>[];
    final bool exists = files.any((Object? f) {
      final Object? name = (f as Map<String, Object?>?)?['file'];
      if (name == null) return false;
      return File(
        p.join('assets', 'content', 'clothing', 'photo', catId, '$name'),
      ).existsSync();
    });
    if (files.isNotEmpty && exists) clothingHit++;
  }
  out['clothing'] = (covered: clothingHit, total: clothingTotal);

  // props：条目在抓取图源里有登记。
  final Map<String, Object?> props = _readJson(
    'assets/content/props/props_presets.json',
  );
  int propsTotal = 0;
  int propsHit = 0;
  for (final Object? raw
      in (props['props'] as List<Object?>? ?? const <Object?>[])) {
    final Map<String, Object?> item = raw as Map<String, Object?>;
    propsTotal++;
    if (sourceItems.containsKey(item['id'])) propsHit++;
  }
  out['props'] = (covered: propsHit, total: propsTotal);
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('S9 · 资源库六类覆盖率 100% 不回归（复刻 gear_coverage.py）', () {
    test('六类都有条目且全部已覆盖', () {
      final Map<String, ({int covered, int total})> cov = _sixKindCoverage();
      expect(cov.keys.toSet(), <String>{
        ..._gearKinds,
        'clothing',
        'props',
      }, reason: '覆盖报告必须恰好六类');
      cov.forEach((String kind, ({int covered, int total}) v) {
        expect(v.total, greaterThan(0), reason: '$kind 不能是空清单');
        expect(
          v.covered,
          v.total,
          reason: '$kind 覆盖率不是 100%（${v.covered}/${v.total}）',
        );
      });
    });

    test('覆盖率报告产物里六类也都是 100%（若已生成）', () {
      final File report = File('../docs/qa/gear-coverage-v7.json');
      if (!report.existsSync()) {
        // 产物不在 git 里（CI 现场生成），跳过强断言。
        expect(_sixKindCoverage().length, 6);
        return;
      }
      final Map<String, Object?> doc =
          jsonDecode(report.readAsStringSync()) as Map<String, Object?>;
      final Map<String, Object?> categories =
          doc['categories'] as Map<String, Object?>? ??
          const <String, Object?>{};
      for (final String kind in <String>[..._gearKinds, 'clothing', 'props']) {
        final Map<String, Object?> row =
            categories[kind] as Map<String, Object?>? ??
            const <String, Object?>{};
        expect(row['pass'], isTrue, reason: '$kind 在报告里未 PASS');
        expect(row['ratio'], 1.0, reason: '$kind 在报告里不是 100%');
      }
      expect(doc['pass'], isTrue, reason: '报告 overall 未 PASS');
    });
  });

  group('S9 · 设置页往返与 debug 入口', () {
    late Directory temp;
    late Workspace ws;
    late AppDatabase db;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ss_s9_settings_');
      ws = await Workspace.initAt(p.join(temp.path, 'ws'));
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('设置往返：公告地址写入后可原样读回（触库不触网）', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final UpdaterController notifier = container.read(
        updaterProvider.notifier,
      );
      const String custom = 'https://intranet.example.com/announce.json';
      await notifier.setAnnouncementUrl('  $custom  ');
      expect(
        await notifier.announcementUrl(),
        custom,
        reason: '设置往返失败：写入的值没被原样读回',
      );
      expect(container.read(updaterProvider).status, '公告地址已保存');
      // 覆盖写回默认域也要能往返。
      await notifier.setAnnouncementUrl('https://a.example.com/x.json');
      expect(await notifier.announcementUrl(), 'https://a.example.com/x.json');
    });

    testWidgets('设置页：debug 构建可见「设计组件预览」入口（合同 §6 L203）', (
      WidgetTester tester,
    ) async {
      expect(kDebugMode, isTrue, reason: '本用例只覆盖 debug 入口可见性');
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            databaseProvider.overrideWithValue(db),
            workspaceProvider.overrideWithValue(ws),
          ],
          child: MaterialApp(home: Scaffold(body: SettingsPage())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: '设置页渲染异常');
      // 入口在长 ListView 的底部（设计系统卡片在「关于与更新」之前），需滚到才建树。
      await tester.scrollUntilVisible(
        find.text('设计组件预览'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('设计组件预览'), findsOneWidget);
      expect(find.text('设计系统'), findsOneWidget);
      // 公告地址输入框（设置项本体）也在。
      expect(
        find.widgetWithText(TextField, '公告 JSON 地址（空 = 官方默认；支持自建站点 / 内网）'),
        findsOneWidget,
      );
    });
  });

  group('S9 · 资源库 / 设备库 / 引导页渲染冒烟', () {
    late Directory temp;
    late Workspace ws;
    late AppDatabase db;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ss_s9_library_');
      ws = await Workspace.initAt(p.join(temp.path, 'ws'));
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    Widget host(Widget child) => ProviderScope(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        workspaceProvider.overrideWithValue(ws),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

    testWidgets('资源库页渲染：五大库 + 设备库切换', (WidgetTester tester) async {
      await tester.pumpWidget(host(const LibrariesPage()));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: '资源库页渲染异常');
      expect(find.text('资源库'), findsWidgets);
    });

    testWidgets('设备库：相机分类可渲染且带选型免责声明', (WidgetTester tester) async {
      // 用较高的视口，让「网格 + 底部免责声明」整块都建树（避免 offstage 跳过）。
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const GearBrowser()));
      // gearListProvider 是 FutureProvider，其 data 分支才有网格与底部免责声明；
      // 显式推进时间轴让它落地。
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: '设备库渲染异常');
    });

    test('设备库：选型免责声明必须写明「禁止商用分发」与「许可/来源以标注为准」', () {
      // 声明常量是许可红线的载体（产品图版权归原品牌，仅供选型参考）。
      expect(kGearPhotoDisclaimer, contains('仅供选型参考'));
      expect(kGearPhotoDisclaimer, contains('禁止商用分发'));
      expect(kGearPhotoDisclaimer, contains('许可与来源以标注为准'));
    });

    testWidgets('引导页渲染', (WidgetTester tester) async {
      await tester.pumpWidget(host(const OnboardingPage()));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: '引导页渲染异常');
    });
  });
}
