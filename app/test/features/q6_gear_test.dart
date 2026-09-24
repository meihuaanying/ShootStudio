import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/libraries/gear_browser.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'package:shoot_studio/services/gear_photo_sync.dart';

// Q6/E 资源库参考图硬门禁（D129–D131，R47/R48/R56/R58）：
// 覆盖率报告、图源登记、断点续跑状态机、补图登记、免责声明。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Q6 资源库参考图', () {
    test('覆盖率报告六类 100% 且含 tier/四层来源（V7/D142）', () {
      final File report = File('../docs/qa/gear-coverage-v7.json');
      expect(
        report.existsSync(),
        isTrue,
        reason: '缺覆盖率报告 docs/qa/gear-coverage-v7.json（V7/D142）',
      );
      final Map<String, Object?> json =
          (jsonDecode(report.readAsStringSync()) as Map)
              .cast<String, Object?>();
      final Map<String, Object?> categories = (json['categories'] as Map)
          .cast<String, Object?>();
      expect(categories.keys.toSet(), <String>{
        'camera',
        'lens',
        'light',
        'accessory',
        'clothing',
        'props',
      }, reason: '六类口径缺失');
      for (final MapEntry<String, Object?> entry in categories.entries) {
        final Map<String, Object?> c = (entry.value as Map)
            .cast<String, Object?>();
        expect(c['total'], isA<int>(), reason: '${entry.key} total');
        expect(c['covered'], isA<int>(), reason: '${entry.key} covered');
        expect(
          (c['covered'] as int) <= (c['total'] as int),
          isTrue,
          reason: '${entry.key} covered > total',
        );
        expect(
          c['missing'],
          isA<List<Object?>>(),
          reason: '${entry.key} 缺缺口清单',
        );
        expect(
          (c['missing'] as List<Object?>).length,
          c['missingCount'],
          reason: '${entry.key} missingCount 不一致',
        );
        // V7/D142：六类 100%（四层兜底后无缺口；R66：口径由 95/90 更新为 100）。
        expect(
          (c['ratio'] as num),
          greaterThanOrEqualTo(1.0),
          reason: '${entry.key} 未达 100%',
        );
        expect(
          c['missing'] as List<Object?>,
          isEmpty,
          reason: '${entry.key} 仍有缺口（应由四层兜底覆盖）',
        );
        expect(
          c['byTier'],
          isA<Map<Object?, Object?>>(),
          reason: '${entry.key} 缺 tier 分布（D142）',
        );
        expect(
          c['byLayer'],
          isA<Map<Object?, Object?>>(),
          reason: '${entry.key} 缺四层来源统计（D142）',
        );
      }
      expect(json['pass'], isTrue, reason: '六类未全部达标');
      expect(json['missingTotal'], 0, reason: '仍有缺口总数');
      // 四层来源统计（D142）：official / retail / series / open（开放图源）等层。
      final Map<String, Object?> byLayer = (json['byLayer'] as Map)
          .cast<String, Object?>();
      final int layerSum = byLayer.values.fold<int>(
        0,
        (int a, Object? b) => a + (b! as int),
      );
      expect(layerSum, greaterThan(0), reason: '四层来源统计为空');
      expect(
        byLayer.keys.any(
          (String k) => k == 'official' || k == 'series' || k == 'open',
        ),
        isTrue,
        reason: '四层来源统计缺关键层：$byLayer',
      );
      // tier 分布（D142）：同系列示意（series）与氛围实拍（atmosphere）必须可追溯。
      final Map<String, Object?> byTier = (json['byTier'] as Map)
          .cast<String, Object?>();
      expect(byTier.keys, contains('product'), reason: 'tier 分布缺 product');
      expect(
        byTier.keys.any((String k) => k == 'series' || k == 'atmosphere'),
        isTrue,
        reason: 'tier 分布缺 series/atmosphere（近似图必须标注）',
      );
    });

    test('R48 离线 fixture 完整且可自测', () {
      final Directory fixtures = Directory('tool/gear_photos_v3/fixtures');
      expect(
        fixtures.existsSync(),
        isTrue,
        reason: '缺离线 fixture 目录 tool/gear_photos_v3/fixtures',
      );

      final Map<String, Object?> gear =
          (jsonDecode(File('assets/content/gear/gear.json').readAsStringSync())
                  as Map)
              .cast<String, Object?>();
      final Set<String> gearIds = <String>{
        for (final Object? item in gear['items']! as List<Object?>)
          ((item! as Map)['id']).toString(),
      };

      String slugOf(String url) {
        final String last = url
            .split('?')
            .first
            .replaceAll(RegExp(r'/+$'), '')
            .split('/')
            .last
            .replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
        return last.replaceAll(RegExp('[^A-Za-z0-9]'), '').toLowerCase();
      }

      // godox：index.json 的每个产品 URL 必须有对应页面 fixture。
      final List<Object?> godoxIndex =
          jsonDecode(
                File(
                  'tool/gear_photos_v3/fixtures/godox/index.json',
                ).readAsStringSync(),
              )
              as List<Object?>;
      expect(godoxIndex, isNotEmpty);
      for (final Object? entry in godoxIndex) {
        final String url = ((entry! as Map)['url']).toString();
        final File page = File(
          'tool/gear_photos_v3/fixtures/godox/page_${slugOf(url)}.html',
        );
        expect(page.existsSync(), isTrue, reason: 'godox 缺 ${page.path}');
      }

      // viltrox：sitemapindex 子 sitemap 的产品 URL 必须有对应页面 fixture。
      final String sitemap = File(
        'tool/gear_photos_v3/fixtures/viltrox/sitemap_products.xml',
      ).readAsStringSync();
      final Iterable<String> productUrls = RegExp(
        r'<loc>(.*?)</loc>',
      ).allMatches(sitemap).map((RegExpMatch m) => m.group(1)!);
      expect(productUrls, isNotEmpty);
      for (final String url in productUrls) {
        final File page = File(
          'tool/gear_photos_v3/fixtures/viltrox/page_${slugOf(url)}.html',
        );
        expect(page.existsSync(), isTrue, reason: 'viltrox 缺 ${page.path}');
      }

      // aputure：suggest.json 的候选图源必须非空（无需页面 fixture）。
      final Map<String, Object?> suggest =
          (jsonDecode(
                    File(
                      'tool/gear_photos_v3/fixtures/aputure/suggest.json',
                    ).readAsStringSync(),
                  )
                  as Map)
              .cast<String, Object?>();
      final List<Object?> products =
          ((((suggest['resources']! as Map)['results']! as Map)['products'])
              as List<Object?>);
      expect(products, isNotEmpty);
      for (final Object? p in products) {
        final Map<String, Object?> product = (p! as Map)
            .cast<String, Object?>();
        expect(
          '${(product['featured_image']! as Map)['url']}'.startsWith('http'),
          isTrue,
          reason: 'aputure suggest 缺图源',
        );
      }

      // 各品牌样例图片必须对应真实 gear 条目、可解码且不低于下载门槛（≥350px）。
      for (final String label in <String>['godox', 'aputure', 'viltrox']) {
        final Directory dir = Directory('tool/gear_photos_v3/fixtures/$label');
        expect(dir.existsSync(), isTrue, reason: '缺 $label fixture');
        final List<File> images = dir
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.toLowerCase().endsWith('.jpg'))
            .toList();
        expect(images, isNotEmpty, reason: '$label 无样例图片');
        for (final File f in images) {
          final String id = f.uri.pathSegments.last.replaceAll('.jpg', '');
          expect(
            gearIds.contains(id),
            isTrue,
            reason: '$label/$id 不在 gear.json',
          );
          final img.Image? decoded = img.decodeImage(f.readAsBytesSync());
          expect(decoded, isNotNull, reason: '$label/$id 不是有效图片');
          expect(
            decoded!.width >= 350 && decoded.height >= 350,
            isTrue,
            reason: '$label/$id 低于下载门槛（${decoded.width}x${decoded.height}）',
          );
        }
      }

      expect(
        File('tool/gear_photos_v3/selftest.py').existsSync(),
        isTrue,
        reason: '缺 R48 离线自测脚本 selftest.py',
      );
    });

    test('图源登记元数据完整且图片不入 git（D130/R47）', () async {
      final Map<String, Object?> sources = await GearPhotoSync.sources();
      final Map<String, Object?> items = (sources['items'] as Map)
          .cast<String, Object?>();
      expect(items.length, greaterThanOrEqualTo(50), reason: '图源条目过少');
      for (final MapEntry<String, Object?> entry in items.entries) {
        final Map<String, Object?> record = (entry.value as Map)
            .cast<String, Object?>();
        expect(
          '${record['imageUrl']}'.startsWith('http'),
          isTrue,
          reason: '${entry.key} 缺可下载图源',
        );
        expect(
          '${record['license']}'.isNotEmpty,
          isTrue,
          reason: '${entry.key} 缺许可',
        );
        expect(
          '${record['fetchedAt']}'.contains('T'),
          isTrue,
          reason: '${entry.key} 缺获取时间',
        );
        expect(record['sha1'], isA<String>(), reason: '${entry.key} 缺指纹');
        expect(record['width'], isA<int>(), reason: '${entry.key} 缺尺寸');
        // 图片只落工具池/工作区，禁止指向 assets 或打包资源。
        expect(
          '${record['rawPath']}',
          contains('tool/gear_photo_pool/'),
          reason: '${entry.key} 原图必须只存工具池（R47）',
        );
      }
      expect(
        Directory('../app/assets/content/gear/photo3').existsSync(),
        isFalse,
        reason: '抓取图片不得进入 assets',
      );
    });

    test('增量同步状态机：断点续跑/失败重试/图源开关（D131）', () {
      final Map<String, Object?> catalog = <String, Object?>{
        'byId': <String, Object?>{
          'g1': <String, Object?>{
            'id': 'g1',
            'file': 'g1.jpg',
            'builtin': true,
            'runtimeUrl': 'https://example.com/g1.jpg',
          },
          'g2': <String, Object?>{
            'id': 'g2',
            'builtin': false,
            'sourceUrl': 'https://example.com/g2.jpg',
          },
        },
      };
      final Map<String, Object?> sources = <String, Object?>{
        'items': <String, Object?>{
          'g3': <String, Object?>{
            'imageUrl': 'https://example.com/g3.jpg',
            'provider': 'official',
            'kind': 'light',
          },
          'g4': <String, Object?>{
            'imageUrl': 'https://example.com/g4.jpg',
            'provider': 'jd',
            'kind': 'light',
          },
        },
      };
      final GearSyncPlan first = GearPhotoSync.planSync(
        catalog: catalog,
        sources: sources,
        localIds: <String>{'g2'},
        bundledIds: <String>{'g1'},
        state: <String, Object?>{
          'done': <String, Object?>{},
          'failed': <String, Object?>{},
        },
      );
      expect(first.skippedBuiltin, 1);
      expect(first.skippedLocal, 1);
      expect(first.targets.map((GearSyncTarget t) => t.id).toSet(), <String>{
        'g3',
        'g4',
      });

      // 已完成（done）默认跳过；force 时重新下载。
      final GearSyncPlan resumed = GearPhotoSync.planSync(
        catalog: catalog,
        sources: sources,
        localIds: <String>{'g2'},
        bundledIds: <String>{'g1'},
        state: <String, Object?>{
          'done': <String, Object?>{
            'g3': <String, Object?>{'at': '2026-09-21T00:00:00Z'},
          },
          'failed': <String, Object?>{},
        },
      );
      expect(resumed.skippedDone, 1);
      expect(resumed.targets.map((GearSyncTarget t) => t.id), <String>['g4']);

      // 连续失败 >= maxAttempts 默认跳过，retryFailed 时重试。
      final Map<String, Object?> failedState = <String, Object?>{
        'done': <String, Object?>{},
        'failed': <String, Object?>{
          'g3': <String, Object?>{'attempts': 3, 'reason': '超时'},
        },
      };
      final GearSyncPlan failed = GearPhotoSync.planSync(
        catalog: catalog,
        sources: sources,
        localIds: <String>{},
        bundledIds: <String>{},
        state: failedState,
      );
      expect(failed.targets.map((GearSyncTarget t) => t.id).toSet(), <String>{
        'g1',
        'g2',
        'g4',
      });
      expect(failed.skippedFailed, 1);
      final GearSyncPlan retried = GearPhotoSync.planSync(
        catalog: catalog,
        sources: sources,
        localIds: <String>{},
        bundledIds: <String>{},
        state: failedState,
        retryFailed: true,
      );
      expect(retried.targets.map((GearSyncTarget t) => t.id).toSet(), <String>{
        'g1',
        'g2',
        'g3',
        'g4',
      });

      // 图源开关：只开 official 时 jd 条目跳过。
      final GearSyncPlan filtered = GearPhotoSync.planSync(
        catalog: catalog,
        sources: sources,
        localIds: <String>{},
        bundledIds: <String>{},
        state: <String, Object?>{
          'done': <String, Object?>{},
          'failed': <String, Object?>{},
        },
        enabledProviders: <String>{'official', 'builtin'},
      );
      expect(filtered.targets.map((GearSyncTarget t) => t.id).toSet(), <String>{
        'g1',
        'g2',
        'g3',
      });
      expect(filtered.skippedSource, 1);
    });

    test('补图：本地图片写入工作区并登记来源（D130）', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'ss_gear_test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      await Workspace.initAt(tempDir.path);
      final File source = File('${tempDir.path}/incoming.jpg');
      await source.writeAsBytes(List<int>.filled(4096, 7));
      final String saved = await GearPhotoSync.importLocalFile(
        'light-test-1',
        source,
      );
      expect(File(saved).existsSync(), isTrue, reason: '补图文件未落工作区');
      final Map<String, Object?> registry = GearPhotoSync.userRegistry();
      final Map<String, Object?> items = (registry['items'] as Map)
          .cast<String, Object?>();
      expect(items.containsKey('light-test-1'), isTrue, reason: '补图未登记来源');
      final Map<String, Object?> record = (items['light-test-1'] as Map)
          .cast<String, Object?>();
      expect(record['source'], 'user-file');
      expect('${record['at']}'.contains('T'), isTrue);
    });

    late Directory uiTempDir;
    late AppDatabase uiDb;
    late ProviderContainer uiContainer;

    setUp(() async {
      uiTempDir = await Directory.systemTemp.createTemp('ss_gear_ui');
      final Workspace workspace = await Workspace.initAt(uiTempDir.path);
      uiDb = AppDatabase.forTesting(NativeDatabase.memory());
      await ContentPacks.syncToDatabase(uiDb);
      uiContainer = ProviderContainer(
        overrides: <Override>[
          databaseProvider.overrideWithValue(uiDb),
          workspaceProvider.overrideWithValue(workspace),
        ],
      );
    });

    tearDown(() async {
      uiContainer.dispose();
      await uiDb.close();
      if (await uiTempDir.exists()) await uiTempDir.delete(recursive: true);
    });

    testWidgets('资源库底部免责声明（D130/R47）', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1700, 1300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: uiContainer,
          child: const MaterialApp(home: Scaffold(body: GearBrowser())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      // 搜索置空命中集：避免卡片网格在测试视口下触发布局断言，仅验证底部免责声明。
      await tester.enterText(find.byType(TextField).first, 'zzz-无匹配-zzz');
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.textContaining('禁止商用分发'),
        findsWidgets,
        reason: '资源库缺产品图免责声明（R47/D130）',
      );
      expect(kGearPhotoDisclaimer.contains('仅供选型参考'), isTrue);
    });

    testWidgets('缺图条目提供「补图」入口（D130）', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1700, 1300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: uiContainer,
          child: const MaterialApp(home: Scaffold(body: GearBrowser())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      // 切到灯具类并搜索无图条目（覆盖率报告中的缺口项）。
      await tester.tap(find.textContaining('灯具（'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField).first, 'Amaran 60d');
      await tester.pump(const Duration(milliseconds: 300));
      final Finder cardTitle = find.descendant(
        of: find.byType(GridView),
        matching: find.text('Amaran 60d'),
      );
      expect(cardTitle, findsOneWidget, reason: '搜索未命中缺口条目');
      await tester.tap(cardTitle);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('补图'), findsOneWidget, reason: '缺图条目详情应有补图入口');
      await tester.tap(find.text('补图'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('选择本地图片'), findsOneWidget);
      expect(find.text('粘贴图片链接'), findsOneWidget);
      await tester.tap(find.text('粘贴图片链接'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('下载并登记'), findsOneWidget, reason: '链接补图弹窗缺失');
      await tester.tap(find.text('取消'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('下载并登记'), findsNothing);
    });
  });
}
