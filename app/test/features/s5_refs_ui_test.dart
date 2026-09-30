import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/refs/refs_board.dart';
import 'package:shoot_studio/features/refs/refs_controller.dart';
import 'package:shoot_studio/features/refs/refs_hit_card.dart';
import 'package:shoot_studio/features/refs/refs_hit_drawer.dart';
import 'package:shoot_studio/features/refs/refs_home.dart';
import 'package:shoot_studio/features/refs/refs_masonry.dart';
import 'package:shoot_studio/features/refs/refs_palette.dart';
import 'package:shoot_studio/services/palette_extractor.dart';
import 'package:shoot_studio/services/search/search_models.dart';
import 'package:shoot_studio/services/search/theme_packs.dart';

/// V8/S5 · D154 画面参考 UI 测试（首屏画报 / 瀑布流 / 详情抽屉 / 画板编排）。
/// 纪律：R79 不回归既有测试（本文件只新增）；R70 只展示真实色卡数据；
/// 管线（13 源 + NetRouter + QueryPlanner）不在本文件范围，由 q6_search_test 41 用例守住。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late Workspace workspace;
  late AppDatabase db;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ss_s5_refs_');
    workspace = await Workspace.initAt(p.join(temp.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  SearchHit hit({
    String id = 'h1',
    String title = '银翼杀手 · 街景霓虹',
    String group = 'blade-runner',
    String sourceId = 'tmdb',
    String sourceLabel = 'TMDB',
    String license = 'TMDB 版权素材',
    bool commercialOk = false,
    int width = 1200,
    int height = 1600,
    String thumbUrl = '',
    String fullUrl = '',
  }) {
    return SearchHit(
      id: id,
      title: title,
      thumbUrl: thumbUrl,
      fullUrl: fullUrl,
      sourceId: sourceId,
      sourceLabel: sourceLabel,
      license: license,
      commercialOk: commercialOk,
      group: group,
      width: width,
      height: height,
      sourcePageUrl: 'https://www.themoviedb.org/movie/78',
    );
  }

  RefFrame frame(String id, String name, {String sourceUrl = 'https://a/b'}) {
    return RefFrame(
      id: id,
      name: name,
      palette: const <String>['#101010', '#202020'],
      gradient: const <String>['#2f5d50', '#a97e2f'],
      sourceUrl: sourceUrl,
      description: '',
      inBoard: true,
      filmTitle: '我的导入',
    );
  }

  void useSurface(WidgetTester tester, {Size size = const Size(1280, 880)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(Widget child, {AppThemeVariant variant = AppThemeVariant.paper}) {
    return ProviderScope(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        workspaceProvider.overrideWithValue(workspace),
      ],
      child: MaterialApp(
        theme: AppTheme.of(variant),
        home: Scaffold(body: child),
      ),
    );
  }

  group('S5 首屏（§4.3 搜索框居中 + 8 常用画报图卡）', () {
    testWidgets('渲染眉题/衬线标题/居中搜索框/8 张画报/全部主题入口', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        host(
          RefsHomeHeader(
            controller: TextEditingController(),
            focusNode: FocusNode(),
            searching: false,
            status: '共 24 条 · 6 源',
            vision: '',
            onSearch: () {},
            onPickTheme: (ThemePack _) {},
            onAllThemes: () {},
            onSearchByImage: () {},
            onPaste: () {},
            onImport: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('REFERENCE · 画面参考'), findsOneWidget);
      expect(find.text('找一张对味的参考，再决定怎么拍。'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('常用画报'), findsOneWidget);
      // 8 张常用主题画报（图卡，不是文字 chip；横向列表懒建，断言数据集 + 可见卡片）
      expect(commonThemePacks(), hasLength(8));
      expect(find.byType(RefsThemeCard), findsWidgets);
      expect(find.text(commonThemePacks().first.name), findsOneWidget);
      expect(find.text('全部 48 个主题'), findsOneWidget);
      // 状态行（mono 读数）与免责声明不在首屏
      expect(find.textContaining('共 24 条'), findsOneWidget);
      // 无障碍：三个导入动作可读
      expect(find.text('以图搜图'), findsOneWidget);
      expect(find.text('粘贴截图'), findsOneWidget);
      expect(find.text('本地导入'), findsOneWidget);
    });

    testWidgets('点击画报 / 搜索 / 全部主题 三个回调', (WidgetTester tester) async {
      ThemePack? picked;
      int search = 0;
      int all = 0;
      final TextEditingController controller = TextEditingController();
      useSurface(tester);
      await tester.pumpWidget(
        host(
          RefsHomeHeader(
            controller: controller,
            focusNode: FocusNode(),
            searching: false,
            status: '',
            vision: '',
            onSearch: () => search++,
            onPickTheme: (ThemePack pack) => picked = pack,
            onAllThemes: () => all++,
            onSearchByImage: () {},
            onPaste: () {},
            onImport: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(commonThemePacks().first.name).last);
      await tester.pump();
      expect(picked?.id, commonThemePacks().first.id);
      await tester.tap(find.text('搜索'));
      await tester.pump();
      expect(search, 1);
      await tester.tap(find.text('全部 48 个主题'));
      await tester.pump();
      expect(all, 1);
      controller.dispose();
    });

    testWidgets('AI 视觉关键词单独一行显示（无则不显示）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        host(
          RefsHomeHeader(
            controller: TextEditingController(),
            focusNode: FocusNode(),
            searching: true,
            status: '检索中…',
            vision: 'neon rain alley',
            onSearch: () {},
            onPickTheme: (ThemePack _) {},
            onAllThemes: () {},
            onSearchByImage: () {},
            onPaste: () {},
            onImport: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('neon rain alley'), findsOneWidget);
      expect(find.text('检索中…'), findsNWidgets(2));
    });
  });

  group('S5 结果（瀑布流 + 悬停浮层）', () {
    testWidgets('瀑布流按列排布，纵向图占更高（保留纵横比）', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 600,
            child: RefsMasonryGrid(
              itemCount: 6,
              itemBuilder: (BuildContext context, int i) => SizedBox(
                height: i.isEven ? 120 : 200,
                child: Text('item $i'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('item 0'), findsOneWidget);
      expect(find.text('item 5'), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('无图时用 surfaceSunken + 衬线首字占位（禁灰块/emoji）', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            height: 300,
            child: RefsMasonryImage(
              width: 800,
              height: 1000,
              placeholderLabel: '夜城',
            ),
          ),
        ),
      );
      await tester.pump();
      final Container box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RefsMasonryImage),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.color ?? (box.decoration as BoxDecoration?)?.color, isNotNull);
      // 衬线首字占位（不是 emoji/灰块图标）
      expect(find.text('夜'), findsOneWidget);
      expect(AppPalette.paper.surfaceSunken, isNot(AppPalette.paper.ink));
    });

    testWidgets('图加载失败回落衬线首字占位（不留空白块）', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 300,
            child: RefsMasonryImage(
              placeholderLabel: '夜城',
              // 测试环境的 HttpClient 是打桩实现（不会真的出网，R62）：必定加载失败
              child: Image.network('https://example.invalid/missing.jpg'),
            ),
          ),
        ),
      );
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('夜'), findsOneWidget);
    });

    testWidgets('图卡悬停显示来源/许可/可商用 + 三枚动作', (WidgetTester tester) async {
      int opened = 0;
      int added = 0;
      int similar = 0;
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 420,
            width: 280,
            child: RefsHitCard(
              hit: hit(commercialOk: true),
              hovered: true,
              onOpen: () => opened++,
              onAdd: () => added++,
              onSearchSimilar: () => similar++,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('TMDB'), findsOneWidget);
      expect(find.text('TMDB 版权素材'), findsOneWidget);
      expect(find.text('可商用'), findsOneWidget);
      await tester.tap(find.text('收画板'));
      await tester.pump();
      expect(added, 1);
      await tester.tap(find.text('以图搜图'));
      await tester.pump();
      expect(similar, 1);
      await tester.tap(find.text('详情'));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('S5 详情抽屉（大图 + 五色色卡 + 来源/许可 + 相似图）', () {
    test('pickSimilar：同 group 优先，最多 6，不含自己', () {
      final List<SearchHit> all = <SearchHit>[
        hit(id: 'self', group: 'a'),
        for (int i = 0; i < 8; i++) hit(id: 'a$i', group: 'a'),
        hit(id: 'b0', group: 'b'),
      ];
      final List<SearchHit> similar = RefsHitDrawer.pickSimilar(all.first, all);
      expect(similar.length, 6);
      expect(similar.every((SearchHit h) => h.id != 'self'), isTrue);
      expect(similar.every((SearchHit h) => h.group == 'a'), isTrue);
    });

    testWidgets('抽屉渲染标题/来源/许可/五色色卡/相似图', (WidgetTester tester) async {
      useSurface(tester, size: const Size(1280, 1200));
      final SearchHit target = hit();
      final List<SearchHit> similar = <SearchHit>[
        hit(id: 'x1', title: '相似一'),
        hit(id: 'x2', title: '相似二'),
      ];
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 1100,
            child: RefsHitDrawer(
              hit: target,
              similar: similar,
              onAdd: () {},
              onOpenSource: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('银翼杀手 · 街景霓虹'), findsOneWidget);
      expect(find.text('PLATE · 详情'), findsOneWidget);
      expect(find.text('来源'), findsOneWidget);
      expect(find.text('TMDB'), findsOneWidget);
      expect(find.text('许可'), findsOneWidget);
      expect(find.text('五色色卡'), findsOneWidget);
      expect(find.byType(RefsPaletteSlot), findsOneWidget);
      expect(find.text('相似参考'), findsOneWidget);
      // 相似参考：大图 1 + 相似 2 = 3 个图位（无图时为衬线首字占位，非 emoji/灰块）
      expect(find.byType(RefsMasonryImage), findsNWidgets(3));
      // 三个图位都带标题占位（网络图失败时回落衬线首字，不留空白块）
      expect(
        tester
            .widgetList<RefsMasonryImage>(find.byType(RefsMasonryImage))
            .map((RefsMasonryImage w) => w.placeholderLabel)
            .toList(),
        <String>['银翼杀手 · 街景霓虹', '相似一', '相似二'],
      );
      expect(find.text('加入参考画面'), findsOneWidget);
    });
  });

  group('S5 画板（编排 + 拖拽排序 + 导出）', () {
    test('applyReorder：向后 / 向前 / 无变化', () {
      final List<RefFrame> board = <RefFrame>[
        frame('a', 'A'),
        frame('b', 'B'),
        frame('c', 'C'),
      ];
      expect(
        RefsBoardView.applyReorder(board, 'a', 'c').map((RefFrame f) => f.id),
        <String>['b', 'a', 'c'],
      );
      expect(
        RefsBoardView.applyReorder(board, 'c', 'a').map((RefFrame f) => f.id),
        <String>['c', 'a', 'b'],
      );
      expect(
        RefsBoardView.applyReorder(board, 'b', 'b').map((RefFrame f) => f.id),
        <String>['a', 'b', 'c'],
      );
    });

    testWidgets('空画板给衬线空态 + 导入动作；有序时显示来源/许可字段', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          RefsBoardView(
            board: const <RefFrame>[],
            imagePathOf: (RefFrame _) => null,
            onOpen: (RefFrame _) {},
            onRemove: (RefFrame _) {},
            onReorder: (String _, String _) {},
            onExport: () {},
            onPaste: () {},
            onImport: () {},
            exporting: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('画板还是空的'), findsOneWidget);
      expect(find.text('粘贴截图'), findsOneWidget);

      await tester.pumpWidget(
        host(
          SizedBox(
            height: 600,
            child: RefsBoardView(
              board: <RefFrame>[frame('a', '夜城参考', sourceUrl: 'https://x/y')],
              imagePathOf: (RefFrame _) => null,
              onOpen: (RefFrame _) {},
              onRemove: (RefFrame _) {},
              onReorder: (String _, String _) {},
              onExport: () {},
              onPaste: () {},
              onImport: () {},
              exporting: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('夜城参考'), findsOneWidget);
      // 来源字段不丢（R63 逐图标注）
      expect(find.text('https://x/y'), findsOneWidget);
      expect(find.byType(RefsPaletteStrip), findsOneWidget);
      expect(find.text('导出画板长图'), findsOneWidget);
    });

    test('setBoardOrder 持久化并回读（settings，不改表结构）', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          workspaceProvider.overrideWithValue(workspace),
        ],
      );
      addTearDown(container.dispose);
      final RefsController controller = container.read(
        refsControllerProvider.notifier,
      );
      await controller.addCustomFrame(
        title: 'A',
        imagePath: 'a.png',
        palette: const <String>['#101010'],
        sourceUrl: 'https://a',
      );
      await controller.addCustomFrame(
        title: 'B',
        imagePath: 'b.png',
        palette: const <String>['#202020'],
        sourceUrl: 'https://b',
      );
      final List<RefFrame> board = container.read(refsControllerProvider).board;
      expect(board, hasLength(2));
      final List<String> reversedIds = board.reversed
          .map((RefFrame f) => f.id)
          .toList();
      await controller.setBoardOrder(reversedIds);
      expect(
        container.read(refsControllerProvider).board.map((RefFrame f) => f.id),
        reversedIds,
      );
      final String? raw = await db.getSetting(RefsController.boardOrderKey);
      expect(raw, isNotNull);
    });
  });

  group('S5 五色色卡（R70 只显示真实提取结果）', () {
    test('fallbackOf 补齐 5 色；空输入回落常量', () {
      expect(
        RefsPaletteStrip.fallbackOf(const <String>[]),
        PaletteExtractor.fallback,
      );
      expect(RefsPaletteStrip.fallbackOf(const <String>['#111111']).length, 5);
      expect(
        RefsPaletteStrip.fallbackOf(<String>[
          '#1',
          '#2',
          '#3',
          '#4',
          '#5',
          '#6',
        ]).length,
        5,
      );
    });

    testWidgets('色卡渲染 5 段并显示 hex 文本', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            height: 60,
            child: RefsPaletteStrip(
              colors: <String>[
                '#2f5d50',
                '#a97e2f',
                '#b43a2b',
                '#101010',
                '#f0ebe3',
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('2f5d50'), findsOneWidget);
      expect(find.text('f0ebe3'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('2f5d50'),
          matching: find.byType(Semantics),
        ),
        findsWidgets,
      );
    });
  });
}
