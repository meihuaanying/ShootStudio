import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'package:shoot_studio/services/net.dart';
import 'package:shoot_studio/services/tmdb_source.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      handler(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data) =>
    ResponseBody.fromString(jsonEncode(data), 200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType]
        });

/// V3 硬门禁：真实素材可溯源、3D 人物契约、QA 产物、TMDB 双鉴权。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object?> attributionIndex() {
    final Map<String, Object?> data =
        (jsonDecode(File('assets/content/attribution.json').readAsStringSync())
                as Map)
            .cast<String, Object?>();
    return <String, Object?>{
      for (final Object? item in data['items'] as List<Object?>? ?? <Object?>[])
        if (item is Map) '${item['file']}': item,
    };
  }

  test('R11/R12：PD 静帧全部存在、可溯源且有署名', () async {
    final Map<String, Object?> stills = await ContentPacks.pdStills();
    final List<Object?> films =
        stills['films'] as List<Object?>? ?? <Object?>[];
    expect(films.length, greaterThanOrEqualTo(6));
    final Map<String, Object?> attr = attributionIndex();
    var frames = 0;
    for (final Object? film in films) {
      expect(film, isA<Map>());
      final List<Object?> list =
          (film as Map)['frames'] as List<Object?>? ?? <Object?>[];
      expect(list.isNotEmpty, isTrue, reason: '${(film)['title']} 无静帧');
      for (final Object? frame in list) {
        final Map<Object?, Object?> f = frame as Map<Object?, Object?>;
        final String path = 'assets/content/stills/pd/${f['file']}';
        expect(File(path).existsSync(), isTrue, reason: '$path 缺失');
        expect(attr.containsKey(path), isTrue, reason: '$path 未署名');
        frames++;
      }
    }
    expect(frames, greaterThanOrEqualTo(24));
  });

  test('R15：人物清单 ≥12、发型 ≥6，GLB/署名齐全且体积合规', () async {
    final Map<String, Object?> manifest =
        await ContentPacks.charactersManifest();
    final List<Object?> chars =
        manifest['characters'] as List<Object?>? ?? <Object?>[];
    final List<Object?> hair =
        manifest['hair'] as List<Object?>? ?? <Object?>[];
    expect(chars.length, greaterThanOrEqualTo(12));
    expect(hair.length, greaterThanOrEqualTo(6));
    final Map<String, Object?> attr = attributionIndex();
    for (final Object? c in chars) {
      final Map<Object?, Object?> m = c as Map<Object?, Object?>;
      final String path = 'assets/models/characters/${m['file']}';
      final File f = File(path);
      expect(f.existsSync(), isTrue, reason: '$path 缺失');
      expect(f.lengthSync(), lessThanOrEqualTo(8 * 1024 * 1024));
      expect(attr.containsKey(path), isTrue, reason: '$path 未署名');
      expect('${m['license']}', contains('CC'), reason: '许可不合规');
    }
    for (final Object? h in hair) {
      final Map<Object?, Object?> m = h as Map<Object?, Object?>;
      expect(
        File('assets/models/characters/${m['file']}').existsSync(),
        isTrue,
        reason: '${m['file']} 缺失',
      );
    }
  });

  test('R16：逐条姿势 QA 截图 ≥250 且 golden ≥40', () {
    final Directory qa = Directory('../docs/pose-qa');
    final int shots = qa
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.png') && f.path.contains('pose-'))
        .length;
    final int goldens = qa
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.png') && f.path.contains('-v'))
        .length;
    expect(shots, greaterThanOrEqualTo(250));
    expect(goldens, greaterThanOrEqualTo(40));
    expect(File('../docs/pose-qa/QA_REPORT.md').existsSync(), isTrue);
  });

  test('P2 引擎契约：GLTFLoader/SkeletonUtils/人物 API 已入包且不超预算', () {
    final File bundle = File('assets/engine/js/engine.bundle.js');
    final String js = bundle.readAsStringSync();
    expect(js.contains('setCharacter'), isTrue);
    expect(js.contains('setHair'), isTrue);
    expect(js.contains('characterChanged'), isTrue);
    expect(js.contains('retarget') || js.contains('Skeleton'), isTrue);
    expect(bundle.lengthSync(), lessThanOrEqualTo(1800 * 1024));
  });

  test('D50/D51：内置默认凭据存在；代理配置可读', () async {
    final Map<String, Object?> config = await ContentPacks.imageSourcesConfig();
    final Map<String, Object?> pexels =
        ((config['pexels'] as Map?) ?? <String, Object?>{})
            .cast<String, Object?>();
    final Map<String, Object?> tmdb =
        ((config['tmdb'] as Map?) ?? <String, Object?>{})
            .cast<String, Object?>();
    expect('${pexels['apiKey']}'.isNotEmpty, isTrue);
    expect('${tmdb['apiKey']}'.isNotEmpty, isTrue);
    expect('${tmdb['readToken']}'.isNotEmpty, isTrue);
    final NetConfig net = await loadNetConfig(proxy: 'http://127.0.0.1:7890');
    expect(net.pexelsKey, '${pexels['apiKey']}');
    expect(net.proxy, 'http://127.0.0.1:7890');
  });

  test('P4：器材实拍 ≥30 / 服装实拍 ≥54，带署名', () async {
    final Map<String, Object?> gear = await ContentPacks.gearPhotos();
    final Map<String, Object?> byKind =
        ((gear['byKind'] as Map?) ?? <String, Object?>{})
            .cast<String, Object?>();
    final Map<String, Object?> byModel =
        ((gear['byModel'] as Map?) ?? <String, Object?>{})
            .cast<String, Object?>();
    final Map<String, Object?> attr = attributionIndex();
    var gearCount = 0;
    void check(Object? list) {
      for (final Object? raw in (list as List<Object?>? ?? <Object?>[])) {
        final Map<Object?, Object?> m = raw as Map<Object?, Object?>;
        final String path = 'assets/content/gear/photo/${m['file']}';
        expect(File(path).existsSync(), isTrue, reason: '$path 缺失');
        expect(attr.containsKey(path), isTrue, reason: '$path 未署名');
        gearCount++;
      }
    }

    for (final Object? list in byKind.values) {
      check(list);
    }
    for (final Object? list in byModel.values) {
      check(list);
    }
    expect(gearCount, greaterThanOrEqualTo(30));

    final Map<String, Object?> clothing = await ContentPacks.clothingPhotos();
    final Map<String, Object?> byCategory =
        ((clothing['byCategory'] as Map?) ?? <String, Object?>{})
            .cast<String, Object?>();
    var clothingCount = 0;
    for (final MapEntry<String, Object?> entry in byCategory.entries) {
      for (final Object? raw
          in (entry.value as List<Object?>? ?? <Object?>[])) {
        final Map<Object?, Object?> m = raw as Map<Object?, Object?>;
        final String path =
            'assets/content/clothing/photo/${entry.key}/${m['file']}';
        expect(File(path).existsSync(), isTrue, reason: '$path 缺失');
        expect(attr.containsKey(path), isTrue, reason: '$path 未署名');
        clothingCount++;
      }
    }
    expect(clothingCount, greaterThanOrEqualTo(54));
    expect(byCategory.length, greaterThanOrEqualTo(9));
  });

  test('TMDB：v3 api_key 与 v4 Bearer 均可鉴权；剧集抓分集静帧', () async {
    final List<String> auths = <String>[];
    final Dio dio = Dio()
      ..httpClientAdapter = _Adapter((RequestOptions o) async {
        auths.add('${o.headers['Authorization']}');
        expect(o.uri.path.contains('/search/'), isTrue);
        return _json(<String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'id': 1,
              'title': 'Test',
              'media_type': 'tv',
              'poster_path': '/p.jpg',
              'first_air_date': '2024-01-01',
            },
          ],
        });
      });
    // v4 token → Authorization header
    final TmdbSource v4 = TmdbSource(apiKey: '', readToken: 'tok', dio: dio);
    final List<TmdbItem> items = await v4.search('demo', mediaType: 'multi');
    expect(items.single.title, 'Test');
    expect(items.single.mediaType, 'tv');
    expect(auths.last, contains('Bearer tok'));
    // v3 key → api_key 参数
    final Dio dio2 = Dio()
      ..httpClientAdapter = _Adapter((RequestOptions o) async {
        expect('${o.uri.queryParameters['api_key']}', 'key3');
        return _json(<String, Object?>{
          'results': <Object?>[
            <String, Object?>{'id': 9, 'name': '剧集', 'media_type': 'tv'},
          ],
        });
      });
    final TmdbSource v3 = TmdbSource(apiKey: 'key3', readToken: '', dio: dio2);
    final List<TmdbItem> items2 = await v3.search('x', mediaType: 'multi');
    expect(items2.single.mediaType, 'tv');
  });

  test('TMDB 剧照/分集 stills 解析', () async {
    final Dio dio = Dio()
      ..httpClientAdapter = _Adapter((RequestOptions o) async {
        if (o.uri.path.contains('/images')) {
          return _json(<String, Object?>{
            'backdrops': <Object?>[
              <String, Object?>{
                'file_path': '/b1.jpg',
                'width': 1920,
                'height': 1080
              },
            ],
          });
        }
        return _json(<String, Object?>{
          'episodes': <Object?>[
            <String, Object?>{'still_path': '/s1.jpg'},
          ],
        });
      });
    final TmdbSource source = TmdbSource(apiKey: 'k', readToken: '', dio: dio);
    final List<TmdbImage> images = await source.images(
      const TmdbItem(id: 5, mediaType: 'tv', title: '动画'),
    );
    expect(images.any((TmdbImage i) => i.filePath == '/b1.jpg'), isTrue);
    expect(images.any((TmdbImage i) => i.isStill), isTrue);
    expect(images.first.url('w780'),
        startsWith('https://image.tmdb.org/t/p/w780/'));
  });
}
