import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/services/net_router.dart';
import 'package:shoot_studio/services/search/query_planner.dart';
import 'package:shoot_studio/services/search/search_engine.dart';
import 'package:shoot_studio/services/search/search_models.dart';
import 'package:shoot_studio/services/search/sources/anilist_source.dart';
import 'package:shoot_studio/services/search/sources/artic_source.dart';
import 'package:shoot_studio/services/search/sources/artvee_source.dart';
import 'package:shoot_studio/services/search/sources/cleveland_source.dart';
import 'package:shoot_studio/services/search/sources/met_source.dart';
import 'package:shoot_studio/services/search/sources/open_index_source.dart';
import 'package:shoot_studio/services/search/sources/openverse_source.dart';
import 'package:shoot_studio/services/search/sources/pexels_source.dart';
import 'package:shoot_studio/services/search/sources/smk_source.dart';
import 'package:shoot_studio/services/search/sources/tmdb_source.dart';
import 'package:shoot_studio/services/search/sources/vam_source.dart';
import 'package:shoot_studio/services/search/sources/wellcome_source.dart';
import 'package:shoot_studio/services/search/sources/wikiart_source.dart';
import 'package:shoot_studio/services/search/sources/wikimedia_source.dart';
import 'package:shoot_studio/services/search/sources/loc_source.dart';

