import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/services/search/image_to_search.dart';
import 'package:shoot_studio/services/search/keywords.dart';
import 'package:shoot_studio/services/search/query_planner.dart';
import 'package:shoot_studio/services/search/result_ranker.dart';
import 'package:shoot_studio/services/search/search_cache.dart';
import 'package:shoot_studio/services/search/search_engine.dart';
import 'package:shoot_studio/services/search/search_models.dart';
import 'package:shoot_studio/services/search/sources/anilist_source.dart';
import 'package:shoot_studio/services/search/sources/artic_source.dart';
import 'package:shoot_studio/services/search/sources/artvee_source.dart';
import 'package:shoot_studio/services/search/sources/cleveland_source.dart';
import 'package:shoot_studio/services/search/sources/europeana_source.dart';
import 'package:shoot_studio/services/search/sources/harvard_source.dart';
import 'package:shoot_studio/services/search/sources/met_source.dart';
import 'package:shoot_studio/services/search/sources/pexels_source.dart';
import 'package:shoot_studio/services/search/sources/rijks_source.dart';
import 'package:shoot_studio/services/search/sources/smithsonian_source.dart';
import 'package:shoot_studio/services/search/sources/source_utils.dart';
import 'package:shoot_studio/services/search/sources/tmdb_source.dart';
import 'package:shoot_studio/services/search/sources/vam_source.dart';
import 'package:shoot_studio/services/search/sources/wikiart_source.dart';
import 'package:shoot_studio/services/search/theme_packs.dart';

