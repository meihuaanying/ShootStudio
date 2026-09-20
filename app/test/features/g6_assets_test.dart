import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'package:shoot_studio/services/image_sources.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data) => ResponseBody.fromString(
  jsonEncode(data),
  200,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('G6 设备库', () {
    test('≥400 条（灯具 ≥150）且每条有图/标签/别名，图片文件齐全', () async {
      final List<GearEntry> gear = await ContentPacks.gear();
      expect(gear.length, greaterThanOrEqualTo(400));
      final int lights = gear.where((GearEntry g) => g.kind == 'light').length;
      expect(lights, greaterThanOrEqualTo(150), reason: '灯具不足 150');
      for (final GearEntry g in gear) {
        expect(g.image.isNotEmpty, isTrue, reason: '${g.displayName} 缺图片');
        final File file = File('assets/content/gear/img/${g.image}');
        expect(file.existsSync(), isTrue, reason: '${g.image} 不存在');
        expect(g.tags.isNotEmpty, isTrue, reason: '${g.displayName} 缺标签');
        expect(g.aliases.isNotEmpty, isTrue, reason: '${g.displayName} 缺别名');
      }
    });

    test('规格/别名搜索语义：焦段/光圈/灯型/中文别名都能命中', () async {
      final List<GearEntry> gear = await ContentPacks.gear();
      List<GearEntry> match(String q) {
        final List<String> tokens = q
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((String t) => t.isNotEmpty)
            .toList();
        return gear
            .where(
              (GearEntry g) =>
                  tokens.every((String t) => g.searchText.contains(t)),
            )
            .toList();
      }

      expect(match('F2.8').isNotEmpty, isTrue);
      expect(match('35mm F1.4').isNotEmpty, isTrue);
      expect(match('全画幅').isNotEmpty, isTrue);
      expect(match('常亮灯').isNotEmpty, isTrue);
      expect(match('闪光灯').isNotEmpty, isTrue);
      expect(match('lens').isNotEmpty, isTrue);
      expect(match('镜头').isNotEmpty, isTrue);
    });

    test('自定义设备可写入 gearItems 表（builtin=false）', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.gearItems)
          .insert(
            GearItemsCompanion.insert(
              id: 'custom-test',
              kind: 'camera',
              brand: '测试',
              model: '自定义机身',
              specsJson: const Value('{"type":"自定义"}'),
              builtin: const Value(false),
            ),
          );
      final List<GearItem> rows = await db.select(db.gearItems).get();
      expect(rows.single.id, 'custom-test');
      expect(rows.single.builtin, isFalse);
    });
  });

  group('G6 素材许可', () {
    test('attribution.json 中每个文件存在且许可在白名单', () async {
      final File f = File('assets/content/attribution.json');
      expect(f.existsSync(), isTrue);
      final Map<String, Object?> data =
          (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
      for (final Object? raw
          in data['items'] as List<Object?>? ?? <Object?>[]) {
        final Map<String, Object?> item = (raw as Map).cast<String, Object?>();
        final String file = '${item['file']}';
        // V4/D73：产品图分内置（Top100）与运行时同步两类；非内置仅在
        // 登记表保留来源与许可（文件不入包，运行时抓取缓存到工作区）。
        final bool bundled = item['builtin'] != false;
        if (bundled) {
          expect(File(file).existsSync(), isTrue, reason: '$file 缺失');
        } else {
          expect(
            '${item['source']}'.isNotEmpty,
            isTrue,
            reason: '$file 非内置条目缺来源',
          );
        }
        final String license = '${item['license']}';
        expect(
          license.contains('CC0') ||
              license.contains('CC BY') ||
              license.toLowerCase().contains('public domain') ||
              license.contains('Pexels License') ||
              license.contains('TMDB'),
          isTrue,
          reason: '许可不合规：$license',
        );
      }
    });
  });

  group('G6 智能搜图', () {
    test('中文关键词翻译：多词拼接 + 保留英文 + 未命中不再原样发中文', () {
      final String kw = translateSceneToKeywords('雨夜霓虹 双人 天台');
      expect(kw.contains('rainy night neon'), isTrue);
      expect(kw.contains('neon lights'), isTrue);
      expect(kw.contains('couple'), isTrue);
      expect(kw.contains('rooftop'), isTrue);
      expect(translateSceneToKeywords('portrait 逆光'), contains('backlight'));
      expect(translateSceneToKeywords(''), '');
      // V5/R33：纯中文未命中词表 → 空串（交由 AI 兜底），不再原样发往外网。
      expect(translateSceneToKeywords('星际穿越'), '');
      expect(needsAiTranslate('星际穿越'), isTrue);
      expect(needsAiTranslate('rainy night'), isFalse);
      expect(hasAsciiQuery('rainy night neon'), isTrue);
      expect(hasAsciiQuery('星际穿越'), isFalse);
      // V5：词表扩充（200+）抽查。
      expect(kSceneKeywordMap.length, greaterThanOrEqualTo(200));
      expect(translateSceneToKeywords('芭蕾 舞者'), contains('ballet dancer'));
      expect(translateSceneToKeywords('大都会'), '');
    });

    test('Openverse 源解析（免 key，实验性标记）', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _Adapter((RequestOptions o) async {
          expect('${o.uri}', contains('api.openverse.org'));
          return _json(<String, Object?>{
            'result_count': 42,
            'results': <Object?>[
              <String, Object?>{
                'title': 'Neon street',
                'thumbnail': 'https://x/thumb.jpg',
                'url': 'https://x/full.jpg',
                'license': 'cc0',
                'license_version': '1.0',
                'creator': 'Tester',
                'width': 1200,
                'height': 800,
              },
            ],
          });
        });
      final OpenverseSource source = OpenverseSource(dio: dio);
      expect(source.experimental, isTrue);
      final SourcePage page = await source.search('neon');
      expect(page.hits, hasLength(1));
      expect(page.hits.first.license, 'cc0 1.0');
      expect(page.hits.first.source, 'Openverse');
      expect(page.hasMore, isTrue);
    });

    test('Pexels/TMDB 需要 Key 并正确携带鉴权/解析/分页', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _Adapter((RequestOptions o) async {
          if ('${o.uri}'.contains('pexels.com')) {
            expect('${o.headers['Authorization']}', 'pk-test');
            expect('${o.uri}', contains('page=2'));
            return _json(<String, Object?>{
              'total_results': 500,
              'photos': <Object?>[
                <String, Object?>{
                  'alt': '雨夜',
                  'photographer': '张三',
                  'src': <String, Object?>{
                    'medium': 'https://p/medium.jpg',
                    'large2x': 'https://p/large.jpg',
                  },
                },
              ],
            });
          }
          return _json(<String, Object?>{
            'total_pages': 3,
            'results': <Object?>[
              <String, Object?>{
                'title': 'Movie',
                'poster_path': '/p.jpg',
                'release_date': '2024-01-01',
              },
            ],
          });
        });
      final SourcePage pexels = await PexelsSource(
        'pk-test',
        dio: dio,
      ).search('rain', page: 2);
      expect(pexels.hits.single.source, 'Pexels');
      expect(pexels.hits.single.fullUrl, contains('large.jpg'));
      expect(pexels.hasMore, isTrue);
      final SourcePage tmdb = await TmdbSource(
        'tmdb-test',
        dio: dio,
      ).search('movie');
      expect(tmdb.hits.single.fullUrl, contains('image.tmdb.org'));
      expect(tmdb.hasMore, isTrue);
      // 缺 Key 的源被禁用并给出提示（R32）。
      expect(PexelsSource('').enabled, isFalse);
      expect(PexelsSource('').disabledHint, isNotEmpty);
    });

    test('聚合：去重、按源容错、每源状态与耗时', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _Adapter((RequestOptions o) async {
          if ('${o.uri}'.contains('openverse')) {
            return _json(<String, Object?>{
              'results': <Object?>[
                <String, Object?>{
                  'title': 'dup',
                  'url': 'https://x/same.jpg',
                  'thumbnail': 'https://x/same.jpg',
                  'license': 'cc0',
                },
              ],
            });
          }
          throw DioException(requestOptions: o, message: 'offline');
        });
      final SmartImageSearch search = SmartImageSearch(
        sources: <ImageSource>[
          OpenverseSource(dio: dio),
          PexelsSource('bad-key', dio: dio),
        ],
      );
      final SmartSearchResult result = await search.search('雨夜');
      expect(result.hits, hasLength(1));
      expect(result.statuses, hasLength(2));
      final SourceStatus ok = result.statuses.firstWhere(
        (SourceStatus s) => s.id == 'openverse',
      );
      expect(ok.ok, isTrue);
      expect(ok.count, 1);
      final SourceStatus failed = result.statuses.firstWhere(
        (SourceStatus s) => s.id == 'pexels',
      );
      expect(failed.ok, isFalse);
      expect(failed.error, contains('offline'));
      expect(failed.elapsedMs, greaterThanOrEqualTo(0));
      expect(result.failedSources, 1);
    });
  });
}