/// V6 搜索 live 门禁（R58）：默认跳过，本机 `SS_SEARCH_LIVE=1 flutter test` 运行。
/// 覆盖中/英/人名/主题 ≥20 用例，产出 `docs/qa/search-live-*.txt`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bool live = Platform.environment['SS_SEARCH_LIVE'] == '1';

  group('搜索 live 门禁（真实网络）', () {
    late AppDatabase db;
    late SearchEngine engine;
    late QueryPlanner planner;
    final StringBuffer report = StringBuffer();

    setUpAll(() async {
      NetRouter.debugRetriesInTests = true;
      await NetRouter.I.configure(userProxy: '', autoTunnel: true);
      final Map<String, Object?> config =
          jsonDecode(
                File('assets/config/image_sources.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      final Map<String, Object?> pexels =
          (config['pexels'] as Map? ?? <String, Object?>{}).cast();
      final Map<String, Object?> tmdb =
          (config['tmdb'] as Map? ?? <String, Object?>{}).cast();
      engine = SearchEngine(
        sources: <SearchSource>[
          PexelsImageSource('${pexels['apiKey'] ?? ''}'),
          TmdbImageSource(
            apiKey: '${tmdb['apiKey'] ?? ''}',
            readToken: '${tmdb['readToken'] ?? ''}',
          ),
          AniListSource(),
          MetSource(),
          ArticSource(),
          ClevelandSource(),
          VamSource(),
          WikiArtSource(),
          ArtveeSource(),
          OpenverseSource(),
          WikimediaSource(),
          WellcomeSource(),
          SmkSource(),
          LocSource(),
          OpenIndexSource(
            id: 'nga',
            label: '美国国家美术馆',
            asset: 'assets/content/search/open_index/nga.json',
            attributionBase: 'National Gallery of Art',
          ),
          OpenIndexSource(
            id: 'walters',
            label: '沃尔特斯艺术博物馆',
            asset: 'assets/content/search/open_index/walters.json',
            attributionBase: 'Walters Art Museum',
          ),
        ],
      );
      db = AppDatabase.forTesting(NativeDatabase.memory());
      planner = QueryPlanner(db);
      report
        ..writeln('V6 搜索 live 证据')
        ..writeln('时间：${DateTime.now().toIso8601String()}')
        ..writeln('网络通道：${NetRouter.I.modeLabel}')
        ..writeln('');
    });

    tearDownAll(() async {
      await db.close();
      final Directory dir = Directory('../docs/qa');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final String stamp = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-');
      final File file = File('${dir.path}/search-live-$stamp.txt');
      file.writeAsStringSync(report.toString());
      // ignore: avoid_print
      print('证据已写入：${file.path}');
    });

    final List<({String input, ImageDomain domain})> cases =
        <({String input, ImageDomain domain})>[
          (input: '星际穿越', domain: ImageDomain.film),
          (input: 'Interstellar', domain: ImageDomain.film),
          (input: '导演 诺兰', domain: ImageDomain.film),
          (input: '新海诚', domain: ImageDomain.film),
          (input: 'Demon Slayer', domain: ImageDomain.film),
          (input: 'Attack on Titan', domain: ImageDomain.film),
          (input: '雨夜霓虹 天台', domain: ImageDomain.photo),
          (input: 'backlit portrait', domain: ImageDomain.photo),
          (input: '伦勃朗光', domain: ImageDomain.photo),
          (input: 'golden hour couple', domain: ImageDomain.photo),
          (input: 'cyberpunk neon', domain: ImageDomain.photo),
          (input: '赛博 霓虹', domain: ImageDomain.photo),
          (input: '国风 汉服', domain: ImageDomain.photo),
          (input: 'japanese kimono portrait', domain: ImageDomain.photo),
          (input: '梵高 向日葵', domain: ImageDomain.art),
          (input: 'Van Gogh Sunflowers', domain: ImageDomain.art),
          (input: 'Hokusai wave', domain: ImageDomain.art),
          (input: '莫奈 睡莲', domain: ImageDomain.art),
          (input: 'Rembrandt self portrait', domain: ImageDomain.art),
          (input: 'ukiyo-e', domain: ImageDomain.art),
          (input: 'art nouveau poster', domain: ImageDomain.art),
          (input: 'Claude Monet Water Lilies', domain: ImageDomain.art),
        ];

    for (final ({String input, ImageDomain domain}) c in cases) {
      test('live：${c.input}（${c.domain.label}）', () async {
        final SearchQuery query = await planner.plan(c.input, domain: c.domain);
        AggregatedResult? result;
        final List<String> attempts = <String>[];
        for (var attempt = 1; attempt <= 3; attempt++) {
          result = await engine.search(query, perPage: 12, allDomains: true);
          final int ok = result.statuses.where((SourceStatus s) => s.ok).length;
          attempts.add('第 $attempt 次：$ok 源可用 / ${result.hits.length} 条');
          if (result.hits.isNotEmpty) break;
          await Future<void>.delayed(Duration(seconds: 2 * attempt));
        }
        final AggregatedResult r = result!;
        final List<String> lines = <String>[
          '用例：${c.input} [${c.domain.name}] 意图=${query.intent.name} '
              '关键词=${query.text} 来源=${query.sourceNote}',
          for (final SourceStatus s in r.statuses)
            '  - ${s.label}(${s.id}): ${s.summary}',
          '  尝试：${attempts.join('；')}',
          '  命中 ${r.hits.length} 条'
              '${r.hits.isEmpty ? '' : ' · 例：${r.hits.take(3).map((SearchHit h) => '${h.title}@${h.sourceLabel}').join(' | ')}'}',
          '',
        ];
        report.writeln(lines.join('\n'));
        final int okSources = r.statuses.where((SourceStatus s) => s.ok).length;
        expect(okSources, greaterThan(0), reason: '${c.input}：所有源均失败（网络/通道问题）');
        expect(r.hits, isNotEmpty, reason: '${c.input}：无结果');
      }, timeout: const Timeout(Duration(minutes: 3)));
    }

    test('live：V7 新增开放源可达性（证据，部分可达即通过）', () async {
      final SearchQuery query = await planner.plan('monet');
      final List<SearchSource> newSources = <SearchSource>[
        OpenverseSource(),
        WikimediaSource(),
        WellcomeSource(),
        SmkSource(),
        LocSource(),
      ];
      int reachable = 0;
      for (final SearchSource source in newSources) {
        final Stopwatch sw = Stopwatch()..start();
        try {
          final SourceSearchPage page = await source.search(query, perPage: 6);
          sw.stop();
          reachable++;
          report.writeln(
            '新增源 ${source.id}: ${page.hits.length} 条 · ${sw.elapsedMilliseconds}ms'
            '${page.hits.isEmpty ? '' : ' · 例：${page.hits.first.title} / ${page.hits.first.license}'}',
          );
        } catch (e) {
          sw.stop();
          report.writeln(
            '新增源 ${source.id}: 失败 ${sw.elapsedMilliseconds}ms · $e',
          );
        }
      }
      // 内置索引源离线可用性（不依赖网络）。
      final SearchQuery indexQuery = await planner.plan('woman');
      for (final String id in <String>['nga', 'walters']) {
        final OpenIndexSource source = OpenIndexSource(
          id: id,
          label: id,
          asset: 'assets/content/search/open_index/$id.json',
          attributionBase: id,
        );
        final SourceSearchPage page = await source.search(
          indexQuery,
          perPage: 6,
        );
        report.writeln('内置索引 $id: ${page.hits.length} 条');
        expect(page.hits, isNotEmpty, reason: '$id 索引应命中 woman');
      }
      report.writeln('');
      expect(reachable, greaterThan(0), reason: 'V7 新增开放源全部不可达（检查 DoH 隧道/网络）');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }, skip: live ? false : '设置 SS_SEARCH_LIVE=1 后本机运行（R58 live 门禁）');
}