/// V6 搜索重做门禁（D113–D121 / R44–R48）：
/// 意图分类、词表/拼音红线、人名分组、许可筛选、缓存 LRU、主题包、
/// 以图搜图降级、每源状态、全部抓取器离线 fixture 解析。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QueryPlanner 意图分类（D114）', () {
    test('人名/作品/主题规则', () {
      expect(QueryPlanner.classifyIntent('导演 诺兰'), SearchIntent.person);
      expect(QueryPlanner.classifyIntent('演员 张颂文'), SearchIntent.person);
      expect(QueryPlanner.classifyIntent('诺兰的代表作'), SearchIntent.person);
      expect(QueryPlanner.classifyIntent('星际穿越 电影'), SearchIntent.title);
      expect(QueryPlanner.classifyIntent('雨夜霓虹 天台'), SearchIntent.keyword);
      expect(QueryPlanner.extractPerson('导演 诺兰'), '诺兰');
      expect(QueryPlanner.extractPerson('演员：张颂文'), contains('张颂文'));
    });

    test('规划：词表命中 + 英文原文 + 拼音兜底（R46 不发中文）', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final QueryPlanner planner = QueryPlanner(db);
      final SearchQuery table = await planner.plan('雨夜霓虹 天台');
      expect(table.text, contains('rainy night neon'));
      expect(table.text, contains('rooftop'));
      expect(table.sourceNote, contains('内置词表'));

      final SearchQuery ascii = await planner.plan('golden hour portrait');
      expect(ascii.text, 'golden hour portrait');
      expect(ascii.sourceNote, '英文原文');

      final SearchQuery unknown = await planner.plan('完全没收录的词');
      expect(containsCjk(unknown.text), isFalse, reason: 'R46：不得把中文原样发往英文源');
      if (unknown.text.isNotEmpty) {
        expect(hasAsciiQuery(unknown.text), isTrue);
      }
      // 规划结果缓存（第二次命中缓存，不再计算）。
      final SearchQuery cached = await planner.plan('雨夜霓虹 天台');
      expect(cached.text, table.text);
      expect(cached.sourceNote, contains('缓存'));
    });

    test('人名意图：perSource 覆盖 tmdb/anilist（R46）', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final QueryPlanner planner = QueryPlanner(db);
      final SearchQuery query = await planner.plan(
        '导演 诺兰',
        domain: ImageDomain.film,
      );
      expect(query.intent, SearchIntent.person);
      expect(query.person, '诺兰');
      // TMDB 多语源支持中文人名；AniList 英文源必须转拼音。
      expect(query.forSource('tmdb'), '诺兰');
      expect(containsCjk(query.forSource('anilist')), isFalse);
    });

    test('主题包 → 查询（D120）', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final QueryPlanner planner = QueryPlanner(db);
      final ThemePack pack = themePackById('rembrandt')!;
      final SearchQuery query = planner.fromThemePack(pack);
      expect(query.text, contains('rembrandt'));
      expect(query.sourceNote, contains('主题包'));
    });
  });

  group('ResultRanker（合同 §3.C.3）', () {
    SearchHit hit({
      required String id,
      required String url,
      String title = 'Neon night portrait',
      String sourceId = 'pexels',
      bool commercial = true,
      int w = 1200,
      int h = 800,
    }) => SearchHit(
      id: id,
      title: title,
      thumbUrl: url,
      fullUrl: url,
      sourceId: sourceId,
      sourceLabel: sourceId,
      license: commercial ? 'CC0' : '© 版权',
      commercialOk: commercial,
      width: w,
      height: h,
    );

    test('URL/ID 去重 + 匹配分排序', () {
      final List<SearchHit> hits = <SearchHit>[
        hit(id: 'a', url: 'https://x/1.jpg'),
        hit(id: 'b', url: 'https://x/1.jpg?size=big'),
        hit(
          id: 'c',
          url: 'https://y/2.jpg',
          title: 'Rooftop rainy night',
          sourceId: 'tmdb',
        ),
      ];
      final SearchQuery query = const SearchQuery(
        raw: '雨夜霓虹',
        intent: SearchIntent.keyword,
        text: 'rainy night neon',
      );
      final List<SearchHit> ranked = ResultRanker.rank(
        hits,
        query: query,
        commercialOnly: false,
      );
      expect(ranked, hasLength(2), reason: '同 URL 仅保留一条');
      // 文本命中 rainy night 的条目应排在前面（标题匹配加分）。
      expect(ranked.first.id, 'c');
    });

    test('仅可商用过滤（D117）', () {
      final List<SearchHit> hits = <SearchHit>[
        hit(
          id: 'a',
          url: 'https://x/a.jpg',
          title: 'Free portrait',
          commercial: true,
        ),
        hit(
          id: 'b',
          url: 'https://x/b.jpg',
          title: 'Copyrighted portrait',
          commercial: false,
        ),
      ];
      const SearchQuery query = SearchQuery(
        raw: 'q',
        intent: SearchIntent.keyword,
        text: 'portrait',
      );
      expect(
        ResultRanker.rank(hits, query: query, commercialOnly: true),
        hasLength(1),
      );
      expect(
        ResultRanker.rank(hits, query: query, commercialOnly: false),
        hasLength(2),
      );
    });

    test('感知哈希：dHash 稳定 + 汉明距离', () {
      // 左亮右暗渐变 → 固定哈希；纯色 → 0。
      final Uint8List gradient = Uint8List(16 * 8);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 16; x++) {
          gradient[y * 16 + x] = x < 8 ? 200 : 50;
        }
      }
      final int a = ResultRanker.dHash(gradient, 16, 8);
      final int b = ResultRanker.dHash(gradient, 16, 8);
      expect(a, b);
      expect(ResultRanker.hammingDistance(a, b), 0);
      final Uint8List flat = Uint8List(16 * 8)..fillRange(0, 16 * 8, 128);
      final int flatHash = ResultRanker.dHash(flat, 16, 8);
      expect(flatHash, 0);
      expect(ResultRanker.hammingDistance(a, flatHash), greaterThan(0));
    });

    test('感知哈希去重（近重复仅留一条）', () {
      final List<SearchHit> hits = <SearchHit>[
        hit(id: 'a', url: 'https://x/a.jpg'),
        hit(id: 'b', url: 'https://x/b.jpg'),
      ];
      final List<SearchHit> deduped = ResultRanker.dedupeByHash(
        hits,
        <String, int>{'a': 0xAAAA, 'b': 0xAAAA ^ 0x3},
        maxDistance: 6,
      );
      expect(deduped, hasLength(1));
    });

    test('许可判定（CC0/PD 可商用，NC 不可）', () {
      expect(isCommercialLicense('CC0 1.0'), isTrue);
      expect(isCommercialLicense('Public Domain'), isTrue);
      expect(isCommercialLicense('CC BY-SA 4.0'), isTrue);
      expect(isCommercialLicense('CC BY-NC 4.0'), isFalse);
      expect(isCommercialLicense('© 艺术家（非商用）'), isFalse);
    });
  });

  group('SearchEngine 聚合与每源状态（R45）', () {
    test('并发聚合 + 失败源状态 + 跳过禁用源', () async {
      final SearchEngine engine = SearchEngine(
        sources: <SearchSource>[
          _FakeSource(id: 'ok1', hits: <SearchHit>[_fakeHit('ok1', 'a')]),
          _FakeSource(id: 'ok2', hits: <SearchHit>[_fakeHit('ok2', 'b')]),
          _FakeSource(id: 'bad', error: 'offline'),
          _DisabledSource(),
        ],
      );
      final AggregatedResult result = await engine.search(
        const SearchQuery(
          raw: 'q',
          intent: SearchIntent.keyword,
          text: 'portrait',
        ),
      );
      expect(result.hits, hasLength(2));
      expect(result.okSources, 2);
      expect(result.failedSources, 1);
      final SourceStatus disabled = result.statuses.firstWhere(
        (SourceStatus s) => s.id == 'disabled',
      );
      expect(disabled.enabled, isFalse);
      expect(disabled.hint, isNotEmpty);
      final SourceStatus failed = result.statuses.firstWhere(
        (SourceStatus s) => s.id == 'bad',
      );
      expect(failed.ok, isFalse);
      expect(failed.error, contains('offline'));
    });

    test('人名结果按作品分组（D114）', () async {
      final SearchEngine engine = SearchEngine(
        sources: <SearchSource>[
          _FakeSource(
            id: 'tmdb',
            hits: <SearchHit>[
              _fakeHit('tmdb', 'a', group: '星际穿越'),
              _fakeHit('tmdb', 'b', group: '星际穿越'),
              _fakeHit('tmdb', 'c', group: '盗梦空间'),
            ],
          ),
        ],
      );
      final AggregatedResult result = await engine.search(
        const SearchQuery(
          raw: '导演 诺兰',
          intent: SearchIntent.person,
          text: '',
          person: '诺兰',
          domain: ImageDomain.film,
        ),
      );
      final Map<String, List<SearchHit>> groups = result.groupedByWork;
      expect(groups.keys, containsAll(<String>['星际穿越', '盗梦空间']));
      expect(groups['星际穿越'], hasLength(2));
    });
  });

  group('主题包（D120）', () {
    test('数量 ≥20、字段完整、英文词无中文（R46）', () {
      expect(kThemePacks.length, greaterThanOrEqualTo(20));
      for (final ThemePack pack in kThemePacks) {
        expect(pack.name, isNotEmpty);
        expect(pack.description, isNotEmpty);
        expect(pack.enQuery, isNotEmpty);
        expect(
          containsCjk(pack.enQuery),
          isFalse,
          reason: '${pack.id} 的检索词不得含中文',
        );
        expect(pack.zhTerms, isNotEmpty);
      }
      expect(themePackById('cyber-neon')?.enQuery, contains('cyberpunk'));
      expect(themePackById('nope'), isNull);
    });
  });

  group('SearchCache 5GB LRU（D118/R47）', () {
    test('写入/命中/LRU 淘汰/清空', () async {
      final Directory dir = await Directory.systemTemp.createTemp('ss_cache');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final SearchCache cache = SearchCache(dir.path, limitMb: 1);
      final Uint8List chunk = Uint8List(600 * 1024)
        ..fillRange(0, 600 * 1024, 7);
      await cache.put('https://x/1.jpg', chunk);
      await cache.put('https://x/2.jpg', chunk);
      // 1MB 上限：第二张写入后应淘汰最旧的 1.jpg。
      expect(await cache.get('https://x/1.jpg'), isNull);
      expect(await cache.get('https://x/2.jpg'), isNotNull);
      expect(await cache.totalBytes(), lessThanOrEqualTo(1024 * 1024));
      await cache.clear();
      expect(await cache.totalBytes(), 0);
      expect(await cache.get('https://x/2.jpg'), isNull);
    });

    test('原图/缩略图分目录（同 URL 不同 kind）', () async {
      final Directory dir = await Directory.systemTemp.createTemp('ss_cache2');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final SearchCache cache = SearchCache(dir.path, limitMb: 10);
      await cache.put(
        'https://x/a.jpg',
        Uint8List.fromList(<int>[1, 2, 3]),
        original: false,
      );
      await cache.put(
        'https://x/a.jpg',
        Uint8List.fromList(<int>[4, 5, 6]),
        original: true,
      );
      expect(await cache.get('https://x/a.jpg'), isNotNull);
      expect(await cache.get('https://x/a.jpg', original: true), isNotNull);
      expect(
        Directory(
          '${dir.path}${Platform.pathSeparator}cache'
          '${Platform.pathSeparator}search'
          '${Platform.pathSeparator}thumb',
        ).existsSync(),
        isTrue,
      );
      expect(
        Directory(
          '${dir.path}${Platform.pathSeparator}cache'
          '${Platform.pathSeparator}search'
          '${Platform.pathSeparator}orig',
        ).existsSync(),
        isTrue,
      );
    });
  });

  group('以图搜图降级（D96/D116）', () {
    test('未配置 AI：返回失败原因而不是静默失败', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ImageToSearch service = ImageToSearch(db);
      final VisionResult result = await service.describe(
        Uint8List.fromList(<int>[1, 2, 3]),
      );
      expect(result.success, isFalse);
      expect(result.needsConfiguration, isTrue);
      expect(result.error, contains('未配置'));
    });

    test('视觉输出解析：描述 + KEYWORDS 行', () {
      final (String desc, String kw) = ImageToSearch.debugSplit(
        '冷调侧光人像，背景深蓝。\nKEYWORDS: cold blue portrait side light',
      );
      expect(desc, contains('冷调侧光'));
      expect(kw, 'cold blue portrait side light');
    });
  });

  group('图源解析 fixture（R48：CI 不依赖外网）', () {
    test('TMDB：作品/人名分组/剧照/分集', () {
      final List<TmdbWork> works = TmdbImageSource.parseSearch(
        <String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'id': 1,
              'media_type': 'movie',
              'title': '星际穿越',
              'release_date': '2014-11-05',
              'poster_path': '/p.jpg',
              'popularity': 90,
            },
          ],
        },
      );
      expect(works.single.title, '星际穿越');
      expect(works.single.year, '2014');

      final List<TmdbWork> credits = TmdbImageSource.parseCredits(
        <String, Object?>{
          'cast': <Object?>[
            <String, Object?>{
              'id': 2,
              'media_type': 'movie',
              'title': '盗梦空间',
              'release_date': '2010-07-16',
              'poster_path': '/i.jpg',
              'popularity': 80,
            },
          ],
          'crew': <Object?>[
            <String, Object?>{
              'id': 2,
              'media_type': 'movie',
              'title': '盗梦空间',
              'popularity': 80,
            },
          ],
        },
      );
      expect(credits, hasLength(1), reason: 'cast/crew 同一作品去重');

      final TmdbWork work = TmdbWork(
        id: 1,
        mediaType: 'movie',
        title: '星际穿越',
        year: '2014',
      );
      final List<SearchHit> stills = TmdbImageSource.parseImages(
        <String, Object?>{
          'backdrops': <Object?>[
            <String, Object?>{
              'file_path': '/still.jpg',
              'width': 1920,
              'height': 1080,
            },
          ],
        },
        work: work,
      );
      expect(stills.single.fullUrl, contains('w1280'));
      expect(stills.single.group, '星际穿越');
      expect(stills.single.commercialOk, isFalse);

      final List<SearchHit> episodes = TmdbImageSource.parseEpisodeStills(
        <String, Object?>{
          'episodes': <Object?>[
            <String, Object?>{'episode_number': 3, 'still_path': '/e3.jpg'},
          ],
        },
        work: work,
      );
      expect(episodes.single.title, contains('第 3 集'));
    });

    test('Pexels：可商用 + 作者署名', () {
      final List<SearchHit> hits = PexelsImageSource.parsePhotos(
        <String, Object?>{
          'photos': <Object?>[
            <String, Object?>{
              'alt': 'rainy night',
              'photographer': '张三',
              'src': <String, Object?>{
                'medium': 'https://p/m.jpg',
                'large2x': 'https://p/l.jpg',
              },
              'width': 1200,
              'height': 800,
            },
          ],
        },
      );
      expect(hits.single.commercialOk, isTrue);
      expect(hits.single.attribution, contains('张三'));
      expect(hits.single.thumbUrl, 'https://p/m.jpg');
    });

    test('大都会：公有领域标记 + objectID 解析', () {
      expect(
        MetSource.parseSearch(<String, Object?>{
          'objectIDs': <Object?>[10, 20, null],
        }),
        <int>[10, 20],
      );
      final SearchHit? pd = MetSource.parseObject(<String, Object?>{
        'objectID': 10,
        'title': 'Sunflowers',
        'artistDisplayName': 'Van Gogh',
        'primaryImage': 'https://met/full.jpg',
        'primaryImageSmall': 'https://met/small.jpg',
        'isPublicDomain': true,
        'objectURL': 'https://met/10',
      });
      expect(pd!.commercialOk, isTrue);
      expect(pd.license, contains('CC0'));
      final SearchHit? copyright = MetSource.parseObject(<String, Object?>{
        'objectID': 11,
        'title': 'Modern',
        'primaryImage': 'https://met/m.jpg',
        'isPublicDomain': false,
      });
      expect(copyright!.commercialOk, isFalse);
    });

    test('芝加哥：IIIF 链接 + 分页', () {
      final ArticPage page = ArticSource.parse(<String, Object?>{
        'config': <String, Object?>{'iiif_url': 'https://www.artic.edu/iiif/2'},
        'pagination': <String, Object?>{'current_page': 1, 'total_pages': 3},
        'data': <Object?>[
          <String, Object?>{
            'id': 5,
            'title': 'Water Lilies',
            'image_id': 'abc-123',
            'is_public_domain': true,
            'artist_display': 'Monet',
          },
        ],
      });
      expect(page.hasMore, isTrue);
      expect(
        page.hits.single.fullUrl,
        contains('https://www.artic.edu/iiif/2/abc-123/full/'),
      );
      expect(page.hits.single.commercialOk, isTrue);
    });

    test('克利夫兰：CC0 判定 + creators 解析', () {
      final List<SearchHit> hits = ClevelandSource.parse(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'c1',
            'title': 'Portrait',
            'share_license_status': 'CC0',
            'creators': <Object?>[
              <String, Object?>{'description': 'Rembrandt'},
            ],
            'images': <String, Object?>{
              'web': <String, Object?>{'url': 'https://cma/web.jpg'},
              'print': <String, Object?>{'url': 'https://cma/print.jpg'},
            },
            'url': 'https://cma/c1',
          },
        ],
      });
      expect(hits.single.commercialOk, isTrue);
      expect(hits.single.attribution, contains('Rembrandt'));
    });

    test('V&A：IIIF base 拼接 + 非商用标注', () {
      final List<SearchHit> hits = VamSource.parse(<String, Object?>{
        'records': <Object?>[
          <String, Object?>{
            'systemNumber': 'O1',
            '_primaryTitle': 'Teapot',
            '_primaryMaker': <String, Object?>{'name': 'Wedgwood'},
            '_images': <String, Object?>{
              '_iiif_image_base_url':
                  'https://framemark.vam.ac.uk/collections/O1/',
              '_primary_thumbnail': 'https://vam/thumb.jpg',
            },
          },
        ],
      });
      expect(hits.single.fullUrl, contains('framemark.vam.ac.uk'));
      expect(hits.single.commercialOk, isFalse);
      expect(hits.single.sourcePageUrl, contains('collections.vam.ac.uk'));
    });

    test('AniList：media/staff 解析 + 作品分组', () {
      final List<SearchHit> media = AniListSource.parseMedia(<String, Object?>{
        'pageInfo': <String, Object?>{'hasNextPage': true},
        'media': <Object?>[
          <String, Object?>{
            'id': 1,
            'title': <String, Object?>{
              'romaji': 'Kimetsu no Yaiba',
              'english': 'Demon Slayer',
            },
            'coverImage': <String, Object?>{
              'large': 'https://anilist/cover.jpg',
              'extraLarge': 'https://anilist/cover-xl.jpg',
            },
            'bannerImage': 'https://anilist/banner.jpg',
            'startDate': <String, Object?>{'year': 2019},
            'siteUrl': 'https://anilist.co/anime/1',
          },
        ],
      });
      expect(media.single.title, contains('Demon Slayer'));
      expect(media.single.fullUrl, 'https://anilist/banner.jpg');
      expect(media.single.imageType, 'still');

      final List<SearchHit> staff = AniListSource.parseStaff(<String, Object?>{
        'staffMedia': <String, Object?>{
          'nodes': <Object?>[
            <String, Object?>{
              'id': 2,
              'title': <String, Object?>{'romaji': 'Fate/Zero'},
              'coverImage': <String, Object?>{'large': 'https://anilist/f.jpg'},
              'siteUrl': 'https://anilist.co/anime/2',
            },
          ],
        },
      });
      expect(staff.single.group, 'Fate/Zero');
    });

    test('WikiArt：JSON 容错（数组与 Paintings 包裹）', () {
      final List<SearchHit> hits = WikiArtSource.parse('''
[{"title":"Irises","artistName":"Van Gogh","image":"https://uploads.wikiart.org/i.jpg!Large.jpg","url":"/en/vincent-van-gogh/irises","width":1000,"height":800}]
''');
      expect(hits.single.title, 'Irises');
      expect(hits.single.fullUrl, 'https://uploads.wikiart.org/i.jpg');
      expect(WikiArtSource.parse('not json'), isEmpty);
      expect(
        WikiArtSource.parse(
          '{"Paintings":[{"title":"A","image":"https://x/a.jpg"}]}',
        ),
        hasLength(1),
      );
    });

    test('Artvee：HTML 图片/链接/标题提取', () {
      final String html = '''
<html><body>
<div class="product-wrapper">
  <h2 class="product-title"><a href="https://artvee.com/dl/iris/">Iris</a></h2>
  <a href="https://artvee.com/dl/iris/">
    <img src="https://artvee.com/wp-content/uploads/2020/01/iris-300x400.jpg" />
  </a>
</div>
<div class="product-wrapper">
  <h2 class="product-title">Poppy</h2>
  <a href="https://artvee.com/dl/poppy/">
    <img src="https://artvee.com/wp-content/uploads/2020/01/poppy.jpg" />
  </a>
</div>
</body></html>''';
      final List<SearchHit> hits = ArtveeSource.parse(html);
      expect(hits, hasLength(2));
      expect(hits.first.commercialOk, isTrue);
      expect(hits.first.fullUrl, isNot(contains('300x400')));
      expect(hits[1].title, 'Poppy');
      expect(ArtveeSource.parse(''), isEmpty);
    });

    test('Europeana：rights 许可判定 + edmPreview', () {
      final List<SearchHit> hits = EuropeanaSource.parse(<String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': '/e1',
            'title': <Object?>['Mona Lisa'],
            'dcCreator': <Object?>['Leonardo'],
            'edmPreview': <Object?>['https://e/thumb.jpg'],
            'edmIsShownBy': <Object?>['https://e/full.jpg'],
            'rights': <Object?>[
              'http://creativecommons.org/publicdomain/zero/1.0/',
            ],
            'guid': 'https://e/guid',
          },
        ],
      });
      expect(hits.single.commercialOk, isTrue);
      expect(hits.single.attribution, contains('Leonardo'));
    });

    test('Smithsonian：media usage CC0', () {
      final List<SearchHit> hits = SmithsonianSource.parse(<String, Object?>{
        'rows': <Object?>[
          <String, Object?>{
            'id': 's1',
            'title': 'Quilt',
            'content': <String, Object?>{
              'descriptiveNonRepeating': <String, Object?>{
                'record_link': 'https://si/s1',
                'unit_code': 'NMAH',
                'online_media': <String, Object?>{
                  'media': <Object?>[
                    <String, Object?>{
                      'content': 'https://si/full.jpg',
                      'thumbnail': 'https://si/thumb.jpg',
                      'usage': <String, Object?>{'access': 'CC0'},
                    },
                  ],
                },
              },
            },
          },
        ],
      });
      expect(hits.single.commercialOk, isTrue);
    });

    test('Harvard：imagepermissionlevel==0 开放', () {
      final List<SearchHit> hits = HarvardSource.parse(<String, Object?>{
        'records': <Object?>[
          <String, Object?>{
            'id': 1,
            'title': 'Buddha',
            'primaryimageurl': 'https://hv/full.jpg',
            'imagepermissionlevel': 0,
            'people': <Object?>[
              <String, Object?>{'name': 'Unknown'},
            ],
            'url': 'https://hv/1',
          },
        ],
      });
      expect(hits.single.commercialOk, isTrue);
      expect(hits.single.attribution, contains('Unknown'));
    });

    test('Rijks：webImage 解析 + 保守许可', () {
      final List<SearchHit> hits = RijksSource.parse(<String, Object?>{
        'artObjects': <Object?>[
          <String, Object?>{
            'objectNumber': 'SK-A-1',
            'title': 'The Night Watch',
            'principalOrFirstMaker': 'Rembrandt',
            'webImage': <String, Object?>{
              'url': 'https://rijks/full.jpg',
              'width': 2000,
              'height': 1600,
            },
            'links': <String, Object?>{'web': 'https://rijks/SK-A-1'},
          },
        ],
      });
      expect(hits.single.width, 2000);
      expect(hits.single.commercialOk, isFalse);
    });
  });

  group('关键词与拼音兜底（R46）', () {
    test('translateToEnglish：词表 → 拼音 → 空', () {
      expect(translateToEnglish('赛博'), contains('cyberpunk'));
      expect(translateToEnglish('golden hour'), contains('golden hour'));
      final String pinyin = toPinyin('雨夜');
      expect(pinyin, 'yu ye');
      expect(containsCjk(toPinyin('雨夜霓虹')), isFalse);
      expect(
        translateToEnglish('完全没收录的词').contains(RegExp(r'[\u4e00-\u9fff]')),
        isFalse,
      );
    });

    test('拼音字典规模与抽查', () {
      expect(kPinyinDict.length, greaterThan(500));
      expect(kPinyinDict['雨'], 'yu');
      expect(kPinyinDict['夜'], 'ye');
    });
  });
}

SearchHit _fakeHit(String source, String id, {String group = ''}) => SearchHit(
  id: '$source:$id',
  title: 'hit $id',
  thumbUrl: 'https://x/$source-$id.jpg',
  fullUrl: 'https://x/$source-$id.jpg',
  sourceId: source,
  sourceLabel: source,
  license: 'CC0',
  commercialOk: true,
  group: group,
  domain: ImageDomain.film,
);

class _FakeSource implements SearchSource {
  _FakeSource({
    required this.id,
    this.hits = const <SearchHit>[],
    this.error = '',
  });

  @override
  final String id;
  final List<SearchHit> hits;
  final String error;

  @override
  String get label => id;
  @override
  SourceCapability get capability => const SourceCapability(
    domains: <ImageDomain>{ImageDomain.film, ImageDomain.photo},
  );
  @override
  bool get enabled => true;
  @override
  String get disabledHint => '';
  @override
  Future<SourceSearchPage> search(
    SearchQuery query, {
    int page = 1,
    int perPage = 24,
  }) async {
    if (error.isNotEmpty) throw StateError(error);
    return SourceSearchPage(hits: hits, hasMore: false);
  }
}

class _DisabledSource implements SearchSource {
  @override
  String get id => 'disabled';
  @override
  String get label => '未启用源';
  @override
  SourceCapability get capability => const SourceCapability(
    domains: <ImageDomain>{ImageDomain.film, ImageDomain.photo},
  );
  @override
  bool get enabled => false;
  @override
  String get disabledHint => '缺 Key（设置 → 图片素材通道）';
  @override
  Future<SourceSearchPage> search(
    SearchQuery query, {
    int page = 1,
    int perPage = 24,
  }) async => const SourceSearchPage(hits: <SearchHit>[], hasMore: false);
}
